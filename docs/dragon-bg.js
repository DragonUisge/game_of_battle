/* dragon-bg.js — shared background + scroll reveal for all pages */
(function () {
  'use strict';

  /* ============================================================
     Dragon canvas background
     Draws several slow-drifting semi-transparent dragon silhouettes
     inspired by the Longi (fire dragon) from draconis.
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

  /* Pre-render one dragon onto an offscreen canvas at 280×180 */
  function buildDragon() {
    const oc = document.createElement('canvas');
    oc.width = 280; oc.height = 180;
    const c = oc.getContext('2d');
    c.fillStyle = '#4db3ff';

    /* ── Body (upper silhouette + belly, head, tail) ── */
    c.beginPath();
    c.moveTo(215, 62);
    // upper jaw
    c.bezierCurveTo(234, 52, 252, 47, 258, 54);
    c.bezierCurveTo(265, 59, 262, 70, 254, 74);
    // open mouth lower jaw
    c.lineTo(264, 83);
    c.lineTo(246, 89);
    // lower neck / belly
    c.bezierCurveTo(228, 93, 210, 94, 185, 97);
    c.bezierCurveTo(155, 101, 110, 102, 78, 97);
    c.bezierCurveTo(52, 94, 30, 102, 18, 106);
    // tail lower curve + spade tip
    c.bezierCurveTo(8, 110, 4, 118, 10, 122);
    c.bezierCurveTo(14, 128, 22, 126, 20, 118);
    c.bezierCurveTo(18, 111, 28, 106, 38, 103);
    // back up along dorsal line
    c.bezierCurveTo(58, 95, 85, 84, 120, 78);
    c.bezierCurveTo(160, 70, 192, 66, 215, 62);
    c.closePath();
    c.fill();

    /* ── Upper wing ── */
    c.beginPath();
    c.moveTo(138, 78);
    c.bezierCurveTo(124, 54, 106, 18, 122, 7);
    c.bezierCurveTo(132, 0, 148, 14, 155, 36);
    c.bezierCurveTo(161, 54, 152, 72, 140, 78);
    c.closePath();
    c.fill();

    /* ── Lower wing ── */
    c.beginPath();
    c.moveTo(132, 88);
    c.bezierCurveTo(116, 114, 104, 148, 120, 158);
    c.bezierCurveTo(130, 165, 142, 152, 146, 132);
    c.bezierCurveTo(150, 115, 142, 93, 134, 88);
    c.closePath();
    c.fill();

    /* ── Horn 1 ── */
    c.beginPath();
    c.moveTo(220, 62);
    c.lineTo(226, 42); c.lineTo(219, 52);
    c.closePath(); c.fill();

    /* ── Horn 2 ── */
    c.beginPath();
    c.moveTo(230, 58);
    c.lineTo(238, 38); c.lineTo(228, 48);
    c.closePath(); c.fill();

    /* ── Dorsal spines ── */
    [[160,74],[170,71],[180,68],[190,65],[200,63]].forEach(([sx,sy]) => {
      c.beginPath();
      c.moveTo(sx, sy);
      c.lineTo(sx + 3, sy - 10);
      c.lineTo(sx + 6, sy);
      c.closePath(); c.fill();
    });

    return oc;
  }

  const dragonImg = buildDragon();
  const DW = dragonImg.width;
  const DH = dragonImg.height;

  /* ── Spawn 5 ghosts at staggered positions ── */
  function spawn(ix) {
    const scale = 0.5 + Math.random() * 1.1;
    const speed = 0.25 + Math.random() * 0.45;
    const dir   = ix % 2 === 0 ? 1 : -1;
    return {
      x:     dir > 0 ? -DW * scale * 1.2 : W + DW * scale * 1.2,
      y:     Math.random() * H,
      vx:    speed * dir,
      vy:    (Math.random() - 0.5) * 0.18,
      scale,
      alpha: 0.035 + Math.random() * 0.055,
    };
  }
  const ghosts = Array.from({length: 5}, (_, i) => spawn(i));

  function tick() {
    ctx.clearRect(0, 0, W, H);
    const margin = 320;
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
      // re-enter from opposite side
      if (g.x > W + margin || g.x < -margin) {
        Object.assign(g, spawn(i));
      }
      if (g.y > H + margin) g.y = -margin;
      if (g.y < -margin)    g.y = H + margin;
    });
    requestAnimationFrame(tick);
  }
  tick();

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
