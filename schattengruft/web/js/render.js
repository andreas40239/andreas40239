'use strict';
// Darstellung: Schräg-Draufsicht (3/4-Ansicht) im Stil lila Steinmauern + orangefarbener Sandboden.
const R = {
  T: 48, YS: 0.8, Z: 0.95, dpr: 1, VW: 800, VH: 450,
  floor: [], column: null, pillar: null, stairs: null, icons: {}
};

const COL = {
  bg: '#3a3940', bg2: '#35343b',
  top: '#cdc6f2', topEdge: '#e6e1ff', topShade: '#b9b1e6',
  front1: '#a79fe0', front2: '#968dd2', front3: '#857cc3',
  base: '#665da6', baseTop: '#7c73bd', groove: 'rgba(80,68,150,0.45)',
  plinth: '#6c63ad', shadow: 'rgba(28,18,58,0.38)', fog: 'rgba(14,10,30,0.55)'
};

function sx(x) { return (x - G.cam.x) * R.T + R.VW / 2; }
function sy(y) { return (y - G.cam.y) * R.T * R.YS + R.VH / 2 + R.T * 0.35; }

function resizeRender(vw, vh, dpr) {
  R.VW = vw; R.VH = vh; R.dpr = dpr;
  R.T = Math.round(clamp(Math.min(vh / 6.6, vw / 10.5), 30, 110));
  buildSprites();
}

function mkCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = Math.max(1, Math.ceil(w)); c.height = Math.max(1, Math.ceil(h));
  return c;
}

// ---------- Sprites ----------
function buildSprites() {
  const d = R.dpr, T = R.T;
  const fw = Math.ceil(T * d), fh = Math.ceil(T * R.YS * d);
  R.floor = [];
  for (let k = 0; k < 8; k++) R.floor.push(makeFloorSprite(fw, fh, 1000 + k * 77));
  R.stairs = makeStairsSprite(fw, fh);
  const colH = (R.Z + 0.75) * T;
  R.column = mkCanvas(0.7 * T * d, colH * d);
  drawColumnShape(R.column.getContext('2d'), R.column.width / 2, R.column.height, T * d, R.Z * T * d, 0.5);
  R.pillar = mkCanvas(0.7 * T * d, colH * d);
  drawColumnShape(R.pillar.getContext('2d'), R.pillar.width / 2, R.pillar.height, T * d, R.Z * T * d * 0.92, 0.6);
  R.icons = {};
}

function makeFloorSprite(w, h, seed) {
  const c = mkCanvas(w, h), g = c.getContext('2d'), r = mulberry32(seed);
  g.fillStyle = '#d6733c'; g.fillRect(0, 0, w, h);
  for (let i = 0; i < 5; i++) {
    g.fillStyle = r() < 0.5 ? 'rgba(160,72,32,0.16)' : 'rgba(245,160,95,0.14)';
    g.beginPath(); g.ellipse(r() * w, r() * h, w * (0.15 + r() * 0.3), h * (0.1 + r() * 0.25), 0, 0, TAU); g.fill();
  }
  if (r() < 0.3) { // Steinplatte
    const pw = w * (0.3 + r() * 0.25), ph = h * (0.25 + r() * 0.2), px = r() * (w - pw), py = r() * (h - ph);
    g.fillStyle = 'rgba(150,70,40,0.35)'; g.fillRect(px, py, pw, ph);
    g.fillStyle = 'rgba(240,150,100,0.3)'; g.fillRect(px, py, pw, Math.max(1, h * 0.03));
  }
  for (let i = 0; i < 12; i++) {
    g.fillStyle = r() < 0.7 ? '#a8522a' : '#b8623a';
    const s = w * (0.025 + r() * 0.04);
    g.beginPath(); g.ellipse(r() * w, r() * h, s, s * 0.7, 0, 0, TAU); g.fill();
  }
  for (let i = 0; i < 7; i++) {
    g.fillStyle = 'rgba(250,175,120,0.8)';
    const s = w * (0.012 + r() * 0.02);
    g.fillRect(r() * w, r() * h, s, s);
  }
  if (r() < 0.45) { // Kiesel
    const px = r() * w * 0.8 + w * 0.1, py = r() * h * 0.8 + h * 0.1, s = w * 0.05;
    g.fillStyle = '#8a5848'; g.beginPath(); g.ellipse(px, py, s * 1.3, s, 0, 0, TAU); g.fill();
    g.fillStyle = '#b07a64'; g.beginPath(); g.ellipse(px - s * 0.3, py - s * 0.3, s * 0.5, s * 0.35, 0, 0, TAU); g.fill();
  }
  return c;
}

function makeStairsSprite(w, h) {
  const c = mkCanvas(w, h), g = c.getContext('2d');
  g.fillStyle = '#2a2240'; g.fillRect(0, 0, w, h);
  const n = 5, m = w * 0.12;
  for (let i = 0; i < n; i++) {
    const y = i * h / n, sh = h / n;
    const shade = 120 - i * 18;
    g.fillStyle = `rgb(${shade * 0.7 | 0},${shade * 0.62 | 0},${shade * 1.1 | 0})`;
    g.fillRect(m, y, w - 2 * m, sh * 0.62);
    g.fillStyle = `rgb(${shade * 0.45 | 0},${shade * 0.4 | 0},${shade * 0.8 | 0})`;
    g.fillRect(m, y + sh * 0.62, w - 2 * m, sh * 0.38);
  }
  g.fillStyle = '#b3abe4'; g.fillRect(0, 0, m, h); g.fillRect(w - m, 0, m, h);
  g.fillStyle = '#8c83c9'; g.fillRect(m * 0.6, 0, m * 0.4, h); g.fillRect(w - m, 0, m * 0.4, h);
  g.fillStyle = '#d4cdf7'; g.fillRect(0, 0, w, h * 0.06);
  return c;
}

// Säule: Sockel, kannelierter Schaft, breites Kapitell
function drawColumnShape(g, cx, baseY, s, zh, plinthW) {
  const YS = R.YS;
  const pw = plinthW * s, pd = 0.42 * s * YS, ph = 0.1 * s;
  // Sockel
  g.fillStyle = '#6a61ab'; g.fillRect(cx - pw / 2, baseY - ph, pw, ph);
  g.fillStyle = '#9f97da'; g.fillRect(cx - pw / 2, baseY - ph - pd * 0.5, pw, pd * 0.5);
  // Schaft
  const sw = 0.3 * s, top = baseY - ph - pd * 0.25 - zh;
  const gr = g.createLinearGradient(cx - sw / 2, 0, cx + sw / 2, 0);
  gr.addColorStop(0, '#c6bff0'); gr.addColorStop(0.45, '#a69edf'); gr.addColorStop(1, '#7a71bb');
  g.fillStyle = gr; g.fillRect(cx - sw / 2, top, sw, zh);
  g.fillStyle = 'rgba(70,60,140,0.35)';
  for (let k = -1; k <= 1; k++) g.fillRect(cx + k * sw * 0.28 - 0.5, top + zh * 0.08, Math.max(1, s * 0.015), zh * 0.85);
  // Kapitell
  const cw = 0.44 * s, chh = 0.12 * s, cd = 0.3 * s * YS;
  g.fillStyle = '#8178c2'; roundRect(g, cx - cw / 2, top - chh, cw, chh, s * 0.04); g.fill();
  g.fillStyle = '#d4cdf8'; roundRect(g, cx - cw / 2, top - chh - cd, cw, cd, s * 0.06); g.fill();
  g.fillStyle = '#ece8ff'; g.fillRect(cx - cw / 2 + s * 0.04, top - chh - cd + s * 0.02, cw - s * 0.08, Math.max(1, s * 0.02));
}

