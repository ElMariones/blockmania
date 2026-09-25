// BLOCKMANIA Steam capsules: key art composed from the game's own sprites, Blockhead logo, swirl
// and CRT, drawn with the trailer engine (tools/trailer/engine.js + scenes.js helpers).
// Steam allows only game art, the game name and an official subtitle on base capsules, so the one
// localized element is the subtitle (the trailer's "THE BLOCK PUZZLE ROGUELIKE").
'use strict';

const SUBTITLE = {
  english: 'THE BLOCK PUZZLE ROGUELIKE',
  spanish: 'EL ROGUELIKE DE PUZLE DE BLOQUES',
  schinese: '方块拼图 ROGUELIKE',
};
// Chinese glyphs: Microsoft YaHei Bold at 16 px, thresholded to 1 bit and scaled by whole numbers,
// the same treatment as tools/store/build_store.py.
const CJK_FONT = 'bold 16px "Microsoft YaHei"';
const CJK_RE = /[⺀-鿿　-〿＀-￯]/;
const LOGO_C = [0, 1, 2, 3, 4, 5, 0, 1, 2, 3];
const FROZEN = 0.5; // the frozen moment: the gold T piece is held over the spot that clears a row and a column
const LEGENDS = ['supernova', 'avalanche', 'hall_of_mirrors', 'philosophers_stone'];

