// Anonymous issue reports: the app POSTs {title, body, version}, the Worker opens a GitHub issue.
const MAX = { title: 120, body: 20000 };
const MAX_REQUEST = 32 * 1024;
const VERSION = /^[\w.+-]{1,40}$/;
const LIMIT = 5;
const WINDOW_MS = 60 * 60 * 1000;
const DAY_MS = 24 * WINDOW_MS;
const DAILY_CAP = 100;
const CLEAN_ABOVE = 1000;
const MAP_CAP = 5000;
// shortcut: per-isolate memory (Map + daily counter), so limits are weak across instances/restarts;
// a real 5/hour limit needs a Durable Object: move to it if abuse shows up (no paid binding for now).
const hits = new Map();
let day = { n: 0, reset: 0 };
const cfg = { dailyCap: DAILY_CAP }; // tests lower it to reach the map limits

// IPv4 as is; IPv6 reduced to its /64 (first 4 groups) so rotating the host part does not help.
function bucket(ip) {
  const mapped = /^::ffff:(\d{1,3}(?:\.\d{1,3}){3})$/i.exec(ip); // IPv4-mapped IPv6 is the IPv4 address
  if (mapped) return mapped[1];
  if (!ip.includes(':')) return ip;
  const [head, tail] = ip.split('::');
  const h = head ? head.split(':') : [];
  const t = tail ? tail.split(':') : [];
  const groups = tail === undefined ? h : [...h, ...Array(Math.max(0, 8 - h.length - t.length)).fill('0'), ...t];
  return groups.slice(0, 4).map((g) => g.toLowerCase().replace(/^0+(?=.)/, '')).join(':');
}

function rateLimited(ip, now) {
  if (hits.size > CLEAN_ABOVE) for (const [k, v] of hits) if (v.reset <= now) hits.delete(k);
  const key = bucket(ip);
  if (!hits.has(key) && hits.size >= MAP_CAP) return true;
  const e = hits.get(key) ?? { n: 0, reset: now + WINDOW_MS };
  if (e.reset <= now) { e.n = 0; e.reset = now + WINDOW_MS; }
  e.n += 1;
  hits.set(key, e);
  return e.n > LIMIT;
}

// Shared daily cap, taken just before the GitHub call: invalid or per-IP-refused requests never use it.
function takeDaily(now) {
  if (day.reset <= now) day = { n: 0, reset: now + DAY_MS };
  if (day.n >= cfg.dailyCap) return false;
  day.n += 1;
  return true;
}

// For tests only: module state is shared across requests.
export const __test = {
  rateLimited,
  hits,
  cfg,
  reset() { hits.clear(); day = { n: 0, reset: 0 }; cfg.dailyCap = DAILY_CAP; },
};

const reply = (status, obj) => Response.json(obj, { status });
// Zero-width space after "@": GitHub no longer sees a mention, nobody gets notified.
const defang = (s) => s.replaceAll('@', '@​');

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return reply(405, { error: 'method not allowed' });
    if (!env.GITHUB_REPO || !env.GITHUB_TOKEN) {
      console.error('misconfigured');
      return reply(500, { error: 'server error' });
    }
    if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json') {
      return reply(415, { error: 'unsupported media type' });
    }
    // The IP is used only for the local counter, never forwarded.
    const ip = request.headers.get('cf-connecting-ip');
    if (!ip) return reply(400, { error: 'missing client ip' });
    const lenHeader = request.headers.get('content-length');
    if (lenHeader === null || !/^\d+$/.test(lenHeader) || Number(lenHeader) > MAX_REQUEST) {
      return reply(413, { error: 'payload too large' });
    }
    if (rateLimited(ip, Date.now())) return reply(429, { error: 'too many requests' });

    const text = await request.text();
    if (text.length > MAX_REQUEST) return reply(413, { error: 'payload too large' });
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      return reply(400, { error: 'invalid json' });
    }
    for (const k of ['title', 'body', 'version']) {
      if (typeof data?.[k] !== 'string') return reply(400, { error: 'invalid fields' });
    }
    // Control and format characters (RTL override, zero-width, ...) are dropped; the body keeps its line breaks and tabs.
    const title = data.title.replace(/\s+/g, ' ').replace(/(?!\u200d)[\p{Cc}\p{Cf}]/gu, '').trim();
    const body = data.body.replace(/(?![\n\r\t\u200d])[\p{Cc}\p{Cf}]/gu, '');
    if (!title || !body.trim() || title.length > MAX.title || body.length > MAX.body
      || !VERSION.test(data.version)) {
      return reply(400, { error: 'invalid fields' });
    }

    if (!takeDaily(Date.now())) return reply(429, { error: 'too many requests' });
    try {
      const res = await fetch(`https://api.github.com/repos/${env.GITHUB_REPO}/issues`, {
        method: 'POST',
        signal: AbortSignal.timeout(8000),
        headers: {
          Authorization: `Bearer ${env.GITHUB_TOKEN}`,
          'User-Agent': 'report-worker',
          Accept: 'application/vnd.github+json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title: defang(title),
          body: defang(`${body}\n\n---\nVersione: ${data.version}`),
          labels: ['da-triage'],
        }),
      });
      if (!res.ok) return reply(502, { error: 'upstream error' });
      const issue = await res.json();
      if (typeof issue?.html_url !== 'string') return reply(502, { error: 'upstream error' });
      return reply(201, { url: issue.html_url });
    } catch {
      return reply(504, { error: 'upstream timeout' }); // no answer from GitHub: the issue may exist
    }
  },
};