function roundRect(g, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  g.beginPath();
  g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r);
  g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
}

// ---------- Welt zeichnen ----------
const drawList = [];
function addDraw(k, f, a, b) { drawList.push({ k, f, a, b }); }

function drawWorld(g) {
  const { T, YS, VW, VH } = R, map = G.map;
  const W = map.W, H = map.H, t = map.t;
  g.fillStyle = COL.bg; g.fillRect(0, 0, VW, VH);

  const c0 = Math.floor(G.cam.x - VW / 2 / T) - 1, c1 = Math.ceil(G.cam.x + VW / 2 / T) + 1;
  const r0 = Math.floor(G.cam.y - VH / 2 / (T * YS)) - 2;
  const r1 = Math.ceil(G.cam.y + VH / 2 / (T * YS)) + Math.ceil(R.Z / YS) + 2;

  // Hintergrund-Raster
  g.fillStyle = COL.bg2;
  for (let r = r0; r <= r1; r++) for (let c = c0; c <= c1; c++)
    if ((r + c) & 1) g.fillRect(Math.round(sx(c)), Math.round(sy(r)), Math.ceil(T) + 1, Math.ceil(T * YS) + 1);

  const seen = G.seen, vis = G.vis, gen = G.visGen, demo = G.demo;
  const isSeen = i => demo || seen[i];
  const isVis = i => demo || vis[i] === gen;

  // Boden
  const fogRects = [];
  for (let r = Math.max(0, r0); r <= Math.min(H - 1, r1); r++) {
    const Y0 = Math.round(sy(r)), Y1 = Math.round(sy(r + 1));
    for (let c = Math.max(0, c0); c <= Math.min(W - 1, c1); c++) {
      const i = r * W + c;
      if (!isSeen(i)) continue;
      const X0 = Math.round(sx(c)), X1 = Math.round(sx(c + 1));
      const tt = t[i];
      const spr = R.floor[hash2(c, r) & 7];
      if (tt === 3) g.drawImage(R.stairs, X0, Y0, X1 - X0, Y1 - Y0);
      else if (tt !== 1) g.drawImage(spr, X0, Y0, X1 - X0, Y1 - Y0);
      else {
        // Wandkachel: nur die Viertel mit Bodennachbarn bemalen
        const sw = spr.width / 2, sh = spr.height / 2, XM = Math.round(sx(c + 0.5)), YM = Math.round(sy(r + 0.5));
        for (let q = 0; q < 4; q++) {
          const qx = q & 1, qy = q >> 1;
          const nx = c + (qx ? 1 : -1), ny = r + (qy ? 1 : -1);
          const fl = (x, y) => x >= 0 && y >= 0 && x < W && y < H && t[y * W + x] !== 1;
          if (fl(nx, r) || fl(c, ny) || fl(nx, ny)) {
            const ax = qx ? XM : X0, bx = qx ? X1 : XM, ay = qy ? YM : Y0, by = qy ? Y1 : YM;
            g.drawImage(spr, qx * sw, qy * sh, sw, sh, ax, ay, bx - ax, by - ay);
          }
        }
      }
      if (!isVis(i)) fogRects.push(X0, Y0, X1 - X0, Y1 - Y0);
    }
  }
  if (fogRects.length) {
    g.fillStyle = COL.fog; g.beginPath();
    for (let k = 0; k < fogRects.length; k += 4) g.rect(fogRects[k], fogRects[k + 1], fogRects[k + 2], fogRects[k + 3]);
    g.fill();
  }

  // Sockelleisten + Schatten
  const dxS = -0.5 * R.Z, dyS = 0.32 * R.Z;
  g.fillStyle = COL.plinth; g.beginPath();
  const shadowPolys = [];
  for (let r = Math.max(0, r0); r <= Math.min(H - 1, r1); r++) {
    for (let c = Math.max(0, c0); c <= Math.min(W - 1, c1); c++) {
      const i = r * W + c;
      if (t[i] !== 1 && t[i] !== 2) continue;
      if (!isSeen(i)) continue;
      if (t[i] === 2) { shadowPolys.push(c + 0.36, r + 0.36, 0.28, 0.28); continue; }
      for (const q of map.rects[i]) {
        const e = 0.06;
        g.rect(sx(q.x - e), sy(q.y - e), (q.w + 2 * e) * T, (q.h + 2 * e) * T * YS);
        shadowPolys.push(q.x, q.y, q.w, q.h);
      }
    }
  }
  g.fill();
  g.fillStyle = COL.shadow; g.beginPath();
  for (let k = 0; k < shadowPolys.length; k += 4) {
    const x = shadowPolys[k], y = shadowPolys[k + 1], w = shadowPolys[k + 2], h = shadowPolys[k + 3];
    const ox = dxS, oy = dyS;
    g.moveTo(sx(x + w), sy(y)); g.lineTo(sx(x + w), sy(y + h)); g.lineTo(sx(x + w + ox), sy(y + h + oy));
    g.lineTo(sx(x + ox), sy(y + h + oy)); g.lineTo(sx(x + ox), sy(y + oy)); g.lineTo(sx(x), sy(y)); g.closePath();
  }
  g.fill('nonzero');

  // --- Sortierte Ebene: Wände, Säulen, Figuren, Effekte ---
  drawList.length = 0;
  for (let r = Math.max(0, r0); r <= Math.min(H - 1, r1); r++) {
    for (let c = Math.max(0, c0); c <= Math.min(W - 1, c1); c++) {
      const i = r * W + c;
      const tt = t[i];
      if ((tt !== 1 && tt !== 2) || !isSeen(i)) continue;
      const dark = !isVis(i);
      if (tt === 2) { addDraw(r + 0.64, drawPillar, i, dark); continue; }
      for (const q of map.rects[i]) addDraw(q.y + q.h, drawWallRect, q, (dark ? 1 : 0) | (q.v && map.sArm[i] ? 2 : 0));
      if (map.col[i]) addDraw(r + 0.8, drawColumnAt, i, dark);
    }
  }
  if (!demo) collectEntities(isVis);
  drawList.sort((a, b) => a.k - b.k);
  for (const d of drawList) d.f(g, d.a, d.b);
}

