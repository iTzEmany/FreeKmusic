// Anonymous issue reports: the app POSTs {title, body, version}, the Worker opens a GitHub issue.
const MAX = { title: 120, body: 20000, version: 40 };
const LIMIT = 5;
const WINDOW_MS = 60 * 60 * 1000;
// shortcut: per-isolate memory, so the limit is weak across instances/restarts; upgrade to a KV/Durable Object counter if abused.
const hits = new Map();

function rateLimited(ip, now) {
  for (const [k, v] of hits) if (v.reset <= now) hits.delete(k);
  const e = hits.get(ip) ?? { n: 0, reset: now + WINDOW_MS };
  e.n += 1;
  hits.set(ip, e);
  return e.n > LIMIT;
}

const reply = (status, obj) => Response.json(obj, { status });

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return reply(405, { error: 'method not allowed' });

    let data;
    try {
      data = await request.json();
    } catch {
      return reply(400, { error: 'invalid json' });
    }
    for (const k of Object.keys(MAX)) {
      if (typeof data?.[k] !== 'string' || data[k].length > MAX[k]) {
        return reply(400, { error: 'invalid fields' });
      }
    }
    if (!data.title.trim() || !data.body.trim()) return reply(400, { error: 'invalid fields' });

    // The IP is used only for the local counter, never forwarded.
    const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
    if (rateLimited(ip, Date.now())) return reply(429, { error: 'too many requests' });

    try {
      const res = await fetch(`https://api.github.com/repos/${env.GITHUB_REPO}/issues`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.GITHUB_TOKEN}`,
          'User-Agent': 'report-worker',
          Accept: 'application/vnd.github+json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title: data.title,
          body: `${data.body}\n\n---\nVersione: ${data.version}`,
          labels: ['da-triage'],
        }),
      });
      if (!res.ok) return reply(502, { error: 'upstream error' });
      const issue = await res.json();
      return reply(201, { url: issue.html_url });
    } catch {
      return reply(502, { error: 'upstream error' });
    }
  },
};