// ------------------------------------------------------------------ pixel text
function runMask(s, cjk) {
  const native = cjk ? 16 : 10;
  const f = cjk ? CJK_FONT : `${native}px BlockheadB`;
  const cv = document.createElement('canvas');
  let g = cv.getContext('2d', { willReadFrequently: true });
  g.font = f;
  cv.width = Math.ceil(g.measureText(s).width) + 8; cv.height = native * 3;
  g = cv.getContext('2d', { willReadFrequently: true });
  g.font = f; g.textBaseline = 'alphabetic'; g.fillStyle = '#fff';
  g.fillText(s, 4, native * 2);
  const im = g.getImageData(0, 0, cv.width, cv.height), d = im.data;
  let x0 = 1e9, x1 = -1, y0 = 1e9, y1 = -1;
  for (let y = 0; y < cv.height; y++) for (let x = 0; x < cv.width; x++) {
    const i = (y * cv.width + x) * 4, on = d[i + 3] >= 128;
    d[i] = d[i + 1] = d[i + 2] = 255; d[i + 3] = on ? 255 : 0;
    if (on) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
  }
  g.putImageData(im, 0, 0);
  const out = document.createElement('canvas');
  out.width = x1 - x0 + 1; out.height = y1 - y0 + 1;
  out.getContext('2d').drawImage(cv, -x0, -y0);
  return out;
}
// Text as a 1-bit mask at pixel size px (Blockhead: multiples of 10; CJK: 16 px glyphs x round(px/16)).
function textMask(s, px) {
  const kL = Math.max(1, Math.round(px / 10)), kC = Math.max(1, Math.round(px / 16));
  const gap = 4 * kL;
  const runs = [];
  for (const tok of s.match(new RegExp(`${CJK_RE.source}+|[^${CJK_RE.source.slice(1, -1)}]+`, 'g'))) {
    const cjk = CJK_RE.test(tok);
    const lead = /^\s/.test(tok), trail = /\s$/.test(tok), body = tok.trim();
    if (lead && runs.length) runs.push({ gap });
    if (body) { const m = runMask(body, cjk); runs.push({ m, k: cjk ? kC : kL }); }
    if (trail) runs.push({ gap });
  }
  const w = runs.reduce((a, r) => a + (r.gap ?? r.m.width * r.k), 0);
  const h = Math.max(...runs.filter((r) => r.m).map((r) => r.m.height * r.k));
  const cv = document.createElement('canvas');
  cv.width = w; cv.height = h;
  const g = cv.getContext('2d');
  g.imageSmoothingEnabled = false;
  let x = 0;
  for (const r of runs) {
    if (r.gap) { x += r.gap; continue; }
    g.drawImage(r.m, x, Math.round((h - r.m.height * r.k) / 2), r.m.width * r.k, r.m.height * r.k);
    x += r.m.width * r.k;
  }
  return cv;
}
function tint(m, c) {
  const cv = document.createElement('canvas');
  cv.width = m.width; cv.height = m.height;
  const g = cv.getContext('2d');
  g.drawImage(m, 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = c; g.fillRect(0, 0, cv.width, cv.height);
  return cv;
}
// Centered pixel text with a hard ink outline and drop shadow. Returns the drawn box.
function pixText(s, cx, cy, px, color, o = {}) {
  const m = textMask(s, px);
  const ol = o.outline ?? Math.round(px / 10), sh = o.shadow ?? Math.round(px / 10);
  const x = Math.round(cx - m.width / 2), y = Math.round(cy - m.height / 2);
  const ink = tint(m, PAL.ink);
  setSmooth(false);
  for (let dy = -ol; dy <= ol; dy++) for (let dx = -ol; dx <= ol; dx++) ctx.drawImage(ink, x + dx + sh, y + dy + sh);
  for (let dy = -ol; dy <= ol; dy++) for (let dx = -ol; dx <= ol; dx++) ctx.drawImage(ink, x + dx, y + dy);
  ctx.drawImage(tint(m, color), x, y);
  return { x, y, w: m.width, h: m.height };
}
// The subtitle, centered under the logo: one line at the largest size that fits, or two balanced
// lines when one line would drop below minPx. Returns the bottom edge.
function subtitleAt(cx, top, maxW, sizes, minPx = 30) {
  const sub = SUBTITLE[LANG];
  const fits = (str, px) => textMask(str, px).width + 2 * Math.round(px / 10) <= maxW;
  let lines = [sub], px = sizes.find((p) => fits(sub, p));
  if (!px || px < minPx) {
    const words = sub.split(' ');
    let best = null;
    for (let i = 1; i < words.length; i++) {
      const l = [words.slice(0, i).join(' '), words.slice(i).join(' ')];
      const d = Math.abs(textMask(l[0], 10).width - textMask(l[1], 10).width);
      if (!best || d < best.d) best = { l, d };
    }
    if (best) {
      const p2 = sizes.find((p) => best.l.every((x) => fits(x, p)));
      if (p2 && (!px || p2 > px)) { lines = best.l; px = p2; }
    }
  }
  px = px || sizes[sizes.length - 1];
  const lh = Math.round(px * 1.25);
  lines.forEach((l, i) => pixText(l, cx, top + lh / 2 + i * lh, px, PAL.sun));
  return top + lines.length * lh;
}

// ------------------------------------------------------------------ art pieces
// The BLOCKTYPE logo: every lit Blockhead pixel is a toy block, with a hard ink shadow.
function logo(str, cx, cy, s, colorOf) {
  const g = glyphs(str, true);
  const x0 = Math.round(cx - (g.w * s) / 2), y0 = Math.round(cy - (g.h * s) / 2);
  const face = Math.round(s * 11 / 12), pad = Math.round((s - face) / 2);
  const sh = Math.max(2, Math.round(s * 0.28));
  ctx.fillStyle = PAL.ink;
  ctx.globalAlpha = 0.8;
  for (const c of g.cells) ctx.fillRect(x0 + c.x * s + pad + sh, y0 + c.y * s + pad + sh, face, face);
  ctx.globalAlpha = 1;
  for (const c of g.cells) block(colorOf(c.li), x0 + c.x * s + pad, y0 + c.y * s + pad, face);
  return { x0, y0, w: g.w * s, h: g.h * s };
}
function logoCell(str, maxW, maxH) { const g = glyphs(str, true); return Math.floor(Math.min(maxW / g.w, maxH / g.h)); }
// Two-line logo: BLOCK over MANIA, colors continuing across the lines like the one-line logo.
function logo2(cx, top, s, gap) {
  const a = glyphs('BLOCK', true), b = glyphs('MANIA', true);
  const l1 = logo('BLOCK', cx, top + (a.h * s) / 2, s, (li) => LOGO_C[li]);
  const l2 = logo('MANIA', cx, top + a.h * s + gap + (b.h * s) / 2, s, (li) => LOGO_C[li + 5]);
  return { top, bottom: l2.y0 + l2.h, w: Math.max(l1.w, l2.w) };
}
function logo2Cell(maxW, maxH, gapK = 0.3) {
  const a = glyphs('BLOCK', true), b = glyphs('MANIA', true);
  return Math.floor(Math.min(maxW / Math.max(a.w, b.w), maxH / (a.h + b.h + gapK * a.h)));
}

// The 8x8 board a beat before a gold T piece lands on row 4 / column 5 and clears both (a cross).
const BOARD_ROWS = ['12.340.5', '3..142.0', '.2.515.3', '231.4..4', '4012...3', '.1.253.4', '..3..2..', '5..413.3'];
const T_CELLS = [[4, 4], [5, 4], [6, 4], [5, 3]];
const FINS = ['gold', 'neon', 'candy', 'prism', 'lava', 'ice', 'glass', 'crystal', 'aurora', 'starfall', 'chrome', 'marble'];
let SIM = null;
function boardSim() {
  if (SIM) return SIM;
  const pre = [];
  BOARD_ROWS.forEach((r, y) => [...r].forEach((ch, x) => {
    if (ch === '.') return;
    const k = rnd(x * 8 + y, 5);
    pre.push([x, y, +ch, k < 0.45 ? FINS[Math.floor(rnd(x * 8 + y, 9) * FINS.length)] : null]);
  }));
  return (SIM = simulateBoard(pre, []));
}
function board(x, y, s, o = {}) {
  const b = Math.max(4, Math.round(s * 0.12)), p = Math.max(6, Math.round(s * 0.22));
  pxRect(x - p, y - p, 8 * s + 2 * p, 8 * s + 2 * p, PAL.plumD, { border: b, borderColor: PAL.ink, shadow: Math.round(s * 0.2), notch: Math.round(p * 1.2) });
  drawBoard(boardSim(), x, y, s, FROZEN);
  const face = Math.round(s * 11 / 12), pad = Math.round((s - face) / 2);
  // Preview lines: the row and column the piece will complete.
  ctx.fillStyle = PAL.sunL;
  ctx.globalAlpha = 0.28;
  for (let i = 0; i < 8; i++) {
    ctx.fillRect(x + i * s + pad, y + 4 * s + pad, face, face);
    if (i !== 4) ctx.fillRect(x + 5 * s + pad, y + i * s + pad, face, face);
  }
  ctx.globalAlpha = 1;
  // Ghost of the piece where it will land.
  for (const [cx, cy] of T_CELLS) {
    finBlock('gold', 2, cx, cy, x + cx * s + pad, y + cy * s + pad, face, 2.2, { alpha: 0.4 });
    outline(x + cx * s + pad, y + cy * s + pad, face, Math.max(2, Math.round(s / 16)), PAL.sunL);
  }
  // The piece in hand, lifted up and to the right with the grab cursor.
  const lift = o.lift ?? [0.45, -0.7];
  const hx = x + lift[0] * s, hy = y + lift[1] * s;
  const ls = Math.round(s * 1.06); // lifted pieces read a touch larger
  piece(T_CELLS, 2, hx - (ls - s) * 5, hy - (ls - s) * 4, ls, 'gold');
  hand(hx + 5.2 * s, hy + 4.2 * s, Math.max(2, Math.round(s / 18)));
}
function outline(x, y, w, b, c) {
  rect(x, y, w, b, c); rect(x, y + w - b, w, b, c); rect(x, y, b, w, c); rect(x + w - b, y, b, w, c);
}
// A Joker portrait as a sticker: rarity rim, cream plate, hard shadow, slight tilt.
function sticker(id, cx, cy, scale, rot = 0, rarity = 'legendary') {
  const p = 16 * scale, b = Math.max(3, Math.round(scale * 1.5));
  ctx.save();
  ctx.translate(Math.round(cx), Math.round(cy));
  ctx.rotate(rot);
  pxRect(-p / 2 - 2 * b, -p / 2 - 2 * b, p + 4 * b, p + 4 * b, RARITY[rarity], { shadow: 2 * b, notch: 2 * b });
  pxRect(-p / 2 - b, -p / 2 - b, p + 2 * b, p + 2 * b, PAL.cream, { notch: b });
  portrait('jokers', id, -p / 2, -p / 2, scale, 0);
  ctx.restore();
}
// POPS, the arcade-bot helper: frame 5 waves.
function pops(x, y, scale, frame = 5) { sprite('helper', x, y, scale, frame * 56, 0, 56, 62); }
// A tray piece (cells as [x,y]) in plain toy blocks.
function piece(cells, ci, x, y, s, fin = null, alpha = 1) {
  const face = Math.round(s * 11 / 12), pad = Math.round((s - face) / 2);
  ctx.fillStyle = PAL.ink; ctx.globalAlpha = 0.6 * alpha;
  for (const [cx, cy] of cells) ctx.fillRect(x + cx * s + pad + s * 0.25, y + cy * s + pad + s * 0.25, face, face);
  ctx.globalAlpha = 1;
  for (const [cx, cy] of cells) {
    if (fin) { glowUnder(fin, ci, x + cx * s + pad, y + cy * s + pad, face, alpha); finBlock(fin, ci, cx, cy, x + cx * s + pad, y + cy * s + pad, face, 2.2, { alpha }); }
    else block(ci, x + cx * s + pad, y + cy * s + pad, face, { alpha });
  }
}
function hand(x, y, scale) { sprite('cursor_grab', x, y, scale); }

// ------------------------------------------------------------------ layouts
const LAYOUTS = {
  // 920x430: two-line logo and subtitle on the left, the board mid-clear on the right.
  header() {
    const S = 42, bx = W - 8 * S - 44, by = Math.round((H - 8 * S) / 2);
    board(bx, by, S);
    sticker('supernova', bx - 12, by + 30, 3, -0.12);
    sticker('avalanche', bx + 8 * S + 10, by + 8 * S - 40, 3, 0.1);
    const left = bx - 40;
    const cell = logo2Cell(left - 60, 205);
    const L = logo2(left / 2 + 6, 36, cell, Math.round(cell * 2.2));
    subtitleAt(left / 2 + 6, L.bottom + 22, left - 30, [30, 20]);
    pops(10, H - 62 * 2 + 24, 2);
    piece([[0, 0], [1, 0], [0, 1], [1, 1]], 4, 150, H - 70, 30, 'neon');
    piece([[0, 0], [1, 0], [2, 0], [1, 1]], 5, 250, H - 70, 30);
  },
  // 462x174: the logo nearly fills the capsule.
  small() {
    const cell = logo2Cell(W - 40, H - 20, 0.28);
    const a = glyphs('BLOCK', true);
    const gap = Math.max(4, Math.round(cell * 1.6));
    const top = Math.round((H - (a.h * 2 * cell + gap)) / 2) - 1;
    logo2(W / 2, top, cell, gap);
  },
  // 1232x706: logo, subtitle and POPS on the left; the board mid-clear with Legendary Jokers on the right.
  main() {
    const S = 64, bx = W - 8 * S - 70, by = Math.round((H - 8 * S) / 2) + 6;
    board(bx, by, S);
    sticker('supernova', bx - 20, by + 40, 5, -0.12);
    sticker('hall_of_mirrors', bx + 8 * S + 18, by + 70, 4, 0.1);
    sticker('avalanche', bx + 8 * S + 4, by + 8 * S - 50, 5, 0.08);
    const left = bx - 50;
    const cell = logo2Cell(left - 90, 300);
    const L = logo2(left / 2 + 10, 70, cell, Math.round(cell * 2.2));
    subtitleAt(left / 2 + 10, L.bottom + 36, left - 40, [40, 30, 20]);
    pops(40, H - 62 * 4 + 20, 4);
    pxRect(282, H - 214, 330, 170, PAL.plumD, { border: 6, borderColor: PAL.ink, shadow: 12, notch: 12 });
    piece([[0, 0], [1, 0], [2, 0], [1, 1]], 5, 312, H - 180, 44);
    piece([[0, 0], [0, 1], [1, 1]], 3, 482, H - 180, 44, 'neon');
  },
  // 748x896: logo and subtitle on top, the board below with POPS and Jokers around it.
  vertical() {
    const cell = logo2Cell(W - 90, 300);
    const L = logo2(W / 2, 56, cell, Math.round(cell * 2.2));
    const sb = subtitleAt(W / 2, L.bottom + 30, W - 60, [40, 30, 20]);
    const S = 50, bx = Math.round((W - 8 * S) / 2) + 20, by = Math.max(sb + 50, H - 8 * S - 36);
    board(bx, by, S);
    sticker('supernova', bx + 8 * S + 10, by + 30, 4, 0.12);
    sticker('philosophers_stone', bx + 8 * S - 4, by + 170, 4, -0.08);
    pops(-8, H - 62 * 4 + 10, 4);
  },
  // 1438x810 page background: quiet swirl, faint empty cells and a few blocks at the edges. No text.
  background() {
    emptyGrid(90, 0.06);
    const falls = [[70, 90, 4, 0], [160, 520, 2, 1], [1270, 160, 5, 2], [1330, 610, 0, 3], [40, 330, 3, 4], [1210, 430, 1, 5]];
    const shapes = [[[0, 0], [1, 0], [0, 1], [1, 1]], [[0, 0], [1, 0], [2, 0], [1, 1]], [[0, 0], [0, 1], [0, 2], [1, 2]], [[0, 0], [1, 0], [1, 1], [2, 1]]];
    for (const [x, y, ci, k] of falls) piece(shapes[k % shapes.length], ci, x, y, 40, null, 0.4);
  },

  // Library assets: Steam allows the game title and nothing else, so no subtitle.
  // 600x900 library capsule: logo on top, the board below with POPS and Jokers around it.
  lib_capsule() {
    const cell = logo2Cell(W - 70, 250);
    const L = logo2(W / 2, 60, cell, Math.round(cell * 2.2));
    const S = 54, bx = Math.round((W - 8 * S) / 2) + 16, by = Math.max(L.bottom + 90, H - 8 * S - 60);
    board(bx, by, S);
    sticker('supernova', bx + 8 * S + 4, by + 24, 3, 0.12);
    sticker('philosophers_stone', bx - 18, by + 8 * S - 30, 3, -0.1);
    pops(-6, H - 62 * 3 + 6, 3);
  },
  // 920x430 library header: the big logo on the left, the board mid-clear on the right.
  lib_header() {
    const S = 42, bx = W - 8 * S - 44, by = Math.round((H - 8 * S) / 2);
    board(bx, by, S);
    sticker('supernova', bx + 8 * S + 6, by + 26, 3, 0.1);
    sticker('avalanche', bx + 8 * S + 10, by + 8 * S - 40, 3, 0.1);
    const left = bx - 40;
    const cell = logo2Cell(left - 70, 260);
    const a = glyphs('BLOCK', true), gap = Math.round(cell * 2.2);
    logo2(left / 2 + 6, Math.round((H - (2 * a.h * cell + gap)) / 2) - 30, cell, gap);
    pops(10, H - 62 * 2 + 24, 2);
    piece([[0, 0], [1, 0], [0, 1], [1, 1]], 4, 150, H - 70, 30, 'neon');
    piece([[0, 0], [1, 0], [2, 0], [1, 1]], 5, 250, H - 70, 30);
  },
  // 3840x1240 library hero: no text. The board sits in the centred safe area (860x380 at the half-size
  // 1920x620, 1720x760 here); Jokers, POPS and falling pieces fill the rest. The bottom-left, where Steam
  // puts the library logo by default, stays quiet.
  lib_hero() {
    emptyGrid(120, 0.05);
    const S = 80, bx = Math.round(W / 2 - 4 * S) + 60, by = Math.round(H / 2 - 4 * S) + 10;
    board(bx, by, S, { lift: [0.45, -0.6] });
    sticker('supernova', bx - 150, by + 70, 7, -0.12);
    sticker('hall_of_mirrors', bx + 8 * S + 90, by + 40, 6, 0.1);
    sticker('avalanche', bx + 8 * S + 60, by + 8 * S - 150, 7, 0.08);
    sticker('philosophers_stone', bx - 190, by + 8 * S - 190, 6, -0.06);
    pops(bx + 8 * S + 330, by + 8 * S - 62 * 7 + 60, 7);
    const shapes = [[[0, 0], [1, 0], [0, 1], [1, 1]], [[0, 0], [1, 0], [2, 0], [1, 1]], [[0, 0], [0, 1], [0, 2], [1, 2]],
      [[0, 0], [1, 0], [1, 1], [2, 1]], [[0, 0], [1, 0], [2, 0], [3, 0]], [[0, 0], [0, 1], [1, 1]]];
    const falls = [
      [260, 120, 4, 0, 70, null, 0.75], [720, 60, 1, 1, 60, 'neon', 0.85], [1000, 330, 3, 5, 54, null, 0.7],
      [2960, 90, 2, 2, 64, 'prism', 0.85], [3400, 300, 5, 3, 70, null, 0.75], [3620, 720, 0, 4, 56, null, 0.6],
      [3150, 960, 4, 5, 60, 'lava', 0.7], [2800, 1080, 1, 0, 50, null, 0.5],
    ];
    for (const [x, y, ci, k, s, fin, a] of falls) piece(shapes[k], ci, x, y, s, fin, a);
  },
  // Library logo: the two-line block logo, 1280 px wide on transparency, with an ink rim so it reads on
  // any part of the hero. Cropped to its height by capsulePNG.
  lib_logo() {
    const a = glyphs('BLOCK', true), b = glyphs('MANIA', true);
    const cell = Math.floor((W - 40) / Math.max(a.w, b.w)), gap = Math.round(cell * 2.2);
    const rim = Math.max(4, Math.round(cell / 5));
    const cx = W / 2 - 6;
    const top = 30;
    // Ink rim under every block of both lines.
    for (const [str, t] of [['BLOCK', top], ['MANIA', top + a.h * cell + gap]]) {
      const g = glyphs(str, true);
      const x0 = Math.round(cx - (g.w * cell) / 2);
      ctx.fillStyle = PAL.ink;
      for (const c of g.cells) ctx.fillRect(x0 + c.x * cell - rim, t + c.y * cell - rim, cell + 2 * rim, cell + 2 * rim);
    }
    logo2(cx, top, cell, gap);
  },
};
const BG_OPTS = {
  header: { swirl: 2.4, focusX: 0.5 }, small: { swirl: 2.2, dark: 0.85 }, main: { swirl: 2.4, focusX: 0.4 },
  vertical: { swirl: 2.6 }, background: { swirl: 2.0, dark: 0.7 },
  lib_capsule: { swirl: 2.6 }, lib_header: { swirl: 2.4, focusX: 0.5 }, lib_hero: { swirl: 2.4, focusX: 0.5 },
};

function renderCapsule() {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, W, H);
  LAYOUTS[CAP]();
  if (CAP === 'lib_logo') return; // transparent: exported straight from the content layer
  const bg = bgp('plum', BG_OPTS[CAP]);
  bg.px = Math.max(2, Math.round(W / 320));
  const small = CAP === 'small';
  present(4.2, bg, {
    sx: 0, sy: 0, zoom: 1, shock: 0, flash: 0, glitch: 0, collapse: 0,
    warp: 0, scan: small ? 0 : 0.07, vig: CAP === 'background' ? 0.4 : 0.22, grain: small ? 0 : 0.01, abr: small ? 0 : 0.45,
  });
}

window.READY = loadAll().then(() => document.fonts.load(CJK_FONT, '方块')).then(() => {
  const cv = document.getElementById('out');
  cv.width = W; cv.height = H;
  initGL(cv);
  renderCapsule();
  return true;
});
window.capsulePNG = () => {
  if (CAP !== 'lib_logo') return document.getElementById('out').toDataURL('image/png');
  // The logo keeps the full 1280 px width and is cropped to the rows it uses.
  const d = ctx.getImageData(0, 0, W, H).data;
  let y0 = H, y1 = -1;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (d[(y * W + x) * 4 + 3]) { y0 = Math.min(y0, y); y1 = y; break; }
  const cv = document.createElement('canvas');
  cv.width = W; cv.height = y1 - y0 + 1;
  cv.getContext('2d').drawImage(layer, 0, -y0);
  return cv.toDataURL('image/png');
};
