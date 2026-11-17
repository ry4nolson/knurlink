import { writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.dirname(fileURLToPath(import.meta.url));
const SR = 44100;
const DUR = 56.5;
const N = Math.ceil(SR * DUR);
const music = new Float32Array(N);
const sfx = new Float32Array(N);
const TAU = Math.PI * 2;

let seed = 7;
const rand = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const mtof = m => 440 * Math.pow(2, (m - 69) / 12);

function add(buf, t0, len, fn) {
  const s0 = Math.floor(t0 * SR), n = Math.floor(len * SR);
  for (let i = 0; i < n; i++) {
    const j = s0 + i;
    if (j < 0 || j >= N) continue;
    buf[j] += fn(i / SR, i);
  }
}

function marimba(buf, t0, m, vel = 1) {
  const f = mtof(m);
  add(buf, t0, 0.6, t => vel * Math.min(1, t * 400) * (Math.sin(TAU * f * t) * Math.exp(-t * 9) + 0.35 * Math.sin(TAU * f * 4 * t) * Math.exp(-t * 30)));
}
function glock(buf, t0, m, vel = 1) {
  const f = mtof(m);
  add(buf, t0, 1.2, t => vel * Math.min(1, t * 600) * (Math.sin(TAU * f * t) * Math.exp(-t * 4) + 0.25 * Math.sin(TAU * f * 2.76 * t) * Math.exp(-t * 9)));
}
function bass(buf, t0, m, len = 0.4, vel = 1) {
  const f = mtof(m);
  add(buf, t0, len + 0.1, t => vel * Math.min(1, t * 200) * Math.exp(-t * 4) * (Math.sin(TAU * f * t) + 0.3 * Math.sin(TAU * 2 * f * t)) * (t < len ? 1 : Math.max(0, 1 - (t - len) * 10)));
}
function kick(buf, t0, vel = 1) {
  add(buf, t0, 0.25, t => vel * Math.sin(TAU * (50 * t + 90 * (1 - Math.exp(-t * 30)) / 30)) * Math.exp(-t * 14));
}
function shaker(buf, t0, vel = 1) {
  let lp = 0;
  add(buf, t0, 0.08, t => { const n = rand() * 2 - 1; lp += 0.5 * (n - lp); return vel * (n - lp) * Math.exp(-t * 60); });
}

function click(t0, v = 0.5) {
  add(sfx, t0, 0.03, t => v * ((rand() * 2 - 1) * Math.exp(-t * 400) + Math.sin(TAU * 2400 * t) * Math.exp(-t * 200) * 0.6));
}
function bloop(t0, f0 = 320, f1 = 900, v = 0.45, len = 0.16) {
  let ph = 0;
  add(sfx, t0, len, t => { const f = f0 + (f1 - f0) * Math.min(1, t / (len * 0.5)); ph += TAU * f / SR; return v * Math.sin(ph) * Math.min(1, t * 300) * Math.exp(-t * 18); });
}
function whoosh(t0, len = 0.45, v = 0.35) {
  let lp = 0, lp2 = 0;
  add(sfx, t0, len, t => {
    const p = t / len, a = 0.04 + 0.4 * Math.sin(Math.PI * p);
    const n = rand() * 2 - 1; lp += a * (n - lp); lp2 += 0.3 * (lp - lp2);
    return v * 2.2 * (lp - lp2 * 0.5) * Math.sin(Math.PI * p);
  });
}
function boing(t0, f = 160, v = 0.4, len = 0.5) {
  let ph = 0;
  add(sfx, t0, len, t => { const fr = f * (1 + 0.6 * t) + 40 * Math.sin(TAU * 16 * t) * Math.exp(-t * 5); ph += TAU * fr / SR; return v * Math.sin(ph) * Math.min(1, t * 200) * Math.exp(-t * 5); });
}
function ding(t0, v = 0.35) {
  add(sfx, t0, 1.4, t => v * Math.min(1, t * 800) * (Math.sin(TAU * 1568 * t) * Math.exp(-t * 3.5) + 0.5 * Math.sin(TAU * 2349 * t) * Math.exp(-t * 5) + 0.25 * Math.sin(TAU * 4186 * t) * Math.exp(-t * 9)));
}
function sparkle(t0, count = 8, v = 0.18) {
  for (let i = 0; i < count; i++) {
    const f = 2000 + rand() * 2500, at = t0 + i * 0.045 + rand() * 0.03;
    add(sfx, at, 0.3, t => v * Math.sin(TAU * f * t) * Math.min(1, t * 1000) * Math.exp(-t * 16));
  }
}
function keyThock(t0, v = 0.5) {
  let lp = 0;
  add(sfx, t0, 0.07, t => { const n = rand() * 2 - 1; lp += 0.25 * (n - lp); return v * (lp * Math.exp(-t * 90) * 2 + 0.6 * Math.sin(TAU * 180 * t) * Math.exp(-t * 60)); });
}
function slideWhistle(t0, f0, f1, len, v = 0.25) {
  let ph = 0;
  add(sfx, t0, len, t => { const p = t / len; const f = f0 * Math.pow(f1 / f0, p) * (1 + 0.012 * Math.sin(TAU * 6 * t)); ph += TAU * f / SR; return v * Math.sin(ph) * Math.min(1, t * 60) * Math.min(1, (len - t) * 20); });
}
function buzz(t0, v = 0.2) {
  add(sfx, t0, 0.12, t => v * (Math.sin(TAU * 110 * t) > 0 ? 1 : -1) * Math.exp(-t * 10));
  add(sfx, t0 + 0.15, 0.12, t => v * (Math.sin(TAU * 98 * t) > 0 ? 1 : -1) * Math.exp(-t * 10));
}
function brass(t0, notes, len, v = 0.16) {
  for (const m of notes) {
    const f = mtof(m);
    let ph = 0;
    add(sfx, t0, len, t => {
      ph += TAU * f * (1 + 0.004 * Math.sin(TAU * 5.5 * t)) / SR;
      const env = Math.min(1, t * 25) * Math.min(1, (len - t) * 6);
      const br = 0.35 + 0.4 * Math.min(1, t * 8);
      let s = 0; for (let k = 1; k <= 8; k++) s += Math.pow(br, k - 1) * Math.sin(ph * k) / k;
      return v * env * s;
    });
  }
}
function trombone(t0, m, len, v = 0.3, wobble = false) {
  const f0 = mtof(m);
  let ph = 0;
  add(sfx, t0, len, t => {
    const vib = wobble ? 1 + 0.03 * Math.sin(TAU * 5 * t) * Math.min(1, t * 2) : 1;
    const bend = wobble ? Math.pow(2, -0.6 * Math.max(0, t - 0.3) / 12) : 1;
    ph += TAU * f0 * vib * bend / SR;
    const wah = 0.25 + 0.55 * Math.sin(Math.PI * Math.min(1, t / Math.min(len, 0.45)));
    const env = Math.min(1, t * 20) * Math.min(1, (len - t) * 8);
    let s = 0; for (let k = 1; k <= 10; k++) s += Math.pow(wah, k - 1) * Math.sin(ph * k) / k;
    return v * env * s;
  });
}
function rewindTape(t0, len) {
  let ph = 0;
  add(sfx, t0, len, t => {
    const cyc = (t * 3.2) % 1;
    const f = 300 + 1700 * cyc * cyc;
    ph += TAU * f / SR;
    const saw = 2 * ((ph / TAU) % 1) - 1;
    return 0.12 * saw * Math.min(1, t * 20) * Math.min(1, (len - t) * 20) + 0.05 * (rand() * 2 - 1);
  });
}

const BPM = 124, beat = 60 / BPM, bar = beat * 4;
const chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]];
const roots = [36, 33, 29, 31];
const arp = [0, 1, 2, 1, 0, 2, 1, 2];
const melody = [
  [72, 0, 1], [74, 1, 0.5], [76, 1.5, 1.5], [79, 3, 1],
  [76, 4, 1], [74, 5, 1], [72, 6, 2],
  [69, 8, 1], [72, 9, 0.5], [74, 9.5, 1.5], [77, 11, 1],
  [79, 12, 1.5], [77, 13.5, 0.5], [76, 14, 1], [74, 15, 1],
];

