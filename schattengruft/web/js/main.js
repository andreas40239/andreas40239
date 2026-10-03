'use strict';
// Einstiegspunkt: Canvas, Größenanpassung, Spielschleife, Android-Brücke.
(() => {
  const canvas = document.getElementById('game');
  const g = canvas.getContext('2d', { alpha: false });

  function resize() {
    const vw = window.innerWidth, vh = window.innerHeight;
    // Pixelbudget (~1920x1200): große Tablets nicht in voller Auflösung rendern, spart CPU/GPU.
    const dpr = Math.max(1, Math.min(window.devicePixelRatio || 1, 2, Math.sqrt(2.3e6 / (vw * vh))));
    canvas.width = Math.round(vw * dpr); canvas.height = Math.round(vh * dpr);
    canvas.style.width = vw + 'px'; canvas.style.height = vh + 'px';
    resizeRender(vw, vh, dpr);
    computeLayout();
  }
  window.addEventListener('resize', resize);
  resize();

  // Demo-Dungeon als Menühintergrund
  G.player = newPlayer();
  G.level = 2;
  startLevel(4242);
  G.cam.x = G.map.W / 2; G.cam.y = G.map.H / 2;

  initInput(canvas);
  UI.init();

  // Erste Berührung startet Audio (Browser-Vorgabe)
  const unlock = () => { Sound.init(); Sound.startMusic(); };
  window.addEventListener('pointerdown', unlock, { once: true });
  window.addEventListener('keydown', unlock, { once: true });

  let last = performance.now();
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    updateInput();
    if (G.demo) {
      G.time += dt;
      G.cam.x = G.map.W / 2 + Math.cos(G.time * 0.05) * G.map.W * 0.3;
      G.cam.y = G.map.H / 2 + Math.sin(G.time * 0.07) * G.map.H * 0.3;
    } else {
      update(dt);
    }
    g.setTransform(R.dpr, 0, 0, R.dpr, 0, 0);
    const shx = G.shake > 0 ? (Math.random() - 0.5) * 8 * G.shake / 0.25 : 0;
    const shy = G.shake > 0 ? (Math.random() - 0.5) * 8 * G.shake / 0.25 : 0;
    g.translate(shx, shy);
    drawWorld(g);
    if (!G.demo) {
      drawOverlays(g);
      drawLighting(g);
      g.setTransform(R.dpr, 0, 0, R.dpr, 0, 0);
      drawHUD(g);
    } else {
      g.fillStyle = 'rgba(8,5,18,0.45)'; g.fillRect(-10, -10, R.VW + 20, R.VH + 20);
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  // Android-WebView-Brücke
  window.onAndroidBack = () => UI.back();
  window.onAppPause = () => {
    Save.autosave();
    Sound.suspend();
    if (G.state === 'play') UI.pause();
  };
  window.onAppResume = () => Sound.resume();
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) window.onAppPause(); else window.onAppResume();
  });

  // Testzugriff (z.B. automatisierte Screenshots)
  window.__G = G;
})();