function drawWallRect(g, q, flags) {
  const T = R.T, Zh = Math.round(R.Z * T);
  const X0 = Math.round(sx(q.x)), X1 = Math.round(sx(q.x + q.w));
  const Y0 = Math.round(sy(q.y)), Y1 = Math.round(sy(q.y + q.h));
  const w = X1 - X0;
  const front = !(flags & 2);
  if (front) {
    g.fillStyle = COL.front2; g.fillRect(X0, Y1 - Zh, w, Zh);
    g.fillStyle = COL.front1; g.fillRect(X0, Y1 - Zh, w, Math.round(Zh * 0.22));
    g.fillStyle = COL.front3; g.fillRect(X0, Y1 - Math.round(Zh * 0.45), w, Math.round(Zh * 0.25));
    g.fillStyle = COL.base; g.fillRect(X0, Y1 - Math.round(Zh * 0.2), w, Math.round(Zh * 0.2));
    g.fillStyle = COL.baseTop; g.fillRect(X0, Y1 - Math.round(Zh * 0.2), w, Math.max(1, Math.round(Zh * 0.04)));
    g.fillStyle = COL.groove;
    const step = 0.34, gw = Math.max(1, Math.round(T * 0.022));
    for (let gx = Math.ceil((q.x + 0.05) / step) * step; gx < q.x + q.w - 0.05; gx += step)
      g.fillRect(Math.round(sx(gx)), Y1 - Math.round(Zh * 0.9), gw, Math.round(Zh * 0.66));
    // kleine Steindetails
    const h = hash2(Math.floor(q.x * 3), Math.floor(q.y * 3));
    if (h % 3 === 0 && w > T * 0.3) {
      g.fillStyle = 'rgba(120,110,190,0.8)';
      g.fillRect(X0 + (h >> 4) % Math.max(1, w - 6), Y1 - Zh * 0.65, Math.max(2, T * 0.06), Math.max(2, T * 0.04));
    }
  }
  g.fillStyle = COL.top; g.fillRect(X0, Y0 - Zh, w, Y1 - Y0);
  g.fillStyle = COL.topShade; g.fillRect(X0, Y0 - Zh, w, Math.max(1, Math.round((Y1 - Y0) * 0.18)));
  if (front) { g.fillStyle = COL.topEdge; g.fillRect(X0, Y1 - Zh - Math.max(1, T * 0.03), w, Math.max(1, T * 0.03)); }
  if (flags & 1) {
    g.fillStyle = 'rgba(14,10,30,0.5)';
    g.fillRect(X0, Y0 - Zh, w, (Y1 - Y0) + (front ? Zh : 0));
  }
}

function drawColumnAt(g, i, dark) {
  const W = G.map.W, c = i % W, r = (i / W) | 0;
  const X = sx(c + 0.5), Y = sy(r + 0.8);
  const spr = R.column, d = R.dpr;
  const x = Math.round(X - spr.width / d / 2), y = Math.round(Y - spr.height / d);
  g.drawImage(spr, x, y, spr.width / d, spr.height / d);
  if (dark) { g.globalAlpha = 0.5; g.fillStyle = '#0e0a1e'; g.fillRect(x + spr.width / d * 0.18, y + spr.height / d * 0.25, spr.width / d * 0.64, spr.height / d * 0.75); g.globalAlpha = 1; }
}

function drawPillar(g, i, dark) {
  const W = G.map.W, c = i % W, r = (i / W) | 0;
  const X = sx(c + 0.5), Y = sy(r + 0.64);
  const spr = R.pillar, d = R.dpr;
  const x = Math.round(X - spr.width / d / 2), y = Math.round(Y - spr.height / d);
  g.drawImage(spr, x, y, spr.width / d, spr.height / d);
  if (dark) { g.globalAlpha = 0.5; g.fillStyle = '#0e0a1e'; g.fillRect(x + spr.width / d * 0.18, y + spr.height / d * 0.25, spr.width / d * 0.64, spr.height / d * 0.75); g.globalAlpha = 1; }
}

function tileVisible(x, y, isVis) {
  const W = G.map.W, H = G.map.H, c = Math.floor(x), r = Math.floor(y);
  if (c < 0 || r < 0 || c >= W || r >= H) return false;
  return isVis(r * W + c);
}

function collectEntities(isVis) {
  for (const ch of G.chests) if (G.seen[Math.floor(ch.y) * G.map.W + Math.floor(ch.x)] || tileVisible(ch.x, ch.y, isVis)) addDraw(ch.y, drawChest, ch);
  for (const d of G.drops) if (tileVisible(d.x, d.y, isVis)) addDraw(d.y, drawDrop, d);
  for (const m of G.monsters) if (tileVisible(m.x, m.y, isVis)) addDraw(m.y, drawMonster, m);
  for (const p of G.projectiles) if (tileVisible(p.x, p.y, isVis)) addDraw(p.y, drawProjectile, p);
  for (const e of G.effects) {
    if (e.kind === 'fire') for (const n of e.nodes) addDraw(n.y + 0.01, drawFlame, n, e);
    if (e.kind === 'ice') for (const s of e.shards) addDraw(s.y, drawShard, s);
  }
  addDraw(G.player.y, drawPlayer, G.player);
}

// ---------- Figuren ----------
function shadowEl(g, X, Y, rx) {
  g.fillStyle = 'rgba(25,15,45,0.4)';
  g.beginPath(); g.ellipse(X, Y, rx, rx * 0.42, 0, 0, TAU); g.fill();
}

