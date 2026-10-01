'use strict';
// Spiellogik: Spieler, Monster, Kampf, Zauber, Truhen, Sicht, Ebenen.
const G = {
  state: 'menu', demo: true, level: 1, map: null, player: null,
  monsters: [], projectiles: [], effects: [], particles: [], texts: [], drops: [], chests: [],
  seen: null, vis: null, visGen: 1, visTimer: 0, flow: null, flowFrom: -1,
  slots: ['sword', null, null], time: 0, cam: { x: 0, y: 0 }, shake: 0, hurtFlash: 0,
  toasts: [], seenTypes: new Set(), minimapDirty: true, bigMap: false, fade: 0, fadeDir: 0,
  stats: { kills: 0 }
};

function newPlayer() {
  return {
    x: 0, y: 0, r: 0.28, hp: 10, maxHp: 10, mana: 6, maxMana: 10, xp: 0, lvl: 1,
    face: Math.PI / 2, moving: false, anim: 0, speed: 3.4,
    weapons: { sword: 1, axe: 0, bow: 0 }, cds: {}, atk: null, held: 'sword',
    inv: 0, stepT: 0, castT: 0, castKind: null, kx: 0, ky: 0
  };
}

function newGame() {
  G.player = newPlayer();
  G.slots = ['sword', null, null];
  G.level = 1;
  G.seenTypes = new Set();
  G.stats = { kills: 0 };
  G.demo = false;
  startLevel();
  G.state = 'play';
  toast('Ebene 1 – finde die Treppe nach unten!');
  toast('Tipp: Aktionstaste lange drücken zum Belegen');
}

function startLevel(demoSeed) {
  const seed = demoSeed || (Math.random() * 1e9) | 0;
  const map = generateDungeon(G.level, seed);
  G.map = map;
  const N = map.W * map.H;
  G.seen = new Uint8Array(N);
  G.vis = new Uint32Array(N);
  G.visGen = 1;
  G.flow = new Int16Array(N).fill(-1);
  G.flowFrom = -1;
  G.monsters = map.monsters.map(m => spawnMonster(m.type, m.x, m.y));
  G.chests = map.chests;
  G.projectiles = []; G.effects = []; G.particles = []; G.texts = []; G.drops = [];
  G.minimapDirty = true;
  if (G.player) {
    G.player.x = map.start.x; G.player.y = map.start.y;
    G.player.atk = null; G.player.kx = G.player.ky = 0;
    G.cam.x = G.player.x; G.cam.y = G.player.y;
    updateVisibility(true);
    updateFlow();
  }
}

function spawnMonster(type, x, y, small) {
  const def = MONSTERS[type];
  const scale = 1 + (G.level - 1) * 0.15;
  const hp = Math.round(def.hp * scale * (small ? 0.4 : 1));
  return {
    type, def, x, y, r: def.r * (small ? 0.65 : 1), hp, maxHp: hp, small: !!small,
    aggro: false, atkCd: 0.5, shootCd: 1.5 + Math.random(), para: 0, slow: 0, hurt: 0,
    kx: 0, ky: 0, wander: Math.random() * TAU, wanderT: 0, growlT: 2 + Math.random() * 4,
    seed: Math.random() * 100, moving: false, bones: false, reviveT: 0, revived: false,
    dmgBonus: Math.floor((G.level - 1) / 3)
  };
}

// ---------- Hilfen: Text, Partikel, Toasts ----------
function toast(text, color) {
  G.toasts.push({ text, color: color || '#f3eaff', t: 0 });
  if (G.toasts.length > 4) G.toasts.shift();
}
function floatText(x, y, text, color, big) {
  G.texts.push({ x: x + rnd(-0.3, 0.3), y, z: 0.9 + rnd(0, 0.35), text, color, life: 1.0, big: !!big, size: Math.max(12, R.T * 0.26) });
}
function burst(x, y, n, c, o) {
  o = o || {};
  for (let i = 0; i < n; i++) {
    const a = Math.random() * TAU, sp = (o.speed || 2) * (0.4 + Math.random() * 0.8);
    G.particles.push({
      x, y, z: o.z == null ? 0.4 : o.z, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
      vz: o.vz == null ? Math.random() * 2 : o.vz, g: o.grav == null ? 4 : o.grav,
      life: (o.life || 0.6) * (0.6 + Math.random() * 0.6), max: o.life || 0.6,
      size: o.size || 0.07, c: c, shrink: true
    });
  }
}

