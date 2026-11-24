import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { decodeFragment, openAppUrl, FragmentError } from '../../docs/site/fragment.js';

const gz = async (bytes) => Buffer.from(await new Response(new Blob([bytes]).stream().pipeThrough(new CompressionStream('gzip'))).arrayBuffer());
const b64u = (b) => b.toString('base64url');
const enc = async (text) => b64u(await gz(Buffer.from(text, 'utf8')));
const ID1 = 'dQw4w9WgXcQ', ID2 = 'a-b_c1234Zz';

test('roundtrip, with and without padding and leading #', async () => {
  const f = await enc(`FK1\np\nÈ Mix ✓\n${ID1}${ID2}`);
  const want = { kind: 'p', title: 'È Mix ✓', ids: [ID1, ID2] };
  assert.deepEqual(await decodeFragment(f), want);
  assert.deepEqual(await decodeFragment('#' + f), want);
  assert.deepEqual(await decodeFragment(f + '='.repeat((4 - (f.length % 4)) % 4)), want);
});

test('rejects invalid payloads', async () => {
  for (const t of [
    `FK2\nt\nx\n${ID1}`, `FK1\nx\nx\n${ID1}`, `FK1\nt\n\n${ID1}`, `FK1\nt\n  \n${ID1}`, `FK1\nt\n${'x'.repeat(121)}\n${ID1}`, `FK1\nt\nx\n${ID1.slice(0, 5)}\n${ID1.slice(5)}`, `FK1\nt\nx\n${ID1}abc`,
    `FK1\nt\nx\n`, `FK1\nt\nx\nabc!efghijk`, `FK1\nt\nx\n${ID1}\nextra`,
    `FK1\nt\nx\n${ID1.repeat(51)}`,
  ]) await assert.rejects(decodeFragment(await enc(t)), t);
  await assert.doesNotReject(decodeFragment(await enc(`FK1\nt\nx\n${ID1.repeat(50)}`)));
});

test('rejects corrupt, truncated, oversized and non-utf8 input', async () => {
  const f = await enc(`FK1\nt\nx\n${ID1}`);
  for (const bad of ['', '#', 'a', '!!!', f.slice(0, f.length - 6), f.slice(0, 8), 'A'.repeat(40)])
    await assert.rejects(decodeFragment(bad), bad);
  await assert.rejects(decodeFragment(b64u(await gz(Buffer.alloc(70000, 65)))));
  await assert.rejects(decodeFragment(b64u(await gz(Buffer.from([0x46, 0x4b, 0x31, 0x0a, 0xff, 0xfe, 0x0a, 0x0a])))));
});

test('title limit counts code points; kind is exactly one of t, a, p', async () => {
  for (const t of ['x'.repeat(120), '🎵'.repeat(61), '🎵'.repeat(120)]) await assert.doesNotReject(decodeFragment(await enc(`FK1\nt\n${t}\n${ID1}`)));
  for (const t of ['🎵'.repeat(121), 'x'.repeat(121)]) await assert.rejects(decodeFragment(await enc(`FK1\nt\n${t}\n${ID1}`)));
  for (const k of ['ta', 't ', '', 'T']) await assert.rejects(decodeFragment(await enc(`FK1\n${k}\nx\n${ID1}`)), k);
  await assert.rejects(decodeFragment(b64u(await gz(Buffer.concat([Buffer.from('FK1\nt\nab'), Buffer.from([0xff]), Buffer.from(`\n${ID1}`)])))));
});

test('malformed base64url wrapper and 64 KB boundary', async () => {
  const f = await enc(`FK1\nt\nx\n${ID1}`);
  for (const bad of ['##' + f, f + '!', f + '===', f + '%3D', f + '?x=1', f + ' x']) await assert.rejects(decodeFragment(bad), bad);
  // Neither payload is valid; only the reason tells the limit apart.
  await assert.rejects(decodeFragment(b64u(await gz(Buffer.alloc(65536, 65)))), /header/);
  await assert.rejects(decodeFragment(b64u(await gz(Buffer.alloc(65537, 65)))), /too big/);
});

test('errors are typed, bomb of ~200 MB is cut quickly', async () => {
  await assert.rejects(decodeFragment('!!!'), FragmentError);
  await assert.rejects(decodeFragment('AAAA'), FragmentError);
  const bomb = b64u(await gz(Buffer.alloc(200 * 1024 * 1024, 65)));
  const t0 = Date.now();
  await assert.rejects(decodeFragment(bomb), FragmentError);
  assert.ok(Date.now() - t0 < 2000, 'bomb took too long');
});

test('openAppUrl: intent on Android, null elsewhere or with odd characters', () => {
  const ua = 'Mozilla/5.0 (Linux; Android 14; Pixel 8)';
  const u = openAppUrl('#abc-_=', ua);
  assert.ok(u.startsWith('intent://itzemany.github.io/FreeKmusic/#abc-_=#Intent;scheme=https;package=com.freekmusic.player;'));
  assert.ok(u.endsWith(';S.browser_fallback_url=' + encodeURIComponent('https://github.com/iTzEmany/FreeKmusic/releases/latest') + ';end'));
  assert.equal(openAppUrl('#abc', 'Mozilla/5.0 (X11; Linux x86_64)'), null);
  for (const bad of ['#a;b', '#a#Intent', '#a b', '#', '']) assert.equal(openAppUrl(bad, ua), null, bad);
});

test('shared vectors (positive and negative)', () => {
  const v = JSON.parse(readFileSync(new URL('../services/share/fragment_vectors.json', import.meta.url), 'utf8'));
  assert.ok(v.length > 0);
  return Promise.all(v.map(async (c) => {
    if (c.error) await assert.rejects(decodeFragment(c.fragment), c.name);
    else assert.deepEqual(await decodeFragment(c.fragment), { kind: c.kind, title: c.title, ids: c.ids });
  }));
});
