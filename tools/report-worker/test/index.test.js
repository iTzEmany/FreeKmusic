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
const send = (body, { method = 'POST', addr = ip() } = {}) =>
  worker.fetch(
    new Request('https://w.test/', {
      method,
      headers: { 'cf-connecting-ip': addr, 'x-forwarded-for': addr },
      body: method === 'GET' ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
    }),
    env,
  );
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
