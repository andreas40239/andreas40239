'use strict';
// DOM-Menüs: Hauptmenü, Anleitung/Bestiarium, Pause, Tastenbelegung, Game Over.
const UI = (() => {
  const $ = id => document.getElementById(id);
  let assignSlot = 0, assignReturn = null;

  function show(id) {
    for (const el of document.querySelectorAll('.overlay')) el.classList.toggle('show', el.id === id);
  }
  function hideAll() { show(null); }

  function wireSounds(root) {
    for (const b of root.querySelectorAll('button')) {
      b.addEventListener('pointerenter', e => { if (e.pointerType === 'mouse') Sound.play('menuMove'); });
      b.addEventListener('pointerdown', () => { Sound.init(); });
    }
  }

  function refreshAudioLabels() {
    for (const b of document.querySelectorAll('[data-act=music]')) b.textContent = 'Musik: ' + (Sound.musicOn ? 'An' : 'Aus');
    for (const b of document.querySelectorAll('[data-act=sfx]')) b.textContent = 'Effekte: ' + (Sound.sfxOn ? 'An' : 'Aus');
  }

  function act(a) {
    Sound.init();
    switch (a) {
      case 'new':
        Sound.play('menuSelect'); Sound.startMusic();
        hideAll(); newGame(); break;
      case 'help':
        Sound.play('menuSelect'); buildHelp(); show('help'); break;
      case 'music': Sound.toggleMusic(); Sound.startMusic(); Sound.play('menuSelect'); refreshAudioLabels(); break;
      case 'sfx': Sound.toggleSfx(); Sound.play('menuSelect'); refreshAudioLabels(); break;
      case 'resume': Sound.play('menuBack'); hideAll(); G.state = 'play'; break;
      case 'assignMenu': Sound.play('menuSelect'); buildSlots(); show('slots'); break;
      case 'toMenu': Sound.play('menuBack'); toMenu(); break;
      case 'retry': Sound.play('menuSelect'); hideAll(); newGame(); break;
      case 'backHelp': Sound.play('menuBack'); show(G.demo ? 'menu' : 'pause'); break;
      case 'backSlots': Sound.play('menuBack'); show('pause'); break;
      case 'closeAssign': Sound.play('menuBack'); closeAssign(); break;
    }
  }

  function toMenu() {
    G.demo = true; G.state = 'menu'; G.level = 1 + Math.floor(Math.random() * 3);
    startLevel(12345 + G.level);
    show('menu');
  }

  function pause() {
    if (G.state !== 'play') return;
    G.state = 'paused';
    Sound.play('menuSelect');
    show('pause');
  }

  // ---------- Tastenbelegung ----------
  function openAssign(slot, ret) {
    if (G.state === 'play') G.state = 'paused';
    assignSlot = slot; assignReturn = ret || null;
    Sound.play('menuSelect');
    $('assignTitle').textContent = 'Taste ' + (slot + 1) + ' belegen';
    const grid = $('assignGrid');
    grid.innerHTML = '';
    const p = G.player;
    for (const id of ACTIONS) {
      const ok = canUse(id);
      const b = document.createElement('button');
      b.className = 'opt' + (G.slots[slot] === id ? ' current' : '') + (ok ? '' : ' locked');
      const info = WEAPONS[id]
        ? (ok ? 'Stufe ' + p.weapons[id] + ' · ' + WEAPONS[id].desc : 'Noch nicht gefunden')
        : (ok ? SPELLS[id].mana + ' Mana · ' + SPELLS[id].desc : 'Lernbar ab Stufe ' + SPELLS[id].lvl);
      b.innerHTML = `<img src="${iconDataURL(id, 64)}" alt=""><span class="n">${actionName(id)}</span><span class="i">${info}</span>`;
      if (ok) b.addEventListener('click', () => assign(id));
      else b.disabled = true;
      grid.appendChild(b);
    }
    const clr = document.createElement('button');
    clr.className = 'opt';
    clr.innerHTML = `<img src="${iconDataURL(null, 64)}" alt=""><span class="n">Leer</span><span class="i">Taste freigeben</span>`;
    clr.addEventListener('click', () => assign(null));
    grid.appendChild(clr);
    wireSounds(grid);
    show('assign');
  }

  function assign(id) {
    if (id) {
      const other = G.slots.indexOf(id);
      if (other >= 0 && other !== assignSlot) G.slots[other] = G.slots[assignSlot];
    }
    G.slots[assignSlot] = id;
    Sound.play('menuSelect');
    closeAssign();
  }

  function closeAssign() {
    if (assignReturn === 'slots') { buildSlots(); show('slots'); return; }
    hideAll();
    if (G.state === 'paused') G.state = 'play';
  }

  function buildSlots() {
    const box = $('slotList');
    box.innerHTML = '';
    for (let i = 0; i < 3; i++) {
      const id = G.slots[i];
      const b = document.createElement('button');
      b.className = 'opt';
      b.innerHTML = `<img src="${iconDataURL(id, 64)}" alt=""><span class="n">Taste ${i + 1}</span><span class="i">${id ? actionName(id) : 'leer'}</span>`;
      b.addEventListener('click', () => openAssign(i, 'slots'));
      box.appendChild(b);
    }
    wireSounds(box);
  }

  function buildHelp() {
    const rows = Object.values(MONSTERS).map(m =>
      `<tr><td>${m.name}</td><td>${m.trait}</td><td class="weak">${m.weak}</td><td>ab Ebene ${m.minLvl}</td></tr>`).join('');
    $('bestiary').innerHTML = `<tr><th>Monster</th><th>Eigenschaft</th><th>Schwäche</th><th></th></tr>${rows}`;
  }

  function showGameOver() {
    const p = G.player;
    $('goStats').textContent = `Ebene ${G.level} erreicht · Stufe ${p.lvl} · ${G.stats.kills} Monster besiegt`;
    show('gameover');
  }

  // Zurück-Taste (Android) / Escape
  function back() {
    const open = document.querySelector('.overlay.show');
    if (!open) { if (G.state === 'play') { pause(); return true; } return false; }
    switch (open.id) {
      case 'pause': act('resume'); return true;
      case 'assign': act('closeAssign'); return true;
      case 'slots': act('backSlots'); return true;
      case 'help': act('backHelp'); return true;
      case 'gameover': act('toMenu'); return true;
      default: return false;
    }
  }

  function init() {
    for (const b of document.querySelectorAll('[data-act]')) b.addEventListener('click', () => act(b.dataset.act));
    wireSounds(document);
    refreshAudioLabels();
    show('menu');
  }

  return { init, pause, openAssign, showGameOver, back, toMenu };
})();
