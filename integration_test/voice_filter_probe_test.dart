// Task 127.1 probe (temporary): does libmpv of this machine accept the `af`
// voice filter of `voiceFilterString`, together with the speed's `scaletempo`?
// Run: xvfb-run -a flutter test integration_test/voice_filter_probe_test.dart -d linux
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:codecore/services/audio/desktop_voice_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';

const _sr = 44100;

/// Stereo PCM16 WAV, [seconds] long: 1 kHz and 60 Hz in the centre, 2 kHz left
/// only; all zeros when [silent].
Uint8List _wav(double seconds, {bool silent = false}) {
  final n = (seconds * _sr).round();
  final d = ByteData(44 + n * 4)
    ..setUint32(0, 0x46464952, Endian.little) // RIFF
    ..setUint32(4, 36 + n * 4, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little) // WAVE
    ..setUint32(12, 0x20746d66, Endian.little) // fmt
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 2, Endian.little)
    ..setUint32(24, _sr, Endian.little)
    ..setUint32(28, _sr * 4, Endian.little)
    ..setUint16(32, 4, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little) // data
    ..setUint32(40, n * 4, Endian.little);
  if (!silent) {
    double s(double f, double t) => math.sin(2 * math.pi * f * t);
    for (var i = 0; i < n; i++) {
      final t = i / _sr;
      final c = 0.3 * s(1000, t) + 0.3 * s(60, t);
      final l = ((c + 0.2 * s(2000, t)) * 32767).round();
      final r = (c * 32767).round();
      d.setInt16(44 + i * 4, l, Endian.little);
      d.setInt16(46 + i * 4, r, Endian.little);
    }
  }
  return d.buffer.asUint8List();
}

/// Amplitude of [hz] in the left/right channel of mpv's `ao=pcm` output (float32).
({double l, double r}) _amp(Uint8List file, double hz) {
  var i = 12;
  while (String.fromCharCodes(file.sublist(i, i + 4)) != 'data') {
    i += 8 + ByteData.sublistView(file, i + 4, i + 8).getUint32(0, Endian.little);
  }
  final v = ByteData.sublistView(file, i + 8);
  final frames = v.lengthInBytes ~/ 8;
  double one(int ch) {
    var re = 0.0, im = 0.0, n = 0;
    for (var k = 20000; k < math.min(frames, 60000); k++, n++) {
      final x = v.getFloat32(k * 8 + ch * 4, Endian.little);
      re += x * math.cos(2 * math.pi * hz / _sr * k);
      im += x * math.sin(2 * math.pi * hz / _sr * k);
    }
    return 2 * math.sqrt(re * re + im * im) / n;
  }

  return (l: one(0), r: one(1));
}

Future<({Uint8List pcm, String af, List<String> errors})> _render(
    String wav, String out, double? level, {double speed = 1.0}) async {
  final player = Player(configuration: const PlayerConfiguration(pitch: true, logLevel: MPVLogLevel.warn));
  final errors = <String>[];
  final subs = [
    player.stream.log.listen((e) {
      // ignore: avoid_print
      if (e.level == 'warn') print('mpv warn: ${e.prefix}: ${e.text}');
      if (e.level == 'error') errors.add('${e.prefix}: ${e.text}');
    }),
    player.stream.error.listen(errors.add),
  ];
  final native = player.platform! as NativePlayer;
  await native.setProperty('ao', 'pcm');
  await native.setProperty('ao-pcm-file', out);
  if (speed != 1.0) await player.setRate(speed); // writes `af=scaletempo...`
  final voice = voiceFilterString(level);
  final tempo = speed == 1.0 ? '' : 'scaletempo:scale=${speed.toStringAsFixed(8)}';
  await native.setProperty('af', [tempo, voice].where((e) => e.isNotEmpty).join(','));
  final done = player.stream.completed.firstWhere((c) => c).timeout(const Duration(seconds: 15));
  await player.open(Media(wav));
  await done;
  final af = await native.getProperty('af');
  await player.dispose();
  for (final s in subs) {
    await s.cancel();
  }
  return (pcm: File(out).readAsBytesSync(), af: af, errors: errors);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() {
    JustAudioMediaKit.ensureInitialized();
    dir = Directory.systemTemp.createTempSync('voice_probe');
    File('${dir.path}/t.wav').writeAsBytesSync(_wav(2));
    File('${dir.path}/silent.wav').writeAsBytesSync(_wav(2, silent: true));
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('libmpv accepts the filter at 0, 0.5 and 1, and it does what it says', () async {
    final r = <double, ({double l, double r})>{};
    for (final level in [1.0, 0.5, 0.0]) {
      final o = await _render('${dir.path}/t.wav', '${dir.path}/o$level.wav', level);
      expect(o.errors, isEmpty, reason: 'level $level');
      if (level == 1.0) {
        expect(o.af, isEmpty); // no filter: mpv writes s16 here, not the float the analysis reads
        continue;
      }
      expect(o.af, contains('lavfi'));
      final centre = _amp(o.pcm, 1000), bass = _amp(o.pcm, 60), side = _amp(o.pcm, 2000);
      // ignore: avoid_print
      print('level $level af=${o.af}\n  1k L/R ${centre.l.toStringAsFixed(3)}/${centre.r.toStringAsFixed(3)}'
          '  60 ${bass.l.toStringAsFixed(3)}/${bass.r.toStringAsFixed(3)}'
          '  2k ${side.l.toStringAsFixed(3)}/${side.r.toStringAsFixed(3)}');
      r[level] = centre;
      expect(bass.l, greaterThan(0.2), reason: 'the bass stays');
    }
    expect(r[0.0]!.l, lessThan(0.1), reason: 'the centre is gone at 0');
    expect(r[0.5]!.l, inInclusiveRange(0.1, 0.2), reason: 'half at 0.5');
  });

  test('the filter and scaletempo (speed 1.25) live together', () async {
    final o = await _render('${dir.path}/t.wav', '${dir.path}/s.wav', 0.5, speed: 1.25);
    expect(o.errors, isEmpty);
    expect(o.af, allOf(contains('scaletempo'), contains('lavfi')));
    // ignore: avoid_print
    print('speed 1.25 af=${o.af}');
    expect(o.pcm.length, greaterThan(100000));
  });

  test('through just_audio: level and speed change while playing, no error logged', () async {
    final logs = <String>[];
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen((r) {
      if (r.level >= Level.WARNING) logs.add('${r.loggerName}: ${r.message}');
    });
    final filter = DesktopVoiceFilter();
    final p = AudioPlayer(
      audioLoadConfiguration: AudioLoadConfiguration(
        darwinLoadControl: DarwinLoadControl(preferredPeakBitRate: filter.preferredPeakBitRate),
      ),
    );
    await filter.setLevel(0.5); // before the native player exists
    await p.setFilePath('${dir.path}/silent.wav');
    await p.setSpeed(1.25);
    await p.play();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await filter.setLevel(0.0);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await p.setSpeed(1.0);
    await filter.setLevel(1.0);
    await filter.setLevel(null);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(p.position, greaterThan(Duration.zero));
    await p.dispose();
    await sub.cancel();
    expect(logs, isEmpty);
  });
}
