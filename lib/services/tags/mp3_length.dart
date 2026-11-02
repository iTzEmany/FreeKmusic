import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/app_log.dart';

/// Real length and average bitrate (bits/s) of an mp3, or null to keep what the tag parser said.
/// The parser reads only the "Xing" frame count: on "Info" (CBR) files it estimates size /
/// first-frame bitrate (a 56 kbps header frame on 64 kbps audio gave 274 s for 240 s), and on
/// VBR files with no header it does the same (47 s for 240 s). Here: the frame count of an
/// Info / Xing / VBRI header, else a walk over the frame headers. Reads in blocks; sync.
({int ms, int bps})? mp3Length(String path) {
  RandomAccessFile? f;
  try {
    f = File(path).openSync();
    return _measure(f);
  } on Object catch (e, st) {
    AppLog.d('mp3 length skipped: $path', e, st);
    return null;
  } finally {
    f?.closeSync();
  }
}

const _br1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
const _br2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
const _sr = {3: [44100, 48000, 32000], 2: [22050, 24000, 16000], 0: [11025, 12000, 8000]};

class _Bytes {
  _Bytes(this.f, this.len);
  final RandomAccessFile f;
  final int len;
  Uint8List _buf = Uint8List(0);
  int _from = 0;

  int at(int p) {
    if (p < 0 || p >= len) return -1;
    if (p < _from || p >= _from + _buf.length) {
      f.setPositionSync(p);
      _buf = f.readSync(65536);
      _from = p;
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
}

/// A valid Layer III frame header at [p]: frame length, samples per frame, sample rate.
({int len, int spf, int sr})? _header(_Bytes b, int p) {
  final b1 = b.at(p + 1), b2 = b.at(p + 2);
  if (b.at(p) != 0xFF || b1 < 0 || b2 < 0 || (b1 & 0xE0) != 0xE0) return null;
  final ver = (b1 >> 3) & 3;
  if (ver == 1 || (b1 >> 1) & 3 != 1) return null; // reserved version / not Layer III
  final bi = b2 >> 4, si = (b2 >> 2) & 3;
  if (bi == 0 || bi == 15 || si == 3) return null;
  final mpeg1 = ver == 3;
  final sr = _sr[ver]![si], kbps = (mpeg1 ? _br1 : _br2)[bi];
  return (len: (mpeg1 ? 144 : 72) * kbps * 1000 ~/ sr + ((b2 >> 1) & 1), spf: mpeg1 ? 1152 : 576, sr: sr);
}

({int ms, int bps})? _measure(RandomAccessFile f) {
  final len = f.lengthSync();
  final b = _Bytes(f, len);
  var start = 0;
  if (b.is_(0, 'ID3')) {
    start = 10 + ((b.at(6) << 21) | (b.at(7) << 14) | (b.at(8) << 7) | b.at(9));
    if (b.at(5) & 0x10 != 0) start += 10;
  }
  var pos = start;
  ({int len, int spf, int sr})? first;
  for (; pos < math.min(len - 4, start + 4096); pos++) {
    first = _header(b, pos);
    if (first != null) break;
  }
  if (first == null) return null;
  ({int ms, int bps}) of(int frames, int bytes) {
    final ms = frames * first!.spf * 1000 ~/ first.sr;
    return (ms: ms, bps: bytes * 8000 ~/ ms);
  }

  for (var i = pos + 4; i < pos + 44; i++) {
    final vbri = b.is_(i, 'VBRI');
    if (vbri || b.is_(i, 'Xing') || b.is_(i, 'Info')) {
      final frames = vbri ? b.u32(i + 14) : (b.at(i + 7) & 1 == 1 ? b.u32(i + 8) : 0);
      if (frames > 0) return of(frames, len - pos);
      break; // a header without the count: walk the frames
    }
  }
  var n = 0, bad = 0, p = pos;
  while (p + 4 <= len) {
    final h = _header(b, p);
    if (h != null) {
      bad = 0;
      n++;
      p += h.len;
    } else if (b.is_(p, 'TAG') || b.is_(p, 'APETAGEX')) {
      break; // ID3v1 / APE at the end
    } else if (b.at(p) == 0) {
      while (p < len && b.at(p) == 0) {
        p++; // zero padding
      }
    } else {
      if (++bad >= 3) return null;
      p++;
      while (p + 4 <= len && b.at(p) != 0xFF) {
        p++;
      }
    }
  }
  return n == 0 ? null : of(n, math.min(p, len) - pos);
}
