// BLOCKMANIA trailer renderer: serves the repo, drives trailer.html in headless Chrome and
// pipes frames to ffmpeg. Frames are pure functions of time, so workers render chunks in parallel.
//
//   node render.mjs cues                      -> build/cues.json (for gen_score.py)
//   node render.mjs stills 0.5 3.1 ...        -> build/stills/t_XXX.png
//   node render.mjs sheet [fps]               -> build/sheet_*.png contact sheets (default 2 fps)
//   node render.mjs video [workers] [draft]   -> build/trailer_silent.mp4, then muxed with build/score.wav
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const OUT = path.join(HERE, 'build');
fs.mkdirSync(OUT, { recursive: true });
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const FPS = 60, DUR = 64;

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.json': 'application/json', '.ttf': 'font/ttf', '.wav': 'audio/wav' };
function serve() {
  return new Promise((res) => {
    const srv = http.createServer((req, rsp) => {
      const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
      if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { rsp.writeHead(404); rsp.end(); return; }
      rsp.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' });
      fs.createReadStream(p).pipe(rsp);
    });
    srv.listen(0, '127.0.0.1', () => res(srv));
  });
}

async function openPage(browser, port) {
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
  page.on('console', (m) => { if (m.type() === 'error') console.error('[page]', m.text()); });
  page.on('pageerror', (e) => console.error('[pageerror]', e.message));
  await page.goto(`http://127.0.0.1:${port}/tools/trailer/trailer.html?capture=1`, { waitUntil: 'load' });
  await page.evaluate(() => window.READY);
  return page;
}
async function frame(page, t, type) {
  const url = await page.evaluate((tt, ty) => window.frameData(tt, ty), t, type);
  return Buffer.from(url.slice(url.indexOf(',') + 1), 'base64');
}
function launch() {
  return puppeteer.launch({
    executablePath: CHROME, headless: 'new',
    args: ['--ignore-gpu-blocklist', '--enable-gpu', '--use-angle=d3d11', '--enable-webgl', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--force-color-profile=srgb'],
  });
}
function run(cmd, args, opts = {}) {
  return new Promise((res, rej) => {
    const p = spawn(cmd, args, { stdio: opts.stdin ? ['pipe', 'ignore', 'inherit'] : ['ignore', 'ignore', 'inherit'] });
    p.on('exit', (c) => (c === 0 ? res() : rej(new Error(cmd + ' exited ' + c))));
    if (opts.stdin) opts.stdin(p);
  });
}

const [mode = 'sheet', ...rest] = process.argv.slice(2);
const srv = await serve();
const port = srv.address().port;
const browser = await launch();
try {
  if (mode === 'cues') {
    const page = await openPage(browser, port);
    fs.writeFileSync(path.join(OUT, 'cues.json'), await page.evaluate(() => window.CUES_JSON));
    console.log('wrote build/cues.json');
  } else if (mode === 'stills') {
    const page = await openPage(browser, port);
    fs.mkdirSync(path.join(OUT, 'stills'), { recursive: true });
    for (const s of rest) {
      const t = +s;
      fs.writeFileSync(path.join(OUT, 'stills', `t_${t.toFixed(2)}.png`), await frame(page, t, 'image/png'));
    }
    console.log('stills done');
  } else if (mode === 'sheet') {
    // contact sheets: 4x4 thumbnails of 480x270 per sheet
    const fps = +(rest[0] || 2), from = +(rest[1] || 0), to = +(rest[2] || DUR);
    const page = await openPage(browser, port);
    const times = [];
    for (let t = from; t < to - 1e-6; t += 1 / fps) times.push(+t.toFixed(4));
    const dir = path.join(OUT, 'sheet_frames'); fs.rmSync(dir, { recursive: true, force: true }); fs.mkdirSync(dir, { recursive: true });
    let i = 0;
    for (const t of times) fs.writeFileSync(path.join(dir, `f_${String(i++).padStart(4, '0')}.jpg`), await frame(page, t, 'image/jpeg'));
    await run('python', [path.join(HERE, 'sheet.py'), String(fps), String(from)]);
    console.log(`sheets for ${times.length} frames`);
  } else if (mode === 'video') {
    const workers = +(rest[0] || 6);
    const draft = rest[1] === 'draft';
    const from = +(rest[2] || 0), to = +(rest[3] || DUR);
    const total = Math.round((to - from) * FPS);
    const per = Math.ceil(total / workers);
    const t0 = Date.now();
    let done = 0;
    await Promise.all(Array.from({ length: workers }, async (_, w) => {
      const a = w * per, b = Math.min(total, a + per);
      if (a >= b) return;
      const page = await openPage(browser, port);
      const file = path.join(OUT, `chunk_${String(w).padStart(2, '0')}.mkv`);
      await run('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', draft ? 'mjpeg' : 'png', '-i', '-',
        '-c:v', 'libx264', '-preset', draft ? 'veryfast' : 'medium', '-crf', draft ? '20' : '8', '-pix_fmt', 'yuv420p', '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', file], {
        stdin: async (p) => {
          for (let f = a; f < b; f++) {
            const buf = await frame(page, from + f / FPS, draft ? 'image/jpeg' : 'image/png');
            if (!p.stdin.write(buf)) await new Promise((r) => p.stdin.once('drain', r));
            done++;
            if (done % 120 === 0) console.log(`${done}/${total} frames, ${((Date.now() - t0) / 1000).toFixed(0)}s`);
          }
          p.stdin.end();
        },
      });
    }));
    const list = fs.readdirSync(OUT).filter((f) => f.startsWith('chunk_')).sort().map((f) => `file '${path.join(OUT, f).replace(/\\/g, '/')}'`).join('\n');
    fs.writeFileSync(path.join(OUT, 'chunks.txt'), list);
    await run('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', path.join(OUT, 'chunks.txt'), '-c', 'copy', path.join(OUT, 'trailer_silent.mkv')]);
    for (const f of fs.readdirSync(OUT)) if (f.startsWith('chunk_')) fs.rmSync(path.join(OUT, f));
    console.log(`video frames done in ${((Date.now() - t0) / 1000).toFixed(0)}s`);
  }
} finally {
  await browser.close();
  srv.close();
}