// ---------- Kollision ----------
function circleRect(e, q) {
  const cx = clamp(e.x, q.x, q.x + q.w), cy = clamp(e.y, q.y, q.y + q.h);
  const dx = e.x - cx, dy = e.y - cy, d2 = dx * dx + dy * dy;
  if (d2 >= e.r * e.r) return false;
  if (d2 > 1e-9) {
    const d = Math.sqrt(d2), push = (e.r - d) / d;
    e.x += dx * push; e.y += dy * push;
  } else {
    const l = e.x - q.x, rr = q.x + q.w - e.x, t = e.y - q.y, b = q.y + q.h - e.y, m = Math.min(l, rr, t, b);
    if (m === l) e.x = q.x - e.r; else if (m === rr) e.x = q.x + q.w + e.r;
    else if (m === t) e.y = q.y - e.r; else e.y = q.y + q.h + e.r;
  }
  return true;
}
function resolveWalls(e) {
  const map = G.map, W = map.W, H = map.H;
  const x0 = Math.floor(e.x - e.r) - 1, x1 = Math.floor(e.x + e.r) + 1;
  const y0 = Math.floor(e.y - e.r) - 1, y1 = Math.floor(e.y + e.r) + 1;
  let hit = false;
  for (let ty = y0; ty <= y1; ty++) for (let tx = x0; tx <= x1; tx++) {
    if (tx < 0 || ty < 0 || tx >= W || ty >= H) continue;
    const i = ty * W + tx, tt = map.t[i];
    if (tt === 1) { for (const q of map.rects[i]) hit = circleRect(e, q) || hit; }
    else if (tt === 2) {
      const dx = e.x - (tx + 0.5), dy = e.y - (ty + 0.5), d = Math.hypot(dx, dy), rr = e.r + 0.18;
      if (d < rr && d > 1e-6) { e.x += dx / d * (rr - d); e.y += dy / d * (rr - d); hit = true; }
    }
  }
  return hit;
}
function moveEntity(e, dx, dy, phase) {
  const steps = Math.max(1, Math.ceil(Math.max(Math.abs(dx), Math.abs(dy)) / 0.15));
  for (let s = 0; s < steps; s++) {
    e.x += dx / steps; e.y += dy / steps;
    if (!phase) resolveWalls(e);
  }
  e.x = clamp(e.x, 0.5, G.map.W - 0.5); e.y = clamp(e.y, 0.5, G.map.H - 0.5);
}
function pointInWall(x, y, pad) {
  const map = G.map, W = map.W;
  const tx = Math.floor(x), ty = Math.floor(y);
  if (tx < 0 || ty < 0 || tx >= W || ty >= map.H) return true;
  for (let oy = -1; oy <= 1; oy++) for (let ox = -1; ox <= 1; ox++) {
    const cx = tx + ox, cy = ty + oy;
    if (cx < 0 || cy < 0 || cx >= W || cy >= map.H) continue;
    if (!pad && (ox || oy)) continue;
    const i = cy * W + cx;
    if (map.t[i] !== 1) continue;
    for (const q of map.rects[i])
      if (x > q.x - pad && x < q.x + q.w + pad && y > q.y - pad && y < q.y + q.h + pad) return true;
  }
  return false;
}
function segClear(x0, y0, x1, y1, pad) {
  const d = dist(x0, y0, x1, y1), n = Math.ceil(d / 0.2);
  for (let k = 1; k < n; k++) {
    const t = k / n;
    if (pointInWall(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, pad)) return false;
  }
  return true;
}

// ---------- Sicht (Nebel des Krieges) ----------
function updateVisibility(force) {
  const p = G.player, map = G.map, W = map.W, H = map.H;
  G.visGen++;
  const gen = G.visGen, vis = G.vis, seen = G.seen;
  const RAD = 8, RAYS = 240;
  const mark = i => { vis[i] = gen; if (!seen[i]) { seen[i] = 1; G.minimapDirty = true; } };
  mark(Math.floor(p.y) * W + Math.floor(p.x));
  for (let k = 0; k < RAYS; k++) {
    const a = k / RAYS * TAU, dx = Math.cos(a) * 0.15, dy = Math.sin(a) * 0.15;
    let x = p.x, y = p.y - 0.1;
    for (let s = 0; s < RAD / 0.15; s++) {
      x += dx; y += dy;
      const tx = Math.floor(x), ty = Math.floor(y);
      if (tx < 0 || ty < 0 || tx >= W || ty >= H) break;
      const i = ty * W + tx;
      mark(i);
      if (map.t[i] === 1 && pointInWall(x, y, 0)) break;
    }
  }
  // Wände um sichtbare Bodenkacheln mitaufdecken
  const x0 = Math.max(1, Math.floor(p.x - RAD)), x1 = Math.min(W - 2, Math.ceil(p.x + RAD));
  const y0 = Math.max(1, Math.floor(p.y - RAD)), y1 = Math.min(H - 2, Math.ceil(p.y + RAD));
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const i = y * W + x;
    if (vis[i] !== gen || map.t[i] === 1) continue;
    for (const n of [i - 1, i + 1, i - W, i + W, i - W - 1, i - W + 1, i + W - 1, i + W + 1])
      if (map.t[n] === 1 && vis[n] !== gen) mark(n);
  }
}
function isVisible(x, y) {
  const W = G.map.W, tx = Math.floor(x), ty = Math.floor(y);
  if (tx < 0 || ty < 0 || tx >= W || ty >= G.map.H) return false;
  return G.vis[ty * W + tx] === G.visGen;
}

