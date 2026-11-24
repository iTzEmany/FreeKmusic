// Decodes the share fragment (rules: docs/architettura/online.md, "Il frammento del link di condivisione").
const MAX_BYTES = 65536, MAX_IDS = 50, MAX_TITLE = 120, MAX_ROW_ARTIST = 60, MAX_ROW_TITLE = 80;
const RELEASE_URL = 'https://github.com/iTzEmany/FreeKmusic/releases/latest';

export class FragmentError extends Error {}
const fail = (m) => { throw new FragmentError(m); };

export async function decodeFragment(fragment) {
  const m = /^([A-Za-z0-9_-]+)(={0,2})$/.exec(String(fragment).replace(/^#/, ''));
  if (!m) fail('base64');
  const [, body, pad] = m;
  if (body.length % 4 === 1 || (pad && pad.length !== (4 - (body.length % 4)) % 4)) fail('padding');
  if (typeof DecompressionStream === 'undefined') fail('DecompressionStream not supported');
  let bytes;
  try {
    const std = body.replace(/-/g, '+').replace(/_/g, '/'), raw = atob(std);
    // atob ignores non-zero trailing bits of the last character; the Dart side rejects them.
    if (btoa(raw).replace(/=+$/, '') !== std) fail('base64 trailing bits');
    bytes = Uint8Array.from(raw, (c) => c.charCodeAt(0));
  } catch (e) { fail('base64: ' + e.message); }
  const all = await gunzipLimited(bytes);
  // The stream checks each member's CRC; ISIZE of the last one must equal the total, as in Dart (rejects extra members).
  if (new DataView(bytes.buffer).getUint32(bytes.length - 4, true) !== all.length) fail('gzip trailer');
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(all); } catch (e) { fail('utf8'); }
  const lines = text.split('\n');
  const v2 = lines[0] === 'FK2';
  if ((!v2 && lines[0] !== 'FK1') || lines.length < 4 || (!v2 && lines.length !== 4)) fail('header');
  const [, kind, title] = lines;
  if (!['t', 'a', 'p'].includes(kind)) fail('kind');
  if (/^[\s\u0085]*$/.test(title) || [...title].length > MAX_TITLE) fail('title');
  // A row is a video id (a string) or, in FK2 only, a search: `~<artist>\t<title>` -> {artist, title}.
  let rows;
  if (v2) rows = lines.slice(3).map(row);
  else {
    const idStr = lines[3];
    if (!/^[A-Za-z0-9_-]*$/.test(idStr) || idStr.length % 11 !== 0) fail('ids');
    rows = idStr.match(/.{11}/g) || [];
  }
  if (!rows.length || rows.length > MAX_IDS) fail('ids');
  return { kind, title, rows };
}

function row(l) {
  if (!l.startsWith('~')) return /^[A-Za-z0-9_-]{11}$/.test(l) ? l : fail('row');
  const p = l.slice(1).split('\t');
  if (p.length !== 2 || /^[\s\u0085]*$/.test(p[1]) || [...p[1]].length > MAX_ROW_TITLE || [...p[0]].length > MAX_ROW_ARTIST) fail('search row');
  return { artist: p[0], title: p[1] };
}

async function gunzipLimited(bytes) {
  const chunks = [];
  let total = 0;
  try {
    const reader = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip')).getReader();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.length;
      if (total > MAX_BYTES) { await reader.cancel(); break; }
      chunks.push(value);
    }
  } catch (e) { fail('gzip: ' + e.message); }
  if (total > MAX_BYTES) fail('too big');
  const all = new Uint8Array(total);
  let off = 0;
  for (const c of chunks) { all.set(c, off); off += c.length; }
  return all;
}

// Android only: an intent:// URL opens the installed app, else the release page. Others: null (button hidden).
export function openAppUrl(fragment, userAgent) {
  const f = String(fragment).replace(/^#/, '');
  if (!/Android/i.test(userAgent) || !/^[A-Za-z0-9_=-]+$/.test(f)) return null;
  return `intent://itzemany.github.io/FreeKmusic/#${f}#Intent;scheme=https;package=com.freekmusic.player;S.browser_fallback_url=${encodeURIComponent(RELEASE_URL)};end`;
}
