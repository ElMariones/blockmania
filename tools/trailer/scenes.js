// BLOCKMANIA trailer scenes. Each scene covers [b0, b1) in beats; draw(t, lt) paints the content
// layer (lt = seconds since the scene start). bg(t) returns swirl parameters for the backdrop.
'use strict';

const BG = {
  plum: ['#140c24', '#3b1d51', '#0b4d57', '#942d70', '#ffb84d'],
  teal: ['#08161f', '#11343f', '#16605e', '#2a8a73', '#ffcc3d'],
  boss: ['#16040c', '#420c1e', '#5e0c1c', '#b8243f', '#ffcc3d'],
  party: ['#1a1026', '#3f2b5e', '#2d7fd0', '#e8406a', '#ffcc3d'],
};
const bgp = (key, o = {}) => ({ cols: BG[key].map(hex3), pulse: o.pulse ?? 0, swirl: o.swirl ?? 2.4, focusX: o.focusX ?? 0, dark: o.dark ?? 1 });

// Generic helpers for scenes -------------------------------------------------------------
function slab(c) { rect(0, 0, W, H, c); }
function emptyGrid(cell, alpha, color = null, off = 0) {
  setSmooth(false);
  ctx.globalAlpha = alpha;
  for (let y = -((off % cell) + cell) % cell - cell; y < H; y += cell)
    for (let x = 0; x < W; x += cell) ctx.drawImage(IMG.cell_empty, x + 4, y + 4, cell - 8, cell - 8);
  ctx.globalAlpha = 1;
}
// Subtitle bar: INK slab with cream text, above the Steam controls.
function subtitle(s, t, t0, t1, o = {}) {
  if (t < t0 || t >= t1) return;
  const size = o.size ?? 40;
  const shown = reveal(s, t, t0, Math.min(0.35, s.length * 0.012));
  const w = textW(s, size, false) + 64;
  const x = o.x ?? (W - w) / 2, y = o.y ?? 900;
  const k = E.outExpo(inv(t0, t0 + 0.15, t));
  rect(x, y, w * k, size + 34, o.bg || PAL.ink);
  if (o.accent) rect(x, y, 10, size + 34, o.accent);
  text(shown, x + 32, y + size + 12, size, o.color || PAL.cream, { bold: false });
}
// Card sticker: rarity border, cream body, portrait, name, rarity pill, wrapped text.
function wrap(s, size, maxW, bold = false) {
  ctx.font = font(size, bold);
  const words = s.split(' '), lines = [];
  let cur = '';
  for (const w of words) {
    const tr = cur ? cur + ' ' + w : w;
    if (ctx.measureText(tr).width > maxW && cur) { lines.push(cur); cur = w; } else cur = tr;
  }
  if (cur) lines.push(cur);
  return lines;
}
function card(x, y, w, h, j, t, o = {}) {
  const col = RARITY[j.rarity] || PAL.dim;
  ctx.save();
  ctx.translate(Math.round(x + w / 2), Math.round(y + h / 2));
  if (o.rot) ctx.rotate(o.rot);
  if (o.scale && o.scale !== 1) ctx.scale(o.scale, o.scale);
  const X = -w / 2, Y = -h / 2;
  pxRect(X, Y, w, h, col, { shadow: o.shadow ?? 14, notch: 10 });
  pxRect(X + 10, Y + 10, w - 20, h - 20, PAL.cream, { notch: 6 });
  const ps = o.ps ?? Math.floor((w - 60) / 16 / 2);
  const pw = 16 * ps;
  pxRect(X + (w - pw) / 2 - 8, Y + 26, pw + 16, pw + 16, PAL.ink, { notch: 4 });
  portrait('jokers', j.id, X + (w - pw) / 2, Y + 34, ps, glint(t, j.id.length * 7 + 3));
  let yy = Y + 34 + pw + 24;
  const rs = o.small ? 20 : 20;
  const rl = j.rarity.toUpperCase();
  const rw = textW(rl, rs) + 24;
  pxRect(-rw / 2, yy, rw, rs + 14, col, { notch: 4 });
  text(rl, 0, yy + rs + 5, rs, PAL.ink, { align: 'center' });
  yy += rs + 14 + (o.small ? 40 : 50);
  let ns = o.small ? 30 : 40;
  while (textW(j.name, ns) > w - 44 && ns > 20) ns -= 10;
  text(j.name, 0, yy, ns, PAL.ink, { align: 'center' });
  if (!o.noText) {
    yy += 14;
    const lines = wrap(j.text, 20, w - 56);
    lines.slice(0, 4).forEach((l, i) => text(l, 0, yy + 24 * (i + 1), 20, PAL.plum, { align: 'center', bold: false }));
  }
  if (o.bump) { ctx.globalAlpha = o.bump; pxRect(X, Y, w, h, '#ffffff', { notch: 10 }); ctx.globalAlpha = 1; }
  ctx.restore();
}
function pill(s, x, y, size, bg, fg, o = {}) {
  const w = textW(s, size) + size * 0.9;
  const h = size * 1.6;
  const X = o.align === 'center' ? x - w / 2 : o.align === 'right' ? x - w : x;
  pxRect(X, y, w, h, bg, { notch: Math.max(4, size / 6), shadow: o.shadow ?? Math.round(size / 5) });
  text(s, X + w / 2, y + h / 2 + size * 0.36, size, fg, { align: 'center' });
  return w;
}
function jok(id) { return JOKERS.find((j) => j.id === id); }

// MEGA text with a solid extrude (stacked offsets) for the chunky toy look.
function mega(s, x, y, size, color, depthColor, depth, o = {}) {
  ctx.font = font(size);
  ctx.textAlign = o.align || 'left';
  ctx.textBaseline = 'alphabetic';
  const step = Math.max(2, Math.round(size / 40));
  ctx.fillStyle = depthColor;
  for (let d = depth; d > 0; d -= step) ctx.fillText(s, Math.round(x + d), Math.round(y + d));
  ctx.fillStyle = color;
  ctx.fillText(s, Math.round(x), Math.round(y));
}
function scaled(cx, cy, s, fn, rot = 0) {
  ctx.save(); ctx.translate(cx, cy); ctx.scale(s, s); if (rot) ctx.rotate(rot); fn(); ctx.restore();
}

// BLOCKTYPE word: letters fall as pieces, optional clear-out. Returns layout.
function blockWord(str, t, o) {
  const g = glyphs(str, true);
  const s = o.cell ?? Math.floor(Math.min(o.fitW / g.w, (o.fitH ?? 9999) / g.h) / 2) * 2;
  const x0 = Math.round((o.cx ?? W / 2) - (g.w * s) / 2), y0 = Math.round((o.cy ?? H / 2) - (g.h * s) / 2);
  const face = Math.round(s * 11 / 12), pad = Math.round((s - face) / 2);
  for (const c of g.cells) {
    const tl = o.land(c.li);
    const ci = o.color(c.li, c);
    let bx = x0 + c.x * s + pad, by = y0 + c.y * s + pad, sx = 1, sy = 1, white = 0, sc = 1;
    const d = drop(t, tl - (o.fall ?? 0.2), o.fall ?? 0.2);
    if (!d.on) continue;
    by += d.y * (y0 + g.h * s + 80);
    if (o.bob && t > tl + 0.4) by += Math.round(Math.sin(t * 5 - c.x * 0.35) * o.bob * Math.min(1, (t - tl - 0.4) * 2));
    sx = d.sx; sy = d.sy;
    if (o.clearAt !== undefined) {
      const tc = o.clearAt + (o.clearWave ? o.clearWave(c) : 0);
      if (t >= tc) {
        const dd = t - tc;
        if (dd > 0.24) continue;
        white = dd < 0.06 ? 1 : 1 - (dd - 0.06) / 0.1;
        sc = dd < 0.06 ? 1.1 : Math.max(0, 1.1 * (1 - E.inQuad((dd - 0.06) / 0.18)));
      }
    }
    const fs = face * sc;
    if (o.fin) finBlock(o.fin, ci, c.x, c.y, bx + (face - fs) / 2, by + (face - fs) / 2, fs, t, { sx, sy, white });
    else block(ci, bx + (face - fs) / 2, by + (face - fs) / 2, fs, { sx, sy, white: Math.max(0, white) });
  }
  if (o.clearAt !== undefined) for (const c of g.cells) {
    if ((c.x + c.y) % 2) continue;
    const tc = o.clearAt + (o.clearWave ? o.clearWave(c) : 0);
    burst(t, tc + 0.06, x0 + c.x * s + s / 2, y0 + c.y * s + s / 2, { n: 3, seed: c.x * 31 + c.y * 17, speed: s * 12, grav: s * 40, size: Math.max(6, s / 4), colors: [HUE[o.color(c.li, c)], PAL.cream], life: 0.6 });
  }
  return { x0, y0, w: g.w * s, h: g.h * s, g, s };
}

// ============================================================================ SCENES
const SCENES = [];
function scene(b0, b1, def) { SCENES.push(Object.assign({ b0, b1, t0: b2t(b0), t1: b2t(b1), shift: 0 }, def)); }

// ---------------------------------------------------------------- HOOK 1: PLACE (b0-4)
{
  const LAND = (li) => li * 0.1; // P lands on the downbeat at t=0
  const TDOT = 0.5;
  scene(0, 2, {
    init() {
      for (let i = 0; i < 5; i++) cue(LAND(i), 'place', { shake: 6 + i * 2, vel: 0.9, var: i });
      cue(TDOT, 'place_big', { shake: 22, shock: 0.4 });
    },
    draw(t) {
      slab(PAL.ink);
      emptyGrid(120, 0.22);
      const lay = blockWord('PLACE', t, { fitW: 1640, cx: W / 2 - 50, cy: 540, fall: 0.14, land: LAND, color: (li) => [0, 1, 2, 3, 4][li] });
      // the full stop: a 2x2 piece slams on beat 2.5
      const s = lay.w / lay.g.w, bx = lay.x0 + lay.w + s * 0.8, by = lay.y0 + lay.h - 2 * s;
      const d = drop(t, TDOT - 0.14, 0.14);
      if (d.on) {
        for (const [ox, oy] of [[0, 0], [1, 0], [0, 1], [1, 1]]) block(5, bx + ox * s, by + oy * s + d.y * 900, s * 11 / 12, { sx: d.sx, sy: d.sy });
        dust(t, TDOT, bx, by + 2 * s, 2 * s, { n: 8, size: 24 });
      }
      for (let i = 0; i < 5; i++) dust(t, LAND(i), lay.x0 + i * lay.w / 5, lay.y0 + lay.h, lay.w / 5, { seed: i + 2, size: 16 });
      // caption tag
      if (t > 0.55) {
        const k = E.outExpo(inv(0.55, 0.7, t));
        pill('01', 150, 150 - (1 - k) * 60, 40, PAL.sun, PAL.ink);
      }
    },
  });
}