// ---------- Wegfindung (Flussfeld zum Spieler) ----------
function updateFlow() {
  const p = G.player, map = G.map, W = map.W, H = map.H;
  let from = Math.floor(p.y) * W + Math.floor(p.x);
  if (map.t[from] === 1 || map.t[from] === 2) {
    let best = -1, bd = 9;
    for (const n of [from - 1, from + 1, from - W, from + W]) {
      if (n < 0 || n >= W * H || map.t[n] === 1 || map.t[n] === 2) continue;
      const d = dist(p.x, p.y, n % W + 0.5, ((n / W) | 0) + 0.5);
      if (d < bd) { bd = d; best = n; }
    }
    if (best < 0) return;
    from = best;
  }
  if (from === G.flowFrom) return;
  G.flowFrom = from;
  const d = G.flow; d.fill(-1);
  const q = new Int32Array(W * H);
  let h = 0, tl = 0;
  d[from] = 0; q[tl++] = from;
  while (h < tl) {
    const i = q[h++];
    if (d[i] > 40) continue;
    const x = i % W;
    const nb = [x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, i - W, i + W];
    for (const n of nb) {
      if (n < 0 || n >= W * H || d[n] >= 0) continue;
      const tt = map.t[n];
      if (tt === 1 || tt === 2) continue;
      d[n] = d[i] + 1; q[tl++] = n;
    }
  }
}
function flowAt(x, y) {
  const W = G.map.W, tx = Math.floor(x), ty = Math.floor(y);
  if (tx < 0 || ty < 0 || tx >= W || ty >= G.map.H) return -1;
  return G.flow[ty * W + tx];
}

// ---------- Aktionen ----------
function canUse(id) {
  const p = G.player;
  if (!id) return false;
  if (WEAPONS[id]) return p.weapons[id] > 0;
  if (SPELLS[id]) return p.lvl >= SPELLS[id].lvl;
  return false;
}
function actionCdFrac(id) {
  const p = G.player, c = p.cds[id] || 0;
  if (c <= 0) return 0;
  const total = WEAPONS[id] ? WEAPONS[id].cd(p.weapons[id] || 1) : SPELLS[id].cd;
  return clamp(c / total, 0, 1);
}

function autoAim(range) {
  const p = G.player;
  if (Input.moveMag > 0.2) return;
  let best = null, bd = range;
  for (const m of G.monsters) {
    if (m.bones || !isVisible(m.x, m.y)) continue;
    const d = dist(p.x, p.y, m.x, m.y);
    if (d < bd && segClear(p.x, p.y, m.x, m.y, 0)) { bd = d; best = m; }
  }
  if (best) p.face = Math.atan2(best.y - p.y, best.x - p.x);
}

function doAction(slot) {
  if (G.state !== 'play') return;
  const id = G.slots[slot];
  if (!id) { UI.openAssign(slot); return; }
  const p = G.player;
  if (!canUse(id)) {
    Sound.play('noMana');
    floatText(p.x, p.y - 0.6, SPELLS[id] ? 'Ab Stufe ' + SPELLS[id].lvl : 'Nicht gefunden', '#bbb');
    return;
  }
  if ((p.cds[id] || 0) > 0) return;
  if (WEAPONS[id]) attack(id);
  else castSpell(id);
}

function attack(id) {
  const p = G.player, w = WEAPONS[id], lvl = p.weapons[id];
  p.held = id;
  p.cds[id] = w.cd(lvl);
  if (w.kind === 'melee') {
    autoAim(2.2);
    p.atk = { kind: id, t: 0, dur: w.anim, ang: p.face };
    Sound.play(id === 'axe' ? 'axe' : 'sword');
    for (const m of G.monsters) {
      if (m.bones) continue;
      const d = dist(p.x, p.y, m.x, m.y) - m.r;
      const a = Math.atan2(m.y - p.y, m.x - p.x);
      if (d < w.range && (Math.abs(angDiff(p.face, a)) < w.arc / 2 || d < 0.25) && segClear(p.x, p.y, m.x, m.y, 0)) {
        damageMonster(m, w.dmg(lvl), w.type, Math.cos(a), Math.sin(a), w.knock);
      }
    }
  } else {
    autoAim(w.range);
    p.atk = { kind: id, t: 0, dur: w.anim, ang: p.face };
    Sound.play('bow');
    const c = Math.cos(p.face), s = Math.sin(p.face);
    G.projectiles.push({
      kind: 'arrow', from: 'player', x: p.x + c * 0.3, y: p.y + s * 0.3, vx: c * w.speed, vy: s * w.speed,
      dmg: w.dmg(lvl), type: w.type, life: w.range / w.speed, knock: w.knock, pierce: lvl >= 4 ? 1 : 0
    });
  }
}

