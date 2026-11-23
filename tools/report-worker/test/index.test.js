import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import worker, { __test } from '../src/index.js';

const env = { GITHUB_TOKEN: 't0k', GITHUB_REPO: 'o/r' };
const realFetch = globalThis.fetch;
let calls;
let ghStatus;
let n = 0;

beforeEach(() => {
  __test.reset(); // module state is shared: every test starts clean, whatever the order
  calls = [];
  ghStatus = 201;
  globalThis.fetch = async (url, init) => {
    calls.push({ url, init });
    return new Response(JSON.stringify({ html_url: 'https://github.com/o/r/issues/1' }), { status: ghStatus });
  };
});
afterEach(() => { globalThis.fetch = realFetch; });

const ip = () => `10.0.${Math.floor(++n / 250)}.${n % 250}`;
const send = (body, { method = 'POST', addr = ip(), type = 'application/json', extra = {}, length } = {}) => {
  const text = method === 'GET' ? undefined : typeof body === 'string' ? body : JSON.stringify(body);
  const headers = { 'x-forwarded-for': addr ?? '', ...extra };
  if (addr) headers['cf-connecting-ip'] = addr;
  if (type) headers['content-type'] = type;
  if (text !== undefined && length !== null) headers['content-length'] = String(length ?? Buffer.byteLength(text));
  return worker.fetch(new Request('https://w.test/', { method, headers, body: text }), env);
};
const ok = { title: 't', body: 'b', version: '1.0' };

test('valid report creates a labelled issue without the client IP', async () => {
  const addr = ip();
  const res = await send(ok, { addr });
  assert.equal(res.status, 201);
  assert.deepEqual(await res.json(), { url: 'https://github.com/o/r/issues/1' });
  const { url, init } = calls[0];
  assert.equal(url, 'https://api.github.com/repos/o/r/issues');
  assert.equal(init.headers.Authorization, 'Bearer t0k');
  assert.deepEqual(JSON.parse(init.body).labels, ['da-triage']);
  assert.ok(!JSON.stringify(init).includes(addr));
});

test('malformed json and oversize fields are 400', async () => {
  assert.equal((await send('{nope')).status, 400);
  assert.equal((await send({ ...ok, title: 'x'.repeat(121) })).status, 400);
  assert.equal((await send({ ...ok, body: 'x'.repeat(20001) })).status, 400);
  assert.equal((await send({ ...ok, version: 5 })).status, 400);
  assert.equal(calls.length, 0);
});

test('GET is 405', async () => {
  assert.equal((await send(null, { method: 'GET' })).status, 405);
});

test('6th report from the same IP in an hour is 429', async () => {
  const addr = ip();
  for (let i = 0; i < 5; i++) assert.equal((await send(ok, { addr })).status, 201);
  assert.equal((await send(ok, { addr })).status, 429);
});

test('GitHub failure is 502', async () => {
  ghStatus = 500;
  assert.equal((await send(ok)).status, 502);
});

const sentBody = () => JSON.parse(calls[0].init.body);

test('body over 32 KB is 413 without calling GitHub; missing content-length too', async () => {
  const big = JSON.stringify({ ...ok, body: 'x'.repeat(40000) });
  assert.equal((await send(big)).status, 413);
  assert.equal((await send(ok, { length: null })).status, 413);
  assert.equal(calls.length, 0);
});

test('wrong content-type is 415', async () => {
  assert.equal((await send(ok, { type: 'text/plain' })).status, 415);
  assert.equal((await send(ok, { type: null })).status, 415);
  assert.equal(calls.length, 0);
});

test('mentions are neutralised with a zero-width space', async () => {
  await send({ ...ok, title: 'hi @octocat', body: 'ping @octocat and @org/team' });
  const sent = sentBody();
  assert.ok(!/@(?!\u200b)/.test(sent.title + sent.body));
  assert.ok(sent.body.includes('@\u200boctocat'));
});

test('title is normalised; whitespace-only title is 400', async () => {
  await send({ ...ok, title: '  a\n\tb   c ' });
  assert.equal(sentBody().title, 'a b c');
  assert.equal((await send({ ...ok, title: ' \n ' })).status, 400);
});