// ---------------------------------------------------------------- HOOK 2: CLEAR (b4-8)
{
  const T0 = 1.0, TC = 1.5, STEP = 0.0625;
  scene(2, 4, {
    init() {
      for (let i = 0; i < 8; i++) cue(T0 + i * STEP, 'tick', { var: i, shake: 3 });
      cue(TC, 'clear_big', { shake: 26, shock: 0.8, flash: 0.35 });
    },
    draw(t) {
      slab(PAL.ink);
      emptyGrid(120, 0.12);
      const s = 220, y = 430, X0 = 80;
      // the board row
      for (let i = 0; i < 8; i++) {
        setSmooth(false);
        ctx.globalAlpha = t < TC ? 1 : Math.max(0, 1 - (t - TC) / 0.2);
        ctx.drawImage(IMG.cell_empty, X0 + i * s + 10, y + 10, 200, 200);
        ctx.globalAlpha = 1;
      }
      // CLEAR word revealed behind the popping row
      if (t >= TC) {
        const k = slam(t, TC, 0.2, 0.6);
        scaled(W / 2, 540, k, () => mega('CLEAR', 0, 115, 330, PAL.mint, '#15704a', 26, { align: 'center' }));
      }
      for (let i = 0; i < 8; i++) {
        const tp = T0 + i * STEP;
        const d = drop(t, tp - 0.08, 0.08);
        if (!d.on) continue;
        const tc = TC + Math.abs(i - 3.5) * 0.03;
        let white = 0, sc = 1;
        if (t >= tc) {
          const dd = t - tc;
          if (dd > 0.26) continue;
          white = dd < 0.07 ? 1 : 1 - (dd - 0.07) / 0.1;
          sc = dd < 0.07 ? 1.08 : Math.max(0, 1.08 * (1 - E.inQuad((dd - 0.07) / 0.19)));
        }
        const f = 200 * sc;
        block(i % 6, X0 + i * s + 10 + (200 - f) / 2, y + 10 + (200 - f) / 2 + d.y * 700, f, { sx: d.sx, sy: d.sy, white: Math.max(0, white) });
      }
      for (let i = 0; i < 8; i++) {
        const tc = TC + Math.abs(i - 3.5) * 0.03;
        burst(t, tc + 0.07, X0 + i * s + 110, y + 110, { n: 16, seed: 40 + i, speed: 1500, grav: 3000, size: 22, colors: [HUE[i % 6], PAL.cream, '#fff'], life: 0.8 });
      }
      if (t > 1.6) pill('02', 150, 150, 40, PAL.mint, PAL.ink);
    },
  });
}

// ---------------------------------------------------------------- HOOK 3: ×MULT (b8-12)
{
  const SL = [
    { id: 'jackpot_window', p: '×5 MULT', x: 1130, y: 80, r: -0.06 },
    { id: 'snowball', p: '×1.9 MULT', x: 1480, y: 120, r: 0.05 },
    { id: 'hot_hand', p: '×1.5 MULT', x: 1150, y: 540, r: 0.04 },
    { id: 'hall_of_mirrors', p: 'TWICE!', x: 1500, y: 570, r: -0.05 },
  ];
  const TB = (i) => 2.0 + i * 0.25, TP = 0.12;
  const MV = [1, 5, 9.5, 14.25, 28.5];
  scene(4, 6, {
    init() {
      cue(2.0, 'slab', { shake: 10 });
      SL.forEach((s, i) => { cue(TB(i), 'joker', { var: i, shake: 12, shock: 0.25 }); cue(TB(i) + TP, 'mult', { var: i }); });
    },
    draw(t) {
      slab(PAL.pink);
      // diagonal stripe texture (brutalist hatching) at the left
      ctx.fillStyle = PAL.pinkD;
      for (let i = -20; i < 40; i++) { const x = i * 60 + ((t * 80) % 60); ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x + 24, 0); ctx.lineTo(x + 24 - 1080 * 0.5, H); ctx.lineTo(x - 1080 * 0.5, H); ctx.fill(); }
      ctx.globalAlpha = 1;
      rect(0, 0, 1060, H, PAL.pink);
      // MEGA ×MULT
      const k = slam(t, 2.0, 0.14, 1.4);
      scaled(90, 600, k, () => mega('×MULT', 0, 0, 250, PAL.cream, PAL.ink, 24));
      // rolling multiplier
      let m = MV[0];
      let lastT = -9;
      for (let i = 0; i < SL.length; i++) if (t >= TB(i) + TP) { m = MV[i + 1]; lastT = TB(i) + TP; }
      const bump = t - lastT;
      const ms = '×' + (Math.round(m * 100) / 100).toString();
      scaled(100, 820, 1 + 0.2 * Math.exp(-bump * 12), () => text(ms, 0, 0, 120, PAL.sun, { shadow: 10 }));
      text('TOTAL MULT', 104, 690, 30, PAL.ink);
      // stickers
      SL.forEach((s, i) => {
        const tb = TB(i);
        if (t < tb) return;
        const sc = slam(t, tb, 0.12, 2.0);
        const j = jok(s.id);
        card(s.x, s.y, 300, 400, j, t, { rot: s.r, scale: sc, noText: true, ps: 10, shadow: 18 });
        // pill flies out on the half beat
        const tp = tb + TP;
        if (t >= tp) {
          const kk = E.outBack(inv(tp, tp + 0.12, t));
          const py = s.y + 360 + (1 - kk) * 40;
          ctx.save(); ctx.translate(s.x + 150, py); ctx.rotate(-s.r * 1.5); ctx.scale(kk, kk);
          pill(s.p, 0, 0, 40, PAL.ink, PAL.pinkL, { align: 'center', shadow: 8 });
          ctx.restore();
        }
      });
      if (t > 2.15) pill('03', 150, 150, 40, PAL.ink, PAL.sun);
    },
  });
}

// ---------------------------------------------------------------- HOOK 4: BREAK THE MACHINE (b12-16)
{
  const T0 = 3.0, T1 = 3.75, CAP = 1e15;
  const val = (t) => { const k = inv(T0 + 0.05, T1, t); return k >= 1 ? CAP : 144 * Math.pow(CAP / 144, Math.pow(k, 1.7)); };
  const WORDS = [['BREAK', 3.25], ['THE', 3.5], ['MACHINE.', 3.75]];
  scene(6, 8, {
    init() {
      cue(3.0, 'counter_start', { shake: 6 });
      cue(3.25, 'word', { shake: 10, shock: 0.2 });
      cue(3.5, 'word', { shake: 12, shock: 0.3 });
      cue(3.75, 'machine_break', { shake: 34, shock: 1.0, flash: 0.3 });
      cue(3.96, 'whoosh', { flash: 1.0 });
    },
    post(t) { return { glitch: t > 3.75 ? 0.35 + 0.5 * Math.sin((t - 3.75) * 40) ** 2 : 0 }; },
    draw(t) {
      slab(PAL.ink);
      emptyGrid(120, 0.1);
      const v = val(t);
      const s = bigCommas(v);
      // fit: 25 chars at the cap should fill ~1760px
      const size = 120;
      const w = textW(s, size);
      const fit = Math.min(1.9, 1760 / w);
      const hot = inv(1e6, 1e14, v);
      const col = hot < 0.5 ? PAL.sun : hot < 0.95 ? PAL.pinkL : PAL.cream;
      const jit = t > T0 + 0.05 && t < T1 ? (rnd(Math.floor(t * 60), 1) - 0.5) * 8 * hot : 0;
      scaled(W / 2 + jit, 470, fit, () => text(s, 0, 40, size, col, { align: 'center', shadow: 8, shadowColor: PAL.pinkD }));
      pill('SCORE', 160, 250, 40, PAL.sun, PAL.ink);
      // words
      let x = W / 2 - textW('BREAK THE MACHINE.', 110) / 2;
      for (const [wd, tw] of WORDS) {
        const ww = textW(wd + ' ', 110);
        if (t >= tw) {
          const k = slam(t, tw, 0.1, 1.5);
          const c = wd === 'MACHINE.' ? PAL.pink : PAL.cream;
          scaled(x + ww / 2, 790, k, () => text(wd, 0, 40, 110, c, { align: 'center', shadow: 10 }));
        }
        x += ww;
      }
      if (t > T1) { // cracked glass lines from the impact
        ctx.strokeStyle = PAL.cream; ctx.lineWidth = 4;
        for (let i = 0; i < 9; i++) {
          const a = rnd(88, i) * Math.PI * 2, L = 300 + rnd(89, i) * 700;
          const k = E.outExpo(inv(T1, T1 + 0.08, t));
          ctx.beginPath(); ctx.moveTo(W / 2, 470);
          const mx = W / 2 + Math.cos(a + 0.2) * L * 0.4 * k, my = 470 + Math.sin(a + 0.2) * L * 0.4 * k;
          ctx.lineTo(mx, my); ctx.lineTo(W / 2 + Math.cos(a) * L * k, 470 + Math.sin(a) * L * k); ctx.stroke();
        }
      }
    },
  });
}

