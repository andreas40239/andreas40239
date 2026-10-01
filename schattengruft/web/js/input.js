'use strict';
// Touch-Steuerung (Joystick links, 3 Aktionstasten rechts), Tastatur für Desktop + HUD-Zeichnung.
const Input = {
  moveX: 0, moveY: 0, moveMag: 0,
  joy: { id: null, bx: 0, by: 0, kx: 0, ky: 0 },
  keys: {},
  btns: [{}, {}, {}],
  layout: null
};

function computeLayout() {
  const VW = R.VW, VH = R.VH;
  const br = clamp(Math.min(VW, VH) * 0.09, 30, 56);
  const pad = Math.max(18, br * 0.5);
  const b0 = { x: VW - pad - br * 1.15, y: VH - pad - br * 1.15, r: br * 1.15 };
  const b1 = { x: b0.x - br * 2.55, y: b0.y + br * 0.25, r: br };
  const b2 = { x: b0.x + br * 0.15, y: b0.y - br * 2.5, r: br };
  const mm = clamp(VH * 0.3, 84, 170);
  const mini = { x: VW - mm - 12, y: 12, w: mm, h: mm };
  const pause = { x: mini.x - 34, y: 30, r: 20 };
  Input.layout = { btn: [b0, b1, b2], mini, pause, joyR: clamp(Math.min(VW, VH) * 0.12, 40, 70) };
}

function hitCircle(c, x, y, extra) { return dist(c.x, c.y, x, y) <= c.r + (extra || 0); }

function initInput(canvas) {
  canvas.addEventListener('pointerdown', e => {
    e.preventDefault();
    Sound.init();
    if (G.state !== 'play') return;
    const x = e.clientX, y = e.clientY, L = Input.layout;
    if (hitCircle(L.pause, x, y, 10)) { UI.pause(); return; }
    const mm = G.bigMap ? bigMapRect() : L.mini;
    if (x >= mm.x && x <= mm.x + mm.w && y >= mm.y && y <= mm.y + mm.h) { G.bigMap = !G.bigMap; Sound.play('menuMove'); return; }
    for (let i = 0; i < 3; i++) {
      if (hitCircle(L.btn[i], x, y, 8)) {
        const b = Input.btns[i];
        b.id = e.pointerId; b.down = performance.now(); b.long = false;
        doAction(i);
        return;
      }
    }
    if (x < R.VW * 0.55 && Input.joy.id === null) {
      const j = Input.joy;
      j.id = e.pointerId; j.bx = x; j.by = y; j.kx = x; j.ky = y;
    }
  }, { passive: false });

  canvas.addEventListener('pointermove', e => {
    const j = Input.joy;
    if (e.pointerId === j.id) {
      e.preventDefault();
      const L = Input.layout;
      let dx = e.clientX - j.bx, dy = e.clientY - j.by;
      const d = Math.hypot(dx, dy);
      if (d > L.joyR) { // Basis folgt dem Finger
        j.bx += dx / d * (d - L.joyR); j.by += dy / d * (d - L.joyR);
        dx = e.clientX - j.bx; dy = e.clientY - j.by;
      }
      j.kx = e.clientX; j.ky = e.clientY;
    }
  }, { passive: false });

  const up = e => {
    if (e.pointerId === Input.joy.id) Input.joy.id = null;
    for (const b of Input.btns) if (b.id === e.pointerId) b.id = null;
  };
  canvas.addEventListener('pointerup', up);
  canvas.addEventListener('pointercancel', up);
  canvas.addEventListener('contextmenu', e => e.preventDefault());

  window.addEventListener('keydown', e => {
    Sound.init();
    if (Input.keys[e.code]) return;
    Input.keys[e.code] = true;
    if (G.state === 'play') {
      if (e.code === 'KeyJ' || e.code === 'Space') doAction(0);
      if (e.code === 'KeyK') doAction(1);
      if (e.code === 'KeyL') doAction(2);
      if (e.code === 'KeyM') G.bigMap = !G.bigMap;
      if (e.code === 'Digit1') UI.openAssign(0);
      if (e.code === 'Digit2') UI.openAssign(1);
      if (e.code === 'Digit3') UI.openAssign(2);
    }
    if (e.code === 'Escape' || e.code === 'KeyP') UI.back();
  });
  window.addEventListener('keyup', e => { Input.keys[e.code] = false; });
  window.addEventListener('blur', () => { Input.keys = {}; Input.joy.id = null; });
}