function drawPlayer(g, p) {
  const s = R.T, X = sx(p.x), Y = sy(p.y);
  shadowEl(g, X, Y, 0.3 * s);
  if (p.inv > 0 && Math.floor(p.inv * 18) % 2 === 0) return;
  const bob = p.moving ? Math.abs(Math.sin(p.anim * 10)) * 0.05 * s : 0;
  const fx = Math.cos(p.face), fy = Math.sin(p.face);
  const back = fy < -0.35;
  if (back) drawHeld(g, p, X, Y - bob, s);
  // Beine
  const leg = p.moving ? Math.sin(p.anim * 10) * 0.06 * s : 0;
  g.fillStyle = '#2a2340';
  g.fillRect(X - 0.12 * s, Y - 0.2 * s + leg, 0.09 * s, 0.2 * s - leg);
  g.fillRect(X + 0.03 * s, Y - 0.2 * s - leg, 0.09 * s, 0.2 * s + leg);
  // Umhang
  const by = Y - bob;
  g.fillStyle = '#23756f';
  g.beginPath();
  g.moveTo(X - 0.25 * s, by - 0.12 * s); g.lineTo(X + 0.25 * s, by - 0.12 * s);
  g.lineTo(X + 0.15 * s, by - 0.58 * s); g.lineTo(X - 0.15 * s, by - 0.58 * s); g.closePath(); g.fill();
  g.fillStyle = '#2fa197';
  g.beginPath();
  g.moveTo(X - 0.18 * s, by - 0.14 * s); g.lineTo(X + 0.18 * s, by - 0.14 * s);
  g.lineTo(X + 0.11 * s, by - 0.56 * s); g.lineTo(X - 0.11 * s, by - 0.56 * s); g.closePath(); g.fill();
  const arm = ARMORS[p.armor];
  if (arm) { // Brustpanzer + Schulterstücke
    g.fillStyle = arm.color;
    g.beginPath();
    g.moveTo(X - 0.15 * s, by - 0.28 * s); g.lineTo(X + 0.15 * s, by - 0.28 * s);
    g.lineTo(X + 0.12 * s, by - 0.54 * s); g.lineTo(X - 0.12 * s, by - 0.54 * s); g.closePath(); g.fill();
    g.fillStyle = arm.trim;
    g.fillRect(X - 0.12 * s, by - 0.54 * s, 0.24 * s, 0.035 * s);
    if (p.armor >= 2) {
      g.beginPath(); g.ellipse(X - 0.16 * s, by - 0.52 * s, 0.08 * s, 0.05 * s, 0, 0, TAU); g.fill();
      g.beginPath(); g.ellipse(X + 0.16 * s, by - 0.52 * s, 0.08 * s, 0.05 * s, 0, 0, TAU); g.fill();
    }
    if (p.armor === 2) { // Kettenglieder andeuten
      g.fillStyle = 'rgba(60,66,84,0.45)';
      for (let k = 0; k < 3; k++) g.fillRect(X - 0.1 * s, by - (0.33 + k * 0.06) * s, 0.2 * s, Math.max(1, 0.012 * s));
    }
  }
  g.fillStyle = '#6b4424'; g.fillRect(X - 0.17 * s, by - 0.3 * s, 0.34 * s, 0.05 * s);
  g.fillStyle = '#e7c14c'; g.fillRect(X - 0.03 * s, by - 0.31 * s, 0.06 * s, 0.07 * s);
  // Kopf + Kapuze
  const hy = by - 0.72 * s;
  g.fillStyle = '#1d5e59';
  g.beginPath(); g.arc(X, hy, 0.22 * s, 0, TAU); g.fill();
  if (!back) {
    g.fillStyle = '#f0c8a0';
    g.beginPath(); g.ellipse(X + fx * 0.04 * s, hy + 0.03 * s, 0.15 * s, 0.14 * s, 0, 0, TAU); g.fill();
    g.fillStyle = '#1a1028';
    const ex = X + fx * 0.07 * s, ey = hy + 0.03 * s + fy * 0.02 * s;
    g.fillRect(ex - 0.07 * s, ey - 0.02 * s, 0.035 * s, 0.05 * s);
    g.fillRect(ex + 0.035 * s, ey - 0.02 * s, 0.035 * s, 0.05 * s);
  }
  g.fillStyle = '#2fa197';
  g.beginPath(); g.arc(X, hy - 0.02 * s, 0.22 * s, Math.PI * 1.05, Math.PI * 1.95); g.fill();
  if (!back) drawHeld(g, p, X, by, s);
  // Zauber-Glühen
  if (p.castT > 0) {
    const col = { paralyze: '200,120,255', firewall: '255,140,40', icerain: '140,220,255' }[p.castKind] || '255,255,255';
    g.save(); g.globalCompositeOperation = 'lighter';
    const gr = g.createRadialGradient(X, by - 0.5 * s, 0, X, by - 0.5 * s, 0.8 * s);
    gr.addColorStop(0, `rgba(${col},${0.6 * p.castT / 0.4})`); gr.addColorStop(1, `rgba(${col},0)`);
    g.fillStyle = gr; g.fillRect(X - s, by - 1.4 * s, 2 * s, 2 * s);
    g.restore();
  }
}

function drawHeld(g, p, X, Y, s) {
  const w = p.held;
  if (!w) return;
  let a = p.face + 0.9;
  let swing = -1;
  if (p.atk && p.atk.kind === w && WEAPONS[w].kind === 'melee') {
    const k = p.atk.t / p.atk.dur, e = 1 - Math.pow(1 - k, 3);
    const arc = WEAPONS[w].arc;
    a = p.atk.ang - arc / 2 + arc * e;
    swing = k;
  } else if (w === 'bow') a = p.face;
  // Schlagspur
  if (swing >= 0) {
    const arc = WEAPONS[w].arc, rr = WEAPONS[w].range * s;
    g.save(); g.globalCompositeOperation = 'lighter';
    g.strokeStyle = `rgba(255,250,235,${0.55 * (1 - swing)})`; g.lineWidth = s * 0.12; g.lineCap = 'round';
    g.beginPath();
    const st = p.atk.ang - arc / 2, en = a;
    for (let k = 0; k <= 12; k++) {
      const aa = st + (en - st) * k / 12;
      const px = X + Math.cos(aa) * rr * 0.85, py = Y - 0.38 * s + Math.sin(aa) * rr * 0.85 * R.YS;
      k ? g.lineTo(px, py) : g.moveTo(px, py);
    }
    g.stroke(); g.restore();
  }
  const hx = X + Math.cos(a) * 0.22 * s, hy = Y - 0.38 * s + Math.sin(a) * 0.18 * s;
  g.save();
  g.translate(hx, hy);
  g.rotate(Math.atan2(Math.sin(a) * R.YS, Math.cos(a)));
  const L = WEAPONS[w].kind === 'melee' ? 1 + 0.1 * (p.weapons[w] - 1) : 1;
  if (w === 'sword') {
    g.fillStyle = '#5a3a1e'; g.fillRect(-0.06 * s, -0.03 * s, 0.14 * s, 0.06 * s);
    g.fillStyle = '#e2b94a'; g.fillRect(0.07 * s, -0.09 * s, 0.04 * s, 0.18 * s);
    g.fillStyle = '#dfe4f0'; g.fillRect(0.11 * s, -0.035 * s, 0.42 * s * L, 0.07 * s);
    g.beginPath(); g.moveTo(0.53 * s * L, -0.035 * s); g.lineTo(0.62 * s * L, 0); g.lineTo(0.53 * s * L, 0.035 * s); g.fill();
    g.fillStyle = '#ffffff'; g.fillRect(0.12 * s, -0.035 * s, 0.4 * s * L, 0.015 * s);
  } else if (w === 'axe') {
    g.fillStyle = '#6b4424'; g.fillRect(-0.05 * s, -0.025 * s, 0.6 * s * L, 0.05 * s);
    g.fillStyle = '#b9bfcc';
    g.beginPath(); g.moveTo(0.38 * s * L, -0.03 * s); g.lineTo(0.42 * s * L, -0.2 * s);
    g.quadraticCurveTo(0.58 * s * L, -0.12 * s, 0.58 * s * L, 0.02 * s);
    g.lineTo(0.52 * s * L, 0.04 * s); g.lineTo(0.38 * s * L, 0.03 * s); g.closePath(); g.fill();
    g.fillStyle = '#eef1f7'; g.fillRect(0.54 * s * L, -0.12 * s, 0.03 * s, 0.13 * s);
  } else if (w === 'bow') {
    g.strokeStyle = '#7a4a24'; g.lineWidth = 0.05 * s;
    g.beginPath(); g.arc(0.02 * s, 0, 0.28 * s, -1.2, 1.2); g.stroke();
    g.strokeStyle = '#eee'; g.lineWidth = Math.max(1, 0.012 * s);
    const pull = p.atk && p.atk.kind === 'bow' ? -0.12 * s * (1 - p.atk.t / p.atk.dur) : 0;
    g.beginPath(); g.moveTo(0.02 * s + Math.cos(-1.2) * 0.28 * s, Math.sin(-1.2) * 0.28 * s);
    g.lineTo(0.12 * s + pull, 0); g.lineTo(0.02 * s + Math.cos(1.2) * 0.28 * s, Math.sin(1.2) * 0.28 * s); g.stroke();
  }
  g.restore();
}

