// BLOCKMANIA trailer engine: assets, WebGL passes, drawing toolkit and the cue timeline.
// render(t) must stay a pure function of time: every animation and particle is computed from
// the events defined at load, so frames can be rendered out of order and in parallel.
'use strict';

const W = 1920, H = 1080, FPS = 60, BPM = 120, BEAT = 60 / BPM, DUR = 72;
const b2t = (b) => b * BEAT;

const PAL = {
  ink: '#1a1026', plumDD: '#211631', plumD: '#2d1e43', plum: '#3f2b5e', plumL: '#5c4282', plumLL: '#8062ad',
  cream: '#fff3db', creamD: '#efd6b0', creamDD: '#cda87c',
  sunL: '#ffec96', sun: '#ffcc3d', sunD: '#de9622', sunDD: '#9e6016',
  mint: '#3dd691', mintL: '#8cf4be', pink: '#ff4d6d', pinkL: '#ff96aa', pinkD: '#c82850',
  sky: '#4daaff', skyL: '#a0d8ff', lilac: '#b388ff', dim: '#b9a6d6', white: '#ffffff',
  boss: '#c82850', bossD: '#5a0f22',
};
const BLOCKS = ['red', 'orange', 'yellow', 'green', 'blue', 'purple', 'stone'];
const HUE = ['#ff4d6d', '#ff9a3d', '#ffcc3d', '#3dd691', '#4daaff', '#b388ff', '#8a7fa0'];
const RARITY = { common: '#9d8fb8', uncommon: PAL.sky, rare: PAL.pink, legendary: PAL.lilac };

// ------------------------------------------------------------------ assets
const A = '../../assets/';
const IMG = {};
const IMG_LIST = {
  jokers: 'ui/cards/jokers.png', items: 'ui/cards/items.png', tools: 'ui/cards/tools.png', badges: 'ui/cards/badges.png',
  helper: 'ui/helper.png', cell_empty: 'ui/cell_empty.png', glow: 'ui/block_glow.png', lever: 'ui/lever.png',
  cursor_hand: 'ui/cursor_hand.png', cursor_grab: 'ui/cursor_grab.png', cursor_arrow: 'ui/cursor_arrow.png',
  coin: 'ui/icon_coin.png', skull: 'ui/icon_skull.png', bag: 'ui/icon_bag.png', flame: 'ui/icon_flame.png',
  chip: 'ui/icon_chip.png', mult: 'ui/icon_mult.png', trophy: 'ui/icon_trophy.png', star: 'ui/icon_star.png',
  lock: 'ui/icon_padlock.png', crate: 'ui/crate_big.png', crate_open: 'ui/crate_big_open.png',
  studio: 'brand/buru_arcade_logo.png', stamp_encore: 'ui/stamp_encore.png',
};
const SHOTS = ['kits', 'boss_round', 'title', 'endless', 'won', 'trophies', 'round'];
const SHOT_BASE = '../../docs/media/';
for (const b of BLOCKS) IMG_LIST['block_' + b] = 'ui/block_' + b + '.png';
const FINISHES = ['gold', 'neon', 'lava', 'prism', 'chrome', 'ice', 'starfall', 'aurora', 'glass', 'crystal', 'candy', 'marble', 'wood', 'cyberpunk'];
for (const f of FINISHES) IMG_LIST['fin_' + f] = 'ui/finish_' + f + '.png';
const FIN_META = {
  aurora: [6, 16, 1], candy: [6, 12, 1], chrome: [10, 16, 1], crystal: [9, 16, 1], cyberpunk: [8, 12, 1],
  glass: [9, 16, 1], gold: [9, 16, 1], ice: [8, 16, 1], lava: [7, 16, 2], marble: [8, 20, 3], neon: [10, 24, 1],
  prism: [7, 12, 1], starfall: [8, 24, 2], wood: [1, 1, 2],
};
const FIN_GLOW = { neon: 0.62, lava: 0.4, starfall: 0.42, aurora: 0.4, crystal: 0.34, prism: 0.26, gold: 0.2, glass: 0.22, ice: 0.16, cyberpunk: 0.24 };
let CARDS = null;