function updateInput() {
  let x = 0, y = 0;
  const k = Input.keys;
  if (k.KeyA || k.ArrowLeft) x -= 1;
  if (k.KeyD || k.ArrowRight) x += 1;
  if (k.KeyW || k.ArrowUp) y -= 1;
  if (k.KeyS || k.ArrowDown) y += 1;
  const j = Input.joy;
  if (j.id !== null) {
    const L = Input.layout;
    x = (j.kx - j.bx) / L.joyR; y = (j.ky - j.by) / L.joyR;
    if (Math.hypot(x, y) < 0.15) x = y = 0;
  }
  const m = Math.hypot(x, y);
  if (m > 1) { x /= m; y /= m; }
  Input.moveX = x; Input.moveY = y; Input.moveMag = Math.min(1, m);
  // Langes Drücken -> Belegung ändern
  if (G.state === 'play') {
    for (let i = 0; i < 3; i++) {
      const b = Input.btns[i];
      if (b.id != null && !b.long && performance.now() - b.down > 650) {
        b.long = true; b.id = null;
        UI.openAssign(i);
      }
    }
  }
}

// ---------- HUD ----------
function drawHUD(g) {
  const p = G.player, L = Input.layout, VW = R.VW, VH = R.VH;
  // Herzen
  const hs = clamp(VH * 0.055, 16, 28);
  const hearts = Math.ceil(p.maxHp / 2);
  for (let i = 0; i < hearts; i++) {
    const x = 16 + hs * 0.5 + i * hs * 1.1, y = 12;
    g.fillStyle = 'rgba(0,0,0,0.45)'; drawHeartShape(g, x + 1.5, y + 1.5, hs); g.fill();
    g.fillStyle = '#4a2030'; drawHeartShape(g, x, y, hs); g.fill();
    const v = clamp(p.hp - i * 2, 0, 2);
    if (v > 0) {
      g.save();
      if (v === 1 || (v > 0 && v < 2)) { g.beginPath(); g.rect(x - hs, y - 2, hs * (v / 2), hs * 1.2); g.clip(); }
      g.fillStyle = '#e8384a'; drawHeartShape(g, x, y, hs); g.fill();
      g.fillStyle = 'rgba(255,200,200,0.6)'; g.beginPath(); g.arc(x - hs * 0.22, y + hs * 0.25, hs * 0.08, 0, TAU); g.fill();
      g.restore();
    }
  }
  // Mana + EP
  const bw = clamp(VW * 0.2, 110, 220), by = 14 + hs * 1.05;
  g.fillStyle = 'rgba(10,8,25,0.7)'; roundRect(g, 14, by, bw + 4, 14, 5); g.fill();
  g.fillStyle = '#3d6cf0'; roundRect(g, 16, by + 2, bw * clamp(p.mana / p.maxMana, 0, 1), 10, 4); g.fill();
  g.fillStyle = '#fff'; g.font = 'bold 10px sans-serif'; g.textAlign = 'center';
  g.fillText(Math.floor(p.mana) + ' / ' + p.maxMana + ' Mana', 16 + bw / 2, by + 11);
  const xy = by + 18;
  g.fillStyle = 'rgba(10,8,25,0.7)'; roundRect(g, 14, xy, bw + 4, 8, 4); g.fill();
  g.fillStyle = '#9be36a'; roundRect(g, 16, xy + 2, bw * clamp(p.xp / xpNeeded(p.lvl), 0, 1), 4, 2); g.fill();
  g.textAlign = 'left'; g.font = 'bold 12px sans-serif';
  g.fillStyle = 'rgba(0,0,0,0.6)'; g.fillText('Stufe ' + p.lvl + '   ·   Ebene ' + G.level, 17, xy + 23);
  g.fillStyle = '#efe8ff'; g.fillText('Stufe ' + p.lvl + '   ·   Ebene ' + G.level, 16, xy + 22);

  // Pause-Taste
  const pb = L.pause;
  g.fillStyle = 'rgba(20,16,40,0.65)'; g.beginPath(); g.arc(pb.x, pb.y, pb.r, 0, TAU); g.fill();
  g.strokeStyle = 'rgba(200,190,255,0.5)'; g.lineWidth = 1.5; g.stroke();
  g.fillStyle = '#e6e0ff'; g.fillRect(pb.x - 6, pb.y - 7, 4, 14); g.fillRect(pb.x + 2, pb.y - 7, 4, 14);

  drawMinimap(g, G.bigMap ? bigMapRect() : L.mini);

  // Joystick
  const j = Input.joy;
  if (j.id !== null) {
    g.fillStyle = 'rgba(200,190,255,0.12)'; g.strokeStyle = 'rgba(200,190,255,0.35)'; g.lineWidth = 2;
    g.beginPath(); g.arc(j.bx, j.by, L.joyR, 0, TAU); g.fill(); g.stroke();
    let kx = j.kx - j.bx, ky = j.ky - j.by; const d = Math.hypot(kx, ky);
    if (d > L.joyR) { kx = kx / d * L.joyR; ky = ky / d * L.joyR; }
    g.fillStyle = 'rgba(220,210,255,0.55)';
    g.beginPath(); g.arc(j.bx + kx, j.by + ky, L.joyR * 0.45, 0, TAU); g.fill();
  } else {
    const hx = Math.max(90, VW * 0.14), hy = VH - Math.max(90, VH * 0.22);
    g.strokeStyle = 'rgba(200,190,255,0.14)'; g.lineWidth = 2;
    g.beginPath(); g.arc(hx, hy, L.joyR, 0, TAU); g.stroke();
    g.fillStyle = 'rgba(200,190,255,0.08)'; g.beginPath(); g.arc(hx, hy, L.joyR * 0.45, 0, TAU); g.fill();
  }

  // Aktionstasten
  for (let i = 0; i < 3; i++) {
    const b = L.btn[i], id = G.slots[i];
    const pressed = Input.btns[i].id != null;
    const usable = canUse(id);
    const noMana = SPELLS[id] && p.mana < SPELLS[id].mana;
    g.fillStyle = pressed ? 'rgba(120,100,200,0.75)' : 'rgba(30,24,60,0.62)';
    g.beginPath(); g.arc(b.x, b.y, b.r, 0, TAU); g.fill();
    g.strokeStyle = SPELLS[id] ? 'rgba(200,150,255,0.8)' : 'rgba(230,220,255,0.6)'; g.lineWidth = 2.5; g.stroke();
    g.globalAlpha = usable && !noMana ? 1 : 0.35;
    drawIcon(g, id, b.x, b.y, b.r * 1.15);
    g.globalAlpha = 1;
    const cd = id ? actionCdFrac(id) : 0;
    if (cd > 0) {
      g.fillStyle = 'rgba(0,0,0,0.55)';
      g.beginPath(); g.moveTo(b.x, b.y); g.arc(b.x, b.y, b.r, -Math.PI / 2, -Math.PI / 2 + cd * TAU); g.closePath(); g.fill();
    }
    g.font = 'bold 11px sans-serif'; g.textAlign = 'center';
    if (WEAPONS[id] && p.weapons[id] > 1) {
      g.fillStyle = '#ffe14a'; g.fillText('+' + (p.weapons[id] - 1), b.x + b.r * 0.62, b.y - b.r * 0.55);
    }
    if (SPELLS[id]) {
      g.fillStyle = noMana ? '#ff7a7a' : '#a9c4ff';
      g.fillText(SPELLS[id].mana + ' MP', b.x, b.y + b.r * 0.78);
      if (!usable) { g.fillStyle = '#fff'; g.fillText('Stufe ' + SPELLS[id].lvl, b.x, b.y - b.r * 0.6); }
    }
  }

  // Meldungen
  g.textAlign = 'center';
  let ty = Math.max(54, VH * 0.15);
  const fsz = clamp(VH * 0.032, 11, 16);
  g.font = `bold ${fsz}px sans-serif`;
  for (const t of G.toasts) {
    const a = clamp(Math.min(t.t * 5, (3.2 - t.t) * 2), 0, 1);
    const w = g.measureText(t.text).width + 24;
    g.fillStyle = `rgba(16,10,34,${0.72 * a})`; roundRect(g, VW / 2 - w / 2, ty - fsz, w, fsz * 1.6, 8); g.fill();
    g.globalAlpha = a; g.fillStyle = t.color; g.fillText(t.text, VW / 2, ty + fsz * 0.2); g.globalAlpha = 1;
    ty += fsz * 1.9;
  }

  if (G.hurtFlash > 0) {
    g.fillStyle = `rgba(200,20,40,${G.hurtFlash * 0.6})`; g.fillRect(0, 0, VW, VH);
  }
  if (G.fade > 0) {
    g.fillStyle = `rgba(4,2,10,${G.fade})`; g.fillRect(0, 0, VW, VH);
    if (G.fade > 0.6) {
      g.globalAlpha = (G.fade - 0.6) / 0.4;
      g.fillStyle = '#d9cfff'; g.font = `bold ${Math.round(VH * 0.08)}px Georgia, serif`;
      g.fillText('Ebene ' + (G.fadeDir > 0 ? G.level + 1 : G.level), VW / 2, VH / 2);
      g.globalAlpha = 1;
    }
  }
}