function hpBar(g, X, Y, w, frac) {
  g.fillStyle = 'rgba(0,0,0,0.6)'; g.fillRect(X - w / 2 - 1, Y - 1, w + 2, 6);
  g.fillStyle = frac > 0.5 ? '#7be06a' : frac > 0.25 ? '#e8c84a' : '#e2523e';
  g.fillRect(X - w / 2, Y, w * clamp(frac, 0, 1), 4);
}

function drawMonster(g, m) {
  const s = R.T, X = sx(m.x), Y = sy(m.y), def = m.def, tm = G.time + m.seed;
  const sc = m.small ? 0.65 : 1;
  if (m.bones) {
    g.fillStyle = '#e8e2d0';
    for (let k = 0; k < 5; k++) g.fillRect(X + Math.cos(k * 2.1) * 0.18 * s, Y - 0.05 * s + Math.sin(k * 1.7) * 0.06 * s, 0.14 * s, 0.04 * s);
    g.beginPath(); g.arc(X, Y - 0.08 * s, 0.09 * s, 0, TAU); g.fill();
    return;
  }
  const hover = def.fly ? 0.45 * s + Math.sin(tm * 6) * 0.05 * s : def.phase ? 0.25 * s + Math.sin(tm * 2) * 0.06 * s : 0;
  shadowEl(g, X, Y, def.r * s * sc * (def.fly ? 0.7 : 1));
  g.save();
  if (def.phase) g.globalAlpha = 0.72;
  const by = Y - hover;
  const flash = m.hurt > 0;
  switch (m.type) {
    case 'slime': {
      const sq = 1 + Math.sin(tm * 5) * 0.08;
      const rw = 0.32 * s * sc * sq, rh = 0.26 * s * sc / sq;
      g.fillStyle = flash ? '#fff' : '#58b84f';
      g.beginPath(); g.ellipse(X, by - rh, rw, rh, 0, Math.PI, 0); g.lineTo(X + rw, by); g.lineTo(X - rw, by); g.fill();
      g.fillStyle = 'rgba(200,255,180,0.55)';
      g.beginPath(); g.ellipse(X - rw * 0.35, by - rh * 1.35, rw * 0.25, rh * 0.18, -0.4, 0, TAU); g.fill();
      g.fillStyle = '#12301a';
      g.fillRect(X - rw * 0.4, by - rh * 1.0, rw * 0.18, rh * 0.3); g.fillRect(X + rw * 0.22, by - rh * 1.0, rw * 0.18, rh * 0.3);
      break;
    }
    case 'bat': {
      const fl = Math.sin(tm * 22);
      g.fillStyle = flash ? '#fff' : '#3b2a52';
      for (const sd of [-1, 1]) {
        g.beginPath(); g.moveTo(X, by - 0.12 * s);
        g.lineTo(X + sd * 0.42 * s, by - 0.22 * s - fl * 0.18 * s);
        g.lineTo(X + sd * 0.3 * s, by - 0.05 * s); g.lineTo(X + sd * 0.15 * s, by - 0.08 * s); g.fill();
      }
      g.fillStyle = flash ? '#fff' : '#4d3a68';
      g.beginPath(); g.ellipse(X, by - 0.12 * s, 0.13 * s, 0.15 * s, 0, 0, TAU); g.fill();
      g.fillStyle = '#ff4040';
      g.fillRect(X - 0.07 * s, by - 0.16 * s, 0.04 * s, 0.04 * s); g.fillRect(X + 0.03 * s, by - 0.16 * s, 0.04 * s, 0.04 * s);
      break;
    }
    case 'skeleton': {
      const wob = m.moving ? Math.sin(tm * 9) * 0.04 * s : 0;
      g.strokeStyle = flash ? '#fff' : '#e8e2d0'; g.lineWidth = 0.06 * s; g.lineCap = 'round';
      g.beginPath();
      g.moveTo(X - 0.08 * s, by); g.lineTo(X - 0.06 * s, by - 0.25 * s + wob);
      g.moveTo(X + 0.08 * s, by); g.lineTo(X + 0.06 * s, by - 0.25 * s - wob);
      g.moveTo(X, by - 0.25 * s); g.lineTo(X, by - 0.6 * s);
      g.moveTo(X - 0.2 * s, by - 0.35 * s - wob); g.lineTo(X - 0.12 * s, by - 0.55 * s);
      g.moveTo(X + 0.2 * s, by - 0.35 * s + wob); g.lineTo(X + 0.12 * s, by - 0.55 * s);
      g.stroke();
      g.lineWidth = 0.04 * s;
      for (let k = 0; k < 3; k++) { g.beginPath(); g.moveTo(X - 0.12 * s, by - (0.36 + k * 0.07) * s); g.lineTo(X + 0.12 * s, by - (0.36 + k * 0.07) * s); g.stroke(); }
      g.fillStyle = flash ? '#fff' : '#f2ecda';
      g.beginPath(); g.arc(X, by - 0.72 * s, 0.15 * s, 0, TAU); g.fill();
      g.fillStyle = '#2a1f3a';
      g.fillRect(X - 0.09 * s, by - 0.76 * s, 0.06 * s, 0.06 * s); g.fillRect(X + 0.03 * s, by - 0.76 * s, 0.06 * s, 0.06 * s);
      g.fillStyle = '#ff5b3a'; g.fillRect(X - 0.07 * s, by - 0.74 * s, 0.025 * s, 0.025 * s); g.fillRect(X + 0.05 * s, by - 0.74 * s, 0.025 * s, 0.025 * s);
      break;
    }
    case 'ghost': {
      const gr = g.createLinearGradient(0, by - 0.8 * s, 0, by);
      gr.addColorStop(0, flash ? '#fff' : '#d8f2ff'); gr.addColorStop(1, 'rgba(150,200,255,0.1)');
      g.fillStyle = gr;
      g.beginPath(); g.arc(X, by - 0.55 * s, 0.24 * s, Math.PI, 0);
      for (let k = 0; k <= 6; k++) g.lineTo(X + 0.24 * s - k * 0.08 * s, by - 0.1 * s + Math.sin(tm * 8 + k) * 0.05 * s + (k % 2) * 0.06 * s);
      g.closePath(); g.fill();
      g.fillStyle = '#1b1430';
      g.beginPath(); g.ellipse(X - 0.08 * s, by - 0.58 * s, 0.04 * s, 0.06 * s, 0, 0, TAU); g.fill();
      g.beginPath(); g.ellipse(X + 0.08 * s, by - 0.58 * s, 0.04 * s, 0.06 * s, 0, 0, TAU); g.fill();
      g.beginPath(); g.ellipse(X, by - 0.44 * s, 0.05 * s, 0.035 * s, 0, 0, TAU); g.fill();
      break;
    }
    case 'imp': {
      g.fillStyle = flash ? '#fff' : '#c23a2a';
      g.beginPath(); g.ellipse(X, by - 0.28 * s, 0.18 * s, 0.24 * s, 0, 0, TAU); g.fill();
      g.beginPath(); g.arc(X, by - 0.58 * s, 0.15 * s, 0, TAU); g.fill();
      g.fillStyle = '#3a1a1a';
      g.beginPath(); g.moveTo(X - 0.12 * s, by - 0.66 * s); g.lineTo(X - 0.2 * s, by - 0.86 * s); g.lineTo(X - 0.05 * s, by - 0.7 * s); g.fill();
      g.beginPath(); g.moveTo(X + 0.12 * s, by - 0.66 * s); g.lineTo(X + 0.2 * s, by - 0.86 * s); g.lineTo(X + 0.05 * s, by - 0.7 * s); g.fill();
      g.fillStyle = '#ffd84a';
      g.fillRect(X - 0.08 * s, by - 0.62 * s, 0.05 * s, 0.04 * s); g.fillRect(X + 0.03 * s, by - 0.62 * s, 0.05 * s, 0.04 * s);
      g.save(); g.globalCompositeOperation = 'lighter';
      const fx = X + 0.22 * s, fy = by - 0.35 * s + Math.sin(tm * 10) * 0.02 * s;
      const gg = g.createRadialGradient(fx, fy, 0, fx, fy, 0.18 * s);
      gg.addColorStop(0, 'rgba(255,220,120,0.9)'); gg.addColorStop(1, 'rgba(255,80,0,0)');
      g.fillStyle = gg; g.fillRect(fx - 0.2 * s, fy - 0.2 * s, 0.4 * s, 0.4 * s); g.restore();
      break;
    }
    case 'golem': {
      const wob = m.moving ? Math.sin(tm * 5) * 0.03 * s : 0;
      g.fillStyle = flash ? '#fff' : '#6e6a78';
      roundRect(g, X - 0.3 * s, by - 0.75 * s + wob, 0.6 * s, 0.55 * s, 0.1 * s); g.fill();
      g.fillStyle = flash ? '#fff' : '#5a5664';
      roundRect(g, X - 0.42 * s, by - 0.68 * s - wob, 0.16 * s, 0.45 * s, 0.06 * s); g.fill();
      roundRect(g, X + 0.26 * s, by - 0.68 * s + wob, 0.16 * s, 0.45 * s, 0.06 * s); g.fill();
      roundRect(g, X - 0.22 * s, by - 0.25 * s, 0.16 * s, 0.25 * s, 0.05 * s); g.fill();
      roundRect(g, X + 0.06 * s, by - 0.25 * s, 0.16 * s, 0.25 * s, 0.05 * s); g.fill();
      g.fillStyle = flash ? '#fff' : '#86828f';
      roundRect(g, X - 0.17 * s, by - 0.98 * s + wob, 0.34 * s, 0.26 * s, 0.07 * s); g.fill();
      g.fillStyle = '#5ff0ff';
      g.fillRect(X - 0.1 * s, by - 0.88 * s + wob, 0.06 * s, 0.04 * s); g.fillRect(X + 0.04 * s, by - 0.88 * s + wob, 0.06 * s, 0.04 * s);
      g.fillStyle = 'rgba(40,36,50,0.6)'; g.fillRect(X - 0.1 * s, by - 0.55 * s, 0.2 * s, 0.03 * s);
      break;
    }
  }
  g.restore();
  // Statuseffekte
  const topY = by - (def.r * 2.6 + 0.25) * s * sc - (m.type === 'golem' ? 0.25 * s : 0);
  if (m.para > 0) {
    g.fillStyle = 'rgba(190,120,255,0.9)';
    for (let k = 0; k < 3; k++) {
      const a = G.time * 4 + k * TAU / 3;
      star(g, X + Math.cos(a) * 0.22 * s, topY + 0.05 * s + Math.sin(a) * 0.06 * s, 0.05 * s);
    }
  }
  if (m.slow > 0) {
    g.fillStyle = 'rgba(150,220,255,0.35)';
    g.beginPath(); g.ellipse(X, Y - 0.02 * s, def.r * s * 1.2, def.r * s * 0.5, 0, 0, TAU); g.fill();
  }
  if (m.hp < m.maxHp) hpBar(g, X, topY - 0.05 * s, 0.6 * s * sc, m.hp / m.maxHp);
}

