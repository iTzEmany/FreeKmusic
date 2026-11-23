// Decodes the share fragment (format: .claude/obiettivi/piani/145.md, "Formato del frammento").
const MAX_BYTES = 65536, MAX_IDS = 50, ID_RE = /^[A-Za-z0-9_-]{11}$/;

export async function decodeFragment(fragment) {
  const b64 = String(fragment).replace(/^#/, '').replace(/=+$/, '');
  if (!b64 || !/^[A-Za-z0-9_-]+$/.test(b64)) throw new Error('base64');
  const bin = atob(b64.replace(/-/g, '+').replace(/_/g, '/'));
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  const reader = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip')).getReader();
  const chunks = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.length;
    if (total > MAX_BYTES) { await reader.cancel(); throw new Error('too big'); }
    chunks.push(value);
  }
  const all = new Uint8Array(total);
  let off = 0;
  for (const c of chunks) { all.set(c, off); off += c.length; }
  const lines = new TextDecoder('utf-8', { fatal: true }).decode(all).split('\n');
  if (lines.length !== 4 || lines[0] !== 'FK1') throw new Error('header');
  const [, type, title, idStr] = lines;
  if (!['t', 'a', 'p'].includes(type) || !title.trim()) throw new Error('fields');
  if (idStr.length % 11 !== 0 || idStr.length / 11 > MAX_IDS) throw new Error('ids');
  const ids = idStr.match(/.{11}/g) || [];
  if (!ids.length || !ids.every((i) => ID_RE.test(i))) throw new Error('ids');
  return { type, title, ids };
}