function bigMapRect() {
  const s = Math.min(R.VW, R.VH) * 0.86;
  return { x: (R.VW - s) / 2, y: (R.VH - s) / 2, w: s, h: s };
}

const MM = { canvas: null, img: null };
function drawMinimap(g, r) {
  const map = G.map, W = map.W, H = map.H;
  if (!MM.canvas || MM.canvas.width !== W || MM.canvas.height !== H) {
    MM.canvas = mkCanvas(W, H);
    MM.img = MM.canvas.getContext('2d').createImageData(W, H);
    G.minimapDirty = true;
  }
  if (G.minimapDirty) {
    G.minimapDirty = false;
    const d = MM.img.data;
    for (let i = 0; i < W * H; i++) {
      const o = i * 4;
      if (!G.seen[i]) { d[o + 3] = 0; continue; }
      const t = map.t[i];
      const c = t === 1 ? [160, 150, 225] : t === 2 ? [140, 130, 200] : t === 3 ? [120, 240, 140] : [205, 110, 60];
      d[o] = c[0]; d[o + 1] = c[1]; d[o + 2] = c[2]; d[o + 3] = 255;
    }
    MM.canvas.getContext('2d').putImageData(MM.img, 0, 0);
  }
  g.fillStyle = G.bigMap ? 'rgba(10,7,22,0.94)' : 'rgba(14,10,30,0.78)'; roundRect(g, r.x, r.y, r.w, r.h, 8); g.fill();
  g.strokeStyle = 'rgba(190,175,255,0.55)'; g.lineWidth = 2; g.stroke();
  const sc = Math.min((r.w - 10) / W, (r.h - 10) / H);
  const ox = r.x + (r.w - W * sc) / 2, oy = r.y + (r.h - H * sc) / 2;
  g.imageSmoothingEnabled = false;
  g.drawImage(MM.canvas, ox, oy, W * sc, H * sc);
  g.imageSmoothingEnabled = true;
  for (const ch of G.chests) {
    if (ch.open || !G.seen[Math.floor(ch.y) * W + Math.floor(ch.x)]) continue;
    g.fillStyle = '#ffd84a'; g.fillRect(ox + ch.x * sc - 2, oy + ch.y * sc - 2, 4, 4);
  }
  for (const m of G.monsters) {
    if (m.bones || !isVisible(m.x, m.y)) continue;
    g.fillStyle = '#ff4a4a'; g.fillRect(ox + m.x * sc - 1.5, oy + m.y * sc - 1.5, 3, 3);
  }
  const p = G.player, pulse = 2.5 + Math.sin(G.time * 6) * 0.8;
  g.fillStyle = '#ffffff'; g.beginPath(); g.arc(ox + p.x * sc, oy + p.y * sc, pulse, 0, TAU); g.fill();
  g.strokeStyle = '#ffffff'; g.lineWidth = 1.5;
  g.beginPath(); g.moveTo(ox + p.x * sc, oy + p.y * sc);
  g.lineTo(ox + (p.x + Math.cos(p.face) * 2.5) * sc, oy + (p.y + Math.sin(p.face) * 2.5) * sc); g.stroke();
}
