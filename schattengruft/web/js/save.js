'use strict';
// Speicherstände (5 Plätze in localStorage) und Wiedereinstieg nach dem Tod.
// Gespeichert wird der komplette Ebenenzustand: Das Labyrinth wird aus dem Seed neu erzeugt,
// dazu kommen überlebende Monster, geöffnete Truhen, liegende Beute und die aufgedeckte Karte.
const SAVE_SLOTS = 5;
const SAVE_KEY = 'sg_save_';

const Save = (() => {
  function packBits(arr) {
    let s = '';
    for (let i = 0; i < arr.length; i += 8) {
      let b = 0;
      for (let k = 0; k < 8; k++) if (arr[i + k]) b |= 1 << k;
      s += String.fromCharCode(b);
    }
    return btoa(s);
  }
  function unpackBits(str, n) {
    const s = atob(str), out = new Uint8Array(n);
    for (let i = 0; i < n; i++) out[i] = (s.charCodeAt(i >> 3) >> (i & 7)) & 1;
    return out;
  }
  const r2 = v => Math.round(v * 100) / 100;

  function serialize() {
    const p = G.player;
    return {
      v: 1, savedAt: Date.now(), level: G.level, seed: G.levelSeed,
      player: {
        hp: r2(p.hp), maxHp: p.maxHp, mana: r2(p.mana), maxMana: p.maxMana, xp: p.xp, lvl: p.lvl,
        weapons: Object.assign({}, p.weapons), armor: p.armor, held: p.held, x: r2(p.x), y: r2(p.y)
      },
      slots: G.slots.slice(),
      stats: Object.assign({}, G.stats),
      seenTypes: Array.from(G.seenTypes),
      monsters: G.monsters.filter(m => !m.dead).map(m => ({
        t: m.type, hx: r2(m.homeX), hy: r2(m.homeY), hp: Math.max(1, Math.round(m.hp)),
        s: m.small ? 1 : 0, rv: m.revived ? 1 : 0, b: m.bones ? 1 : 0
      })),
      chests: G.chests.map(c => (c.open ? 1 : 0)),
      drops: G.drops.map(d => ({ k: d.kind, x: r2(d.x), y: r2(d.y) })),
      seen: packBits(G.seen)
    };
  }

  function apply(d) {
    G.demo = false;
    G.level = d.level;
    G.player = newPlayer();
    const p = G.player;
    Object.assign(p, {
      hp: d.player.hp, maxHp: d.player.maxHp, mana: d.player.mana, maxMana: d.player.maxMana,
      xp: d.player.xp, lvl: d.player.lvl, armor: d.player.armor || 0, held: d.player.held || 'sword'
    });
    p.weapons = Object.assign({ sword: 1, axe: 0, bow: 0 }, d.player.weapons);
    G.slots = d.slots.slice(0, 3);
    G.stats = Object.assign({ kills: 0, time: 0, deaths: 0 }, d.stats);
    G.seenTypes = new Set(d.seenTypes || []);
    startLevel(d.seed);
    // Monster stehen beim Laden in ihrem Revier (kein Hinterhalt direkt nach dem Laden)
    G.monsters = d.monsters.map(s => {
      const m = spawnMonster(s.t, s.hx, s.hy, !!s.s);
      m.hp = Math.min(s.hp, m.maxHp); m.revived = !!s.rv;
      if (s.b) { m.bones = true; m.reviveT = 4; m.hp = 0; }
      return m;
    });
    G.chests.forEach((c, i) => { c.open = !!d.chests[i]; });
    G.drops = (d.drops || []).map(o => ({ kind: o.k, x: o.x, y: o.y }));
    G.seen = unpackBits(d.seen, G.map.W * G.map.H);
    G.minimapDirty = true;
    p.x = d.player.x; p.y = d.player.y;
    G.cam.x = p.x; G.cam.y = p.y;
    G.flowFrom = -1;
    updateVisibility(true); updateFlow();
    G.toasts = [];
    G.state = 'play';
  }

  function read(i) {
    try { const s = localStorage.getItem(SAVE_KEY + i); return s ? JSON.parse(s) : null; } catch (e) { return null; }
  }
  function write(i) {
    try { localStorage.setItem(SAVE_KEY + i, JSON.stringify(serialize())); return true; } catch (e) { return false; }
  }
  function remove(i) { try { localStorage.removeItem(SAVE_KEY + i); } catch (e) { } }
  function list() { const a = []; for (let i = 0; i < SAVE_SLOTS; i++) a.push(read(i)); return a; }
  function newest() {
    let best = -1, t = 0;
    list().forEach((d, i) => { if (d && d.savedAt > t) { t = d.savedAt; best = i; } });
    return best;
  }
  function firstFree() { return list().findIndex(d => !d); }

  // Automatisch in den aktiven Platz speichern (Treppe, Hauptmenü, App im Hintergrund)
  function autosave() {
    if (G.activeSlot == null || G.demo || !G.player || G.player.hp <= 0) return false;
    if (G.state !== 'play' && G.state !== 'paused') return false;
    return write(G.activeSlot);
  }

  function load(i) {
    const d = read(i);
    if (!d) return false;
    try { apply(d); } catch (e) { return false; }
    G.activeSlot = i;
    return true;
  }

  return { read, write, remove, list, newest, firstFree, autosave, load };
})();

// Nach dem Tod: gleiche Ebene, alles Erreichte bleibt, überlebende Monster kehren geheilt ins Revier zurück.
function respawn() {
  const p = G.player;
  G.stats.deaths = (G.stats.deaths || 0) + 1;
  p.hp = p.maxHp; p.mana = p.maxMana;
  p.inv = 2.5; p.kx = p.ky = 0; p.atk = null; p.cds = {}; p.castT = 0;
  p.x = G.map.start.x; p.y = G.map.start.y; p.face = Math.PI / 2;
  for (const m of G.monsters) {
    if (m.bones) continue;
    m.x = m.homeX; m.y = m.homeY; m.hp = m.maxHp;
    m.aggro = false; m.returning = false; m.trail = []; m.lastTile = -1;
    m.para = 0; m.slow = 0; m.kx = m.ky = 0; m.calmT = 3; m.lostT = 0;
  }
  G.projectiles = []; G.effects = []; G.particles = []; G.texts = [];
  G.cam.x = p.x; G.cam.y = p.y;
  G.flowFrom = -1;
  updateVisibility(true); updateFlow();
  G.toasts = [];
  G.state = 'play';
  toast('Du erwachst am Eingang von Ebene ' + G.level, '#d9cfff');
  toast('Besiegte Monster bleiben besiegt', '#b8aee6');
  Save.autosave();
}