function castSpell(id) {
  const p = G.player, sp = SPELLS[id];
  if (p.mana < sp.mana) {
    Sound.play('noMana');
    floatText(p.x, p.y - 0.6, 'Kein Mana!', '#7aa8ff');
    return;
  }
  p.mana -= sp.mana;
  p.cds[id] = sp.cd;
  p.castT = 0.4; p.castKind = id;
  const lvl = p.lvl;
  if (id === 'paralyze') {
    G.effects.push({ kind: 'ring', x: p.x, y: p.y, t: 0, dur: 0.5, R: 3.8, hit: new Set(), power: 3 + lvl * 0.3 });
    Sound.play('paralyze');
    burst(p.x, p.y, 30, '200,130,255', { speed: 4, life: 0.6, z: 0.5 });
  } else if (id === 'firewall') {
    autoAim(5);
    const c = Math.cos(p.face), s = Math.sin(p.face);
    const cx = p.x + c * 1.7, cy = p.y + s * 1.7;
    const nodes = [];
    for (let k = -3; k <= 3; k++) {
      const nx = cx - s * k * 0.5, ny = cy + c * k * 0.5;
      if (!pointInWall(nx, ny, 0.1) && nx > 0 && ny > 0 && nx < G.map.W && ny < G.map.H) nodes.push({ x: nx, y: ny, seed: Math.random() * 10 });
    }
    G.effects.push({ kind: 'fire', nodes, t: 0, dur: 4.5, tick: 0, dmg: 14 + lvl * 3 });
    Sound.play('fire');
  } else if (id === 'icerain') {
    let tx = p.x + Math.cos(p.face) * 3, ty = p.y + Math.sin(p.face) * 3, bd = 7.5;
    for (const m of G.monsters) {
      if (m.bones || !isVisible(m.x, m.y)) continue;
      const d = dist(p.x, p.y, m.x, m.y);
      if (d < bd) { bd = d; tx = m.x; ty = m.y; }
    }
    G.effects.push({ kind: 'ice', x: tx, y: ty, R: 2.3, t: 0, dur: 2.4, acc: 0, shards: [], dmg: 18 + lvl * 3 });
    Sound.play('ice');
  }
}

// ---------- Schaden ----------
function damageMonster(m, base, type, kx, ky, knock) {
  if (m.bones || m.hp <= 0) return;
  const mult = m.def.mult[type] == null ? 1 : m.def.mult[type];
  const dmg = Math.round(base * mult);
  m.hp -= dmg; m.hurt = 0.12; m.aggro = true;
  const kb = (knock || 0) * (m.def.heavy ? 0.25 : 1) * 6;
  m.kx += kx * kb; m.ky += ky * kb;
  if (mult >= 1.4) { floatText(m.x, m.y, dmg + ' SCHWACH!', '#ffe14a', true); Sound.play('weak'); }
  else if (mult === 0) { floatText(m.x, m.y, 'IMMUN', '#9a9a9a'); Sound.play('resist'); }
  else if (mult <= 0.6) { floatText(m.x, m.y, dmg + ' resistent', '#b0b0c0'); Sound.play('resist'); }
  else { floatText(m.x, m.y, String(dmg), '#ffffff'); Sound.play('hit'); }
  burst(m.x, m.y, 6, type === 'fire' ? '255,140,40' : type === 'ice' ? '160,220,255' : '255,230,200', { speed: 2.5, life: 0.35 });
  if (m.hp <= 0) killMonster(m, type);
}

function killMonster(m, type) {
  const def = m.def;
  if (def.revive && !m.revived && type !== 'heavy' && type !== 'fire') {
    m.bones = true; m.reviveT = 4; m.revived = true; m.hp = 0;
    Sound.play('bones');
    floatText(m.x, m.y, 'Knochen...', '#e8e2d0');
    return;
  }
  m.dead = true;
  G.stats.kills++;
  Sound.play('monsterDie');
  burst(m.x, m.y, 18, m.type === 'slime' ? '110,220,100' : m.type === 'imp' ? '255,120,40' : '210,200,255', { speed: 3, life: 0.7 });
  gainXp(Math.max(1, Math.round(def.xp * (m.small ? 0.5 : 1))), m.x, m.y);
  if (def.split && !m.small) {
    for (const sd of [-1, 1]) {
      const c = spawnMonster(m.type, m.x + sd * 0.25, m.y, true);
      c.aggro = true; c.kx = sd * 3;
      G.monsters.push(c);
    }
  }
  if (Math.random() < 0.18) G.drops.push({ kind: Math.random() < 0.6 ? 'heart' : 'mana', x: m.x, y: m.y });
}