function loadAll() {
  const all = Object.entries(IMG_LIST).map(([k, p]) => [k, A + p]).concat(SHOTS.map((n) => ['shot_' + n, SHOT_BASE + 'shot_' + n + '.jpg']));
  const jobs = all.map(([k, p]) => new Promise((res, rej) => {
    const im = new Image();
    im.onload = () => { IMG[k] = im; res(); };
    im.onerror = () => rej(new Error('image ' + p));
    im.src = p;
  }));
  const fonts = [['Blockhead', 'fonts/blockhead.ttf'], ['BlockheadB', 'fonts/blockhead_bold.ttf']].map(([n, p]) => {
    const f = new FontFace(n, `url(${A + p})`);
    return f.load().then((ff) => document.fonts.add(ff));
  });
  const cards = fetch(A + 'ui/cards/cards.json').then((r) => r.json()).then((j) => { CARDS = j; });
  return Promise.all([...jobs, ...fonts, cards]);
}

// ------------------------------------------------------------------ math
const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const lerp = (a, b, k) => a + (b - a) * k;
const inv = (a, b, x) => clamp((x - a) / (b - a));
const E = {
  outExpo: (k) => (k >= 1 ? 1 : 1 - Math.pow(2, -10 * k)),
  inExpo: (k) => (k <= 0 ? 0 : Math.pow(2, 10 * k - 10)),
  outCubic: (k) => 1 - Math.pow(1 - k, 3),
  inCubic: (k) => k * k * k,
  inOutCubic: (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2),
  outBack: (k) => { const c = 1.9; return 1 + (c + 1) * Math.pow(k - 1, 3) + c * Math.pow(k - 1, 2); },
  inQuad: (k) => k * k,
  outQuad: (k) => 1 - (1 - k) * (1 - k),
};
// A seeded hash RNG: rnd(seed, i) -> [0,1)
function rnd(seed, i = 0) {
  let x = (seed * 374761393 + i * 668265263) | 0;
  x = (x ^ (x >>> 13)) * 1274126177 | 0;
  x = x ^ (x >>> 16);
  return (x >>> 0) / 4294967296;
}
// Arrival with the block "squash": 0 before t0, falls in `dur`, 1-frame squash then settle.
function drop(t, t0, dur = 0.16) {
  const k = (t - t0) / dur;
  if (k < 0) return { y: -1, sx: 1, sy: 1, on: false };
  if (k < 1) return { y: -(1 - E.inQuad(k)), sx: 0.94, sy: 1.08, on: true };
  const s = t - (t0 + dur);
  const sq = Math.exp(-s / 0.05) * Math.cos(s * 55);
  return { y: 0, sx: 1 + 0.12 * sq, sy: 1 - 0.14 * sq, on: true };
}
// Pop scale for a "slam" arrival: overshoot then settle.
function slam(t, t0, dur = 0.18, from = 1.8) {
  const k = (t - t0) / dur;
  if (k < 0) return 0;
  if (k >= 1) {
    const s = t - t0 - dur;
    return 1 + 0.05 * Math.exp(-s / 0.06) * Math.cos(s * 40);
  }
  return lerp(from, 1, E.outExpo(k));
}

// ------------------------------------------------------------------ number formatting
function commas(n) {
  const s = Math.floor(n).toString();
  return s.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}