test('version must match the allowed pattern', async () => {
  assert.equal((await send({ ...ok, version: '1.0\n## x' })).status, 400);
  assert.equal((await send({ ...ok, version: '' })).status, 400);
  assert.equal(calls.length, 0);
});

test('json null, array and number are 400', async () => {
  for (const v of ['null', '[]', '5']) assert.equal((await send(v)).status, 400);
});

test('fetch that throws, 2xx without html_url, and GitHub error body stay generic 502', async () => {
  globalThis.fetch = async () => { throw new Error('boom'); };
  assert.equal((await send(ok)).status, 502);
  globalThis.fetch = async () => new Response('{}', { status: 201 });
  assert.equal((await send(ok)).status, 502);
  globalThis.fetch = async () => new Response('SECRET-DETAIL', { status: 500 });
  const res = await send(ok);
  assert.equal(res.status, 502);
  assert.ok(!(await res.text()).includes('SECRET-DETAIL'));
});

test('GitHub call has a timeout signal and forwards no client header', async () => {
  await send(ok, { extra: { 'x-secret': 'leak', cookie: 'c=1' } });
  const init = calls[0].init;
  assert.ok(init.signal instanceof AbortSignal);
  assert.ok(!JSON.stringify(init).includes('leak'));
  assert.ok(!JSON.stringify(init).includes('c=1'));
});

test('missing cf-connecting-ip is 400', async () => {
  assert.equal((await send(ok, { addr: null })).status, 400);
  assert.equal(calls.length, 0);
});

test('missing repo or token is 500 without leaking values', async () => {
  const errs = [];
  const real = console.error;
  console.error = (...a) => errs.push(a.join(' '));
  try {
    const res = await worker.fetch(new Request('https://w.test/', {
      method: 'POST',
      headers: { 'cf-connecting-ip': ip(), 'content-type': 'application/json', 'content-length': '2' },
      body: '{}',
    }), { GITHUB_REPO: 'o/r' });
    assert.equal(res.status, 500);
  } finally { console.error = real; }
  assert.deepEqual(errs, ['misconfigured']);
});

test('separate IPs have separate buckets; IPv6 shares its /64', async () => {
  const a = '2001:db8:1:2::a';
  for (let i = 0; i < 5; i++) assert.equal((await send(ok, { addr: a })).status, 201);
  assert.equal((await send(ok, { addr: '2001:db8:1:2:ffff::b' })).status, 429);
  assert.equal((await send(ok, { addr: '2001:db8:1:3::a' })).status, 201);
  assert.equal((await send(ok)).status, 201);
});

test('the window expires', async () => {
  const addr = ip();
  const realNow = Date.now;
  for (let i = 0; i < 5; i++) await send(ok, { addr });
  assert.equal((await send(ok, { addr })).status, 429);
  Date.now = () => realNow() + 61 * 60 * 1000;
  try { assert.equal((await send(ok, { addr })).status, 201); } finally { Date.now = realNow; }
});

test('global daily cap: the 100th passes, the 101st is 429', async () => {
  for (let i = 0; i < 100; i++) assert.equal((await send(ok)).status, 201);
  assert.equal((await send(ok)).status, 429);
});

test('requests refused per IP do not use the daily cap', async () => {
  const addr = ip();
  for (let i = 0; i < 20; i++) await send(ok, { addr }); // 5 pass, 15 refused
  for (let i = 0; i < 95; i++) assert.equal((await send(ok)).status, 201); // the 100th use of the cap
  assert.equal((await send(ok)).status, 429);
});

test('IPv4-mapped IPv6 uses the IPv4 bucket; distinct mapped addresses are distinct', async () => {
  for (let i = 0; i < 5; i++) assert.equal((await send(ok, { addr: '::ffff:1.2.3.4' })).status, 201);
  assert.equal((await send(ok, { addr: '1.2.3.4' })).status, 429);
  assert.equal((await send(ok, { addr: '::ffff:1.2.3.5' })).status, 201);
});

test('IPv6 /64 grouping, with and without leading zeros and case', async () => {
  for (let i = 0; i < 5; i++) assert.equal((await send(ok, { addr: '2001:db8::1' })).status, 201);
  assert.equal((await send(ok, { addr: '2001:DB8:0:0::2' })).status, 429);
  assert.equal((await send(ok, { addr: '2001:db8:0:1::1' })).status, 201);
});