function playMusic(from, to, startBar = 0, withMelody = true) {
  for (let b = 0; ; b++) {
    const bt = from + b * bar;
    if (bt >= to) break;
    const ci = (b + startBar) % 4;
    const ch = chords[ci];
    for (let i = 0; i < 8; i++) {
      const t = bt + i * beat / 2;
      if (t >= to) break;
      const n = ch[arp[i]] + 12;
      marimba(music, t, n, i % 2 ? 0.22 : 0.3);
      shaker(music, t + beat / 4, i % 2 ? 0.05 : 0.03);
    }
    for (let k = 0; k < 4; k++) {
      const t = bt + k * beat;
      if (t >= to) break;
      if (k % 2 === 0) kick(music, t, 0.5);
      bass(music, t, roots[ci] + (k === 3 ? 7 : 0), beat * 0.8, 0.45);
    }
    if (withMelody && (b + startBar) % 8 >= 4) {
      const phraseStart = from + (b - ((b + startBar) % 4)) * bar;
      for (const [m, at, d] of melody) {
        const nt = phraseStart + at * beat;
        if (nt >= bt && nt < bt + bar && nt < to) glock(music, nt, m, 0.16);
      }
    }
  }
}

playMusic(0.0, 10.8, 0, false);
playMusic(14.3, 55.4, 0, true);
brass(14.25, [60, 64, 67, 72], 1.1, 0.07);