// ---------------------------------------------------------------- LOGO (b16-24)
{
  const T0 = 4.0;
  const LAND = (li) => T0 + 0.04 + li * 0.05;
  const LOGO_C = [0, 1, 2, 3, 4, 5, 0, 1, 2, 3];
  const TC = 5.78, TW = 4.75;
  scene(8, 12, {
    bg: () => bgp('plum'),
    init() {
      for (let i = 0; i < 10; i++) cue(LAND(i), 'place', { var: i, vel: 0.7, shake: 4 });
      cue(T0, 'impact', { shake: 20, shock: 0.5 });
      ['THE', 'BLOCK PUZZLE', 'ROGUELIKE'].forEach((w, i) => cue(TW + i * 0.125, 'word', { var: i, shake: 4 }));
      cue(TC, 'clear_big', { shake: 18, shock: 0.5 });
    },
    draw(t) {
      const lay = blockWord('BLOCKMANIA', t, { cell: 26, cy: 400, fall: 0.14, land: LAND, color: (li) => LOGO_C[li], clearAt: TC, clearWave: (c) => c.x * 0.004 });
      const words = [['THE ', PAL.cream], ['BLOCK PUZZLE ', PAL.sun], ['ROGUELIKE', PAL.cream]];
      const size = 70;
      const full = words.map((w) => w[0]).join('');
      let x = W / 2 - textW(full, size) / 2;
      words.forEach(([w, c], i) => {
        const tw = TW + i * 0.125;
        const ww = textW(w, size);
        if (t >= tw && t < TC + 0.1) {
          const k = E.outExpo(inv(tw, tw + 0.1, t));
          text(w, x, 700 + (1 - k) * 40, size, c, { shadow: 8 });
        }
        x += ww;
      });
      if (t >= 5.1 && t < TC + 0.1) {
        const s = 'tricks, jokers and one very full board';
        text(reveal(s, t, 5.1, 0.25), W / 2, 790, 40, PAL.dim, { align: 'center', bold: false });
      }
    },
  });
}

// ---------------------------------------------------------------- HOW TO PLAY (b24-40)
{
  const BX = 1060, BY = 92, S = 88;
  const PRE_ROWS = ['12.35..0', '3..14.2.', '..2..1.3', '231...45', '40123...', '.1.25..4', '..3.0.1.', '5..41.03'];
  const pre = [];
  PRE_ROWS.forEach((r, y) => [...r].forEach((ch, x) => { if (ch !== '.') pre.push([x, y, +ch]); }));
  const PIECES = [
    { shape: [[0, 0], [0, 1], [1, 1]], at: [0, 5], ci: 3, pick: 12.55, arrive: 13.3, place: 13.5, slot: 0 },
    { shape: [[0, 0], [1, 0], [2, 0]], at: [5, 4], ci: 4, pick: 14.45, arrive: 15.3, place: 15.5, slot: 1 },
    { shape: [[1, 0], [0, 1], [1, 1], [2, 1], [1, 2]], at: [3, 2], ci: 0, fin: 'gold', pick: 16.35, arrive: 17.3, place: 17.5, slot: 2 },
  ];
  const sim = simulateBoard(pre, PIECES.map((p) => ({ t: p.place, cells: p.shape.map(([x, y]) => [x + p.at[0], y + p.at[1]]), ci: p.ci, fin: p.fin })));
  const SLOT_X = (i) => BX + 352 + (i - 1) * 250, SLOT_Y = 905;
  const STEPS = [
    ['01', 'EIGHT BY EIGHT.', 'One board. No timer.', 12.0],
    ['02', 'THREE PIECES.', 'Dealt from your own bag.', 14.0],
    ['03', 'FILL A LINE.', 'Rows and columns clear.', 16.0],
    ['04', 'BEAT THE TARGET.', 'Before your placements run out.', 18.0],
  ];
  const SCORE = [[12, 0], [13.5, 30], [15.6, 160], [17.6, 1480]];
  const scoreAt = (t) => { let v = 0; for (const [tt, vv] of SCORE) if (t >= tt) v = vv; return v; };
  scene(12, 28, {
    shift: 6,
    bg: () => bgp('plum', { dark: 0.75, focusX: 0.4 }),
    init() {
      cue(12.0, 'whoosh', { shake: 4 });
      STEPS.forEach((s) => cue(s[3], 'word', { shake: 3 }));
      PIECES.forEach((p) => { cue(p.pick, 'pick'); cue(p.place, 'place', { shake: 8, var: p.slot }); });
      cue(15.6, 'clear_1', { shake: 12, shock: 0.3 });
      cue(17.6, 'clear_2', { shake: 20, shock: 0.6 });
      cue(18.7, 'coin');
      cue(19.0, 'stamp', { shake: 24, shock: 0.5 });
    },
    draw(t) {
      const lt = t - 12.0;
      const slide = (1 - E.outExpo(inv(0, 0.4, lt))) * 900;
      ctx.save(); ctx.translate(slide, 0);
      // board frame
      pxRect(BX - 22, BY - 22, 8 * S + 44, 8 * S + 44, PAL.sun, { shadow: 16, notch: 10, border: 6, borderColor: PAL.ink });
      rect(BX - 6, BY - 6, 8 * S + 12, 8 * S + 12, PAL.ink);
      // line preview while dragging
      for (const p of PIECES) {
        if (t < p.arrive - 0.35 || t >= p.place) continue;
        const cells = p.shape.map(([x, y]) => [x + p.at[0], y + p.at[1]]);
        const blink = 0.55 + 0.45 * Math.sin(t * 20);
        const cl = sim.clears.find((c) => c.P.t === p.place);
        if (cl) {
          ctx.globalAlpha = 0.35 * blink; ctx.fillStyle = PAL.sun;
          for (const r of cl.rows) ctx.fillRect(BX, BY + r * S, 8 * S, S);
          for (const c of cl.cols) ctx.fillRect(BX + c * S, BY, S, 8 * S);
          ctx.globalAlpha = 1;
        }
      }
      drawBoard(sim, BX, BY, S, t, { bits: 8 });
      // ghost
      for (const p of PIECES) {
        if (t < p.arrive - 0.35 || t >= p.place) continue;
        ctx.globalAlpha = 0.45;
        for (const [x, y] of p.shape) { ctx.strokeStyle = PAL.cream; ctx.lineWidth = 6; ctx.strokeRect(BX + (x + p.at[0]) * S + 7, BY + (y + p.at[1]) * S + 7, S - 14, S - 14); }
        ctx.globalAlpha = 1;
      }
      // tray
      for (let i = 0; i < 3; i++) {
        const cx = SLOT_X(i);
        pxRect(cx - 110, SLOT_Y - 70, 220, 150, PAL.plumD, { shadow: 10, notch: 8, border: 4, borderColor: PAL.ink });
        text(String(i + 1), cx - 96, SLOT_Y - 38, 30, PAL.dim);
        const p = PIECES[i];
        if (t < p.pick) {
          const bw = Math.max(...p.shape.map((c) => c[0])) + 1, bh = Math.max(...p.shape.map((c) => c[1])) + 1;
          const ts = 40;
          for (const [x, y] of p.shape) {
            const bx = cx - bw * ts / 2 + x * ts, by = SLOT_Y + 5 - bh * ts / 2 + y * ts;
            if (p.fin) finBlock(p.fin, p.ci, x, y, bx, by, ts - 4, t); else block(p.ci, bx, by, ts - 4);
          }
        } else if (t > p.place) text('placed', cx, SLOT_Y + 20, 30, PAL.plumLL, { align: 'center', bold: false });
      }
      // dragging piece + cursor
      let cur = null;
      for (const p of PIECES) {
        if (t < p.pick - 0.4 || t >= p.place + 0.35) continue;
        const sx0 = SLOT_X(p.slot), sy0 = SLOT_Y;
        const bw = Math.max(...p.shape.map((c) => c[0])) + 1, bh = Math.max(...p.shape.map((c) => c[1])) + 1;
        const tx = BX + p.at[0] * S + (bw * S) / 2, ty = BY + p.at[1] * S + (bh * S) / 2;
        if (t < p.pick) { // cursor travels to the slot
          const k = E.inOutCubic(inv(p.pick - 0.4, p.pick, t));
          cur = { x: lerp(sx0 + 300, sx0, k), y: lerp(sy0 - 200, sy0, k), grab: false };
          continue;
        }
        if (t >= p.place) { const k = E.outCubic(inv(p.place, p.place + 0.35, t)); cur = { x: tx + k * 60, y: ty + k * 90, grab: false }; continue; }
        const k = E.inOutCubic(inv(p.pick, p.arrive, t));
        const x = lerp(sx0, tx, k), y = lerp(sy0, ty, k) - Math.sin(k * Math.PI) * 120;
        const lift = 1.06;
        ctx.globalAlpha = 0.35;
        for (const [px, py] of p.shape) rect(x - bw * S / 2 + px * S + 22, y - bh * S / 2 + py * S + 26, S - 8, S - 8, PAL.ink);
        ctx.globalAlpha = 1;
        for (const [px, py] of p.shape) {
          const bx = x - bw * S * lift / 2 + px * S * lift, by = y - bh * S * lift / 2 + py * S * lift;
          if (p.fin) finBlock(p.fin, p.ci, px, py, bx, by, (S - 8) * lift, t); else block(p.ci, bx, by, (S - 8) * lift);
        }
        cur = { x: x + 20, y: y + 20, grab: true };
      }
      if (cur) sprite(cur.grab ? 'cursor_grab' : 'cursor_hand', cur.x, cur.y, 5);
      // score pops
      const pops = [[13.5, '+30', PAL.cream, 50, PIECES[0]], [15.6, '+130', PAL.sun, 70, PIECES[1]], [17.6, '+1,320', PAL.sun, 110, PIECES[2]]];
      for (const [tp, s, c, size, p] of pops) {
        const d = t - tp;
        if (d < 0 || d > 1.1) continue;
        const px = BX + (p.at[0] + 1) * S, py = BY + (p.at[1] + 0.5) * S - E.outCubic(Math.min(1, d / 0.6)) * 80;
        ctx.globalAlpha = d > 0.9 ? 1 - (d - 0.9) / 0.2 : 1;
        scaled(px, py, slam(t, tp, 0.12, 1.8), () => text(s, 0, 0, size, c, { align: 'center', outline: 6 }));
        ctx.globalAlpha = 1;
      }
      if (t >= 17.62 && t < 18.8) {
        const k = slam(t, 17.62, 0.14, 2);
        scaled(BX + 4 * S, BY + 4.6 * S, k, () => mega('DOUBLE!', 0, 0, 120, PAL.pinkL, PAL.pinkD, 12, { align: 'center' }), -0.05);
      }
      ctx.restore();
      // left column
      const lx = 120;
      STEPS.forEach(([n, head, sub, ts], i) => {
        if (t < ts) return;
        const k = E.outExpo(inv(ts, ts + 0.25, t));
        const y = 170 + i * 150;
        const active = (i === STEPS.length - 1) || t < STEPS[i + 1][3];
        ctx.globalAlpha = k;
        pill(n, lx + (1 - k) * -60, y - 44, 26, active ? PAL.sun : PAL.plumL, PAL.ink, { shadow: 5 });
        text(head, lx + 90 + (1 - k) * -60, y, 70, active ? PAL.cream : PAL.plumLL, { shadow: active ? 7 : 0 });
        text(sub, lx + 92, y + 50, 30, active ? PAL.dim : PAL.plumL, { bold: false });
        ctx.globalAlpha = 1;
      });
      // score / target bar
      if (t >= 12.2) {
        const y = 790;
        const v = scoreAt(t);
        pxRect(lx, y, 820, 150, PAL.plumD, { shadow: 12, border: 4, borderColor: PAL.ink });
        pill('SCORE', lx + 24, y + 22, 24, PAL.sun, PAL.ink, { shadow: 4 });
        text(commas(v), lx + 24, y + 118, 70, PAL.cream, { shadow: 6 });
        text('/ 1,200', lx + 780, y + 56, 30, PAL.dim, { align: 'right' });
        const fr = Math.min(1, v / 1200);
        rect(lx + 380, y + 88, 400, 30, PAL.ink);
        rect(lx + 384, y + 92, 392 * fr, 22, fr >= 1 ? PAL.mint : PAL.sun);
      }
      // ROUND CLEARED stamp
      if (t >= 19.0) {
        const k = slam(t, 19.0, 0.16, 2.6);
        ctx.save(); ctx.translate(BX + 4 * S + slide, BY + 4 * S); ctx.rotate(-0.07); ctx.scale(k, k);
        pxRect(-450, -110, 900, 220, PAL.mint, { shadow: 20, notch: 12, border: 8, borderColor: PAL.ink });
        text('ROUND CLEARED!', 0, 36, 90, PAL.ink, { align: 'center' });
        ctx.restore();
      }
    },
  });
}