function hurtPlayer(dmg, fromX, fromY) {
  const p = G.player;
  if (p.inv > 0 || G.state !== 'play') return;
  p.hp -= dmg; p.inv = 1.0;
  const a = Math.atan2(p.y - fromY, p.x - fromX);
  p.kx += Math.cos(a) * 5; p.ky += Math.sin(a) * 5;
  G.shake = 0.25; G.hurtFlash = 0.35;
  Sound.play('playerHurt');
  try { if (navigator.vibrate) navigator.vibrate(40); } catch (e) { }
  floatText(p.x, p.y - 0.3, '-' + dmg + ' ♥', '#ff6070');
  if (p.hp <= 0) {
    p.hp = 0;
    G.state = 'dead';
    Sound.play('gameOver');
    burst(p.x, p.y, 30, '230,60,80', { speed: 3, life: 1 });
    setTimeout(() => UI.showGameOver(), 1300);
  }
}

function gainXp(n, x, y) {
  const p = G.player;
  p.xp += n;
  floatText(x, y + 0.3, '+' + n + ' EP', '#b6f0ff');
  while (p.xp >= xpNeeded(p.lvl)) {
    p.xp -= xpNeeded(p.lvl);
    p.lvl++;
    p.maxMana += 2; p.mana = p.maxMana;
    if (p.lvl % 2 === 0) { p.maxHp += 2; }
    p.hp = Math.min(p.maxHp, p.hp + 2);
    Sound.play('levelUp');
    toast('Stufe ' + p.lvl + ' erreicht!', '#ffe14a');
    burst(p.x, p.y, 40, '255,225,120', { speed: 3.5, life: 1, vz: 3 });
    for (const id in SPELLS) {
      if (SPELLS[id].lvl === p.lvl) {
        toast('Neuer Zauber: ' + SPELLS[id].name + '!', '#d9a6ff');
        autoAssign(id);
      }
    }
  }
}

function autoAssign(id) {
  if (G.slots.includes(id)) return;
  const k = G.slots.indexOf(null);
  if (k >= 0) G.slots[k] = id;
}

// ---------- Truhen & Beute ----------
function openChest(ch) {
  ch.open = true;
  const p = G.player;
  Sound.play('chest');
  burst(ch.x, ch.y, 24, '255,220,120', { speed: 2.5, life: 0.8, vz: 3 });
  let c = ch.content;
  if (c === 'upgrade') {
    const ids = Object.keys(WEAPONS).filter(k => p.weapons[k] < 5);
    c = ids.length ? 'up:' + pick(ids) : 'heartmax';
  }
  if (c === 'axe' || c === 'bow') c = 'up:' + c;
  setTimeout(() => {
    if (c.startsWith('up:')) {
      const w = c.slice(3);
      if (!p.weapons[w]) {
        p.weapons[w] = 1; p.held = w;
        autoAssign(w);
        toast('Neue Waffe: ' + WEAPONS[w].name + '!', '#ffe14a');
        floatText(ch.x, ch.y, WEAPONS[w].name + '!', '#ffe14a', true);
      } else {
        p.weapons[w]++;
        toast(WEAPONS[w].name + ' verbessert auf Stufe ' + p.weapons[w], '#ffe14a');
        floatText(ch.x, ch.y, WEAPONS[w].name + ' +' + (p.weapons[w] - 1), '#ffe14a', true);
      }
      Sound.play('upgrade');
    } else if (c === 'heart' || c === 'heartmax') {
      if (c === 'heartmax' || Math.random() < 0.25) {
        p.maxHp += 2; p.hp = Math.min(p.maxHp, p.hp + 4);
        toast('Herzcontainer! Ein Herz mehr', '#ff7080');
      } else {
        p.hp = Math.min(p.maxHp, p.hp + 4);
        floatText(ch.x, ch.y, '+2 ♥', '#ff7080', true);
      }
      Sound.play('heart');
    } else if (c === 'mana') {
      if (Math.random() < 0.25) {
        p.maxMana += 2; p.mana = p.maxMana;
        toast('Manakristall! Maximales Mana +2', '#7aa8ff');
      } else {
        p.mana = Math.min(p.maxMana, p.mana + 6);
        floatText(ch.x, ch.y, '+6 Mana', '#7aa8ff', true);
      }
      Sound.play('mana');
    }
  }, 350);
}

