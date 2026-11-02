import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/app_log.dart';

/// Real length and average bitrate (bits/s) of an mp3, or null to keep what the tag parser said.
/// The parser reads only the "Xing" frame count: on "Info" (CBR) files it estimates size /
/// first-frame bitrate (a 56 kbps header frame on 64 kbps audio gave 274 s for 240 s), and on
/// VBR files with no header it does the same (47 s for 240 s). Here: the frame count of an
/// Info / Xing / VBRI header (checked against the bytes), else the audio bytes over the bitrate
/// when the first frames all share it (CBR), else a walk over every frame header. Blocks of
/// 16 KB, sync. [onRead] gets the size of each block read (tests).
/// The CBR guess is checked at 1/4, 1/2 and 3/4 of the file too (a VBR file can start quiet).
({int ms, int bps})? mp3Length(String path, {void Function(int)? onRead}) {
  try {
    return mp3LengthChecked(path, onRead: onRead);
  } on Object catch (e, st) {
    AppLog.d('mp3 length skipped: $path', e, st);
    return null;
  }
}

/// Like [mp3Length] but a file that cannot be opened or read throws (null: not measurable).
({int ms, int bps})? mp3LengthChecked(String path, {void Function(int)? onRead}) {
  final f = File(path).openSync();
  try {
    return _measure(f, onRead);
  } finally {
    f.closeSync();
  }
}

const _br1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
const _br2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
const _sr = {3: [44100, 48000, 32000], 2: [22050, 24000, 16000], 0: [11025, 12000, 8000]};
const _minFrames = 10; // fewer valid frames than this before junk: not a measure
const _cbrProbe = 30;

class _Bytes {
  _Bytes(this.f, this.len, this.onRead);
  final RandomAccessFile f;
  final int len;
  final void Function(int)? onRead;
  Uint8List _buf = Uint8List(0);
  int _from = 0;

  int at(int p) {
    if (p < 0 || p >= len) return -1;
    if (p < _from || p >= _from + _buf.length) {
      f.setPositionSync(p);
      _buf = f.readSync(16384);
      _from = p;
      onRead?.call(_buf.length);
    }
    return _buf[p - _from];
  }

  bool is_(int p, String s) {
    for (var i = 0; i < s.length; i++) {
      if (at(p + i) != s.codeUnitAt(i)) return false;
    }
    return true;
  }

  int u32(int p) => (at(p) << 24) | (at(p + 1) << 16) | (at(p + 2) << 8) | at(p + 3);
  int u32le(int p) => at(p) | (at(p + 1) << 8) | (at(p + 2) << 16) | (at(p + 3) << 24);
}

typedef _Header = ({int len, int spf, int sr, int kbps});

/// A valid Layer III frame header at [p].
_Header? _header(_Bytes b, int p) {
  final b1 = b.at(p + 1), b2 = b.at(p + 2);
  if (b.at(p) != 0xFF || b1 < 0 || b2 < 0 || (b1 & 0xE0) != 0xE0) return null;
  final ver = (b1 >> 3) & 3;
  if (ver == 1 || (b1 >> 1) & 3 != 1) return null; // reserved version / not Layer III
  final bi = b2 >> 4, si = (b2 >> 2) & 3;
  if (bi == 0 || bi == 15 || si == 3) return null;
  final mpeg1 = ver == 3;
  final sr = _sr[ver]![si], kbps = (mpeg1 ? _br1 : _br2)[bi];
  return (
    len: (mpeg1 ? 144 : 72) * kbps * 1000 ~/ sr + ((b2 >> 1) & 1),
    spf: mpeg1 ? 1152 : 576,
    sr: sr,
    kbps: kbps,
  );
}

bool _same(_Header a, _Header b) => a.sr == b.sr && a.spf == b.spf;

int _syncsafe(_Bytes b, int p) {
  var v = 0;
  for (var i = 0; i < 4; i++) {
    final x = b.at(p + i);
    if (x < 0 || x > 0x7F) return -1;
    v = (v << 7) | x;
  }
  return v;
}

/// Where the audio starts: after the leading ID3v2 tags (they can be chained). A tag that does
/// not look right (version, size bits, size past the file) is not skipped.
int _audioStart(_Bytes b) {
  var p = 0;
  while (b.is_(p, 'ID3')) {
    final ver = b.at(p + 3), size = _syncsafe(b, p + 6);
    if (ver < 2 || ver > 4 || size < 0) break;
    final total = 10 + size + (ver == 4 && b.at(p + 5) & 0x10 != 0 ? 10 : 0); // v2.4 footer
    if (p + total > b.len) break;
    p += total;
  }
  return p;
}

