'use strict';
// DOM-Menüs: Hauptmenü, Anleitung/Bestiarium, Pause, Tastenbelegung, Game Over.
const UI = (() => {
  const $ = id => document.getElementById(id);
  let assignSlot = 0, assignReturn = null;
  let savesMode = 'save', savesReturn = 'pause', confirmSlot = -1, confirmDel = -1;

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
      case 'respawn': Sound.play('menuSelect'); hideAll(); respawn(); break;
      case 'continue': {
        const i = Save.newest();
        if (i >= 0 && Save.load(i)) { Sound.play('menuSelect'); Sound.startMusic(); hideAll(); toast('Spielstand ' + (i + 1) + ' geladen – Ebene ' + G.level, '#d9cfff'); }
        break;
      }
      case 'loadMenu': Sound.play('menuSelect'); openSaves('load'); break;
      case 'saveMenu': Sound.play('menuSelect'); openSaves('save'); break;
      case 'backSaves': Sound.play('menuBack'); show(savesReturn); break;
      case 'backHelp': Sound.play('menuBack'); show(G.demo ? 'menu' : 'pause'); break;
      case 'backSlots': Sound.play('menuBack'); show('pause'); break;
      case 'closeAssign': Sound.play('menuBack'); closeAssign(); break;
    }
  }

  function toMenu() {
    Save.autosave();
    G.demo = true; G.state = 'menu'; G.level = 1 + Math.floor(Math.random() * 3);
    startLevel(12345 + G.level);
    refreshMenu();
    show('menu');
  }

  function refreshMenu() {
    const n = Save.newest(), has = n >= 0;
    $('btnContinue').style.display = has ? '' : 'none';
    if (has) $('btnContinue').textContent = 'Fortsetzen · Ebene ' + Save.read(n).level;
    $('btnLoad').style.display = has ? '' : 'none';
  }

  // ---------- Speicherplätze ----------
  function fmtTime(sec) {
    const h = Math.floor(sec / 3600), m = Math.floor(sec / 60) % 60, s = Math.floor(sec) % 60;
    return 'Spielzeit ' + (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(s).padStart(2, '0');
  }

  function slotDetails(i, d) {
    const p = d.player;
    const arm = ARMORS[p.armor] ? ARMORS[p.armor].name : 'keine Rüstung';
    const weps = Object.keys(WEAPONS).filter(k => p.weapons[k] > 0)
      .map(k => WEAPONS[k].name + (p.weapons[k] > 1 ? ' +' + (p.weapons[k] - 1) : '')).join(', ');
    const spells = Object.keys(SPELLS).filter(k => p.lvl >= SPELLS[k].lvl).map(k => SPELLS[k].name).join(', ') || 'keine';
    const date = new Date(d.savedAt).toLocaleString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    const st = d.stats || {};
    const deaths = st.deaths || 0;
    return `<span class="sh"><span class="sn">Platz ${i + 1}</span>Ebene ${d.level} · Stufe ${p.lvl} · ♥ ${fmtNum(p.hp / 2)}/${p.maxHp / 2} · ${arm}${G.activeSlot === i && !G.demo ? '<span class="act">AKTIV</span>' : ''}</span>
      <span class="sd">${weps} · Zauber: ${spells} · ${st.kills || 0} Monster · ${deaths} ${deaths === 1 ? 'Tod' : 'Tode'} · ${fmtTime(st.time || 0)} · ${date}</span>`;
  }

  function openSaves(mode) {
    const open = document.querySelector('.overlay.show');
    if (open && open.id !== 'saves') savesReturn = open.id;
    savesMode = mode; confirmSlot = -1; confirmDel = -1;
    buildSaves();
    show('saves');
  }

  function buildSaves() {
    $('savesTitle').textContent = savesMode === 'save' ? 'Spiel speichern' : 'Spiel laden';
    $('savesHint').textContent = savesMode === 'save'
      ? 'Der gewählte Platz speichert danach automatisch weiter (Treppe, Hauptmenü, App im Hintergrund).'
      : '';
    $('savesHint').style.display = $('savesHint').textContent ? '' : 'none';
    const box = $('saveList');
    box.innerHTML = '';
    Save.list().forEach((d, i) => {
      const card = document.createElement('div');
      card.className = 'slot' + (G.activeSlot === i && !G.demo ? ' active' : '') + (confirmSlot === i ? ' confirm' : '');
      const main = document.createElement('button');
      main.className = 'slotMain';
      main.innerHTML = d ? slotDetails(i, d) : `<span class="sh"><span class="sn">Platz ${i + 1}</span></span><span class="sd empty">– leer –</span>`;
      if (confirmSlot === i) main.innerHTML += '<span class="warn">Nochmal tippen zum Überschreiben</span>';
      if (savesMode === 'load' && !d) main.disabled = true;
      main.addEventListener('click', () => slotClicked(i, d));
      card.appendChild(main);
      if (d) {
        const del = document.createElement('button');
        del.className = 'del' + (confirmDel === i ? ' armed' : '');
        del.textContent = confirmDel === i ? 'Wirklich löschen?' : 'Löschen';
        del.addEventListener('click', e => {
          e.stopPropagation();
          if (confirmDel === i) {
            Save.remove(i); confirmDel = -1;
            if (G.activeSlot === i) G.activeSlot = null;
            Sound.play('menuBack');
          } else { confirmDel = i; confirmSlot = -1; Sound.play('menuMove'); }
          buildSaves(); refreshMenu();
        });
        card.appendChild(del);
      }
      box.appendChild(card);
    });
    wireSounds(box);
  }

  function slotClicked(i, d) {
    confirmDel = -1;
    if (savesMode === 'save') {
      if (d && confirmSlot !== i && G.activeSlot !== i) { confirmSlot = i; Sound.play('menuMove'); buildSaves(); return; }
      if (Save.write(i)) {
        G.activeSlot = i;
        Sound.play('chest');
        toast('Gespeichert auf Platz ' + (i + 1), '#ffe14a');
        confirmSlot = -1;
        show(savesReturn);
      } else { Sound.play('noMana'); $('savesHint').textContent = 'Speichern fehlgeschlagen (Speicher voll?)'; }
      return;
    }
    if (!d) return;
    if (Save.load(i)) {
      Sound.play('menuSelect'); Sound.startMusic();
      hideAll();
      toast('Spielstand ' + (i + 1) + ' geladen – Ebene ' + G.level, '#d9cfff');
    } else { Sound.play('noMana'); $('savesHint').textContent = 'Spielstand konnte nicht geladen werden.'; }
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
    $('goStats').textContent = `Ebene ${G.level} · Stufe ${p.lvl} · ${G.stats.kills} Monster besiegt`;
    $('btnRespawn').textContent = 'Weiter – Ebene ' + G.level + ' neu betreten';
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
      case 'gameover': act('respawn'); return true;
      case 'saves': act('backSaves'); return true;
      default: return false;
    }
  }

  function init() {
    for (const b of document.querySelectorAll('[data-act]')) b.addEventListener('click', () => act(b.dataset.act));
    wireSounds(document);
    refreshAudioLabels();
    refreshMenu();
    show('menu');
  }

  return { init, pause, openAssign, showGameOver, back, toMenu };
})();
