import { chromium } from 'playwright-core';
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.dirname(fileURLToPath(import.meta.url));
const exe = process.env.CHROME_PATH || path.join(homedir(), 'Library/Caches/ms-playwright/chromium-1254/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing');
const fps = Number(process.env.FPS || 30);
const args = process.argv.slice(2);
const stillsArg = args.find(a => a.startsWith('--stills='));
const out = path.join(dir, 'out');
mkdirSync(out, { recursive: true });

const browser = await chromium.launch({ executablePath: exe, args: ['--allow-file-access-from-files', '--font-render-hinting=none'] });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
page.on('pageerror', e => console.error('page error:', e.message));
await page.goto('file://' + path.join(dir, 'index.html'));
await page.evaluate(() => window.ready);
const duration = await page.evaluate(() => window.DURATION);

if (stillsArg) {
  for (const t of stillsArg.split('=')[1].split(',').map(Number)) {
    await page.evaluate(t => window.render(t), t);
    writeFileSync(path.join(out, `still-${t.toFixed(2)}.png`), await page.screenshot());
  }
} else {
  const total = Math.round(duration * fps);
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-i', '-',
    '-i', path.join(out, 'audio.wav'), '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', path.join(dir, 'knurlink-demo.mp4')], { stdio: ['pipe', 'inherit', 'inherit'] });
  for (let f = 0; f < total; f++) {
    await page.evaluate(t => window.render(t), f / fps);
    const buf = await page.screenshot({ type: 'jpeg', quality: 95 });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if (f % 150 === 0) console.log(`frame ${f}/${total}`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  console.log('wrote knurlink-demo.mp4');
}
await browser.close();