function bigCommas(v) { // v may exceed 2^53: use BigInt path for digits
  if (v < 9e15) return commas(v);
  return BigInt(Math.floor(v)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// ------------------------------------------------------------------ cue timeline (shared with audio)
const CUES = [];
function cue(t, sfx, o = {}) { CUES.push(Object.assign({ t, sfx }, o)); }

function impactsAt(t) {
  let shake = 0, shock = 0, flash = 0, sx = 0, sy = 0;
  for (const c of CUES) {
    const d = t - c.t;
    if (d < 0 || d > 0.6) continue;
    if (c.shake) {
      const a = c.shake * Math.exp(-d / 0.07);
      sx += a * (rnd(Math.round(c.t * 1000), Math.floor(d * 60)) * 2 - 1);
      sy += a * (rnd(Math.round(c.t * 1000) + 7, Math.floor(d * 60)) * 2 - 1);
      shake += a;
    }
    if (c.shock) shock += c.shock * Math.exp(-d / 0.12);
    if (c.flash) flash += c.flash * Math.exp(-d / 0.09);
  }
  return { sx, sy, shock: Math.min(shock, 1.2), flash: Math.min(flash, 1) };
}

// ------------------------------------------------------------------ 2D drawing toolkit
let ctx; // the content layer
function setSmooth(on) { ctx.imageSmoothingEnabled = on; }

function rect(x, y, w, h, c) { ctx.fillStyle = c; ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); }
// Pixel-art rectangle: notched corners (n px), optional hard shadow and border.
function pxRect(x, y, w, h, c, o = {}) {
  const n = o.notch ?? 6;
  x = Math.round(x); y = Math.round(y); w = Math.round(w); h = Math.round(h);
  const shape = (ox, oy, col) => {
    ctx.fillStyle = col;
    ctx.fillRect(ox + n, oy, w - 2 * n, h);
    ctx.fillRect(ox, oy + n, w, h - 2 * n);
  };
  if (o.shadow) shape(x + o.shadow, y + o.shadow, o.shadowColor || PAL.ink);
  if (o.border) {
    const b = o.border;
    shape(x, y, o.borderColor || PAL.ink);
    ctx.fillStyle = c;
    ctx.fillRect(x + b + Math.max(0, n - b), y + b, w - 2 * b - 2 * Math.max(0, n - b), h - 2 * b);
    ctx.fillRect(x + b, y + b + Math.max(0, n - b), w - 2 * b, h - 2 * b - 2 * Math.max(0, n - b));
  } else shape(x, y, c);
}

function font(size, bold = true) { return `${size}px ${bold ? 'BlockheadB' : 'Blockhead'}`; }
// Text with an optional hard shadow (offset in px) and outline. Returns width.
function text(s, x, y, size, color, o = {}) {
  ctx.font = font(size, o.bold !== false);
  ctx.textAlign = o.align || 'left';
  ctx.textBaseline = o.base || 'alphabetic';
  x = Math.round(x); y = Math.round(y);
  if (o.shadow) {
    ctx.fillStyle = o.shadowColor || PAL.ink;
    ctx.fillText(s, x + o.shadow, y + o.shadow);
  }
  if (o.outline) {
    ctx.fillStyle = o.outlineColor || PAL.ink;
    const k = o.outline;
    for (const [dx, dy] of [[-k, 0], [k, 0], [0, -k], [0, k], [-k, -k], [k, k], [-k, k], [k, -k]]) ctx.fillText(s, x + dx, y + dy);
  }
  ctx.fillStyle = color;
  ctx.fillText(s, x, y);
  return ctx.measureText(s).width;
}
function textW(s, size, bold = true) { ctx.font = font(size, bold); return ctx.measureText(s).width; }

// Typewriter-ish reveal: characters appear over `dur` from t0.
function reveal(s, t, t0, dur) { const k = inv(t0, t0 + dur, t); return s.slice(0, Math.ceil(k * s.length)); }

// Blocks ----------------------------------------------------------------
function block(ci, x, y, s, o = {}) {
  const im = IMG['block_' + BLOCKS[ci]];
  const smooth = s < 44;
  setSmooth(smooth);
  const a = o.alpha ?? 1;
  if (a <= 0) return;
  ctx.globalAlpha = a;
  const sx = o.sx ?? 1, sy = o.sy ?? 1;
  const w = s * sx, h = s * sy;
  // squash anchored at the bottom
  ctx.drawImage(im, Math.round(x + (s - w) / 2), Math.round(y + (s - h)), Math.round(w), Math.round(h));
  if (o.white) { ctx.globalAlpha = a * o.white; ctx.fillStyle = '#fff'; ctx.fillRect(Math.round(x + (s - w) / 2 + s * 0.04), Math.round(y + (s - h) + s * 0.04), Math.round(w * 0.92), Math.round(h * 0.92)); }
  ctx.globalAlpha = 1;
}
// Animated finish face (88px face in a 96px cell sheet), color 0..5.
function finishFrame(fin, cx, cy, t) {
  const [fps, frames] = FIN_META[fin];
  if (frames <= 1) return 0;
  const hold = { marble: 20, neon: 0, prism: 0 }[fin] ?? 8;
  const cycle = frames + hold;
  const off = -(cx + cy);
  const f = ((Math.floor(t * fps) + off) % cycle + cycle) % cycle;
  return f < frames ? f : 0;
}
function finBlock(fin, ci, cx, cy, x, y, s, t, o = {}) {
  const im = IMG['fin_' + fin];
  const [, , variants] = FIN_META[fin];
  const v = variants > 1 ? (((cx * 5 + cy * 3 + (cx * cy) % 3) % variants) + variants) % variants : 0;
  const f = finishFrame(fin, cx, cy, t);
  setSmooth(s < 44);
  const a = o.alpha ?? 1;
  const sx = o.sx ?? 1, sy = o.sy ?? 1;
  const w = s * sx, h = s * sy;
  ctx.globalAlpha = a;
  ctx.drawImage(im, f * 96 + 4, (ci * variants + v) * 96 + 4, 88, 88, Math.round(x + (s - w) / 2), Math.round(y + (s - h)), Math.round(w), Math.round(h));
  if (o.white) { ctx.globalAlpha = a * o.white; ctx.fillStyle = '#fff'; ctx.fillRect(Math.round(x + (s - w) / 2 + s * 0.04), Math.round(y + s - h + s * 0.04), Math.round(w * 0.92), Math.round(h * 0.92)); }
  ctx.globalAlpha = 1;
}
function glowUnder(fin, ci, x, y, s, a = 1) {
  const g = FIN_GLOW[fin];
  if (!g) return;
  const c = fin === 'gold' ? PAL.sun : fin === 'aurora' ? PAL.mint : HUE[ci];
  // tint the halo sprite through an offscreen canvas cache
  const im = tinted(IMG.glow, c);
  const r = s * 0.32;
  setSmooth(true);
  ctx.globalAlpha = g * a;
  ctx.drawImage(im, x - r, y - r, s + 2 * r, s + 2 * r);
  ctx.globalAlpha = 1;
}
const _tint = {};
function tinted(im, c) {
  const k = im.src + c;
  if (_tint[k]) return _tint[k];
  const cv = document.createElement('canvas');
  cv.width = im.width; cv.height = im.height;
  const g = cv.getContext('2d');
  g.drawImage(im, 0, 0);
  g.globalCompositeOperation = 'source-in';
  g.fillStyle = c; g.fillRect(0, 0, cv.width, cv.height);
  return (_tint[k] = cv);
}

// Sprite from a card sheet: set = jokers/items/tools, id, frame (0..7), scale.
function portrait(set, id, x, y, scale, frame = 0, alpha = 1) {
  const row = CARDS[set][id] ?? 0;
  setSmooth(false);
  ctx.globalAlpha = alpha;
  ctx.drawImage(IMG[set], frame * 16, row * 16, 16, 16, Math.round(x), Math.round(y), 16 * scale, 16 * scale);
  ctx.globalAlpha = 1;
}
function glint(t, seed) { // occasional 8-frame shine
  const cyc = 2.4 + rnd(seed) * 1.5;
  const ph = (t + rnd(seed, 3) * cyc) % cyc;
  const f = Math.floor(ph * 14);
  return f >= 1 && f <= 6 ? f : 0;
}
function sprite(key, x, y, scale, sx = 0, sy = 0, sw = null, sh = null, alpha = 1) {
  const im = IMG[key];
  sw = sw ?? im.width; sh = sh ?? im.height;
  setSmooth(false);
  ctx.globalAlpha = alpha;
  ctx.drawImage(im, sx, sy, sw, sh, Math.round(x), Math.round(y), Math.round(sw * scale), Math.round(sh * scale));
  ctx.globalAlpha = 1;
}

// BLOCKTYPE: text rasterized from Blockhead at 10 px; each lit font pixel is a block.
const _glyph = {};
function glyphs(str, bold = true) {
  const key = str + bold;
  if (_glyph[key]) return _glyph[key];
  // Rasterize at 40 px (4 canvas px per font pixel) and sample each font pixel at its centre:
  // at small sizes Blockhead's edges fall on half pixels.
  const P = 4;
  const cv = document.createElement('canvas');
  cv.width = 10 * P * str.length + 40; cv.height = 16 * P;
  const g = cv.getContext('2d', { willReadFrequently: true });
  g.font = `${10 * P}px ${bold ? 'BlockheadB' : 'Blockhead'}`;
  g.textBaseline = 'alphabetic';
  g.fillStyle = '#fff';
  g.fillText(str, 8, 12 * P);
  const spans = [];
  let acc = 8;
  for (let i = 0; i < str.length; i++) {
    const w = g.measureText(str.slice(0, i + 1)).width + 8;
    spans.push([acc, w]); acc = w;
  }
  const d = g.getImageData(0, 0, cv.width, cv.height).data;
  const A = (x, y) => d[(y * cv.width + x) * 4 + 3];
  let minX = 1e9, maxX = -1, minY = 1e9, maxY = -1;
  for (let yy = 0; yy < cv.height; yy++) for (let xx = 0; xx < cv.width; xx++) if (A(xx, yy) > 200) {
    minX = Math.min(minX, xx); maxX = Math.max(maxX, xx); minY = Math.min(minY, yy); maxY = Math.max(maxY, yy);
  }
  const gw = Math.round((maxX - minX + 1) / P), gh = Math.round((maxY - minY + 1) / P);
  const cells = [];
  for (let j = 0; j < gh; j++) for (let i = 0; i < gw; i++) {
    const sx = Math.floor(minX + i * P + P / 2), sy = Math.floor(minY + j * P + P / 2);
    if (A(sx, sy) > 128) {
      let li = spans.findIndex((s) => sx >= s[0] && sx < s[1]);
      if (li < 0) li = spans.length - 1;
      cells.push({ x: i, y: j, li });
    }
  }
  return (_glyph[key] = { cells, w: gw, h: gh, n: spans.length });
}

// Particles: square pixel bits, analytic from the spawn event.
function burst(t, t0, x, y, o = {}) {
  const d = t - t0;
  const life = o.life ?? 0.7;
  if (d < 0 || d > life) return;
  const n = o.n ?? 10, seed = o.seed ?? 1, sp = o.speed ?? 700, g = o.grav ?? 2200;
  const cols = o.colors || [PAL.cream];
  const size = o.size ?? 10;
  for (let i = 0; i < n; i++) {
    const a = (o.dir ?? -Math.PI / 2) + (rnd(seed, i) - 0.5) * (o.spread ?? Math.PI * 2);
    const v = sp * (0.35 + 0.65 * rnd(seed, i + 101));
    const px = x + Math.cos(a) * v * d;
    const py = y + Math.sin(a) * v * d + 0.5 * g * d * d;
    const k = 1 - d / life;
    const s = Math.max(2, Math.round(size * (0.5 + rnd(seed, i + 211)) * (0.3 + 0.7 * k) / 2) * 2);
    ctx.fillStyle = cols[Math.floor(rnd(seed, i + 307) * cols.length)];
    ctx.fillRect(Math.round(px / 2) * 2 - s / 2, Math.round(py / 2) * 2 - s / 2, s, s);
  }
}
// A ring of dust puffs at a landing.
function dust(t, t0, x, y, w, o = {}) {
  const d = t - t0;
  if (d < 0 || d > 0.4) return;
  const k = d / 0.4;
  const n = o.n ?? 6;
  ctx.fillStyle = o.color || PAL.cream;
  ctx.globalAlpha = 1 - k;
  for (let i = 0; i < n; i++) {
    const side = i % 2 ? 1 : -1;
    const px = x + w / 2 + side * (w / 2 + E.outCubic(k) * (60 + 40 * rnd(o.seed || 3, i)));
    const py = y - E.outCubic(k) * 30 * rnd(o.seed || 3, i + 9);
    const s = Math.round((1 - k) * (o.size ?? 18));
    ctx.fillRect(Math.round(px - s / 2), Math.round(py - s), s, s);
  }
  ctx.globalAlpha = 1;
}

// ------------------------------------------------------------------ board simulation
// placements: [{t, cells:[[x,y]...], ci, fin}] -> per-cell lives + clear events.
function simulateBoard(pre, placements, o = {}) {
  const grid = Array.from({ length: 8 }, () => Array(8).fill(null));
  const lives = [];
  const clears = [];
  for (const p of pre) {
    const L = { x: p[0], y: p[1], ci: p[2], fin: p[3] || null, tp: -99, tc: Infinity, drop: false };
    grid[p[1]][p[0]] = L; lives.push(L);
  }
  const delay = o.clearDelay ?? 0.1;
  for (const P of placements) {
    for (const [x, y] of P.cells) {
      const L = { x, y, ci: P.ci, fin: P.fin || null, tp: P.t, tc: Infinity, drop: P.drop ?? false };
      if (grid[y][x]) grid[y][x].tc = Math.min(grid[y][x].tc, P.t); // overwritten (shouldn't happen)
      grid[y][x] = L; lives.push(L);
    }
    const rows = [], cols = [];
    for (let i = 0; i < 8; i++) {
      if (grid[i].every((c) => c)) rows.push(i);
      if (grid.every((r) => r[i])) cols.push(i);
    }
    if (rows.length || cols.length) {
      const cx = P.cells.reduce((s, c) => s + c[0], 0) / P.cells.length;
      const cy = P.cells.reduce((s, c) => s + c[1], 0) / P.cells.length;
      const hit = new Set();
      for (const r of rows) for (let i = 0; i < 8; i++) hit.add(grid[r][i]);
      for (const c of cols) for (let i = 0; i < 8; i++) hit.add(grid[i][c]);
      const tc0 = P.t + delay;
      for (const L of hit) {
        L.tc = tc0 + Math.hypot(L.x - cx, L.y - cy) * 0.022;
        grid[L.y][L.x] = null;
      }
      clears.push({ t: tc0, rows, cols, n: rows.length + cols.length, cx, cy, P });
    }
  }
  return { lives, clears };
}
// Draw a simulated board. origin (x,y), cell size s (face = s*11/12).
function drawBoard(sim, x, y, s, t, o = {}) {
  const face = Math.round(s * 11 / 12), pad = Math.round((s - face) / 2);
  if (!o.noEmpty) {
    setSmooth(face < 44);
    for (let j = 0; j < 8; j++) for (let i = 0; i < 8; i++) ctx.drawImage(IMG.cell_empty, x + i * s + pad, y + j * s + pad, face, face);
  }
  // glow pass
  for (const L of sim.lives) {
    if (!L.fin || t < L.tp || t > L.tc + 0.05) continue;
    glowUnder(L.fin, L.ci, x + L.x * s + pad, y + L.y * s + pad, face);
  }
  for (const L of sim.lives) {
    if (t < L.tp - (L.drop ? 0.2 : 0)) continue;
    let yy = y + L.y * s + pad, sx = 1, sy = 1, white = 0, sc = 1;
    if (L.drop) {
      const d = drop(t, L.tp - 0.16, 0.16);
      if (!d.on) continue;
      yy += d.y * (L.y + 2) * s; sx = d.sx; sy = d.sy;
    } else if (t < L.tp + 0.2) {
      const k = (t - L.tp) / 0.2; // place pop
      sc = 1 + 0.18 * Math.exp(-k * 5) * Math.cos(k * 12);
      white = Math.max(0, 0.7 - k * 3);
    }
    if (t >= L.tc) {
      const d = t - L.tc;
      if (d > 0.24) continue;
      white = d < 0.07 ? 1 : 1 - (d - 0.07) / 0.1;
      sc = d < 0.07 ? 1 + d * 2 : Math.max(0, 1.14 * (1 - E.inQuad((d - 0.07) / 0.17)));
    }
    const fs = face * sc;
    const bx = x + L.x * s + pad + (face - fs) / 2, by = yy + (face - fs) / 2;
    if (L.fin) finBlock(L.fin, L.ci, L.x, L.y, bx, by, fs, t, { sx, sy, white });
    else block(L.ci, bx, by, fs, { sx, sy, white: Math.max(0, white) });
  }
  // particles for clears
  for (const L of sim.lives) {
    if (L.tc === Infinity) continue;
    burst(t, L.tc + 0.07, x + L.x * s + s / 2, y + L.y * s + s / 2, {
      n: o.bits ?? 7, seed: L.x * 13 + L.y * 7 + Math.round(L.tc * 100), speed: s * 7, grav: s * 26,
      colors: [HUE[L.ci], PAL.cream, PAL.white], size: Math.max(6, s / 7), life: 0.65,
    });
  }
}

// ------------------------------------------------------------------ WebGL: swirl + composite + CRT
const VS = `#version 300 es
in vec2 p; out vec2 uv; void main(){ uv = p*0.5+0.5; gl_Position = vec4(p,0.,1.); }`;
const FS_SWIRL = `#version 300 es
precision highp float; in vec2 uv; out vec4 o;
uniform vec3 c0,c1,c2,c3,c4; uniform float T, pulse, swirl, px, focusX, dark;
uniform vec2 res;
float hash(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
float vn(vec2 p){ vec2 i=floor(p), f=fract(p); vec2 u=f*f*(3.-2.*f);
  return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y); }
float fbm(vec2 p){ float v=0., a=.5; for(int i=0;i<4;i++){ v+=a*vn(p); p=p*2.03+vec2(17.1,9.2); a*=.5; } return v; }
float bayer(vec2 p){ int x=int(mod(p.x,4.)), y=int(mod(p.y,4.)); int m[16]=int[](0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5); return (float(m[x+y*4])+.5)/16.; }
void main(){
  vec2 fc = uv*res; vec2 cell=floor(fc/px); vec2 u=cell*px/res; float asp=res.x/res.y;
  float t=T*0.06;
  vec2 p=(u-.5)*vec2(asp,1.); p.x -= focusX*0.3;
  float r=length(p); float ang=atan(p.y,p.x)+swirl*exp(-r*1.6)+t*1.3+pulse*0.6;
  p=vec2(cos(ang),sin(ang))*r;
  vec2 q=vec2(fbm(p*2.2+vec2(t,-t*.7)), fbm(p*2.2+vec2(-t*.8,t)+5.2));
  vec2 w=vec2(fbm(p*1.7+q*2.6+vec2(1.7,9.2)+t*.6), fbm(p*1.7+q*2.6+vec2(8.3,2.8)-t*.5));
  float n=fbm(p*1.4+w*3.); n=clamp(n*1.25-.1+pulse*.12,0.,1.);
  float d=bayer(cell)-.5; float l=clamp(floor(n*5.+d*.9),0.,4.);
  vec3 col = l<1.?c0 : l<2.?mix(c0,c1,.6) : l<3.?c1 : l<4.?mix(c2,c3,smoothstep(.3,.7,w.x)) : mix(c3,c4,.35+pulse*.4);
  float vig=smoothstep(1.15,.35,length((u-.5)*vec2(asp*.8,1.)));
  col*=mix(.55,1.,vig); col*=dark;
  o=vec4(col,1.);
}`;
const FS_COMP = `#version 300 es
precision highp float; in vec2 uv; out vec4 o;
uniform sampler2D bg, fg; uniform vec2 shake; uniform float zoom;
void main(){
  vec2 u = (uv-.5)/zoom+.5 + shake;
  vec3 b = texture(bg, uv).rgb;
  vec4 f = texture(fg, vec2(u.x, 1.-u.y));
  if(u.x<0.||u.x>1.||u.y<0.||u.y>1.) f=vec4(0.);
  o = vec4(b*(1.-f.a)+f.rgb, 1.);
}`;
const FS_POST = `#version 300 es
precision highp float; in vec2 uv; out vec4 o;
uniform sampler2D src; uniform vec2 res; uniform float T, shock, flash, glitch, collapse, warp, scan, vig, grain, abr;
float rand(vec2 c){ return fract(sin(dot(c,vec2(12.9898,78.233)))*43758.5453); }
vec2 curve(vec2 u){ vec2 dc=abs(.5-u); dc*=dc; u.x-=.5; u.x*=1.+dc.y*(.3*warp); u.x+=.5; u.y-=.5; u.y*=1.+dc.x*(.4*warp); u.y+=.5; return u; }
void main(){
  vec2 u = curve(uv);
  // CRT power-off collapse: squash vertically to a line, then horizontally to a dot
  float cy = clamp(collapse*2.,0.,1.), cx = clamp(collapse*2.-1.,0.,1.);
  float sy = mix(1., 0.004, pow(cy,.6)), sx = mix(1., 0.002, pow(cx,.8));
  u = (u-.5)/vec2(sx,sy)+.5;
  if(glitch>0.){
    float band = floor(u.y*18.+floor(T*30.)*3.1);
    float g = step(1.-glitch*.55, rand(vec2(band, floor(T*30.))));
    u.x += (rand(vec2(band,2.))-.5)*.12*g*glitch;
  }
  if(u.x<0.||u.x>1.||u.y<0.||u.y>1.){ o=vec4(.012,.008,.02,1.); return; }
  vec2 pxs=1./res; vec2 fc=u-.5; float edge=dot(fc,fc)*4.;
  vec2 ab = fc*pxs*(abr*(.6+edge)+shock*9.+glitch*24.);
  vec3 c; c.r=texture(src,u+ab).r; c.g=texture(src,u).g; c.b=texture(src,u-ab).b;
  c *= 1.+shock*.18;
  float line = abs(sin(uv.y*res.y*1.5708))*.5*scan; c=mix(c,vec3(0.),line);
  c += (rand(uv*431.+fract(T))-.5)*grain;
  c *= 1.-vig*smoothstep(.25,.95,length(fc*vec2(1.1,1.25)));
  c = mix(c, vec3(1.,.98,.94), clamp(flash,0.,1.));
  float lum = 1. + collapse*2.5*step(.001,collapse);
  o=vec4(c*lum,1.);
}`;

let gl, glc, prog = {}, tex = {}, fbo = {}, layer;
function initGL(canvas) {
  glc = canvas;
  gl = canvas.getContext('webgl2', { preserveDrawingBuffer: true, antialias: false, premultipliedAlpha: false });
  const mk = (vs, fs) => {
    const p = gl.createProgram();
    for (const [type, src] of [[gl.VERTEX_SHADER, vs], [gl.FRAGMENT_SHADER, fs]]) {
      const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
      gl.attachShader(p, s);
    }
    gl.bindAttribLocation(p, 0, 'p'); gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
    return p;
  };
  prog.swirl = mk(VS, FS_SWIRL); prog.comp = mk(VS, FS_COMP); prog.post = mk(VS, FS_POST);
  const buf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
  const mkTex = (filter) => {
    const t = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, t);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    return t;
  };
  for (const k of ['bg', 'comp']) {
    tex[k] = mkTex(gl.LINEAR);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, W, H, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    fbo[k] = gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER, fbo[k]);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex[k], 0);
  }
  tex.fg = mkTex(gl.NEAREST);
  layer = document.createElement('canvas'); layer.width = W; layer.height = H;
  ctx = layer.getContext('2d');
}
const hex3 = (h) => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255];
function u(p, name) { return gl.getUniformLocation(p, name); }
function present(t, bgp, post) {
  gl.viewport(0, 0, W, H);
  // swirl
  gl.bindFramebuffer(gl.FRAMEBUFFER, fbo.bg); gl.useProgram(prog.swirl);
  const P = prog.swirl;
  bgp.cols.forEach((c, i) => gl.uniform3fv(u(P, 'c' + i), c));
  gl.uniform1f(u(P, 'T'), t); gl.uniform1f(u(P, 'pulse'), bgp.pulse); gl.uniform1f(u(P, 'swirl'), bgp.swirl);
  gl.uniform1f(u(P, 'px'), 6); gl.uniform1f(u(P, 'focusX'), bgp.focusX); gl.uniform1f(u(P, 'dark'), bgp.dark);
  gl.uniform2f(u(P, 'res'), W, H);
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  // composite content
  gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, tex.fg);
  gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, true);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, layer);
  gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, tex.bg);
  gl.bindFramebuffer(gl.FRAMEBUFFER, fbo.comp); gl.useProgram(prog.comp);
  gl.uniform1i(u(prog.comp, 'bg'), 0); gl.uniform1i(u(prog.comp, 'fg'), 1);
  gl.uniform2f(u(prog.comp, 'shake'), post.sx / W, post.sy / H); gl.uniform1f(u(prog.comp, 'zoom'), post.zoom);
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  // post
  gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.useProgram(prog.post);
  gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, tex.comp);
  const Q = prog.post;
  gl.uniform1i(u(Q, 'src'), 0); gl.uniform2f(u(Q, 'res'), W, H); gl.uniform1f(u(Q, 'T'), t);
  for (const k of ['shock', 'flash', 'glitch', 'collapse', 'warp', 'scan', 'vig', 'grain', 'abr']) gl.uniform1f(u(Q, k), post[k]);
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
}
