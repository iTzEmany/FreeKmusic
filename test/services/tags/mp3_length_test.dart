import 'dart:io';
import 'dart:typed_data';

import 'package:codecore/services/tags/mp3_length.dart';
import 'package:flutter_test/flutter_test.dart';

const _br1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
const _br2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];

/// A Layer III frame of zeros with a valid header (MPEG1 44.1 kHz or MPEG2 22.05 kHz, stereo).
Uint8List frame(int kbps, {bool mpeg2 = false, bool crc = false, int pad = 0}) {
  final idx = (mpeg2 ? _br2 : _br1).indexOf(kbps);
  final len = (mpeg2 ? 72 : 144) * kbps * 1000 ~/ (mpeg2 ? 22050 : 44100) + pad;
  return Uint8List(len)
    ..setAll(0, [0xFF, (mpeg2 ? 0xF2 : 0xFA) | (crc ? 0 : 1), (idx << 4) | (pad << 1), 0x00]);
}

Uint8List id3v2({int body = 100, bool footer = false}) {
  final size = [0, 0, (body >> 14) & 0x7F, (body >> 7) & 0x7F, body & 0x7F].sublist(1); // syncsafe
  final b = BytesBuilder()
    ..add([0x49, 0x44, 0x33, 4, 0, footer ? 0x10 : 0, ...size])
    ..add(Uint8List(body));
  if (footer) b.add([0x33, 0x44, 0x49, 4, 0, 0x10, ...size]);
  return b.toBytes();
}

/// Frames at [kbps] with the padding bit toggled the way a real encoder does (exact on average).
List<int> cbr(int n, int kbps, {bool mpeg2 = false, bool crc = false}) => [
      for (var i = 0; i < n; i++) ...frame(kbps, mpeg2: mpeg2, crc: crc, pad: i % 2),
    ];

List<int> vbr(int n, {bool crc = false}) => [
      for (var i = 0; i < n; i++) ...frame(i.isEven ? 160 : 32, crc: crc),
    ];

({int ms, int bps})? measure(List<int> bytes, {void Function(int)? onRead}) {
  final dir = Directory.systemTemp.createTempSync('mp3len');
  addTearDown(() => dir.deleteSync(recursive: true));
  final f = File('${dir.path}/a.mp3')..writeAsBytesSync(bytes);
  return mp3Length(f.path, onRead: onRead);
}

void main() {
  const ms1100 = 28734; // 1100 MPEG1 frames
  const ms3000 = 78367; // 3000 MPEG1 frames (or 3000 MPEG2 frames at 22.05 kHz)

  test('CBR with no header: the length comes from the bytes, reading only a few blocks', () {
    var read = 0;
    final bytes = [...id3v2(), ...cbr(3000, 128), 0x54, 0x41, 0x47, ...List.filled(125, 0)];
    final m = measure(bytes, onRead: (n) => read += n)!;
    expect(m.ms, closeTo(ms3000, 250));
    expect(m.bps ~/ 1000, 128);
    expect(read, lessThan(bytes.length ~/ 4));
  });

  test('VBR with no header: every frame is counted (frames on CRC too)', () {
    expect(measure(vbr(1100, crc: true))!.ms, closeTo(ms1100, 30));
  });

  test('VBR with no header whose first 40 frames share a bitrate is not taken for CBR', () {
    final bytes = [for (var i = 0; i < 40; i++) ...frame(32), ...vbr(1060)];
    expect(measure(bytes)!.ms, closeTo(ms1100, 30));
  });

  test('MPEG2 frames carry 576 samples', () {
    expect(measure(cbr(3000, 64, mpeg2: true))!.ms, closeTo(ms3000, 250));
  });

  test('junk after the frames (three invalid syncs): the frames counted stand', () {
    final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46, 0, 1, 0xFF, 0xDB, 0xFF, 0xC0, 0xFF, 0xC4];
    expect(measure([...vbr(1100), ...jpeg, ...List.filled(40, 0x41)])!.ms, closeTo(ms1100, 30));
  });

  test('an ID3v2 tag with a JPEG after the frames is no music', () {
    final tag = id3v2(body: 2000);
    tag.setAll(10, [0xFF, 0xD8, 0xFF, 0xE0, 0xFF, 0xFB, 0x90, 0]);
    expect(measure([...vbr(1100), ...tag])!.ms, closeTo(ms1100, 30));
  });

  test('a trailing ID3v2.4 tag with its footer is left out of the CBR bytes', () {
    // 20000 bytes of tag counted as audio would add 1.25 s at 128 kbps.
    final m = measure([...id3v2(), ...cbr(3000, 128), ...id3v2(body: 20000, footer: true)])!;
    expect(m.ms, closeTo(ms3000, 250));
  });

  test('a leading ID3v2.4 tag with a footer is skipped', () {
    expect(measure([...id3v2(footer: true), ...cbr(3000, 128)])!.ms, closeTo(ms3000, 250));
  });

  test('a stereo Xing header (tag at offset 36) gives the count', () {
    final x = frame(128)..setAll(36, [0x58, 0x69, 0x6E, 0x67, 0, 0, 0, 1, 0, 0, 0x03, 0xE8]); // 1000 frames
    expect(measure([...x, ...vbr(1000)])!.ms, closeTo(26122, 5));
  });

  test('an Info count the bytes do not bear out (cut file) is not trusted', () {
    final info = frame(64)..setAll(36, [0x49, 0x6E, 0x66, 0x6F, 0, 0, 0, 1, 0, 0, 0x23, 0xE5]); // 9189 frames
    final m = measure([...info, ...cbr(2000, 64)])!;
    expect(m.ms, closeTo(52245, 250)); // 2000 frames, not 240 s
  });

  test('a file that is not an mp3 is not measurable', () {
    expect(measure(List.filled(3000, 0xFF)), isNull);
    expect(measure([...cbr(5, 128)]), isNull); // too few frames to say
  });

  test('a file that is not there throws in the checked form', () {
    expect(() => mp3LengthChecked('/nope/a.mp3'), throwsA(isA<FileSystemException>()));
    expect(mp3Length('/nope/a.mp3'), isNull);
  });
}