function star(g, x, y, r) {
  g.beginPath();
  for (let k = 0; k < 8; k++) {
    const rr = k % 2 ? r * 0.4 : r, a = k * Math.PI / 4;
    k ? g.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr) : g.moveTo(x + rr, y);
  }
  g.closePath(); g.fill();
}

function drawChest(g, ch) {
  const s = R.T, X = sx(ch.x), Y = sy(ch.y);
  shadowEl(g, X, Y, 0.34 * s);
  const w = 0.56 * s, h = 0.3 * s, d = 0.24 * s;
  g.fillStyle = '#6b3f1f'; g.fillRect(X - w / 2, Y - h, w, h);
  g.fillStyle = '#8a5428'; g.fillRect(X - w / 2, Y - h, w, h * 0.45);
  g.fillStyle = '#d9b04a'; g.fillRect(X - w / 2, Y - h * 0.62, w, h * 0.1);
  g.fillRect(X - w * 0.42, Y - h, w * 0.08, h); g.fillRect(X + w * 0.34, Y - h, w * 0.08, h);
  if (!ch.open) {
    g.fillStyle = '#9a6030'; roundRect(g, X - w / 2, Y - h - d, w, d, d * 0.45); g.fill();
    g.fillStyle = '#d9b04a'; g.fillRect(X - w * 0.42, Y - h - d, w * 0.08, d); g.fillRect(X + w * 0.34, Y - h - d, w * 0.08, d);
    g.fillStyle = '#f6dc7a'; g.fillRect(X - 0.04 * s, Y - h - 0.04 * s, 0.08 * s, 0.1 * s);
    // Glitzern
    const tw = (Math.sin(G.time * 3 + ch.x) + 1) / 2;
    g.fillStyle = `rgba(255,240,170,${0.3 + tw * 0.6})`;
    star(g, X + w * 0.3, Y - h - d - 0.05 * s, 0.05 * s + tw * 0.03 * s);
  } else {
    g.fillStyle = '#2a170c'; g.fillRect(X - w / 2 + 2, Y - h - 2, w - 4, 4);
    g.fillStyle = '#7a4a22'; g.fillRect(X - w / 2, Y - h - d * 1.6, w, d * 0.9);
    g.fillStyle = '#d9b04a'; g.fillRect(X - w / 2, Y - h - d * 1.6, w, d * 0.15);
  }
}

function drawShield(g, x, y, s, fill) {
  g.beginPath();
  g.moveTo(x, y); g.lineTo(x + s * 0.42, y + s * 0.12); g.lineTo(x + s * 0.38, y + s * 0.55);
  g.quadraticCurveTo(x + s * 0.25, y + s * 0.85, x, y + s); g.quadraticCurveTo(x - s * 0.25, y + s * 0.85, x - s * 0.38, y + s * 0.55);
  g.lineTo(x - s * 0.42, y + s * 0.12); g.closePath();
  g.fillStyle = fill; g.fill();
}