// ---------------------------------------------------------------- RECEIPT (b40-48)
{
  const LINES = [
    ['Plus 5  (5 cells)', '', PAL.ink, true],
    ['Neon', '', PAL.sky],
    ['Cells ×5', '+50', PAL.sky],
    ['Lines ×3', '+300', PAL.sky],
    ['Multi-line bonus', '+80', PAL.sky],
    ['Multi-line Mult', '+2 mult', PAL.pink],
    ['Neon cells cleared ×6', '+3 mult', PAL.pink],
    ['Snowball', '×1.9 mult', PAL.pink],
    ['Jackpot Window', '×5 mult', PAL.pink],
    ['Jackpot Window, mirrored', '×5 mult', PAL.pink],
  ];
  const TL = (i) => 20.2 + i * 0.2;
  const TT = TL(LINES.length) + 0.1;
  scene(28, 36, {
    shift: 6,
    bg: () => bgp('plum', { dark: 0.55 }),
    init() {
      LINES.forEach((_, i) => cue(TL(i), 'print', { var: i }));
      cue(TT, 'receipt_total', { shake: 10 });
      cue(20.0, 'slab', { shake: 8 });
      cue(20.5, 'word', { shake: 8 }); cue(21.0, 'word', { shake: 8 });
      cue(22.5, 'score_big', { shake: 22, shock: 0.6, flash: 0.15 });
    },
    draw(t) {
      // receipt printer
      const px = 150, pw = 700;
      const n = LINES.filter((_, i) => t >= TL(i)).length + (t >= TT ? 2 : 0);
      const ph = 120 + n * 58;
      const feed = E.outCubic(inv(0, 0.15, (t - 20.2) % 0.2)) * 0;
      pxRect(px - 30, 50, pw + 60, 60, PAL.ink, { notch: 8, shadow: 10, shadowColor: '#0006' });
      rect(px - 10, 90, pw + 20, 10, '#000');
      // paper with torn zigzag bottom
      const py = 96;
      ctx.fillStyle = PAL.cream;
      ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(px + pw, py); ctx.lineTo(px + pw, py + ph);
      for (let x = pw; x >= 0; x -= 20) ctx.lineTo(px + x - 10, py + ph + ((x / 20) % 2 ? 14 : 0));
      ctx.lineTo(px, py + ph); ctx.fill();
      text('RECEIPT', px + pw / 2, py + 64, 40, PAL.creamDD, { align: 'center' });
      LINES.forEach(([l, r, c, bold], i) => {
        if (t < TL(i)) return;
        const y = py + 130 + i * 58;
        const k = inv(TL(i), TL(i) + 0.08, t);
        ctx.globalAlpha = k;
        text(l, px + 36, y, 30, bold ? PAL.ink : (r ? PAL.ink : c), { bold: !!bold || !r });
        if (r) text(r, px + pw - 36, y, 30, c, { align: 'right' });
        ctx.globalAlpha = 1;
      });
      if (t >= TT) {
        const y = py + 130 + LINES.length * 58;
        ctx.fillStyle = PAL.creamDD; for (let x = px + 36; x < px + pw - 36; x += 24) ctx.fillRect(x, y - 20, 12, 4);
        const k = slam(t, TT, 0.12, 1.5);
        scaled(px + pw / 2, y + 50, k, () => text('430 × 812.25 = 349,267', 0, 0, 40, PAL.ink, { align: 'center' }));
      }
      // right: CHIPS × MULT = POINTS
      const rx = 1000;
      const words = [['CHIPS', PAL.sky, '#1f5f99', 20.0, '430'], ['× MULT', PAL.pink, PAL.pinkD, 20.5, '812.25'], ['= POINTS', PAL.sun, PAL.sunDD, 21.0, '349,267']];
      words.forEach(([w, c, dc, tw, num], i) => {
        if (t < tw) return;
        const k = slam(t, tw, 0.16, 1.7);
        const y = 300 + i * 250;
        scaled(rx, y, k, () => mega(w, 0, 0, 170, c, dc, 16));
        const tn = 21.5 + i * 0.5;
        if (t >= tn) {
          const kk = E.outBack(inv(tn, tn + 0.18, t));
          const big = i === 2;
          ctx.save(); ctx.translate(rx + 10, y + 30); ctx.scale(kk, kk);
          pill(num, 0, 0, big ? 60 : 40, big ? PAL.sun : PAL.ink, big ? PAL.ink : c, { shadow: 8 });
          ctx.restore();
        }
      });
      subtitle('Every point is itemized. No hidden rolls.', t, 22.6, 24.0, { y: 930, accent: PAL.sun });
    },
  });
}