boing(0.62, 150, 0.45);
for (let i = 0; i < 8; i++) bloop(1.0 + i * 0.08, 500 + i * 60, 900 + i * 90, 0.2, 0.1);
[0, 1, 2].forEach(i => bloop(2.05 + i * 0.09, 700 + i * 150, 1400 + i * 200, 0.28, 0.14));
sparkle(2.8, 6, 0.12);
whoosh(4.6, 0.6, 0.35);
bloop(5.6, 400, 700, 0.3); bloop(6.2, 450, 800, 0.3);
click(7.6); whoosh(7.7, 0.5); boing(8.1, 220, 0.25, 0.3);
slideWhistle(9.8, 500, 1100, 0.45, 0.18);
trombone(10.9, 62, 0.42); trombone(11.35, 61, 0.42); trombone(11.8, 60, 0.42); trombone(12.25, 59, 1.0, 0.3, true);
rewindTape(12.9, 1.0);
sparkle(14.2, 12, 0.15);
whoosh(15.15, 0.4, 0.2);
click(16.35); sparkle(16.45, 10, 0.14);
click(17.9);
[0, 1, 2, 3, 4].forEach(i => bloop(17.97 + i * 0.03, 350 + i * 80, 900 + i * 120, 0.18, 0.14));
[19.3, 19.9].forEach(t => click(t, 0.18));
click(20.7); whoosh(20.78, 0.5); boing(21.2, 240, 0.22, 0.3); sparkle(21.45, 12, 0.15);
click(23.4); [0, 1, 2, 3, 4].forEach(i => bloop(23.47 + i * 0.03, 350 + i * 80, 900 + i * 120, 0.16, 0.14));
keyThock(24.55); click(24.62, 0.2);
keyThock(25.33); whoosh(25.5, 0.45);
ding(26.2, 0.3);
whoosh(27.35, 0.6, 0.3);
for (const [T, miss] of [[28.4, false], [30.4, false], [32.4, false], [34.4, true]]) {
  whoosh(T, 0.35, 0.18);
  if (miss) { buzz(T + 0.55); bloop(T + 1.25, 600, 1200, 0.25, 0.12); whoosh(T + 1.6, 0.45, 0.22); boing(T + 2.05, 200, 0.3, 0.4); }
  else { bloop(T + 0.55, 600, 1200, 0.25, 0.12); whoosh(T + 1.1, 0.45, 0.22); boing(T + 1.55, 200, 0.3, 0.4); }
}
whoosh(37.3, 0.4, 0.25);
[0, 1, 2, 3, 4].forEach(i => bloop(37.77 + i * 0.03, 350 + i * 80, 900 + i * 120, 0.16, 0.14));
keyThock(38.4, 0.6);
slideWhistle(38.9, 1400, 450, 0.6, 0.2);
brass(39.5, [67, 71, 74], 0.5, 0.08); sparkle(39.5, 12, 0.14);
bloop(42.5, 900, 300, 0.2, 0.18);
[0, 1, 2, 3, 4, 5].forEach(i => bloop(42.97 + i * 0.03, 350 + i * 80, 900 + i * 120, 0.15, 0.14));
click(44.1, 0.3);
[44.55, 44.8].forEach(t => click(t, 0.12));
click(45.0); boing(45.35, 240, 0.22, 0.3); sparkle(45.5, 8, 0.12);
[47.2, 47.45, 47.7].forEach((t, i) => bloop(t, 300 + i * 100, 800 + i * 150, 0.28, 0.16));
for (let i = 0; i < 12; i++) click(47.8 + i * 0.065, 0.08);
click(48.4, 0.3); ding(48.9, 0.15);
whoosh(50.1, 0.5, 0.3);
boing(50.75, 150, 0.4);
for (let i = 0; i < 8; i++) bloop(51.0 + i * 0.06, 500 + i * 60, 900 + i * 90, 0.18, 0.1);
sparkle(51.0, 16, 0.15);
brass(52.0, [60, 64, 67, 72], 1.6, 0.06);
glock(sfx, 53.3, 84, 0.2); glock(sfx, 53.45, 88, 0.2); glock(sfx, 53.6, 91, 0.2);

const out = new Int16Array(N * 2);
let peak = 0;
const mix = new Float32Array(N);
for (let i = 0; i < N; i++) {
  const t = i / SR;
  const fade = Math.min(1, Math.max(0, (DUR - 0.3 - t) / 1.8));
  mix[i] = (music[i] * 0.55 + sfx[i]) * fade;
  peak = Math.max(peak, Math.abs(mix[i]));
}
const g = 0.89 / peak;
for (let i = 0; i < N; i++) {
  const s = Math.tanh(mix[i] * g * 1.1) / Math.tanh(1.1);
  const v = Math.round(s * 32000);
  out[i * 2] = v; out[i * 2 + 1] = v;
}

const header = Buffer.alloc(44);
header.write('RIFF', 0); header.writeUInt32LE(36 + out.byteLength, 4); header.write('WAVE', 8);
header.write('fmt ', 12); header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(2, 22);
header.writeUInt32LE(SR, 24); header.writeUInt32LE(SR * 4, 28); header.writeUInt16LE(4, 32); header.writeUInt16LE(16, 34);
header.write('data', 36); header.writeUInt32LE(out.byteLength, 40);
mkdirSync(path.join(dir, 'out'), { recursive: true });
writeFileSync(path.join(dir, 'out', 'audio.wav'), Buffer.concat([header, Buffer.from(out.buffer)]));
console.log('wrote out/audio.wav');
