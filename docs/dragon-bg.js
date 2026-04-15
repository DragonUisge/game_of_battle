/* dragon-bg.js — shared background + scroll reveal for all pages */
(function () {
  'use strict';

  /* ============================================================
     Dragon canvas background
     Drifting semi-transparent dragons using the real dragon image.
     mix-blend-mode:screen on the canvas makes the black
     background disappear naturally over the dark navy theme.
     ============================================================ */
  const canvas = document.getElementById('dragon-canvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  let W, H;

  function resize() {
    W = canvas.width  = window.innerWidth;
    H = canvas.height = window.innerHeight;
  }
  resize();
  window.addEventListener('resize', resize);

  /* Base display size for one ghost (px) */
  const DW = 360;
  const DH = 360;

  function spawn(ix) {
    const scale = 0.4 + Math.random() * 0.85;
    const speed = 0.22 + Math.random() * 0.38;
    const dir   = ix % 2 === 0 ? 1 : -1;
    return {
      x:     dir > 0 ? -DW * scale * 1.2 : W + DW * scale * 1.2,
      y:     Math.random() * H,
      vx:    speed * dir,
      vy:    (Math.random() - 0.5) * 0.14,
      scale,
      alpha: 0.18 + Math.random() * 0.14,
    };
  }

  let ghosts;

  function tick() {
    ctx.clearRect(0, 0, W, H);
    const margin = 420;
    ghosts.forEach((g, i) => {
      const w = DW * g.scale, h = DH * g.scale;
      ctx.save();
      ctx.globalAlpha = g.alpha;
      if (g.vx < 0) {
        ctx.translate(g.x + w, g.y);
        ctx.scale(-1, 1);
        ctx.drawImage(dragonImg, 0, 0, w, h);
      } else {
        ctx.drawImage(dragonImg, g.x, g.y, w, h);
      }
      ctx.restore();
      g.x += g.vx; g.y += g.vy;
      if (g.x > W + margin || g.x < -margin) {
        Object.assign(g, spawn(i));
      }
      if (g.y > H + margin) g.y = -margin;
      if (g.y < -margin)    g.y = H + margin;
    });
    requestAnimationFrame(tick);
  }

  const dragonImg = new Image();
  dragonImg.onload = function () {
    /* Stagger starting positions across the screen on load */
    ghosts = Array.from({length: 5}, (_, i) => {
      const g = spawn(i);
      g.x = Math.random() * W;
      return g;
    });
    tick();
  };
  dragonImg.src = 'assets/dragon_hero.png';

  /* ============================================================
     Scroll reveal — shared by all pages
     ============================================================ */
  const revealObs = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        e.target.classList.add('visible');
        revealObs.unobserve(e.target);
      }
    });
  }, { threshold: 0.09 });
  document.querySelectorAll('.reveal').forEach(el => revealObs.observe(el));
})();