// ---------------------------------------------------------------- JOKERS (b48-64)
{
  const ORDER = { legendary: 0, rare: 1, uncommon: 2, common: 3 };
  const WALL = [...JOKERS].sort((a, b) => ORDER[a.rarity] - ORDER[b.rarity] || a.name.localeCompare(b.name));
  const FEAT = [
    { id: 'snowball', head: 'GROW THEM.', p: 'NOW ×2.05 MULT', t: 26.0 },
    { id: 'mimic', head: 'COPY THEM.', p: 'COPYING: JACKPOT', t: 27.0 },
    { id: 'jackpot_window', head: 'STACK THEM.', p: '×5 MULT', t: 28.0 },
    { id: 'hall_of_mirrors', head: 'DOUBLE EVERYTHING.', p: 'EVERY JOKER ×2', t: 29.0 },
  ];
  scene(36, 48, {
    shift: 6,
    bg: (t) => (t < 26 ? bgp('plum', { dark: 0.5 }) : bgp('plum', { dark: 0.8, pulse: 0.2 })),
    init() {
      cue(24.0, 'cascade');
      cue(25.0, 'slab_big', { shake: 24, shock: 0.6 });
      FEAT.forEach((f, i) => { cue(f.t, 'joker', { var: i, shake: 14, shock: 0.25 }); cue(f.t + 0.5, 'mult', { var: i }); });
      cue(25.5, 'legendary', { shake: 10, shock: 0.3 });
    },
    draw(t) {
      if (t < 26.0) { // the wall
        slab(PAL.plumDD);
        const cols = 12, tile = 136, gap = 14, x0 = (W - (cols * tile + (cols - 1) * gap)) / 2, y0 = 72;
        WALL.forEach((j, i) => {
          const c = i % cols, r = Math.floor(i / cols);
          const ta = 24.0 + (c + r) * 0.035;
          if (t < ta) return;
          let k = slam(t, ta, 0.14, 0.6);
          const legend = j.rarity === 'legendary';
          if (legend && t >= 25.5) k *= slam(t, 25.5 + i * 0.06, 0.14, 1.9) * 1.12;
          const x = x0 + c * (tile + gap), y = y0 + r * (tile + gap);
          ctx.save(); ctx.translate(x + tile / 2, y + tile / 2); ctx.scale(k, k);
          if (legend && t >= 25.5) { ctx.globalAlpha = 0.5 + 0.3 * Math.sin(t * 12); pxRect(-tile / 2 - 12, -tile / 2 - 12, tile + 24, tile + 24, PAL.lilac, { notch: 8 }); ctx.globalAlpha = 1; }
          pxRect(-tile / 2, -tile / 2, tile, tile, RARITY[j.rarity], { shadow: 8, notch: 6 });
          pxRect(-tile / 2 + 6, -tile / 2 + 6, tile - 12, tile - 12, PAL.cream, { notch: 4 });
          portrait('jokers', j.id, -56, -56, 7, glint(t, i * 13 + 5));
          ctx.restore();
        });
        if (t >= 25.0) {
          const k = E.outExpo(inv(25.0, 25.15, t));
          const hh = 330 * k;
          rect(0, 540 - hh / 2, W, hh, PAL.ink);
          rect(0, 540 - hh / 2 - 12, W, 12, PAL.sun); rect(0, 540 + hh / 2, W, 12, PAL.sun);
          if (k > 0.6) scaled(W / 2, 520, slam(t, 25.05, 0.16, 1.6), () => mega('70 JOKERS', 0, 95, 250, PAL.sun, PAL.pinkD, 22, { align: 'center' }));
        }
        if (t >= 25.5) { // the four Legendaries in the first row
          const tags = ['4 LEGENDARY', '15 RARE', '27 UNCOMMON', '24 COMMON'];
          const cols = [PAL.lilac, PAL.pink, PAL.sky, RARITY.common];
          const ws = tags.map((s2) => textW(s2, 26) + 26 * 0.9);
          let px = W / 2 - (ws.reduce((a, b) => a + b, 0) + 3 * 24) / 2;
          tags.forEach((s2, i) => {
            const ta = 25.5 + i * 0.07;
            if (t >= ta) {
              const kk = E.outBack(inv(ta, ta + 0.15, t));
              ctx.save(); ctx.translate(px + ws[i] / 2, 648); ctx.scale(kk, kk);
              pill(s2, 0, 0, 26, cols[i], PAL.ink, { align: 'center', shadow: 5 });
              ctx.restore();
            }
            px += ws[i] + 24;
          });
        }
        return;
      }
      { // featured
        const cx0 = 800, cw = 400, ch = 580;
        FEAT.forEach((f, i) => {
          if (t < f.t) return;
          const sc = slam(t, f.t, 0.16, 1.9);
          const x = cx0 + i * 225, y = 220 + (i % 2) * 70;
          const trig = f.t + 0.5;
          let bump = 0, lift = 0;
          if (t >= trig) { const d = t - trig; bump = Math.max(0, 0.2 - d * 2); lift = 40 * Math.exp(-d * 10); }
          card(x, y - lift, cw, ch, jok(f.id), t, { rot: [-0.05, 0.03, -0.03, 0.05][i], scale: sc, bump, ps: 12 });
          if (t >= trig) {
            const kk = E.outBack(inv(trig, trig + 0.2, t));
            ctx.save(); ctx.translate(x + cw / 2, y - 40); ctx.scale(kk, kk);
            pill(f.p, 0, 0, 30, f.id === 'hall_of_mirrors' ? PAL.lilac : PAL.pink, PAL.ink, { align: 'center', shadow: 6 });
            ctx.restore();
          }
        });
        FEAT.forEach((f, i) => {
          if (t < f.t) return;
          const k = E.outExpo(inv(f.t, f.t + 0.2, t));
          const active = i === 3 || t < FEAT[i + 1].t;
          const words = f.head.split(' ');
          const y = 250 + i * 190;
          ctx.globalAlpha = k;
          const col = active ? (i === 3 ? PAL.sun : PAL.cream) : PAL.plumLL;
          const dep = active ? 8 : 0;
          if (f.head.length > 12) { // DOUBLE / EVERYTHING. on two lines
            mega(words[0], 100 - (1 - k) * 80, y, 80, col, PAL.ink, dep);
            mega(words.slice(1).join(' '), 100 - (1 - k) * 80, y + 90, 80, col, PAL.ink, dep);
          } else mega(f.head, 100 - (1 - k) * 80, y, 80, col, PAL.ink, dep);
          ctx.globalAlpha = 1;
        });
        return;
      }
    },
  });
}

// ---------------------------------------------------------------- SHOP (b64-72)
{
  const OFF = [
    { k: 'jokers', id: 'heavy_hand', price: 3 },
    { k: 'jokers', id: 'golden_ratio', price: 5 },
    { k: 'jokers', id: 'wide_awake', price: 5 },
    { k: 'items', id: 'eraser', price: 4 },
    { k: 'items', id: 'polish', price: 3 },
  ];
  const OFF2 = [
    { k: 'jokers', id: 'compound_interest', price: 7 },
    { k: 'jokers', id: 'color_cycle', price: 5 },
    { k: 'jokers', id: 'neon_sign', price: 4 },
    { k: 'items', id: 'emergency_brick', price: 4 },
    { k: 'items', id: 'spark', price: 3 },
  ];
  // Reroll (BMRun.reroll_shop): costs 2, replaces every offer, next reroll costs 3.
  const TD = (i) => 32.25 + i * 0.125, TBUY = 33.5, TRR = 34.5, OUT = (i) => TRR + 0.04 + i * 0.05, IN = (i) => TRR + 0.2 + i * 0.07;
  const def = (o) => (o.k === 'jokers' ? jok(o.id) : Object.assign({ rarity: 'item' }, ITEMS.find((x) => x.id === o.id)));
  function offer(o, x, y, t, flip, pressed) {
    const d = def(o);
    const w = 300, h = 420;
    const col = o.k === 'items' ? PAL.pink : RARITY[d.rarity];
    ctx.save(); ctx.translate(x + w / 2, y + h / 2); ctx.scale(flip, 1);
    pxRect(-w / 2, -h / 2, w, h, col, { shadow: 12, notch: 10 });
    pxRect(-w / 2 + 8, -h / 2 + 8, w - 16, h - 16, PAL.cream, { notch: 6 });
    pxRect(-80, -h / 2 + 22, 160, 160, PAL.ink, { notch: 4 });
    portrait(o.k, o.id, -72, -h / 2 + 30, 9, glint(t, o.id.length * 5));
    const lab = o.k === 'items' ? 'ITEM' : d.rarity.toUpperCase();
    const lw = textW(lab, 20) + 20;
    pxRect(-lw / 2, -h / 2 + 194, lw, 32, col, { notch: 4 });
    text(lab, 0, -h / 2 + 217, 20, PAL.ink, { align: 'center' });
    let ns = 30; while (textW(d.name, ns) > w - 40 && ns > 20) ns -= 10;
    text(d.name, 0, -h / 2 + 266, ns, PAL.ink, { align: 'center' });
    wrap(d.text, 20, w - 40).slice(0, 2).forEach((l, i) => text(l, 0, -h / 2 + 298 + i * 24, 20, PAL.plum, { align: 'center', bold: false }));
    const by = h / 2 - 66 + (pressed ? 6 : 0);
    pxRect(-w / 2 + 22, by, w - 44, 50, pressed ? PAL.mint : PAL.sun, { notch: 6, shadow: pressed ? 0 : 6, shadowColor: PAL.sunDD });
    text(pressed ? 'BOUGHT!' : 'BUY ' + o.price, 0, by + 38, 30, PAL.ink, { align: 'center' });
    ctx.restore();
  }
  scene(48, 56, {
    shift: 8,
    bg: () => bgp('teal', { dark: 0.9 }),
    init() {
      cue(32.0, 'awning', { shake: 14 });
      OFF.forEach((_, i) => cue(TD(i), 'card_drop', { var: i, shake: 3 }));
      cue(TBUY, 'buy', { shake: 8 });
      cue(TRR, 'reroll', { shake: 8 });
      OFF2.forEach((_, i) => cue(IN(i), 'card_drop', { var: i }));
      cue(35.5, 'coin');
    },
    draw(t) {
      // awning
      const ay = -170 * (1 - E.outExpo(inv(32.0, 32.3, t)));
      for (let i = 0; i < 24; i++) {
        rect(i * 80, ay, 80, 150, i % 2 ? PAL.cream : PAL.pink);
        const c = i % 2 ? PAL.cream : PAL.pink;
        rect(i * 80 + 10, ay + 150, 60, 20, c); rect(i * 80 + 25, ay + 170, 30, 10, c);
      }
      rect(0, ay + 146, W, 6, '#0003');
      // sign
      const sk = slam(t, 32.05, 0.18, 0.3);
      ctx.save(); ctx.translate(560, ay + 170); ctx.scale(sk, sk); ctx.rotate(-0.03);
      pxRect(-400, -80, 800, 160, PAL.ink, { shadow: 12, notch: 10, border: 6, borderColor: PAL.sun });
      mega('THE TOYBOX', 0, 42, 110, PAL.sun, PAL.pinkD, 10, { align: 'center' });
      ctx.restore();
      // credits
      let credits = t < TBUY ? 23 : t < TBUY + 0.3 ? Math.round(lerp(23, 18, inv(TBUY, TBUY + 0.3, t))) : 18;
      if (t >= TRR) credits = t < TRR + 0.2 ? Math.round(lerp(18, 16, inv(TRR, TRR + 0.2, t))) : 16;
      pxRect(1380, ay + 110, 400, 110, PAL.ink, { shadow: 10, border: 5, borderColor: PAL.sun });
      sprite('coin', 1410, ay + 132, 1.5);
      text(String(credits), 1500, ay + 198, 80, PAL.sun, { shadow: 6 });
      text('CREDITS', 1760, ay + 198, 30, PAL.dim, { align: 'right' });
      // shelf
      rect(0, 800, W, 30, PAL.ink); rect(0, 830, W, 16, '#0006');
      const flipOut = (t0) => Math.cos(Math.PI / 2 * clamp((t - t0) / 0.1));
      OFF.forEach((o, i) => {
        const x = 60 + i * 318, y = 360;
        const d = drop(t, TD(i) - 0.14, 0.14);
        if (!d.on) return;
        if (i === 1 && t >= TBUY + 0.2) { // flies to the rack
          const k = E.inCubic(inv(TBUY + 0.2, TBUY + 0.5, t));
          if (k >= 1) return;
          ctx.save(); ctx.translate(x + 135 + k * 1400, y + 190 - k * 500); ctx.scale(1 - 0.7 * k, 1 - 0.7 * k); ctx.translate(-x - 135, -y - 190);
          offer(o, x, y, t, 1, true); ctx.restore();
          return;
        }
        if (t >= OUT(i)) { // flip out on the reroll
          const f = flipOut(OUT(i));
          if (f > 0.02) offer(o, x, y, t, f, i === 1);
          return;
        }
        offer(o, x, y + d.y * 600, t, 1, i === 1 && t >= TBUY);
      });
      OFF2.forEach((o, i) => {
        const ta = IN(i);
        if (t < ta - 0.1) return;
        const f = Math.sin(Math.PI / 2 * clamp((t - (ta - 0.1)) / 0.1));
        offer(o, 60 + i * 318, 360, t, f, false);
      });
      // the REROLL button (sky, refresh icon, price) and the cursor that presses it
      const pressed = t >= TRR && t < TRR + 0.12;
      const bx = 1540, by = ay + 250, bw = 300, bh = 84;
      pxRect(bx, by + (pressed ? 6 : 0), bw, bh, pressed ? '#2f7fcc' : PAL.sky, { notch: 8, border: 5, borderColor: PAL.ink, shadow: pressed ? 0 : 8, shadowColor: '#1f4f80' });
      sprite('refresh', bx + 22, by + 20 + (pressed ? 6 : 0), 1);
      text('REROLL  ' + (t >= TRR ? 3 : 2), bx + 84, by + 56 + (pressed ? 6 : 0), 30, PAL.ink);
      if (t >= TRR - 0.45 && t < TRR + 0.5) {
        const k = E.inOutCubic(inv(TRR - 0.45, TRR - 0.05, t));
        sprite('cursor_hand', lerp(1500, bx + 150, k), lerp(760, by + 50, k), 5);
      }
      subtitle('Spend Credits. Reroll. Build your bag.', t, 33.0, 36.0, { y: 900, accent: PAL.mint });
    },
  });
}

