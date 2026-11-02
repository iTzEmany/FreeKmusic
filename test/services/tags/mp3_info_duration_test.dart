import 'dart:io';
import 'dart:typed_data';

import 'package:codecore/services/tags/audio_metadata_tag_reader.dart';
import 'package:codecore/services/tags/mp3_length.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metadata_god/metadata_god.dart' as mg;

// MPEG1 L3 44.1 kHz frames; the first is the Info frame claiming 9189 frames = 240.04 s.
Future<({int? ms, int? kbps})> _read(int audioKbps, int infoKbps, {required bool id3}) async {
  final idx = {56: 0x40, 64: 0x50}; // bitrate index nibble of header byte 3
  Uint8List frame(int kbps) {
    final len = 144 * kbps * 1000 ~/ 44100;
    return Uint8List(len)..setAll(0, [0xFF, 0xFB, idx[kbps]!, 0xC0]); // mono
  }

  final info = frame(infoKbps)..setAll(21, [0x49, 0x6E, 0x66, 0x6F, 0, 0, 0, 1, 0, 0, 0x23, 0xE5]);
  final audio = frame(audioKbps);
  final tag = id3 ? [0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 16, ...List.filled(16, 0)] : <int>[];
  final dir = Directory.systemTemp.createTempSync('info_dur');
  addTearDown(() => dir.deleteSync(recursive: true));
  final f = File('${dir.path}/a.mp3')
    ..writeAsBytesSync([...tag, ...info, for (var i = 0; i < 9188; i++) ...audio]);
  final t = await AudioMetadataTagReader(loftyIds: (_) async => const mg.TrackIds()).read(f.path);
  return (ms: t.durationMs, kbps: t.bitrateKbps);
}

void main() {
  test('Info frame at a lower bitrate than the audio: real length, not a longer estimate', () async {
    final r = await _read(64, 56, id3: true); // was 9189*182... read as ~274 s
    expect(r.ms, closeTo(240040, 100));
    expect(r.kbps, closeTo(64, 1));
  });

  test('Info frame at a higher bitrate than the audio: real length, not a shorter estimate', () async {
    final r = await _read(56, 64, id3: false);
    expect(r.ms, closeTo(240040, 100));
    expect(r.kbps, closeTo(56, 1));
  });

  test('VBR with no header: the frames are counted, not size / first-frame bitrate', () async {
    // 1100 frames alternating 160 and 32 kbps (so not CBR), then an ID3v1 tag: 1100 * 1152 / 44100 = 28.7 s.
    Uint8List frame(int idx, int kbps) =>
        Uint8List(144 * kbps * 1000 ~/ 44100)..setAll(0, [0xFF, 0xFB, idx << 4, 0xC0]);
    final dir = Directory.systemTemp.createTempSync('vbr_dur');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/v.mp3')
      ..writeAsBytesSync([
        for (var i = 0; i < 1100; i++) ...(i.isEven ? frame(10, 160) : frame(1, 32)),
        0x54, 0x41, 0x47, ...List.filled(125, 0),
      ]);
    final m = mp3Length(f.path)!;
    expect(m.ms, closeTo(28734, 30));
    expect(m.bps ~/ 1000, closeTo(96, 1)); // (160 + 32) / 2
    final t = await AudioMetadataTagReader(loftyIds: (_) async => const mg.TrackIds()).read(f.path);
    expect(t.durationMs, closeTo(28734, 30));
  });

  test('garbage with no frames keeps the parser value (null)', () {
    final dir = Directory.systemTemp.createTempSync('junk_dur');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/j.mp3')..writeAsBytesSync(List.filled(3000, 0xFF));
    expect(mp3Length(f.path), isNull);
  });
}
