'use strict';
// Labyrinth-Generator: Zellen-Labyrinth (Backtracker) + Schleifen + offene Räume mit Säulen.
// Kachelarten: 0 Boden, 1 Wand, 2 Säule (frei stehend), 3 Treppe (Ausgang)
const CELL = 3;
const WALL_T = 0.36;               // Wandstärke in Kacheln
const WALL_O = (1 - WALL_T) / 2;   // Abstand Kachelrand -> Wand

function generateDungeon(level, seed) {
  const rng = mulberry32(seed);
  const cw = Math.min(5 + level * 2, 27), ch = Math.min(4 + level * 2, 23);
  const W = cw * CELL + 1, H = ch * CELL + 1;
  const t = new Uint8Array(W * H).fill(1);
  const I = (x, y) => y * W + x;
  const ci = (cx, cy) => cy * cw + cx;

  for (let cy = 0; cy < ch; cy++) for (let cx = 0; cx < cw; cx++)
    for (let dy = 1; dy <= 2; dy++) for (let dx = 1; dx <= 2; dx++) t[I(cx * CELL + dx, cy * CELL + dy)] = 0;

  function between(cx, cy, nx, ny) {
    const res = [];
    if (nx !== cx) { const x = Math.max(cx, nx) * CELL; for (let d = 1; d <= 2; d++) res.push(I(x, cy * CELL + d)); }
    else { const y = Math.max(cy, ny) * CELL; for (let d = 1; d <= 2; d++) res.push(I(cx * CELL + d, y)); }
    return res;
  }
  const carve = (cx, cy, nx, ny) => between(cx, cy, nx, ny).forEach(i => { t[i] = 0; });
  const isOpen = (cx, cy, nx, ny) => t[between(cx, cy, nx, ny)[0]] !== 1;

  // --- Labyrinth (iterativer Backtracker) ---
  const visited = new Uint8Array(cw * ch);
  const stack = [[Math.floor(rng() * cw), Math.floor(rng() * ch)]];
  visited[ci(stack[0][0], stack[0][1])] = 1;
  const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  while (stack.length) {
    const [cx, cy] = stack[stack.length - 1];
    const opts = [];
    for (const [dx, dy] of DIRS) {
      const nx = cx + dx, ny = cy + dy;
      if (nx >= 0 && ny >= 0 && nx < cw && ny < ch && !visited[ci(nx, ny)]) opts.push([nx, ny]);
    }
    if (!opts.length) { stack.pop(); continue; }
    const [nx, ny] = pick(opts, rng);
    carve(cx, cy, nx, ny);
    visited[ci(nx, ny)] = 1;
    stack.push([nx, ny]);
  }

  // --- Schleifen: weniger bei höheren Ebenen (komplizierter) ---
  const loopChance = Math.max(0.05, 0.14 - level * 0.012);
  for (let cy = 0; cy < ch; cy++) for (let cx = 0; cx < cw; cx++) {
    if (cx + 1 < cw && !isOpen(cx, cy, cx + 1, cy) && rng() < loopChance) carve(cx, cy, cx + 1, cy);
    if (cy + 1 < ch && !isOpen(cx, cy, cx, cy + 1) && rng() < loopChance) carve(cx, cy, cx, cy + 1);
  }

  // --- Räume ---
  const rooms = [];
  const nRooms = 2 + Math.floor(level * 0.8);
  for (let a = 0; a < nRooms * 8 && rooms.length < nRooms; a++) {
    const rw = 2 + Math.floor(rng() * 3), rh = 2 + Math.floor(rng() * 2);
    const rx = Math.floor(rng() * (cw - rw + 1)), ry = Math.floor(rng() * (ch - rh + 1));
    if (rooms.some(r => rx < r.x + r.w + 1 && rx + rw + 1 > r.x && ry < r.y + r.h + 1 && ry + rh + 1 > r.y)) continue;
    rooms.push({ x: rx, y: ry, w: rw, h: rh });
    for (let y = ry * CELL + 1; y <= (ry + rh) * CELL - 1; y++)
      for (let x = rx * CELL + 1; x <= (rx + rw) * CELL - 1; x++) t[I(x, y)] = 0;
    for (let j = 1; j < rh; j++) for (let i = 1; i < rw; i++)
      if (rng() < 0.55) t[I((rx + i) * CELL, (ry + j) * CELL)] = 2;
  }

  // --- Start, Ausgang (am weitesten entfernte Zelle) ---
  const passable = i => t[i] === 0 || t[i] === 3;
  function bfs(from) {
    const d = new Int16Array(W * H).fill(-1);
    const q = new Int32Array(W * H);
    let h = 0, tl = 0;
    d[from] = 0; q[tl++] = from;
    while (h < tl) {
      const i = q[h++], x = i % W, y = (i / W) | 0;
      const nb = [x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, y > 0 ? i - W : -1, y < H - 1 ? i + W : -1];
      for (const n of nb) if (n >= 0 && d[n] < 0 && passable(n)) { d[n] = d[i] + 1; q[tl++] = n; }
    }
    return d;
  }
  let scx = Math.floor(rng() * cw), scy = Math.floor(rng() * ch);
  const startTile = I(scx * CELL + 1, scy * CELL + 1);
  const dStart = bfs(startTile);
  let best = startTile, bestD = 0;
  for (let i = 0; i < W * H; i++) {
    const x = i % W, y = (i / W) | 0;
    if (x % CELL && y % CELL && dStart[i] > bestD) { bestD = dStart[i]; best = i; }
  }
  t[best] = 3;
  const stairs = { x: best % W + 0.5, y: ((best / W) | 0) + 0.5 };

  // --- Truhen: Sackgassen bevorzugt ---
  const cellCenter = (cx, cy) => ({ x: cx * CELL + 2, y: cy * CELL + 2 });
  const deadEnds = [], others = [];
  const bestCx = Math.floor((best % W) / CELL), bestCy = Math.floor(((best / W) | 0) / CELL);
  for (let cy = 0; cy < ch; cy++) for (let cx = 0; cx < cw; cx++) {
    if ((cx === scx && cy === scy) || (cx === bestCx && cy === bestCy)) continue;
    let open = 0;
    for (const [dx, dy] of DIRS) {
      const nx = cx + dx, ny = cy + dy;
      if (nx >= 0 && ny >= 0 && nx < cw && ny < ch && isOpen(cx, cy, nx, ny)) open++;
    }
    (open === 1 ? deadEnds : others).push([cx, cy]);
  }
  shuffle(deadEnds, rng); shuffle(others, rng);
  const chestCells = deadEnds.concat(others);
  // Ab Ebene 3 wird es härter: mehr Truhen, mehr Herzen, garantierter Herzcontainer.
  const hard = level >= 3;
  const nChests = Math.min(chestCells.length, 3 + level + (hard ? 2 : 0));
  const contents = [];
  if (level === 1) contents.push('axe');
  if (level === 2) contents.push('bow');
  if (level === 3) contents.push('armor');
  if (hard) contents.push('heartmax');
  while (contents.length < nChests) {
    const r = rng();
    const pHeart = hard ? 0.5 : 0.38, pMana = pHeart + (hard ? 0.22 : 0.3);
    const pArmor = level >= 2 ? 0.12 : 0;
    contents.push(r < pHeart ? 'heart' : r < pMana ? 'mana' : r < pMana + pArmor ? 'armor' : 'upgrade');
  }
  shuffle(contents, rng);
  const chests = [];
  const used = new Set();
  for (let k = 0; k < nChests; k++) {
    const [cx, cy] = chestCells[k];
    used.add(ci(cx, cy));
    const p = cellCenter(cx, cy);
    chests.push({ x: p.x, y: p.y, content: contents[k], open: false, t: 0 });
  }

  // --- Monster ---
  const types = Object.keys(MONSTERS).filter(k => MONSTERS[k].minLvl <= level);
  const nMon = Math.floor(cw * ch * 0.2) + level + 2;
  const monsters = [];
  const floorTiles = [];
  for (let i = 0; i < W * H; i++) if (t[i] === 0 && dStart[i] > 9) floorTiles.push(i);
  shuffle(floorTiles, rng);
  for (let k = 0; k < nMon && k < floorTiles.length; k++) {
    const i = floorTiles[k];
    let type = pick(types, rng);
    // neuere Monsterarten etwas seltener
    if (MONSTERS[type].minLvl === level && level > 1 && rng() < 0.4) type = pick(types, rng);
    monsters.push({ type, x: i % W + 0.5, y: ((i / W) | 0) + 0.5 });
  }

  const map = { W, H, t, level, rooms, chests, monsters, stairs, start: { x: startTile % W + 1, y: ((startTile / W) | 0) + 1 } };
  buildWallGeometry(map);
  return map;
}