// ---------------------------------------------------------------- FINISHES (b72-80)
{
  const LIST = [['gold', 'GOLD', PAL.sun], ['neon', 'NEON', PAL.sky], ['lava', 'LAVA', PAL.pink], ['prism', 'PRISM', PAL.lilac],
    ['chrome', 'CHROME', PAL.cream], ['ice', 'ICE', PAL.skyL], ['starfall', 'STARFALL', PAL.sun], ['aurora', 'AURORA', PAL.mint]];
  const TS = (i) => 36.0 + i * 0.5;
  scene(56, 64, {
    shift: 8,
    init() { LIST.forEach((_, i) => cue(TS(i), 'finish', { var: i, shake: 6, shock: 0.15, fin: LIST[i][0] })); },
    draw(t) {
      slab(PAL.ink);
      const s = 96;
      const idx = Math.min(7, Math.floor((t - 36.0) / 0.5));
      for (let cy = 0; cy < 12; cy++) for (let cx = 0; cx < 20; cx++) {
        // diagonal wipe from the previous finish
        const d = (cx + cy) / 30;
        const tn = Math.min(7, Math.floor((t - 36.0 + 0.06) / 0.5));
        let k = tn;
        if (t - (TS(tn) - 0.06) < d * 0.12) k = tn - 1;
        if (k < 0) continue;
        const f = LIST[Math.max(0, k)][0];
        const ci = Math.floor(rnd(cx * 7 + cy * 131, 3) * 6);
        const x = cx * s, y = cy * s - 36;
        finBlock(f, ci, cx, cy, x + 4, y + 4, 88, t);
      }
      // center plate
      const [, name, col] = LIST[idx];
      const tn = TS(idx);
      const k = slam(t, tn, 0.12, 1.3);
      const w = Math.max(700, textW(name, 200) + 160);
      ctx.save(); ctx.translate(W / 2, 520); ctx.scale(k, k);
      pxRect(-w / 2, -150, w, 300, PAL.ink, { shadow: 18, notch: 12, border: 8, borderColor: col });
      mega(name, 0, 72, 200, col, PAL.plum, 14, { align: 'center' });
      ctx.restore();
      pill('14 BLOCK FINISHES', 120, 110, 30, PAL.cream, PAL.ink);
      subtitle('Every face is animated pixel art.', t, 37.0, 40.0, { y: 900, accent: col });
    },
  });
}

// ---------------------------------------------------------------- BOSS (b80-96)
{
  const NAMES = [
    ['THE WARDEN', 'Two tray slots start barred until you clear a line.', 40.0],
    ['THE LOCKDOWN', 'Refresh, Hold and the Second Tray: all locked.', 42.0],
    ['THE LAST CALL', 'Only 12 placements. Make them count.', 44.0],
  ];
  const TMK = 43.0, TR = 46.0;
  scene(64, 80, {
    shift: 8,
    bg: (t) => bgp('boss', { swirl: 3.2, dark: t > 47.7 ? 0 : 0.9, pulse: 0.1 }),
    post(t) { let g = 0; for (const tt of [42.0, 44.0]) if (t >= tt - 0.04 && t < tt + 0.1) g = 0.8; return { glitch: g }; },
    init() {
      cue(40.0, 'boss_slam', { shake: 30, shock: 0.9, flash: 0.2 });
      cue(42.0, 'boss_hit', { shake: 16, shock: 0.5 });
      cue(TMK, 'mk2', { shake: 26, shock: 0.6 });
      cue(44.0, 'boss_hit', { shake: 18, shock: 0.6 });
      for (let i = 0; i < 12; i++) cue(TR + i * 0.125, 'pip', { var: i, shake: (i + 1) % 4 === 0 ? 10 : 2 });
    },
    draw(t) {
      if (t > 47.7) return; // blackout before the drop
      // hazard bands
      const k = E.outExpo(inv(40.0, 40.18, t));
      const band = (y0, dir) => {
        const y = y0 + dir * (1 - k) * -200;
        rect(0, y, W, 90, PAL.ink);
        ctx.save(); ctx.beginPath(); ctx.rect(0, y + 90, W, 44); ctx.clip();
        rect(0, y + 90, W, 44, PAL.sun);
        ctx.fillStyle = PAL.ink;
        const off = (t * 160 * dir) % 88;
        for (let x = -200; x < W + 200; x += 88) { ctx.beginPath(); ctx.moveTo(x + off, y + 90); ctx.lineTo(x + off + 44, y + 90); ctx.lineTo(x + off + 0, y + 134); ctx.lineTo(x + off - 44, y + 134); ctx.fill(); }
        ctx.restore();
        const msg = 'WARNING   BOSS ROUND   WARNING   MK II   ';
        const mw = textW(msg, 50);
        const ox = ((t * 300 * dir) % mw + mw) % mw;
        for (let x = -mw + ox; x < W; x += mw) text(msg, x, y + 66, 50, PAL.pink);
      };
      ctx.save(); band(0, 1); ctx.translate(0, H); ctx.scale(1, -1); ctx.restore();
      // bottom band (not mirrored text): draw tape above text
      {
        const y = H - 134 + (1 - k) * 200;
        rect(0, y + 44, W, 90, PAL.ink);
        rect(0, y, W, 44, PAL.sun);
        ctx.fillStyle = PAL.ink;
        const off = (-t * 160) % 88;
        ctx.save(); ctx.beginPath(); ctx.rect(0, y, W, 44); ctx.clip();
        for (let x = -200; x < W + 200; x += 88) { ctx.beginPath(); ctx.moveTo(x + off, y); ctx.lineTo(x + off + 44, y); ctx.lineTo(x + off, y + 44); ctx.lineTo(x + off - 44, y + 44); ctx.fill(); }
        ctx.restore();
        const msg = 'MK II   WARNING   BOSS ROUND   WARNING   ';
        const mw = textW(msg, 50);
        const ox = ((-t * 300) % mw + mw) % mw;
        for (let x = -mw + ox; x < W; x += mw) text(msg, x, y + 110, 50, PAL.pink);
      }
      if (t < TR) {
        const cur = NAMES.filter((n) => t >= n[2]).pop();
        const [name, rule, tn] = cur;
        const sk = slam(t, tn, 0.14, 1.5);
        sprite('skull', W / 2 - 66, 250 - (sk - 1) * 40, 3);
        // chromatic split name
        scaled(W / 2, 530, sk, () => {
          ctx.globalAlpha = 0.8;
          text(name, -8, 60, 160, PAL.sky, { align: 'center' });
          text(name, 8, 60, 160, PAL.pink, { align: 'center' });
          ctx.globalAlpha = 1;
          text(name, 0, 60, 160, PAL.cream, { align: 'center' });
        });
        const rk = inv(tn + 0.2, tn + 0.5, t);
        if (rk > 0) text(reveal(rule, t, tn + 0.2, 0.3), W / 2, 700, 40, PAL.pinkL, { align: 'center', bold: false });
        if (name === 'THE LOCKDOWN' && t >= TMK) {
          const mk = slam(t, TMK, 0.12, 2.8);
          ctx.save(); ctx.translate(1500, 400); ctx.rotate(-0.12); ctx.scale(mk, mk);
          pxRect(-170, -75, 340, 150, PAL.sun, { shadow: 14, notch: 10, border: 8, borderColor: PAL.ink });
          text('MK II', 0, 42, 100, PAL.ink, { align: 'center' });
          ctx.restore();
        }
        if (name === 'THE LAST CALL') pill('FINAL BOSS', W / 2, 800, 30, PAL.pink, PAL.ink, { align: 'center' });
      } else {
        // run track
        const k2 = E.outExpo(inv(TR, TR + 0.2, t));
        text('12 ROUNDS  ·  3 ACTS', W / 2, 380 - (1 - k2) * 60, 110, PAL.cream, { align: 'center', shadow: 10, shadowColor: PAL.pinkD });
        for (let i = 0; i < 12; i++) {
          const x = W / 2 - 6 * 130 + i * 130 + 10, y = 520;
          const on = t >= TR + i * 0.125;
          const boss = (i + 1) % 4 === 0;
          const pop = on ? slam(t, TR + i * 0.125, 0.1, 1.5) : 1;
          ctx.save(); ctx.translate(x + 55, y + 55); ctx.scale(pop, pop);
          pxRect(-55, -55, 110, 110, on ? (boss ? PAL.pink : PAL.sun) : PAL.plumD, { shadow: 8, notch: 8, border: 5, borderColor: PAL.ink });
          if (boss) sprite('skull', -33, -33, 1.5, 0, 0, null, null, on ? 1 : 0.4);
          else text(String(i + 1), 0, 18, 50, on ? PAL.ink : PAL.plumL, { align: 'center' });
          ctx.restore();
        }
        subtitle('Every act ends with a boss that rewrites a rule.', t, 46.3, 47.7, { y: 760, accent: PAL.pink });
      }
    },
  });
}

