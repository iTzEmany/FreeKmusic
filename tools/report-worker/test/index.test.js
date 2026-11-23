import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';

const env = { GITHUB_TOKEN: 't0k', GITHUB_REPO: 'o/r' };
const realFetch = globalThis.fetch;
let calls;
let ghStatus;
let n = 0;

beforeEach(() => {
  calls = [];
  ghStatus = 201;
  globalThis.fetch = async (url, init) => {
    calls.push({ url, init });
    return new Response(JSON.stringify({ html_url: 'https://github.com/o/r/issues/1' }), { status: ghStatus });
  };
});
afterEach(() => { globalThis.fetch = realFetch; });

const ip = () => `10.0.0.${++n}`; // fresh IP per test: the counter is module-level
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

test('global daily cap is 429 (keep last: it leaves the counter full)', async () => {
  const realNow = Date.now;
  Date.now = () => realNow() + 3 * 24 * 60 * 60 * 1000;
  try {
    let last;
    for (let i = 0; i < 101; i++) last = (await send(ok)).status;
    assert.equal(last, 429);
  } finally { Date.now = realNow; }
});
