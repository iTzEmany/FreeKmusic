// Decodes the share fragment (rules: docs/architettura/online.md, "Il frammento del link di condivisione").
const MAX_BYTES = 65536, MAX_IDS = 50, MAX_TITLE = 120;
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
  if (lines.length !== 4 || lines[0] !== 'FK1') fail('header');
  const [, kind, title, idStr] = lines;
  if (!['t', 'a', 'p'].includes(kind)) fail('kind');
  if (/^[\s\u0085]*$/.test(title) || [...title].length > MAX_TITLE) fail('title');
  if (!/^[A-Za-z0-9_-]*$/.test(idStr) || idStr.length % 11 !== 0 || idStr.length / 11 > MAX_IDS) fail('ids');
  const ids = idStr.match(/.{11}/g) || [];
  if (!ids.length) fail('ids');
  return { kind, title, ids };
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