// ---------------------------------------------------------------- CLIMAX A: chain board (b96-104)
{
  const T0 = 48.0, T1 = 52.0;
  // procedural storm: blocks rain in on 16ths, a line set clears on each beat
  const pl = [];
  const clearBeats = [];
  {
    const g = Array.from({ length: 8 }, () => Array(8).fill(0));
    const fins = ['neon', 'gold', 'prism', 'chrome', null, 'glass', null, 'lava'];
    // seed board
    const seedCells = [];
    for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) if (rnd(x * 8 + y, 5) < 0.5) { g[y][x] = 1; seedCells.push([x, y]); }
    // break any full lines in the seed
    for (let y = 0; y < 8; y++) if (g[y].every((c) => c)) { g[y][y] = 0; }
    for (let x = 0; x < 8; x++) if (g.every((r) => r[x])) { g[x][x] = 0; }
    PRESEED = [];
    for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) if (g[y][x]) PRESEED.push([x, y, Math.floor(rnd(x, y + 50) * 6), fins[(x + y) % fins.length]]);
    let n = 0;
    for (let b = 0; b < 8; b++) {
      const tb = T0 + b * 0.5;
      // filler 16ths
      for (let s = 1; s < 4 && b < 7; s++) {
        const empt = [];
        for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) if (!g[y][x]) {
          g[y][x] = 1; const full = g[y].every((c) => c) || g.every((r) => r[x]); g[y][x] = 0;
          if (!full) empt.push([x, y]);
        }
        const k = Math.min(2, empt.length);
        const cells = [];
        for (let i = 0; i < k; i++) { const c = empt.splice(Math.floor(rnd(n++, 9) * empt.length), 1)[0]; cells.push(c); g[c[1]][c[0]] = 1; }
        if (cells.length) pl.push({ t: tb + s * 0.125, cells, ci: Math.floor(rnd(n, 2) * 6), fin: fins[n % fins.length], drop: true });
      }
      // clear beat: fill the emptiest lines' gaps, 1..3 lines
      const want = [1, 2, 1, 2, 3, 2, 3, 4][b];
      const lines = [];
      for (let i = 0; i < 8; i++) {
        lines.push({ k: 'r', i, e: g[i].filter((c) => !c).length });
        lines.push({ k: 'c', i, e: g.filter((r) => !r[i]).length });
      }
      lines.sort((a, c) => a.e - c.e || rnd(a.i, b) - 0.5);
      const pick = [];
      for (const L of lines) { if (pick.length >= want) break; if (!pick.some((p) => p.k === L.k && p.i === L.i)) pick.push(L); }
      const cells = [];
      for (const L of pick) for (let j = 0; j < 8; j++) {
        const [x, y] = L.k === 'r' ? [j, L.i] : [L.i, j];
        if (!g[y][x] && !cells.some((c) => c[0] === x && c[1] === y)) cells.push([x, y]);
      }
      for (const [x, y] of cells) g[y][x] = 1;
      pl.push({ t: tb - 0.02, cells, ci: b % 6, fin: fins[(b + 3) % fins.length], drop: true });
      for (const L of pick) for (let j = 0; j < 8; j++) { const [x, y] = L.k === 'r' ? [j, L.i] : [L.i, j]; g[y][x] = 0; }
      clearBeats.push({ t: tb, n: pick.length });
    }
  }
  var PRESEED;
  const sim = simulateBoard(PRESEED, pl, { clearDelay: 0.03 });
  const WORDS = ['CLEAR!', 'DOUBLE!', 'COMBO ×3', 'DOUBLE!', 'TRIPLE!', 'OVERKILL', 'COMBO ×8', 'ROW + COLUMN ×4'];
  const RACK = ['snowball', 'jackpot_window', 'hall_of_mirrors', 'mimic', 'supernova'];
  const scoreAt = (t) => 349267 * Math.pow(250, clamp((t - T0) / 4));
  scene(80, 88, {
    shift: 8,
    bg: (t) => bgp('party', { pulse: 0.5 + 0.5 * Math.exp(-((t - T0) % 0.5) * 6), swirl: 3.0 }),
    init() {
      cue(T0, 'drop_impact', { shake: 36, shock: 1.0, flash: 0.35 });
      for (const P of pl) if (P.cells.length <= 2) cue(P.t, 'tick', { var: Math.floor(P.t * 8) % 8, vol: 0.5 });
      for (const c of sim.clears) cue(c.t, c.n >= 3 ? 'clear_3' : c.n === 2 ? 'clear_2' : 'clear_1', { shake: 8 + c.n * 6, shock: 0.2 + c.n * 0.12 });
    },
    draw(t) {
      const S = 100, BX = W / 2 - 400, BY = 150;
      pxRect(BX - 22, BY - 22, 844, 844, PAL.sun, { shadow: 18, notch: 10, border: 6, borderColor: PAL.ink });
      rect(BX - 6, BY - 6, 812, 812, PAL.ink);
      drawBoard(sim, BX, BY, S, t, { bits: 6 });
      // odometer
      const v = scoreAt(t);
      pxRect(BX - 22, 20, 844, 104, PAL.ink, { shadow: 10, border: 5, borderColor: PAL.sun });
      text(commas(v), W / 2, 100, 80, PAL.sun, { align: 'center', shadow: 6, shadowColor: PAL.pinkD });
      // rack left
      const bi = Math.floor((t - T0) / 0.5);
      RACK.forEach((id, i) => {
        const y = 170 + i * 150;
        const fire = bi % RACK.length === i ? Math.max(0, 1 - ((t - T0) % 0.5) * 5) : 0;
        const x = 70 + fire * 20;
        pxRect(x, y, 380, 124, RARITY[jok(id).rarity], { shadow: 10, notch: 8 });
        pxRect(x + 6, y + 6, 368, 112, PAL.cream, { notch: 5 });
        portrait('jokers', id, x + 18, y + 14, 6, glint(t, i));
        text(jok(id).name, x + 130, y + 56, 30, PAL.ink);
        const tags = ['×2.35', '×5', 'TWICE', 'COPY', '×4.5'];
        text(tags[i], x + 130, y + 96, 30, PAL.pink);
        if (fire > 0) { ctx.globalAlpha = fire * 0.4; pxRect(x, y, 380, 124, '#fff', { notch: 8 }); ctx.globalAlpha = 1; }
      });
      // word per beat on the right
      if (bi >= 0 && bi < 8) {
        const tb = T0 + bi * 0.5;
        const k = slam(t, tb, 0.12, 1.3);
        const w = WORDS[bi];
        const c = [PAL.mint, PAL.sky, PAL.sun, PAL.sky, PAL.pinkL, PAL.pink, PAL.sun, PAL.lilac][bi];
        ctx.save(); ctx.translate(1660, 540); ctx.rotate(-0.08 + (bi % 2) * 0.12); ctx.scale(k, k);
        const lines = w.split(' ');
        const fs = Math.min(100, Math.floor(420 / Math.max(...lines.map((l) => textW(l, 10) / 10)) / 10) * 10);
        lines.forEach((l, i) => mega(l, 0, (i - (lines.length - 1) / 2) * fs * 1.1 + fs * 0.36, fs, c, PAL.ink, Math.round(fs / 10), { align: 'center' }));
        ctx.restore();
      }
    },
  });
}

// ---------------------------------------------------------------- CLIMAX B: feature bars (b104-112)
{
  const BARS = [
    ['5 KITS', 'starter bags with their own rules', PAL.sun, 'bag'],
    ['HEAT 0-5', 'stakes that bite back', PAL.pink, 'flame'],
    ['DAILY RUN', 'one seed, the same for everyone', PAL.sky, 'star'],
    ['ENDLESS', 'a ×10 combo ladder, no target', PAL.mint, 'chip'],
    ['OVERTIME', 'the run goes on after the final boss', PAL.lilac, 'mult'],
    ['60 ACHIEVEMENTS', 'ten of them secret', PAL.cream, 'trophy'],
    ['POPS', 'an old arcade bot shows you around', PAL.sunL, null],
  ];
  const TA = (i) => 52.0 + i * 0.5;
  const TCL = 55.5;
  scene(88, 96, {
    shift: 8,
    bg: () => bgp('party', { dark: 0.6 }),
    init() {
      BARS.forEach((_, i) => cue(TA(i), 'bar', { var: i, shake: 10, shock: 0.15 }));
      cue(TCL, 'clear_3', { shake: 28, shock: 0.7 });
    },
    draw(t) {
      slab(PAL.ink);
      // real in-game screenshots, stacked like stickers as each bar lands
      const SH = ['kits', 'boss_round', 'title', 'endless', 'won', 'trophies', 'round'];
      SH.forEach((n, i) => {
        const ta = TA(i);
        if (t < ta || t >= TCL + 0.1) return;
        const k = slam(t, ta, 0.14, 1.5);
        const im = IMG['shot_' + n];
        const w = 860, h = 484, rot = [-0.05, 0.04, -0.03, 0.05, -0.04, 0.03, -0.02][i];
        ctx.save(); ctx.translate(1450 + [0, 20, -30, 10, -10, 30, 0][i], 520 + [-20, 30, -10, 20, -30, 10, 0][i]); ctx.rotate(rot); ctx.scale(k, k);
        rect(-w / 2 - 14 + 18, -h / 2 - 14 + 18, w + 28, h + 28, '#000a');
        rect(-w / 2 - 14, -h / 2 - 14, w + 28, h + 28, PAL.cream);
        setSmooth(true);
        ctx.drawImage(im, -w / 2, -h / 2, w, h);
        // tape
        ctx.globalAlpha = 0.85; rect(-60, -h / 2 - 34, 120, 40, BARS[i][2]); ctx.globalAlpha = 1;
        ctx.restore();
      });
      pill('IN-GAME', 1090, 64, 30, PAL.sun, PAL.ink);
      BARS.forEach(([big, small, col, icon], i) => {
        const ta = TA(i);
        if (t < ta) return;
        const y = 92 + i * 128;
        const dir = i % 2 ? 1 : -1;
        const k = E.outExpo(inv(ta, ta + 0.18, t));
        const x = -(1 - k) * 1100;
        const tc = TCL + (6 - i) * 0.04;
        let sc = 1, white = 0;
        if (t >= tc) { const d = t - tc; if (d > 0.22) return; white = d < 0.06 ? 1 : 1 - (d - 0.06) / 0.1; sc = d < 0.06 ? 1 : 1 - E.inQuad((d - 0.06) / 0.16); }
        const BW = 1000;
        ctx.save(); ctx.translate(x + BW / 2, y + 60); ctx.scale(1, sc); ctx.translate(-BW / 2, -60);
        rect(0, 0, BW, 120, col);
        rect(BW, 0, 16, 120, PAL.ink);
        rect(0, 120, BW, 10, '#0005');
        if (icon) sprite(icon, 70, 16, 2);
        else sprite('helper', 80, 4, 1.8, 0, 0, 56, 62);
        text(big, 190, 72, 70, PAL.ink);
        text(small, 192, 108, 30, PAL.ink, { bold: false });
        if (white > 0) { ctx.globalAlpha = white; rect(0, 0, BW, 120, '#fff'); ctx.globalAlpha = 1; }
        ctx.restore();
        if (t >= tc) for (let j = 0; j < 7; j++) burst(t, tc + 0.05, 80 + j * 150, y + 60, { n: 4, seed: i * 20 + j, speed: 1200, grav: 2600, size: 20, colors: [col, PAL.cream], life: 0.6 });
      });
    },
  });
}

