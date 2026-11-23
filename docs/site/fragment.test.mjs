import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { decodeFragment } from './fragment.js';

const gz = async (bytes) => Buffer.from(await new Response(new Blob([bytes]).stream().pipeThrough(new CompressionStream('gzip'))).arrayBuffer());
const b64u = (b) => b.toString('base64url');
const enc = async (text) => b64u(await gz(Buffer.from(text, 'utf8')));
const ID1 = 'dQw4w9WgXcQ', ID2 = 'a-b_c1234Zz';

test('roundtrip, with and without padding and leading #', async () => {
  const f = await enc(`FK1\np\nÈ Mix ✓\n${ID1}${ID2}`);
  const want = { type: 'p', title: 'È Mix ✓', ids: [ID1, ID2] };
  assert.deepEqual(await decodeFragment(f), want);
  assert.deepEqual(await decodeFragment('#' + f), want);
  assert.deepEqual(await decodeFragment(f + '='.repeat((4 - (f.length % 4)) % 4)), want);
});

test('rejects invalid payloads', async () => {
  for (const t of [
    `FK2\nt\nx\n${ID1}`, `FK1\nx\nx\n${ID1}`, `FK1\nt\n\n${ID1}`, `FK1\nt\nx\n${ID1}abc`,
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

test('Dart vectors, when present', async (t) => {
  const p = new URL('../../test/services/share/fragment_vectors.json', import.meta.url);
  if (!existsSync(p)) return t.skip('no vectors yet');
  const v = JSON.parse(readFileSync(p, 'utf8'));
  for (const c of Array.isArray(v) ? v : (v.vectors ?? [])) {
    const frag = c.fragment ?? c.frag;
    if (c.valid === false || c.error) await assert.rejects(decodeFragment(frag), frag);
    else await decodeFragment(frag);
  }
});
