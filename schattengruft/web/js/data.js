'use strict';
// ---------- Hilfsfunktionen ----------
const TAU = Math.PI * 2;
function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
function lerp(a, b, t) { return a + (b - a) * t; }
function dist(ax, ay, bx, by) { return Math.hypot(bx - ax, by - ay); }
function angDiff(a, b) {
  let d = (b - a) % TAU;
  if (d > Math.PI) d -= TAU;
  if (d < -Math.PI) d += TAU;
  return d;
}
function mulberry32(seed) {
  return function () {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
function rnd(a, b) { return a + Math.random() * (b - a); }
function pick(arr, r) { return arr[Math.floor((r || Math.random)() * arr.length)]; }
function shuffle(arr, r) {
  r = r || Math.random;
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(r() * (i + 1));
    const t = arr[i]; arr[i] = arr[j]; arr[j] = t;
  }
  return arr;
}
function hash2(x, y) {
  let h = (x * 374761393 + y * 668265263) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0);
}

// ---------- Waffen ----------
// Schadenswerte sind x10 skaliert (Monster-HP ebenfalls), damit ganze Zahlen angezeigt werden.
const WEAPONS = {
  sword: {
    name: 'Schwert', type: 'slash', kind: 'melee',
    dmg: l => 20 + (l - 1) * 8, range: 1.05, arc: 2.0, cd: l => 0.36 - l * 0.01,
    knock: 0.35, anim: 0.2, desc: 'Schnell, Schnittschaden'
  },
  axe: {
    name: 'Axt', type: 'heavy', kind: 'melee',
    dmg: l => 42 + (l - 1) * 14, range: 1.15, arc: 2.8, cd: l => 0.75 - l * 0.02,
    knock: 0.9, anim: 0.32, desc: 'Langsam, schwerer Wuchtschaden'
  },
  bow: {
    name: 'Bogen', type: 'pierce', kind: 'ranged',
    dmg: l => 20 + (l - 1) * 8, range: 9, cd: l => 0.52 - l * 0.03, speed: 11,
    knock: 0.2, anim: 0.18, desc: 'Fernkampf, Stichschaden'
  }
};

// ---------- Zauber ----------
const SPELLS = {
  paralyze: { name: 'Lähmung', lvl: 2, mana: 3, cd: 6, desc: 'Lähmt alle Gegner im Umkreis' },
  firewall: { name: 'Feuerwand', lvl: 3, mana: 5, cd: 8, desc: 'Flammenwand vor dir, Feuerschaden' },
  icerain: { name: 'Eisregen', lvl: 5, mana: 7, cd: 10, desc: 'Eissplitter regnen herab, verlangsamen' }
};

const ACTIONS = ['sword', 'axe', 'bow', 'paralyze', 'firewall', 'icerain'];
function actionName(id) { return (WEAPONS[id] || SPELLS[id] || {}).name || ''; }

// ---------- Monster ----------
// mult: Schadensmultiplikator je Schadensart (>1 = Schwäche, <1 = Resistenz)
const MONSTERS = {
  slime: {
    name: 'Schleim', hp: 50, speed: 1.1, dmg: 1, r: 0.3, xp: 2, aggro: 6, minLvl: 1,
    mult: { slash: 1, heavy: 0.8, pierce: 0.5, fire: 2, ice: 1 }, para: 1,
    weak: 'Feuer', trait: 'Teilt sich beim Tod', split: true
  },
  bat: {
    name: 'Fledermaus', hp: 30, speed: 3.0, dmg: 1, r: 0.22, xp: 2, aggro: 7, minLvl: 1,
    mult: { slash: 1, heavy: 0.6, pierce: 2.2, fire: 1, ice: 1.5 }, para: 1,
    weak: 'Bogen', trait: 'Schnell und sprunghaft', erratic: true, fly: true
  },
  skeleton: {
    name: 'Skelett', hp: 90, speed: 1.5, dmg: 2, r: 0.3, xp: 4, aggro: 7, minLvl: 2,
    mult: { slash: 0.7, heavy: 2.2, pierce: 0.35, fire: 1, ice: 0.8 }, para: 1,
    weak: 'Axt', trait: 'Setzt sich wieder zusammen (außer Axt/Feuer)', revive: true
  },
  ghost: {
    name: 'Geist', hp: 70, speed: 1.3, dmg: 2, r: 0.3, xp: 5, aggro: 8, minLvl: 2,
    mult: { slash: 0.4, heavy: 0.4, pierce: 0.25, fire: 1.8, ice: 1.8 }, para: 1.3,
    weak: 'Magie', trait: 'Schwebt durch Wände', phase: true
  },
  imp: {
    name: 'Feuerkobold', hp: 60, speed: 1.9, dmg: 1, r: 0.27, xp: 6, aggro: 8, minLvl: 3,
    mult: { slash: 1.2, heavy: 1, pierce: 1.3, fire: 0, ice: 2.5 }, para: 1,
    weak: 'Eis', trait: 'Wirft Feuerbälle, immun gegen Feuer', ranged: true
  },
  golem: {
    name: 'Steingolem', hp: 200, speed: 0.85, dmg: 3, r: 0.42, xp: 10, aggro: 6, minLvl: 3,
    mult: { slash: 0.45, heavy: 1.6, pierce: 0.2, fire: 0.5, ice: 2 }, para: 0.4,
    weak: 'Eis & Axt', trait: 'Zäh, kaum zu lähmen', heavy: true
  }
};

function xpNeeded(lvl) { return 8 + (lvl - 1) * 8; }
