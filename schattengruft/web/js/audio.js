'use strict';
// Prozedurale Audio-Engine: düstere Hintergrundmusik + alle Soundeffekte per WebAudio synthetisiert.
// Auf schwächere Android-Geräte ausgelegt: großer Audiopuffer, günstiger Delay-Hall statt Faltungshall,
// Stimmenbegrenzung, Aufräumen beendeter Knoten und ein Wächter, der einen hängenden Kontext neu startet.
const Sound = (() => {
  let ctx = null, master, reverb, noiseBuf, musicBus, sfxBus;
  let musicOn = true, sfxOn = true;
  let musicRunning = false, schedTimer = null, nextStep = 0, stepIdx = 0, drone = null;
  let melodyIdx = 4;
  let sfxVoices = 0, musicVoices = 0, appPaused = false, wantMusic = false;
  let watchdog = null, lastCT = -1, stuck = 0;
  const MAX_SFX = 22, HARD_SFX = 34, MAX_MUSIC = 26;
  const PRIORITY = new Set(['playerHurt', 'levelUp', 'chest', 'gameOver', 'stairs', 'menuSelect', 'menuBack', 'upgrade', 'heart', 'mana', 'armor']);
  const lastPlay = {};

  try {
    const s = JSON.parse(localStorage.getItem('sg_audio') || '{}');
    if (s.music === false) musicOn = false;
    if (s.sfx === false) sfxOn = false;
  } catch (e) { /* ignorieren */ }
  function save() {
    try { localStorage.setItem('sg_audio', JSON.stringify({ music: musicOn, sfx: sfxOn })); } catch (e) { }
  }

  // Günstiger Hall: vier rückgekoppelte, tiefpassgefilterte Verzögerungen (kein ConvolverNode).
  function makeReverb() {
    const input = ctx.createGain(), out = ctx.createGain();
    out.gain.value = 0.5;
    const pre = ctx.createDelay(0.1); pre.delayTime.value = 0.03;
    input.connect(pre);
    [[0.113, 0.62, -0.7], [0.157, 0.6, 0.7], [0.191, 0.58, -0.3], [0.233, 0.56, 0.3]].forEach(([t, fb, pan]) => {
      const d = ctx.createDelay(0.5); d.delayTime.value = t;
      const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 2400;
      const g = ctx.createGain(); g.gain.value = fb;
      pre.connect(d); d.connect(lp); lp.connect(g); g.connect(d);
      if (ctx.createStereoPanner) {
        const p = ctx.createStereoPanner(); p.pan.value = pan;
        lp.connect(p); p.connect(out);
      } else lp.connect(out);
    });
    out.connect(master);
    return input;
  }

  function makeBus(vol) {
    const dry = ctx.createGain(), wet = ctx.createGain();
    const vDry = ctx.createGain(), vWet = ctx.createGain();
    vDry.gain.value = vol; vWet.gain.value = vol;
    dry.connect(vDry); vDry.connect(master);
    wet.connect(vWet); vWet.connect(reverb);
    return {
      dry, wet,
      set(v) {
        const t = ctx.currentTime;
        vDry.gain.setTargetAtTime(v, t, 0.1);
        vWet.gain.setTargetAtTime(v, t, 0.1);
      }
    };
  }

  function init() {
    if (ctx) { if (ctx.state === 'suspended' && !appPaused) ctx.resume().catch(() => { }); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    // 'playback' = größerer Puffer -> kein Knacksen/Rauschen bei CPU-Spitzen (etwas mehr Latenz).
    try { ctx = new AC({ latencyHint: 'playback' }); } catch (e) { ctx = new AC(); }
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -16; comp.knee.value = 10; comp.ratio.value = 5;
    comp.attack.value = 0.004; comp.release.value = 0.25;
    comp.connect(ctx.destination);
    master = ctx.createGain(); master.gain.value = 0.9; master.connect(comp);
    reverb = makeReverb();
    musicBus = makeBus(musicOn ? 0.55 : 0);
    sfxBus = makeBus(sfxOn ? 0.9 : 0);
    const len = ctx.sampleRate * 2;
    noiseBuf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    sfxVoices = 0; musicVoices = 0; lastCT = -1; stuck = 0;
    ctx.onstatechange = () => { if (ctx && ctx.state === 'suspended' && !appPaused && !document.hidden) ctx.resume().catch(() => { }); };
    if (!watchdog) watchdog = setInterval(checkHealth, 1000);
  }

  // Wächter: Kontext hängt (Zeit steht trotz 'running') oder wurde vom System geschlossen -> neu aufbauen.
  function checkHealth() {
    if (!ctx || appPaused || document.hidden) { stuck = 0; return; }
    if (ctx.state === 'closed') { rebuild(); return; }
    if (ctx.state === 'suspended') { ctx.resume().catch(() => { }); return; }
    if (ctx.currentTime === lastCT) { if (++stuck >= 3) rebuild(); }
    else stuck = 0;
    lastCT = ctx.currentTime;
  }

  function rebuild() {
    const old = ctx;
    const hadMusic = musicRunning || wantMusic;
    if (musicRunning) { clearInterval(schedTimer); musicRunning = false; drone = null; }
    ctx = null;
    try { old.close(); } catch (e) { }
    init();
    if (hadMusic) startMusic();
  }

  // Beendete Klangquellen: alle zugehörigen Knoten trennen, damit nichts liegen bleibt.
  function track(src, nodes, bus) {
    const music = bus === musicBus;
    if (music) musicVoices++; else sfxVoices++;
    src.onended = () => {
      for (const n of nodes) { try { n.disconnect(); } catch (e) { } }
      if (music) musicVoices--; else sfxVoices--;
    };
  }

  function route(node, bus, wet, nodes) {
    node.connect(bus.dry);
    if (wet > 0) {
      const s = ctx.createGain(); s.gain.value = wet;
      node.connect(s); s.connect(bus.wet);
      nodes.push(s);
    }
  }

  function env(g, t0, vol, a, dur) {
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(Math.max(vol, 0.0002), t0 + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + Math.max(dur, a + 0.01));
  }

  // Oszillator-Ton mit Hüllkurve und optionalem Filter
  function tone(type, f, t0, dur, o) {
    o = o || {};
    const bus = o.bus || sfxBus;
    if (bus === sfxBus && sfxVoices >= HARD_SFX) return null; // harte Obergrenze gleichzeitiger Effektstimmen
    const osc = ctx.createOscillator();
    osc.type = type;
    osc.frequency.setValueAtTime(f, t0);
    if (o.f1) osc.frequency.exponentialRampToValueAtTime(Math.max(1, o.f1), t0 + (o.glide || dur));
    if (o.detune) osc.detune.value = o.detune;
    const g = ctx.createGain();
    env(g, t0, o.vol || 0.2, o.a || 0.005, dur);
    const nodes = [osc, g];
    let n = osc;
    if (o.filter) {
      const fl = ctx.createBiquadFilter();
      fl.type = o.filter; fl.frequency.setValueAtTime(o.ff || 1000, t0);
      if (o.ff1) fl.frequency.exponentialRampToValueAtTime(o.ff1, t0 + dur);
      fl.Q.value = o.q || 1;
      osc.connect(fl); n = fl; nodes.push(fl);
    }
    if (o.vib) {
      const lfo = ctx.createOscillator(), lg = ctx.createGain();
      lfo.frequency.value = o.vib; lg.gain.value = o.vibAmt || f * 0.03;
      lfo.connect(lg); lg.connect(osc.frequency);
      lfo.start(t0); lfo.stop(t0 + dur + 0.05);
      nodes.push(lfo, lg);
    }
    n.connect(g);
    route(g, bus, o.wet == null ? 0.15 : o.wet, nodes);
    track(osc, nodes, bus);
    osc.start(t0); osc.stop(t0 + dur + 0.05);
    return osc;
  }

  // Gefiltertes Rauschen
  function noise(t0, dur, o) {
    o = o || {};
    const bus = o.bus || sfxBus;
    if (bus === sfxBus && sfxVoices >= HARD_SFX) return null; // harte Obergrenze gleichzeitiger Effektstimmen
    const s = ctx.createBufferSource();
    s.buffer = noiseBuf; s.loop = true;
    const fl = ctx.createBiquadFilter();
    fl.type = o.type || 'bandpass';
    fl.frequency.setValueAtTime(o.f || 1000, t0);
    if (o.f1) fl.frequency.exponentialRampToValueAtTime(o.f1, t0 + dur);
    fl.Q.value = o.q || 1;
    const g = ctx.createGain();
    env(g, t0, o.vol || 0.2, o.a || 0.005, dur);
    s.connect(fl); fl.connect(g);
    const nodes = [s, fl, g];
    route(g, bus, o.wet == null ? 0.1 : o.wet, nodes);
    track(s, nodes, bus);
    s.start(t0, Math.random() * 1.5); s.stop(t0 + dur + 0.05);
  }

  // FM-Glocke
  function bell(f, t0, dur, o) {
    o = o || {};
    const bus = o.bus || sfxBus;
    if (bus === sfxBus && sfxVoices >= HARD_SFX) return null; // harte Obergrenze gleichzeitiger Effektstimmen
    const car = ctx.createOscillator(), mod = ctx.createOscillator();
    const mg = ctx.createGain(), g = ctx.createGain();
    car.frequency.value = f; mod.frequency.value = f * (o.ratio || 3.5);
    mg.gain.setValueAtTime(f * (o.index || 2.5), t0);
    mg.gain.exponentialRampToValueAtTime(f * 0.05, t0 + dur);
    mod.connect(mg); mg.connect(car.frequency);
    env(g, t0, o.vol || 0.08, o.a || 0.004, dur);
    car.connect(g);
    const nodes = [car, mod, mg, g];
    route(g, bus, o.wet == null ? 0.4 : o.wet, nodes);
    track(car, nodes, bus);
    car.start(t0); mod.start(t0); car.stop(t0 + dur + 0.05); mod.stop(t0 + dur + 0.05);
  }

  const midi = n => 440 * Math.pow(2, (n - 69) / 12);

  // ================= MUSIK =================
  // D-Moll (harmonisch) mit neapolitanischem Es-Dur: Dm Bb Gm A | Dm Eb Bb A
  const CHORDS = [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52], [50, 53, 57], [51, 55, 58], [46, 50, 53], [45, 49, 52]];
  const MELODY = [62, 64, 65, 67, 69, 70, 73, 74, 76, 77, 79, 81];
  const STEP = 60 / 58 / 2;

  function startDrone() {
    const t = ctx.currentTime;
    const out = ctx.createGain();
    out.gain.setValueAtTime(0.0001, t);
    out.gain.exponentialRampToValueAtTime(0.14, t + 4);
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 170; lp.Q.value = 3;
    const lfo = ctx.createOscillator(), lg = ctx.createGain();
    lfo.frequency.value = 0.06; lg.gain.value = 90;
    lfo.connect(lg); lg.connect(lp.frequency);
    const oscs = [lfo], nodes = [lfo, lg, lp, out];
    [[26, 0, 1], [38, -6, 0.8], [33, 3, 0.35]].forEach(([n, det, v]) => {
      const o = ctx.createOscillator(); o.type = 'sawtooth';
      o.frequency.value = midi(n); o.detune.value = det;
      const g = ctx.createGain(); g.gain.value = v;
      o.connect(g); g.connect(lp); o.start(t); oscs.push(o); nodes.push(o, g);
    });
    lp.connect(out); route(out, musicBus, 0.3, nodes);
    lfo.start(t);
    drone = { out, oscs, nodes };
  }

  // Akkordfläche: ein Sägezahn je Ton + Sub-Sinus, gemeinsamer Filter und Hüllkurve (wenige Knoten).
  function pad(notes, t, dur) {
    const fl = ctx.createBiquadFilter(); fl.type = 'lowpass'; fl.Q.value = 0.7;
    fl.frequency.setValueAtTime(520, t); fl.frequency.linearRampToValueAtTime(900, t + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.05, t + 2.6);
    g.gain.setValueAtTime(0.05, t + dur - 0.5);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur + 1.6);
    const nodes = [fl, g];
    const oscs = notes.map((n, i) => {
      const o = ctx.createOscillator(); o.type = 'sawtooth';
      o.frequency.value = midi(n); o.detune.value = (i - 1) * 7;
      o.connect(fl); nodes.push(o); return o;
    });
    const sub = ctx.createOscillator(); sub.frequency.value = midi(notes[0] - 12);
    const sg = ctx.createGain(); sg.gain.value = 1.4;
    sub.connect(sg); sg.connect(g); nodes.push(sub, sg); oscs.push(sub);
    fl.connect(g);
    route(g, musicBus, 0.7, nodes);
    track(oscs[0], nodes, musicBus);
    for (const o of oscs) { o.start(t); o.stop(t + dur + 1.7); }
    // Chor-artige Formantstimme
    tone('sawtooth', midi(notes[2] + 12), t + 0.5, dur, {
      bus: musicBus, vol: 0.012, a: 3, filter: 'bandpass', ff: 800, q: 6, wet: 0.9, vib: 4.5, vibAmt: 3
    });
  }

  function heartbeat(t, amp) {
    tone('sine', 72, t, 0.32, { bus: musicBus, f1: 36, glide: 0.25, vol: 0.38 * amp, a: 0.004, wet: 0.2 });
    noise(t, 0.08, { bus: musicBus, type: 'lowpass', f: 200, vol: 0.15 * amp, wet: 0.1 });
  }

  function playStep(i, t) {
    const inBar = i % 8, chord = CHORDS[Math.floor(i / 16) % CHORDS.length];
    if (i % 16 === 0) pad(chord, t, STEP * 16);
    if (musicVoices > MAX_MUSIC) return; // Notbremse: Zierstimmen auslassen
    if (inBar === 0) { heartbeat(t, 1); heartbeat(t + 0.24, 0.6); }
    if (i % 16 === 0 || i % 16 === 11) {
      tone('triangle', midi(chord[0] - 12), t, 1.8, { bus: musicBus, vol: 0.11, filter: 'lowpass', ff: 600, ff1: 120, wet: 0.3 });
    }
    const p = inBar % 2 === 0 ? 0.26 : 0.1;
    if (Math.random() < p) {
      melodyIdx = clamp(melodyIdx + Math.floor(Math.random() * 5) - 2, 0, MELODY.length - 1);
      let n = MELODY[melodyIdx];
      if (Math.random() < 0.5) n = chord[Math.floor(Math.random() * 3)] + 12;
      bell(midi(n), t, 3.2, { bus: musicBus, vol: 0.045, ratio: 2.76, index: 1.6, wet: 0.95 });
    }
    if (i % 32 === 24) noise(t, 3.5, { bus: musicBus, type: 'bandpass', f: 900, f1: 2600, q: 9, vol: 0.05, a: 1.5, wet: 1 });
    if (i % 64 === 40) { // fernes Kettenrasseln
      for (let k = 0; k < 4; k++) noise(t + k * 0.08 + Math.random() * 0.03, 0.05, { bus: musicBus, f: 3500 + Math.random() * 1500, q: 12, vol: 0.05, wet: 1 });
    }
  }

  function schedule() {
    if (!ctx || ctx.state !== 'running') return;
    // Nach Rucklern/Pausen nicht alle verpassten Schritte auf einmal nachholen (Stimmenlawine).
    if (nextStep < ctx.currentTime - 0.05) nextStep = ctx.currentTime + 0.05;
    while (nextStep < ctx.currentTime + 0.3) {
      playStep(stepIdx, nextStep);
      nextStep += STEP; stepIdx++;
    }
  }

  function startMusic() {
    wantMusic = true;
    if (!ctx || musicRunning) return;
    musicRunning = true;
    nextStep = ctx.currentTime + 0.15; stepIdx = 0;
    startDrone();
    schedTimer = setInterval(schedule, 60);
  }

  function stopMusic() {
    wantMusic = false;
    if (!musicRunning) return;
    musicRunning = false;
    clearInterval(schedTimer);
    if (drone) {
      const t = ctx.currentTime, dr = drone;
      dr.out.gain.setTargetAtTime(0.0001, t, 0.4);
      dr.oscs.forEach(o => o.stop(t + 2));
      dr.oscs[0].onended = () => dr.nodes.forEach(n => { try { n.disconnect(); } catch (e) { } });
      drone = null;
    }
  }

  // ================= SOUNDEFFEKTE =================
  const SFX = {
    sword(t) {
      noise(t, 0.2, { f: 1200, f1: 5000, q: 1.6, vol: 0.32 });
      tone('sine', 2600, t + 0.03, 0.18, { f1: 2200, vol: 0.04, wet: 0.3 });
    },
    axe(t) {
      noise(t, 0.34, { type: 'lowpass', f: 250, f1: 1600, q: 2, vol: 0.45, a: 0.06 });
      tone('sine', 140, t + 0.12, 0.25, { f1: 50, vol: 0.25 });
    },
    bow(t) {
      tone('triangle', 260, t, 0.22, { f1: 170, vol: 0.28 });
      noise(t, 0.02, { f: 3000, vol: 0.2 });
      noise(t + 0.02, 0.22, { type: 'highpass', f: 2500, f1: 6000, vol: 0.1 });
    },
    hit(t) {
      noise(t, 0.09, { type: 'lowpass', f: 1100, vol: 0.4 });
      tone('sine', 190, t, 0.12, { f1: 70, vol: 0.3 });
    },
    weak(t) {
      noise(t, 0.12, { type: 'lowpass', f: 1800, vol: 0.5 });
      tone('square', 110, t, 0.15, { f1: 45, vol: 0.18, filter: 'lowpass', ff: 900 });
      tone('sine', 880, t + 0.02, 0.2, { f1: 1320, vol: 0.06, wet: 0.4 });
    },
    resist(t) {
      tone('sine', 920, t, 0.25, { vol: 0.1, wet: 0.3 });
      tone('sine', 1390, t, 0.18, { vol: 0.07, wet: 0.3 });
      noise(t, 0.03, { f: 4000, vol: 0.15 });
    },
    arrowWall(t) { noise(t, 0.05, { f: 2200, vol: 0.18 }); tone('triangle', 400, t, 0.06, { f1: 200, vol: 0.08 }); },
    paralyze(t) {
      for (let k = 0; k < 4; k++) tone('sine', 1500 - k * 180, t + k * 0.05, 0.9, { f1: 300 + k * 40, vol: 0.06, vib: 9, vibAmt: 40, wet: 0.7 });
      noise(t, 0.6, { f: 3000, f1: 800, q: 5, vol: 0.08, wet: 0.6 });
    },
    fire(t) {
      noise(t, 0.9, { type: 'lowpass', f: 400, f1: 1600, q: 1, vol: 0.4, a: 0.15, wet: 0.3 });
      tone('sawtooth', 70, t, 0.8, { f1: 40, vol: 0.1, filter: 'lowpass', ff: 300 });
      for (let k = 0; k < 8; k++) noise(t + Math.random() * 0.9, 0.02, { f: 2000 + Math.random() * 3000, q: 2, vol: 0.12 });
    },
    ice(t) {
      noise(t, 1.2, { type: 'highpass', f: 3000, f1: 6000, vol: 0.06, a: 0.3, wet: 0.6 });
      for (let k = 0; k < 6; k++) bell(2000 + Math.random() * 2500, t + Math.random() * 1.1, 0.5, { vol: 0.03, ratio: 1.41, index: 1, wet: 0.7 });
    },
    shard(t) { tone('sine', 2500 + Math.random() * 1500, t, 0.12, { vol: 0.04, wet: 0.4 }); noise(t, 0.04, { type: 'highpass', f: 5000, vol: 0.06 }); },
    burn(t) { noise(t, 0.12, { f: 900, q: 1, vol: 0.12 }); },
    step(t) {
      noise(t, 0.06, { type: 'lowpass', f: 500 + Math.random() * 400, q: 1, vol: 0.16, wet: 0.05 });
      noise(t, 0.03, { f: 2500, q: 3, vol: 0.03, wet: 0 });
    },
    growl_slime(t) { tone('sine', 230, t, 0.3, { f1: 80, vol: 0.25, filter: 'lowpass', ff: 600 }); tone('sine', 160, t + 0.15, 0.25, { f1: 300, vol: 0.15 }); },
    growl_bat(t) { tone('square', 3200, t, 0.08, { f1: 2400, vol: 0.06 }); tone('square', 3600, t + 0.1, 0.07, { f1: 2800, vol: 0.05 }); },
    growl_skeleton(t) { for (let k = 0; k < 6; k++) noise(t + k * 0.05, 0.03, { f: 1800 + Math.random() * 800, q: 6, vol: 0.2 }); },
    growl_ghost(t) { tone('sine', 420, t, 1.2, { f1: 620, glide: 0.6, vol: 0.09, a: 0.3, vib: 6, vibAmt: 15, wet: 0.9 }); },
    growl_imp(t) { for (let k = 0; k < 4; k++) tone('square', 700 + k * 40, t + k * 0.09, 0.07, { f1: 500, vol: 0.06, filter: 'lowpass', ff: 2000 }); },
    growl_golem(t) { tone('sawtooth', 55, t, 0.9, { f1: 38, vol: 0.25, a: 0.1, filter: 'lowpass', ff: 220, wet: 0.3 }); noise(t, 0.7, { type: 'lowpass', f: 150, vol: 0.2, a: 0.1 }); },
    monsterDie(t) {
      tone('sawtooth', 320, t, 0.45, { f1: 40, vol: 0.18, filter: 'lowpass', ff: 1500, ff1: 200 });
      noise(t, 0.3, { type: 'lowpass', f: 1200, f1: 200, vol: 0.25 });
    },
    bones(t) { for (let k = 0; k < 5; k++) noise(t + k * 0.05 + Math.random() * 0.02, 0.03, { f: 1500 + Math.random() * 1500, q: 5, vol: 0.2 }); },
    playerHurt(t) {
      tone('sawtooth', 240, t, 0.25, { f1: 110, vol: 0.2, filter: 'lowpass', ff: 1400 });
      noise(t, 0.15, { type: 'lowpass', f: 1500, vol: 0.3 });
    },
    fireball(t) { noise(t, 0.35, { f: 500, f1: 1400, q: 1.5, vol: 0.2, a: 0.05 }); },
    chest(t) {
      tone('sawtooth', 110, t, 0.35, { f1: 160, vol: 0.08, filter: 'lowpass', ff: 700, vib: 18, vibAmt: 12 });
      [62, 65, 69, 74].forEach((n, k) => bell(midi(n + 12), t + 0.25 + k * 0.09, 1.2, { vol: 0.06, ratio: 2, index: 1.2, wet: 0.5 }));
    },
    heart(t) { tone('sine', midi(76), t, 0.2, { vol: 0.12 }); tone('sine', midi(81), t + 0.1, 0.35, { vol: 0.12, wet: 0.3 }); },
    mana(t) { tone('sine', 700, t, 0.5, { f1: 1600, vol: 0.09, vib: 12, vibAmt: 30, wet: 0.6 }); },
    armor(t) {
      for (let k = 0; k < 3; k++) noise(t + k * 0.06, 0.05, { f: 2500 + k * 400, q: 8, vol: 0.18 });
      tone('sine', 520, t + 0.15, 0.6, { vol: 0.08, wet: 0.4 }); tone('sine', 780, t + 0.15, 0.5, { vol: 0.05, wet: 0.4 });
      [50, 57, 62].forEach((n, k) => tone('triangle', midi(n + 12), t + 0.25 + k * 0.1, 0.5, { vol: 0.09, wet: 0.4 }));
    },
    upgrade(t) { [57, 62, 65, 69, 74].forEach((n, k) => tone('triangle', midi(n), t + k * 0.08, 0.5, { vol: 0.1, wet: 0.4 })); },
    levelUp(t) {
      [50, 57, 62, 65, 69, 74].forEach((n, k) => bell(midi(n + 12), t + k * 0.12, 2.2, { vol: 0.07, ratio: 2, index: 1.5, wet: 0.8 }));
      tone('sawtooth', midi(38), t, 2.5, { vol: 0.06, a: 0.4, filter: 'lowpass', ff: 400, ff1: 1200, wet: 0.5 });
    },
    stairs(t) {
      for (let k = 0; k < 5; k++) noise(t + k * 0.16, 0.07, { type: 'lowpass', f: 700 - k * 90, vol: 0.2 });
      bell(70, t + 0.6, 4, { vol: 0.2, ratio: 1.47, index: 3, wet: 0.9 });
    },
    noMana(t) { tone('square', 110, t, 0.18, { vol: 0.08, filter: 'lowpass', ff: 800 }); },
    menuMove(t) { tone('sine', 880, t, 0.06, { vol: 0.07, wet: 0.2 }); },
    menuSelect(t) {
      tone('triangle', midi(62), t, 0.25, { vol: 0.12, wet: 0.5 });
      tone('triangle', midi(69), t + 0.08, 0.4, { vol: 0.12, wet: 0.5 });
    },
    menuBack(t) {
      tone('triangle', midi(69), t, 0.2, { vol: 0.1, wet: 0.4 });
      tone('triangle', midi(62), t + 0.07, 0.3, { vol: 0.1, wet: 0.4 });
    },
    gameOver(t) {
      [62, 58, 55, 50].forEach((n, k) => tone('sawtooth', midi(n - 12), t + k * 0.35, 2.5, { vol: 0.07, a: 0.1, filter: 'lowpass', ff: 900, ff1: 200, wet: 0.8 }));
      bell(55, t, 5, { vol: 0.2, ratio: 1.4, index: 4, wet: 1 });
    }
  };

  const THROTTLE = { step: 0.12, shard: 0.07, burn: 0.15, hit: 0.05, resist: 0.08, weak: 0.06 };
  function play(name, delay) {
    if (!ctx || !sfxOn || !SFX[name] || ctx.state !== 'running') return;
    if (sfxVoices >= MAX_SFX && !PRIORITY.has(name)) return;
    const now = ctx.currentTime;
    if (lastPlay[name] && now - lastPlay[name] < (THROTTLE[name] || 0.04)) return;
    lastPlay[name] = now;
    SFX[name](now + 0.01 + (delay || 0));
  }

  return {
    init, play, startMusic, stopMusic,
    get musicOn() { return musicOn; },
    get sfxOn() { return sfxOn; },
    toggleMusic() {
      musicOn = !musicOn; save();
      if (ctx) musicBus.set(musicOn ? 0.55 : 0);
      return musicOn;
    },
    toggleSfx() {
      sfxOn = !sfxOn; save();
      if (ctx) sfxBus.set(sfxOn ? 0.9 : 0);
      return sfxOn;
    },
    suspend() { appPaused = true; if (ctx && ctx.state === 'running') ctx.suspend(); },
    resume() { appPaused = false; stuck = 0; if (ctx && ctx.state !== 'running') ctx.resume().catch(() => { }); },
    get voices() { return { sfx: sfxVoices, music: musicVoices, state: ctx ? ctx.state : 'none' }; }
  };
})();