function drawHeartShape(g, x, y, s) {
  g.beginPath();
  g.moveTo(x, y + s * 0.3);
  g.bezierCurveTo(x, y, x - s * 0.5, y, x - s * 0.5, y + s * 0.3);
  g.bezierCurveTo(x - s * 0.5, y + s * 0.6, x, y + s * 0.75, x, y + s * 0.95);
  g.bezierCurveTo(x, y + s * 0.75, x + s * 0.5, y + s * 0.6, x + s * 0.5, y + s * 0.3);
  g.bezierCurveTo(x + s * 0.5, y, x, y, x, y + s * 0.3);
  g.closePath();
}

function drawDrop(g, d) {
  const s = R.T, X = sx(d.x), Y = sy(d.y), b = Math.sin(G.time * 4 + d.x) * 0.05 * s;
  shadowEl(g, X, Y, 0.14 * s);
  if (d.kind === 'heart') {
    g.fillStyle = '#e8384a'; drawHeartShape(g, X, Y - 0.42 * s + b, 0.3 * s); g.fill();
  } else {
    g.fillStyle = '#4a7dff'; g.beginPath(); g.arc(X, Y - 0.3 * s + b, 0.12 * s, 0, TAU); g.fill();
    g.fillStyle = '#bcd2ff'; g.beginPath(); g.arc(X - 0.04 * s, Y - 0.34 * s + b, 0.04 * s, 0, TAU); g.fill();
  }
}

function drawProjectile(g, p) {
  const s = R.T, X = sx(p.x), Y = sy(p.y) - 0.4 * s;
  if (p.kind === 'arrow') {
    const a = Math.atan2(p.vy * R.YS, p.vx);
    g.save(); g.translate(X, Y); g.rotate(a);
    g.fillStyle = '#7a4a24'; g.fillRect(-0.3 * s, -0.015 * s, 0.5 * s, 0.03 * s);
    g.fillStyle = '#dfe4f0'; g.beginPath(); g.moveTo(0.2 * s, -0.05 * s); g.lineTo(0.3 * s, 0); g.lineTo(0.2 * s, 0.05 * s); g.fill();
    g.fillStyle = '#e8e8e8'; g.fillRect(-0.3 * s, -0.05 * s, 0.08 * s, 0.1 * s);
    g.restore();
  } else {
    g.save(); g.globalCompositeOperation = 'lighter';
    const gr = g.createRadialGradient(X, Y, 0, X, Y, 0.3 * s);
    gr.addColorStop(0, 'rgba(255,240,160,1)'); gr.addColorStop(0.4, 'rgba(255,120,30,0.8)'); gr.addColorStop(1, 'rgba(255,40,0,0)');
    g.fillStyle = gr; g.fillRect(X - 0.3 * s, Y - 0.3 * s, 0.6 * s, 0.6 * s);
    g.restore();
  }
}

function drawFlame(g, n, e) {
  const s = R.T, X = sx(n.x), Y = sy(n.y);
  const life = clamp(Math.min(e.t * 4, (e.dur - e.t) * 2), 0, 1);
  g.save(); g.globalCompositeOperation = 'lighter';
  const gr = g.createRadialGradient(X, Y - 0.3 * s, 0, X, Y - 0.3 * s, 0.7 * s);
  gr.addColorStop(0, `rgba(255,150,40,${0.45 * life})`); gr.addColorStop(1, 'rgba(255,60,0,0)');
  g.fillStyle = gr; g.fillRect(X - 0.7 * s, Y - s, 1.4 * s, 1.4 * s);
  for (let k = 0; k < 3; k++) {
    const ph = G.time * 9 + n.seed + k * 2.1;
    const h = (0.55 + Math.sin(ph) * 0.15) * s * life * (1 - k * 0.22);
    const w = (0.2 - k * 0.04) * s;
    const ox = Math.sin(ph * 0.7) * 0.06 * s + (k - 1) * 0.1 * s;
    g.fillStyle = k === 2 ? `rgba(255,240,170,${0.9 * life})` : k === 1 ? `rgba(255,170,50,${0.8 * life})` : `rgba(230,70,20,${0.8 * life})`;
    g.beginPath(); g.moveTo(X + ox - w, Y); g.quadraticCurveTo(X + ox - w * 0.8, Y - h * 0.6, X + ox, Y - h);
    g.quadraticCurveTo(X + ox + w * 0.8, Y - h * 0.6, X + ox + w, Y); g.closePath(); g.fill();
  }
  g.restore();
}

function drawShard(g, sh) {
  const s = R.T, X = sx(sh.x), Y = sy(sh.y);
  const k = 1 - sh.z / 4;
  g.fillStyle = `rgba(120,200,255,${0.25 + k * 0.3})`;
  g.beginPath(); g.ellipse(X, Y, 0.18 * s * k + 2, 0.07 * s * k + 1, 0, 0, TAU); g.fill();
  const yy = Y - sh.z * s;
  g.fillStyle = '#d8f4ff';
  g.beginPath(); g.moveTo(X, yy + 0.18 * s); g.lineTo(X - 0.06 * s, yy - 0.1 * s); g.lineTo(X, yy - 0.25 * s); g.lineTo(X + 0.06 * s, yy - 0.1 * s); g.closePath(); g.fill();
  g.fillStyle = '#7fc8ff'; g.beginPath(); g.moveTo(X, yy + 0.18 * s); g.lineTo(X + 0.06 * s, yy - 0.1 * s); g.lineTo(X, yy - 0.25 * s); g.closePath(); g.fill();
}

// ---------- Overlays (Effekte, Partikel, Text) ----------
function drawOverlays(g) {
  const s = R.T;
  for (const e of G.effects) {
    if (e.kind === 'ring') {
      const k = e.t / e.dur, rr = e.R * k;
      g.save(); g.globalCompositeOperation = 'lighter';
      g.strokeStyle = `rgba(200,130,255,${0.9 * (1 - k)})`; g.lineWidth = 0.25 * s * (1 - k) + 2;
      g.beginPath(); g.ellipse(sx(e.x), sy(e.y), rr * s, rr * s * R.YS, 0, 0, TAU); g.stroke();
      g.strokeStyle = `rgba(255,220,255,${0.6 * (1 - k)})`; g.lineWidth = 2;
      g.beginPath(); g.ellipse(sx(e.x), sy(e.y), rr * s * 0.92, rr * s * 0.92 * R.YS, 0, 0, TAU); g.stroke();
      g.restore();
    } else if (e.kind === 'ice') {
      const a = clamp(Math.min(e.t * 3, (e.dur - e.t) * 3), 0, 1) * 0.25;
      g.fillStyle = `rgba(140,210,255,${a})`;
      g.beginPath(); g.ellipse(sx(e.x), sy(e.y), e.R * s, e.R * s * R.YS, 0, 0, TAU); g.fill();
    }
  }
  g.save(); g.globalCompositeOperation = 'lighter';
  for (const p of G.particles) {
    const a = clamp(p.life / p.max, 0, 1);
    g.fillStyle = `rgba(${p.c},${a})`;
    const sz = p.size * s * (p.shrink ? a : 1);
    g.fillRect(sx(p.x) - sz / 2, sy(p.y) - p.z * s - sz / 2, sz, sz);
  }
  g.restore();
  g.textAlign = 'center';
  for (const t of G.texts) {
    const a = clamp(t.life / 0.4, 0, 1);
    g.font = `bold ${Math.round(t.size * (t.big ? 1.25 : 1))}px sans-serif`;
    g.fillStyle = `rgba(0,0,0,${a * 0.7})`;
    g.fillText(t.text, sx(t.x) + 1.5, sy(t.y) - t.z * s + 1.5);
    g.fillStyle = t.color; g.globalAlpha = a;
    g.fillText(t.text, sx(t.x), sy(t.y) - t.z * s);
    g.globalAlpha = 1;
  }
}

