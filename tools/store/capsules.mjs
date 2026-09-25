// Renders the Steam capsules (tools/store/capsules.html) to store/steam/capsules/.
// Uses the trailer's puppeteer-core install:   cd tools/trailer && npm install   (once)
//
//   node tools/store/capsules.mjs            -> every capsule in english, spanish and schinese + page background
//   node tools/store/capsules.mjs main small -> only those capsules
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const require = createRequire(path.join(ROOT, 'tools/trailer/package.json'));
const puppeteer = require('puppeteer-core');
const OUT = path.join(ROOT, 'store/steam/capsules');
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const LANGS = ['english', 'spanish', 'schinese'];
const CAPS = { header: 'capsule_header', small: 'capsule_small', main: 'capsule_main', vertical: 'capsule_vertical' };
const SIZES = { header: [920, 430], small: [462, 174], main: [1232, 706], vertical: [748, 896], background: [1438, 810] };
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.jpg': 'image/jpeg', '.json': 'application/json', '.ttf': 'font/ttf' };

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

const want = process.argv.slice(2);
const jobs = [];
for (const [cap, name] of Object.entries(CAPS)) if (!want.length || want.includes(cap)) for (const lang of LANGS) jobs.push([cap, lang, `${name}_${lang}.png`]);
if (!want.length || want.includes('background')) jobs.push(['background', 'english', 'page_background.png']);

fs.mkdirSync(OUT, { recursive: true });
const srv = await serve();
const browser = await puppeteer.launch({
  executablePath: CHROME, headless: 'new',
  args: ['--ignore-gpu-blocklist', '--enable-gpu', '--use-angle=d3d11', '--enable-webgl', '--force-color-profile=srgb'],
});
try {
  for (const [cap, lang, file] of jobs) {
    const page = await browser.newPage();
    const [w, h] = SIZES[cap];
    await page.setViewport({ width: w, height: h, deviceScaleFactor: 1 });
    page.on('pageerror', (e) => console.error('[pageerror]', e.message));
    page.on('console', (m) => { if (m.type() === 'error') console.error('[page]', m.text()); });
    await page.goto(`http://127.0.0.1:${srv.address().port}/tools/store/capsules.html?cap=${cap}&lang=${lang}`, { waitUntil: 'load' });
    await page.evaluate(() => window.READY);
    const url = await page.evaluate(() => window.capsulePNG());
    fs.writeFileSync(path.join(OUT, file), Buffer.from(url.slice(url.indexOf(',') + 1), 'base64'));
    console.log(file, `${w}x${h}`);
    await page.close();
  }
} finally {
  await browser.close();
  srv.close();
}