// Erzeugt für jede Wandkachel ihre schmalen Wandrechtecke (Kollision + Darstellung)
function buildWallGeometry(map) {
  const { W, H, t } = map;
  const isW = (x, y) => x >= 0 && y >= 0 && x < W && y < H && t[y * W + x] === 1;
  map.rects = new Array(W * H).fill(null);
  map.col = new Uint8Array(W * H);
  map.sArm = new Uint8Array(W * H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    if (t[i] !== 1) continue;
    const n = isW(x, y - 1), s = isW(x, y + 1), e = isW(x + 1, y), w = isW(x - 1, y);
    const rects = [];
    const cx0 = x + WALL_O, cy0 = y + WALL_O;
    if (e || w || (!n && !s)) {
      const x0 = w ? x : cx0, x1 = e ? x + 1 : cx0 + WALL_T;
      rects.push({ x: x0, y: cy0, w: x1 - x0, h: WALL_T, v: false });
    }
    if (n || s) {
      const y0 = n ? y : cy0, y1 = s ? y + 1 : cy0 + WALL_T;
      rects.push({ x: cx0, y: y0, w: WALL_T, h: y1 - y0, v: true });
    }
    map.rects[i] = rects;
    map.sArm[i] = s ? 1 : 0;
    const junction = x % CELL === 0 && y % CELL === 0;
    const end = (n + s + e + w) === 1;
    if (junction || end) map.col[i] = 1;
  }
}