/// Where the audio ends: before an ID3v1, APE or ID3v2-footer tag at the end, when recognisable.
int _audioEnd(_Bytes b, int start) {
  var end = b.len;
  for (var i = 0; i < 3; i++) {
    var cut = 0;
    if (end - start >= 128 && b.is_(end - 128, 'TAG')) {
      cut = 128;
    } else if (end - start >= 32 && b.is_(end - 32, 'APETAGEX')) {
      cut = b.u32le(end - 32 + 12) + (b.at(end - 32 + 23) & 0x80 != 0 ? 32 : 0); // size has the footer
    } else if (end - start >= 10 && b.is_(end - 10, '3DI')) {
      final s = _syncsafe(b, end - 10 + 6);
      cut = s < 0 ? 0 : s + 20;
    }
    if (cut <= 0 || cut > end - start) break;
    end -= cut;
  }
  return end;
}

/// True when, at 1/4, 1/2 and 3/4 of the music, a run of consecutive frames shares [kbps].
/// A spot where no run is found counts as «not the same», so the caller walks every frame.
bool _sameAtQuarters(_Bytes b, int from, int end, _Header first, int kbps) {
  for (var q = 1; q <= 3; q++) {
    final at = from + (end - from) * q ~/ 4;
    var ok = false;
    for (var p = at; p < math.min(end - 4, at + 4096) && !ok; p++) {
      var h = _header(b, p);
      if (h == null || !_same(h, first)) continue;
      var q2 = p, run = 0;
      while (run < 8 && h != null && _same(h, first) && q2 + 4 <= end) {
        if (h.kbps != kbps) return false;
        run++;
        q2 += h.len;
        h = _header(b, q2);
      }
      ok = run >= 5;
    }
    if (!ok) return false;
  }
  return true;
}

({int ms, int bps})? _measure(RandomAccessFile f, void Function(int)? onRead) {
  final b = _Bytes(f, f.lengthSync(), onRead);
  final start = _audioStart(b), end = _audioEnd(b, start);
  var pos = start;
  _Header? first;
  for (; pos < math.min(end - 4, start + 4096); pos++) {
    first = _header(b, pos);
    if (first != null) break;
  }
  if (first == null) return null;
  ({int ms, int bps}) of(int frames, int bytes) {
    final ms = frames * first!.spf * 1000 ~/ first.sr;
    return (ms: ms, bps: bytes * 8000 ~/ math.max(ms, 1));
  }

  var from = pos; // where the music frames start
  for (var i = pos + 4; i < pos + 44; i++) {
    final vbri = b.is_(i, 'VBRI');
    final info = b.is_(i, 'Info');
    if (!vbri && !info && !b.is_(i, 'Xing')) continue;
    from = pos + first.len; // the header frame is no music
    final frames = vbri ? b.u32(i + 14) : (b.at(i + 7) & 1 == 1 ? b.u32(i + 8) : 0);
    if (frames <= 0) break;
    final m = of(frames, end - pos);
    // A count that the bytes do not bear out (cut file, bad header) is not trusted; the CBR
    // check uses the size of a music frame, not of the header frame.
    final music = _header(b, from)?.len ?? first.len;
    if (m.bps >= 8000 && !(info && frames * music > 1.05 * (end - pos))) return m;
    break;
  }

  var n = 0, p = from;
  final probe = _header(b, from);
  if (probe != null && _same(probe, first)) {
    while (n < _cbrProbe && p + 4 <= end) {
      final h = _header(b, p);
      if (h == null || !_same(h, first) || h.kbps != probe.kbps) break;
      n++;
      p += h.len;
    }
    if (n == _cbrProbe && _sameAtQuarters(b, from, end, first, probe.kbps)) {
      final ms = (end - from) * 8 ~/ probe.kbps;
      return (ms: ms, bps: (end - from) * 8000 ~/ math.max(ms, 1));
    }
  }
  n = 0;
  p = from;
  var bad = 0, good = from; // good: where the last valid frame ends
  while (p + 4 <= end) {
    final h = _header(b, p);
    if (h != null && _same(h, first)) {
      bad = 0;
      n++;
      p += h.len;
      good = p;
    } else if (b.is_(p, 'TAG') || b.is_(p, 'APETAGEX') || b.is_(p, 'ID3')) {
      break; // a tag at the end
    } else if (b.at(p) == 0) {
      while (p < end && b.at(p) == 0) {
        p++; // zero padding
      }
    } else {
      if (++bad >= 3) break; // junk: what was counted stands
      p++;
      while (p + 4 <= end && b.at(p) != 0xFF) {
        p++;
      }
    }
  }
  return n < _minFrames ? null : of(n, math.min(good, end) - from);
}