// ---------- Update ----------
function update(dt) {
  G.time += dt;
  if (G.state === 'transition') { updateTransition(dt); return; }
  if (G.state !== 'play' && G.state !== 'dead') return;
  const p = G.player;

  if (G.state === 'play') updatePlayer(dt);
  G.visTimer -= dt;
  if (G.visTimer <= 0) { G.visTimer = 0.08; updateVisibility(); updateFlow(); }
  updateMonsters(dt);
  updateProjectiles(dt);
  updateEffects(dt);
  updateParticles(dt);

  if (G.state === 'play') {
    for (const ch of G.chests) if (!ch.open && dist(p.x, p.y, ch.x, ch.y) < 0.7) openChest(ch);
    for (let i = G.drops.length - 1; i >= 0; i--) {
      const d = G.drops[i];
      if (dist(p.x, p.y, d.x, d.y) < 0.55) {
        if (d.kind === 'heart') { p.hp = Math.min(p.maxHp, p.hp + 2); Sound.play('heart'); floatText(d.x, d.y, '+1 ♥', '#ff7080'); }
        else { p.mana = Math.min(p.maxMana, p.mana + 3); Sound.play('mana'); floatText(d.x, d.y, '+3 Mana', '#7aa8ff'); }
        G.drops.splice(i, 1);
      }
    }
    const st = G.map.stairs;
    if (dist(p.x, p.y, st.x, st.y) < 0.45) {
      G.state = 'transition'; G.fade = 0; G.fadeDir = 1;
      Sound.play('stairs');
    }
  }
  G.shake = Math.max(0, G.shake - dt);
  G.hurtFlash = Math.max(0, G.hurtFlash - dt);
  for (const t of G.toasts) t.t += dt;
  G.toasts = G.toasts.filter(t => t.t < 3.2);
}

function updateTransition(dt) {
  G.fade += dt * 1.4 * G.fadeDir;
  if (G.fadeDir > 0 && G.fade >= 1) {
    G.fade = 1; G.fadeDir = -1;
    G.level++;
    const p = G.player;
    p.hp = Math.min(p.maxHp, p.hp + 2);
    startLevel();
    toast('Ebene ' + G.level, '#ffe14a');
  } else if (G.fadeDir < 0 && G.fade <= 0) {
    G.fade = 0; G.fadeDir = 0; G.state = 'play';
  }
}

function updatePlayer(dt) {
  const p = G.player;
  const mx = Input.moveX, my = Input.moveY, mag = Input.moveMag;
  p.moving = mag > 0.12;
  if (p.moving) {
    p.face = Math.atan2(my, mx);
    const sp = p.speed * Math.min(1, mag);
    moveEntity(p, mx / mag * sp * dt * Math.min(1, mag), my / mag * sp * dt * Math.min(1, mag));
    p.anim += dt * Math.min(1, mag);
    p.stepT -= dt * Math.min(1, mag);
    if (p.stepT <= 0) { p.stepT = 0.3; Sound.play('step'); }
  }
  if (Math.abs(p.kx) + Math.abs(p.ky) > 0.01) {
    moveEntity(p, p.kx * dt, p.ky * dt);
    p.kx *= Math.pow(0.0005, dt); p.ky *= Math.pow(0.0005, dt);
  }
  for (const k in p.cds) if (p.cds[k] > 0) p.cds[k] -= dt;
  if (p.atk) { p.atk.t += dt; if (p.atk.t >= p.atk.dur) p.atk = null; }
  p.inv = Math.max(0, p.inv - dt);
  p.castT = Math.max(0, p.castT - dt);
  p.mana = Math.min(p.maxMana, p.mana + dt * 0.18);
  G.cam.x = p.x; G.cam.y = p.y;
}