function drawLighting(g) {
  const X = sx(G.player.x), Y = sy(G.player.y) - R.T * 0.4;
  const fl = Math.sin(G.time * 7) * 0.012 + Math.sin(G.time * 13) * 0.008;
  const r0 = Math.min(R.VW, R.VH) * (0.42 + fl), r1 = Math.max(R.VW, R.VH) * 0.72;
  const gr = g.createRadialGradient(X, Y, r0 * 0.35, X, Y, r1);
  gr.addColorStop(0, 'rgba(255,170,90,0.06)');
  gr.addColorStop(0.35, 'rgba(10,6,22,0)');
  gr.addColorStop(1, 'rgba(6,3,14,0.82)');
  g.fillStyle = gr; g.fillRect(0, 0, R.VW, R.VH);
}

// ---------- Icons (Aktionstasten, Menü) ----------
function drawIcon(g, id, x, y, s) {
  g.save(); g.translate(x, y);
  g.lineCap = 'round'; g.lineJoin = 'round';
  switch (id) {
    case 'sword':
      g.rotate(-Math.PI / 4);
      g.fillStyle = '#dfe4f0'; g.fillRect(-0.08 * s, -0.45 * s, 0.16 * s, 0.62 * s);
      g.beginPath(); g.moveTo(-0.08 * s, -0.45 * s); g.lineTo(0, -0.58 * s); g.lineTo(0.08 * s, -0.45 * s); g.fill();
      g.fillStyle = '#e2b94a'; g.fillRect(-0.24 * s, 0.15 * s, 0.48 * s, 0.08 * s);
      g.fillStyle = '#6b4424'; g.fillRect(-0.05 * s, 0.23 * s, 0.1 * s, 0.22 * s);
      break;
    case 'axe':
      g.rotate(-Math.PI / 5);
      g.fillStyle = '#8a5a30'; g.fillRect(-0.05 * s, -0.4 * s, 0.1 * s, 0.9 * s);
      g.fillStyle = '#c9ced9';
      g.beginPath(); g.moveTo(0.04 * s, -0.38 * s); g.quadraticCurveTo(0.5 * s, -0.42 * s, 0.42 * s, 0.02 * s);
      g.quadraticCurveTo(0.25 * s, -0.08 * s, 0.04 * s, -0.08 * s); g.fill();
      break;
    case 'bow':
      g.rotate(-Math.PI / 4);
      g.strokeStyle = '#a0682e'; g.lineWidth = 0.09 * s;
      g.beginPath(); g.arc(-0.12 * s, 0, 0.45 * s, -1.1, 1.1); g.stroke();
      g.strokeStyle = '#eee'; g.lineWidth = 0.03 * s;
      g.beginPath(); g.moveTo(-0.12 * s + Math.cos(-1.1) * 0.45 * s, Math.sin(-1.1) * 0.45 * s); g.lineTo(-0.12 * s + Math.cos(1.1) * 0.45 * s, Math.sin(1.1) * 0.45 * s); g.stroke();
      g.strokeStyle = '#dfe4f0'; g.beginPath(); g.moveTo(-0.3 * s, 0); g.lineTo(0.42 * s, 0); g.stroke();
      break;
    case 'paralyze':
      g.strokeStyle = '#d9a6ff'; g.lineWidth = 0.08 * s;
      g.beginPath();
      for (let k = 0; k < 40; k++) { const a = k * 0.42, r = k / 40 * 0.42 * s; k ? g.lineTo(Math.cos(a) * r, Math.sin(a) * r) : g.moveTo(0, 0); }
      g.stroke();
      g.fillStyle = '#fff'; star(g, 0.28 * s, -0.3 * s, 0.1 * s);
      break;
    case 'firewall':
      for (let k = -1; k <= 1; k++) {
        g.fillStyle = '#ff6a20';
        g.beginPath(); g.moveTo(k * 0.28 * s - 0.15 * s, 0.38 * s); g.quadraticCurveTo(k * 0.28 * s - 0.15 * s, -0.1 * s, k * 0.28 * s, (-0.45 + Math.abs(k) * 0.12) * s);
        g.quadraticCurveTo(k * 0.28 * s + 0.15 * s, -0.1 * s, k * 0.28 * s + 0.15 * s, 0.38 * s); g.fill();
        g.fillStyle = '#ffd36a';
        g.beginPath(); g.moveTo(k * 0.28 * s - 0.07 * s, 0.38 * s); g.quadraticCurveTo(k * 0.28 * s, -0.05 * s, k * 0.28 * s, -0.1 * s);
        g.quadraticCurveTo(k * 0.28 * s, -0.05 * s, k * 0.28 * s + 0.07 * s, 0.38 * s); g.fill();
      }
      break;
    case 'icerain':
      for (const [ox, oy] of [[-0.25, -0.15], [0.05, -0.35], [0.28, 0.0], [-0.05, 0.2]]) {
        g.fillStyle = '#d8f4ff';
        g.beginPath(); g.moveTo(ox * s, (oy + 0.22) * s); g.lineTo((ox - 0.07) * s, (oy - 0.05) * s); g.lineTo(ox * s, (oy - 0.2) * s); g.lineTo((ox + 0.07) * s, (oy - 0.05) * s); g.fill();
        g.fillStyle = '#7fc8ff';
        g.beginPath(); g.moveTo(ox * s, (oy + 0.22) * s); g.lineTo((ox + 0.07) * s, (oy - 0.05) * s); g.lineTo(ox * s, (oy - 0.2) * s); g.fill();
      }
      break;
    default:
      g.strokeStyle = 'rgba(255,255,255,0.6)'; g.lineWidth = 0.08 * s;
      g.beginPath(); g.moveTo(-0.25 * s, 0); g.lineTo(0.25 * s, 0); g.moveTo(0, -0.25 * s); g.lineTo(0, 0.25 * s); g.stroke();
  }
  g.restore();
}

function iconDataURL(id, size) {
  const key = id + ':' + size;
  if (R.icons[key]) return R.icons[key];
  const c = mkCanvas(size, size), g = c.getContext('2d');
  drawIcon(g, id, size / 2, size / 2, size * 0.8);
  return (R.icons[key] = c.toDataURL());
}