// ---------------------------------------------------------------- CLIMAX C: the number (b112-128)
{
  const T0 = 56.0, TCAP = 62.0, TBRK = 63.0;
  const MS = [[56.0, 'ONE MILLION', PAL.sun, 1e6], [58.0, 'ONE BILLION', PAL.pink, 1e9], [60.0, 'ONE TRILLION', PAL.sky, 1e12], [62.0, 'ONE QUADRILLION', PAL.lilac, 1e15]];
  const val = (t) => {
    if (t >= TCAP) return 1e15;
    for (let i = 0; i < 3; i++) if (t < MS[i + 1][0]) { const k = inv(MS[i][0] + 0.5, MS[i + 1][0], t); return MS[i][3] * Math.pow(1000, Math.pow(k, 1.6)); }
    return 1e15;
  };
  scene(96, 112, {
    shift: 8,
    bg: (t) => bgp('party', { pulse: 0.3 + 0.7 * Math.exp(-((t - T0) % 0.5) * 5), swirl: 2.4 + (t - T0) * 0.3, dark: t > TBRK ? 0.6 : 1 }),
    post(t) {
      const glitch = t >= TBRK ? 0.4 + 0.6 * inv(TBRK, 63.5, t) : (t >= TCAP && t < TCAP + 0.15 ? 0.6 : 0);
      const collapse = inv(63.55, 64.0, t);
      return { glitch, collapse };
    },
    init() {
      MS.forEach(([tm], i) => cue(tm, 'milestone', { var: i, shake: 30, shock: 0.9, flash: 0.25 }));
      cue(TBRK, 'machine_break', { shake: 40, shock: 1.2 });
      cue(63.55, 'crt_off');
    },
    draw(t) {
      const mi = MS.filter((m) => t >= m[0]).length - 1;
      const [tm, word, col] = MS[mi];
      const inSlab = t < tm + 0.75;
      // falling block rain
      const speed = 500 + (t - T0) * 180;
      for (let i = 0; i < 40; i++) {
        const x = Math.floor(rnd(i, 1) * 20) * 96 + 4;
        const ph = rnd(i, 2) * 2000;
        const y = ((t * speed + ph) % 1400) - 200;
        block(Math.floor(rnd(i, 3) * 6), x, y, 88, { alpha: 0.9 });
      }
      if (inSlab) {
        const k = E.outExpo(inv(tm, tm + 0.1, t));
        rect(0, 540 - 540 * k, W, 1080 * k, col);
        const sk = slam(t, tm, 0.14, 1.8);
        const parts = word.split(' ');
        scaled(W / 2, 540, sk, () => {
          mega(parts[0], 0, -60, 200, PAL.ink, '#0003', 0, { align: 'center' });
          const fs2 = Math.min(320, Math.floor(1700 / (textW(parts[1], 100) / 100) / 10) * 10);
          mega(parts[1], 0, 60 + fs2 * 0.72, fs2, PAL.ink, '#0003', 0, { align: 'center' });
        });
        return;
      }
      const v = val(t);
      const s = bigCommas(v);
      const w = textW(s, 120);
      const fit = Math.min(3, 1760 / w);
      rect(0, 330, W, 330, PAL.ink);
      rect(0, 318, W, 12, col); rect(0, 660, W, 12, col);
      const jit = t >= TCAP ? (rnd(Math.floor(t * 60), 4) - 0.5) * 30 : 0;
      scaled(W / 2 + jit, 500, fit, () => text(s, 0, 44, 120, t >= TCAP ? PAL.cream : col, { align: 'center', shadow: 6, shadowColor: PAL.pinkD }));
      pill('SINGLE PLACEMENT', 160, 250, 30, col, PAL.ink);
      if (t < TCAP) {
        const chips = Math.round(Math.pow(v, 0.38) * 7);
        const mult = v / chips;
        const ms = mult >= 1e6 ? (mult / 1e6).toFixed(2) + 'M' : commas(mult);
        text(commas(chips) + ' CHIPS  ×  ' + ms + ' MULT', W / 2, 720, 30, PAL.cream, { align: 'center' });
      }
      if (mi === 0) subtitle('Overtime: keep going after the final boss.', t, 56.6, 57.9, { y: 860, accent: col });
      if (mi === 2) subtitle('Until one placement breaks the machine.', t, 60.6, 61.9, { y: 860, accent: col });
      if (t >= TBRK) {
        const k = slam(t, TBRK, 0.1, 2.5);
        ctx.save(); ctx.translate(W / 2, 820); ctx.rotate(-0.06); ctx.scale(k, k);
        pxRect(-560, -80, 1120, 160, PAL.pink, { shadow: 16, notch: 12, border: 8, borderColor: PAL.ink });
        text('MACHINE BROKEN', 0, 40, 110, PAL.ink, { align: 'center' });
        ctx.restore();
      }
    },
  });
}

// ---------------------------------------------------------------- END (b128-144)
{
  const TP = 64.6, TL = 66.0;
  const LOGO_C = [0, 1, 2, 3, 4, 5, 0, 1, 2, 3];
  scene(112, 128, {
    shift: 8,
    bg: (t) => (t < TL ? bgp('plum', { dark: 0 }) : bgp('plum', { dark: E.outCubic(inv(TL, TL + 0.4, t)) })),
    init() {
      cue(TP, 'pops_hi');
      cue(TL, 'logo_hit', { shake: 16, shock: 0.4 });
      for (let i = 0; i < 10; i++) cue(TL + 0.02 + i * 0.05, 'place', { var: i, vel: 0.5 });
      cue(67.0, 'button');
    },
    draw(t) {
      if (t < TL) {
        slab('#07040b');
        if (t < TP) return;
        // POPS pops up, speech bubble
        const k = E.outBack(inv(TP, TP + 0.3, t));
        const fr = t < TP + 0.9 ? (Math.floor((t - TP) * 10) % 2 ? 2 : 3) : 6;
        sprite('helper', W / 2 - 224, 1080 - 520 * k, 8, fr * 56, 0, 56, 62);
        if (t > TP + 0.2) {
          const kk = E.outBack(inv(TP + 0.2, TP + 0.4, t));
          ctx.save(); ctx.translate(W / 2, 330); ctx.scale(kk, kk);
          pxRect(-520, -120, 1040, 220, PAL.cream, { shadow: 14, notch: 12, border: 8, borderColor: PAL.ink });
          rect(-30, 100, 60, 30, PAL.cream); rect(-10, 130, 20, 20, PAL.cream);
          text(reveal('ONE MORE RUN?', t, TP + 0.3, 0.5), 0, 36, 100, PAL.ink, { align: 'center' });
          ctx.restore();
        }
        return;
      }
      blockWord('BLOCKMANIA', t, { cell: 26, cy: 330, land: (li) => TL + 0.02 + li * 0.05, fall: 0.15, color: (li) => LOGO_C[li], bob: 4 });
      if (t >= TL + 0.5) {
        const k = E.outExpo(inv(TL + 0.5, TL + 0.7, t));
        text('THE BLOCK PUZZLE ROGUELIKE', W / 2, 560 + (1 - k) * 30, 60, PAL.cream, { align: 'center', shadow: 6 });
      }
      if (t >= 67.0) {
        const k = slam(t, 67.0, 0.16, 1.6);
        const pulse = 1 + 0.03 * Math.max(0, Math.sin((t - 67.0) * Math.PI * 2));
        ctx.save(); ctx.translate(W / 2, 730); ctx.scale(k * pulse, k * pulse);
        pxRect(-490, -70, 980, 150, PAL.sunD, { notch: 12, border: 7, borderColor: PAL.ink, shadow: 12 });
        pxRect(-483, -63, 966, 124, PAL.sun, { notch: 8 });
        sprite('steam', -455, -48, 4);
        text('WISHLIST ON STEAM', 50, 28, 70, PAL.ink, { align: 'center' });
        ctx.restore();
      }
      if (t >= 67.5) {
        const k = inv(67.5, 67.8, t);
        ctx.globalAlpha = k;
        setSmooth(true);
        const im = IMG.studio; const sw = 300, sh = sw * im.height / im.width;
        ctx.drawImage(im, W - sw - 90, H - sh - 60, sw, sh);
        text('Windows · macOS · Linux', W / 2, 870, 30, PAL.dim, { align: 'center', bold: false });
        ctx.globalAlpha = 1;
        // POPS waves from the corner
        const fr = Math.floor(t * 4) % 2 ? 4 : 5;
        sprite('helper', 120, H - 62 * 5 - 70 + (1 - E.outBack(k)) * 400, 5, fr * 56, 0, 56, 62);
      }
    },
  });
}