test('control and format characters are removed from title and body', async () => {
  await send({ ...ok, title: 'a\u202Eb\u200Bc', body: 'x\u0007y\nz\u200Bw' });
  assert.equal(sentBody().title, 'abc');
  assert.ok(sentBody().body.startsWith('xy\nzw\n'));
  assert.equal((await send({ ...ok, title: '\u200B\u202E' })).status, 400);
  assert.equal((await send({ ...ok, body: '\u200B \u0007' })).status, 400);
});

test('field limits: 120-char title and 20000-char body are accepted; whitespace-only body and 41-char version are 400', async () => {
  assert.equal((await send({ ...ok, title: 'x'.repeat(120), body: 'y'.repeat(20000) })).status, 201);
  assert.equal((await send({ ...ok, body: ' \n\t ' })).status, 400);
  assert.equal((await send({ ...ok, version: 'v'.repeat(41) })).status, 400);
  assert.equal((await send({ ...ok, version: 'v'.repeat(40) })).status, 201);
});

test('request size: 32768 is accepted, 32769 is 413; a small content-length cannot hide a big body', async () => {
  const pad = (len) => JSON.stringify(ok) + ' '.repeat(len - JSON.stringify(ok).length);
  assert.equal((await send(pad(32768))).status, 201);
  assert.equal((await send(pad(32769))).status, 413);
  assert.equal((await send(pad(40000), { length: 10 })).status, 413);
  assert.equal(calls.length, 1);
});

test('content-length must be a plain decimal integer', async () => {
  for (const length of ['abc', '-5', '1e3', '0x10', ' ', '']) {
    assert.equal((await send(ok, { length })).status, 413, `length ${JSON.stringify(length)}`);
  }
});

test('content-type is matched as a media type, case-insensitive, parameters allowed', async () => {
  assert.equal((await send(ok, { type: 'Application/JSON' })).status, 201);
  assert.equal((await send(ok, { type: 'application/json; charset=utf-8' })).status, 201);
  assert.equal((await send(ok, { type: 'text/json' })).status, 415);
  assert.equal((await send(ok, { type: 'application/jsonp' })).status, 415);
});

test('missing token alone is 500', async () => {
  const real = console.error;
  console.error = () => {};
  try {
    const res = await worker.fetch(new Request('https://w.test/', {
      method: 'POST',
      headers: { 'cf-connecting-ip': ip(), 'content-type': 'application/json', 'content-length': '2' },
      body: '{}',
    }), { GITHUB_REPO: 'o/r' });
    assert.equal(res.status, 500);
    const res2 = await worker.fetch(new Request('https://w.test/', { method: 'POST' }), { GITHUB_TOKEN: 't' });
    assert.equal(res2.status, 500);
  } finally { console.error = real; }
});

test('the GitHub call times out after 8000 ms', async () => {
  const realTimeout = AbortSignal.timeout;
  const asked = [];
  AbortSignal.timeout = (ms) => { asked.push(ms); return realTimeout.call(AbortSignal, ms); };
  try { await send(ok); } finally { AbortSignal.timeout = realTimeout; }
  assert.deepEqual(asked, [8000]);
});

test('the IP map stops growing at 5000 entries but known IPs still pass', () => {
  __test.cfg.dailyCap = Infinity;
  const t = 1_000_000;
  for (let i = 0; i < 5000; i++) assert.equal(__test.rateLimited(`ip${i}`, t), false);
  assert.equal(__test.hits.size, 5000);
  assert.equal(__test.rateLimited('new', t), true);
  assert.equal(__test.hits.size, 5000);
  assert.equal(__test.rateLimited('ip0', t), false);
});

test('expired entries are swept only above 1000 entries', () => {
  __test.cfg.dailyCap = Infinity;
  const t = 1_000_000;
  for (let i = 0; i < 1000; i++) __test.rateLimited(`ip${i}`, t);
  __test.rateLimited('later', t + 2 * 60 * 60 * 1000);
  assert.equal(__test.hits.size, 1001, 'at 1000 entries nothing is swept');
  __test.rateLimited('later2', t + 2 * 60 * 60 * 1000);
  assert.equal(__test.hits.size, 2, 'above 1000 the expired ones go');
});