function updateMonsters(dt) {
  const p = G.player;
  for (const m of G.monsters) {
    const def = m.def;
    m.hurt = Math.max(0, m.hurt - dt);
    if (m.bones) {
      m.reviveT -= dt;
      if (m.reviveT <= 0) {
        m.bones = false; m.hp = Math.round(m.maxHp * 0.5); m.aggro = true;
        Sound.play('bones');
        burst(m.x, m.y, 10, '232,226,208', { speed: 2, life: 0.4 });
      }
      continue;
    }
    if (m.kx || m.ky) {
      moveEntity(m, m.kx * dt, m.ky * dt, def.phase);
      m.kx *= Math.pow(0.002, dt); m.ky *= Math.pow(0.002, dt);
      if (Math.abs(m.kx) + Math.abs(m.ky) < 0.05) m.kx = m.ky = 0;
    }
    m.atkCd -= dt;
    m.slow = Math.max(0, m.slow - dt);
    if (m.para > 0) { m.para -= dt; m.moving = false; continue; }

    const d = dist(m.x, m.y, p.x, p.y);
    const vis = isVisible(m.x, m.y);
    if (vis && !G.seenTypes.has(m.type) && G.state === 'play') {
      G.seenTypes.add(m.type);
      toast(def.name + ': schwach gegen ' + def.weak + ' – ' + def.trait, '#ffb27a');
    }
    if (!m.aggro) {
      const fd = flowAt(m.x, m.y);
      if ((vis && d < def.aggro) || (fd >= 0 && fd <= 3)) {
        m.aggro = true;
        Sound.play('growl_' + m.type);
      }
    } else if (d > 18) m.aggro = false;

    let dx = 0, dy = 0, speed = def.speed * (m.slow > 0 ? 0.45 : 1);
    if (G.state !== 'play') speed *= 0.3;
    if (m.aggro) {
      const los = def.phase || (d < 6 && segClear(m.x, m.y, p.x, p.y, m.r * 0.8));
      if (los) { dx = (p.x - m.x) / d; dy = (p.y - m.y) / d; }
      else {
        const tx = Math.floor(m.x), ty = Math.floor(m.y);
        let best = flowAt(m.x, m.y), bx = -1, by = -1;
        if (best < 0) best = 999;
        for (const [ox, oy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const f = flowAt(tx + ox + 0.5, ty + oy + 0.5);
          if (f >= 0 && f < best) { best = f; bx = tx + ox + 0.5; by = ty + oy + 0.5; }
        }
        if (bx >= 0) { const dd = dist(m.x, m.y, bx, by) || 1; dx = (bx - m.x) / dd; dy = (by - m.y) / dd; }
        else { dx = Math.cos(m.wander) * 0.3; dy = Math.sin(m.wander) * 0.3; }
      }
      if (def.ranged && los && d < 6) {
        if (d < 3) { dx = -dx; dy = -dy; }
        else if (d < 4.8) { const t = dx; dx = -dy * 0.6; dy = t * 0.6; }
        m.shootCd -= dt;
        if (m.shootCd <= 0 && G.state === 'play') {
          m.shootCd = 2.2 + Math.random();
          const a = Math.atan2(p.y - m.y, p.x - m.x);
          G.projectiles.push({ kind: 'fireball', from: 'enemy', x: m.x, y: m.y, vx: Math.cos(a) * 5.5, vy: Math.sin(a) * 5.5, dmg: def.dmg + m.dmgBonus, life: 2.5 });
          Sound.play('fireball');
        }
      }
      if (def.erratic) {
        const w = Math.sin(G.time * 5 + m.seed) * 0.9;
        const t = dx; dx += -dy * w; dy += t * w;
      }
      m.growlT -= dt;
      if (m.growlT <= 0 && vis) { m.growlT = 3 + Math.random() * 5; Sound.play('growl_' + m.type); }
    } else {
      m.wanderT -= dt;
      if (m.wanderT <= 0) { m.wanderT = 1 + Math.random() * 2; m.wander = Math.random() * TAU; }
      dx = Math.cos(m.wander) * 0.35; dy = Math.sin(m.wander) * 0.35;
    }
    m.moving = dx || dy;
    moveEntity(m, dx * speed * dt, dy * speed * dt, def.phase);
    if (G.state === 'play' && d < m.r + p.r + 0.1 && m.atkCd <= 0) {
      m.atkCd = def.heavy ? 1.4 : 1.0;
      hurtPlayer(def.dmg + m.dmgBonus, m.x, m.y);
      m.kx -= dx * 2; m.ky -= dy * 2;
    }
  }
  // Monster schieben sich auseinander
  const ms = G.monsters;
  for (let i = 0; i < ms.length; i++) for (let j = i + 1; j < ms.length; j++) {
    const a = ms[i], b = ms[j];
    if (a.bones || b.bones) continue;
    const dx = b.x - a.x, dy = b.y - a.y, rr = a.r + b.r;
    if (Math.abs(dx) > rr || Math.abs(dy) > rr) continue;
    const d = Math.hypot(dx, dy);
    if (d < rr && d > 1e-4) {
      const push = (rr - d) / d * 0.5;
      a.x -= dx * push; a.y -= dy * push; b.x += dx * push; b.y += dy * push;
    }
  }
  G.monsters = G.monsters.filter(m => !m.dead);
}

function updateProjectiles(dt) {
  const p = G.player;
  for (const pr of G.projectiles) {
    pr.x += pr.vx * dt; pr.y += pr.vy * dt; pr.life -= dt;
    if (pr.life <= 0) { pr.dead = true; continue; }
    if (pointInWall(pr.x, pr.y, 0) || G.map.t[Math.floor(pr.y) * G.map.W + Math.floor(pr.x)] === 2) {
      pr.dead = true;
      if (pr.kind === 'arrow') Sound.play('arrowWall');
      burst(pr.x, pr.y, 5, pr.kind === 'arrow' ? '220,200,180' : '255,130,40', { speed: 1.5, life: 0.3 });
      continue;
    }
    if (pr.kind === 'fireball') {
      if (Math.random() < 0.6) G.particles.push({ x: pr.x, y: pr.y, z: 0.4, vx: 0, vy: 0, vz: 0.5, g: 0, life: 0.3, max: 0.3, size: 0.12, c: '255,130,30', shrink: true });
    }
    if (pr.from === 'player') {
      for (const m of G.monsters) {
        if (m.bones || (pr.hitSet && pr.hitSet.has(m))) continue;
        if (dist(pr.x, pr.y, m.x, m.y) < m.r + 0.12) {
          damageMonster(m, pr.dmg, pr.type, pr.vx / 11, pr.vy / 11, pr.knock);
          if (pr.pierce > 0) { pr.pierce--; (pr.hitSet = pr.hitSet || new Set()).add(m); }
          else { pr.dead = true; break; }
        }
      }
    } else if (G.state === 'play' && dist(pr.x, pr.y, p.x, p.y) < p.r + 0.15) {
      pr.dead = true;
      hurtPlayer(pr.dmg, pr.x - pr.vx, pr.y - pr.vy);
      burst(pr.x, pr.y, 12, '255,130,40', { speed: 2.5, life: 0.4 });
    }
  }
  G.projectiles = G.projectiles.filter(pr => !pr.dead);
}

function updateEffects(dt) {
  for (const e of G.effects) {
    e.t += dt;
    if (e.kind === 'ring') {
      const rr = e.R * Math.min(1, e.t / e.dur);
      for (const m of G.monsters) {
        if (e.hit.has(m) || m.bones) continue;
        if (dist(e.x, e.y, m.x, m.y) <= rr + m.r) {
          e.hit.add(m);
          const dur = e.power * m.def.para;
          m.para = Math.max(m.para, dur); m.aggro = true;
          floatText(m.x, m.y, m.def.para < 0.6 ? 'kaum gelähmt' : 'gelähmt!', '#d9a6ff');
        }
      }
    } else if (e.kind === 'fire') {
      e.tick -= dt;
      if (Math.random() < 0.5 && e.nodes.length) {
        const n = pick(e.nodes);
        G.particles.push({ x: n.x + rnd(-0.15, 0.15), y: n.y, z: 0.3, vx: rnd(-0.2, 0.2), vy: 0, vz: rnd(1, 2), g: -0.5, life: 0.6, max: 0.6, size: 0.08, c: '255,150,50', shrink: true });
      }
      if (e.tick <= 0) {
        e.tick = 0.5;
        let any = false;
        for (const m of G.monsters) {
          if (m.bones) continue;
          if (e.nodes.some(n => dist(n.x, n.y, m.x, m.y) < 0.55 + m.r)) { damageMonster(m, e.dmg, 'fire', 0, 0, 0); any = true; }
        }
        if (any) Sound.play('burn');
      }
    } else if (e.kind === 'ice') {
      e.acc += dt;
      while (e.acc > 0.11 && e.t < e.dur - 0.4) {
        e.acc -= 0.11;
        const a = Math.random() * TAU, r = Math.sqrt(Math.random()) * e.R;
        e.shards.push({ x: e.x + Math.cos(a) * r, y: e.y + Math.sin(a) * r, z: 4, vz: 0 });
      }
      for (const s of e.shards) {
        s.vz += 30 * dt; s.z -= s.vz * dt;
        if (s.z <= 0) {
          s.dead = true;
          Sound.play('shard');
          burst(s.x, s.y, 6, '180,230,255', { speed: 2, life: 0.35, z: 0.05 });
          for (const m of G.monsters) {
            if (m.bones) continue;
            if (dist(s.x, s.y, m.x, m.y) < 0.6 + m.r) { damageMonster(m, e.dmg, 'ice', 0, 0, 0); m.slow = 2.5; }
          }
        }
      }
      e.shards = e.shards.filter(s => !s.dead);
    }
  }
  G.effects = G.effects.filter(e => e.t < e.dur || (e.kind === 'ice' && e.shards.length));
}

function updateParticles(dt) {
  for (const pt of G.particles) {
    pt.x += pt.vx * dt; pt.y += pt.vy * dt;
    pt.vz -= pt.g * dt; pt.z = Math.max(0, pt.z + pt.vz * dt);
    pt.vx *= 0.96; pt.vy *= 0.96;
    pt.life -= dt;
  }
  G.particles = G.particles.filter(pt => pt.life > 0);
  if (G.particles.length > 400) G.particles.splice(0, G.particles.length - 400);
  for (const t of G.texts) { t.life -= dt; t.z += dt * 0.8; }
  G.texts = G.texts.filter(t => t.life > 0);
}
