// Task 127.1 probe (temporary): does libmpv of this machine accept the `af`
// voice filter of `voiceFilterString`, together with the speed's `scaletempo`?
// Run: xvfb-run -a flutter test integration_test/voice_filter_probe_test.dart -d linux
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:codecore/services/audio/crossfade_engine.dart';
import 'package:codecore/services/audio/desktop_voice_filter.dart';
import 'package:codecore/services/audio/just_audio_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_media_kit/mediakit_player.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart' show SetSpeedRequest;
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';

const _sr = 44100;

/// Stereo PCM16 WAV, [seconds] long. Default: 300 Hz and 1 kHz (0.2) and 60 Hz
/// (0.3) in the centre, 2 kHz (0.2) in antiphase (side only). [loud]: a centred
/// 60 Hz at 0.99. [silent]: zeros.
Uint8List _wav(double seconds, {bool silent = false, bool loud = false}) {
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
      final c = loud ? 0.99 * s(60, t) : 0.2 * s(300, t) + 0.2 * s(1000, t) + 0.3 * s(60, t);
      final side = loud ? 0.0 : 0.2 * s(2000, t);
      d.setInt16(44 + i * 4, ((c + side) * 32767).round(), Endian.little);
      d.setInt16(46 + i * 4, ((c - side) * 32767).round(), Endian.little);
    }
  }
  return d.buffer.asUint8List();
}

/// Amplitude of [hz] in the left/right channel of mpv's `ao=pcm` output (float32).
({double l, double r}) _amp(Uint8List file, double hz, {int start = 20000}) {
  var i = 12;
  while (String.fromCharCodes(file.sublist(i, i + 4)) != 'data') {
    i += 8 + ByteData.sublistView(file, i + 4, i + 8).getUint32(0, Endian.little);
  }
  final v = ByteData.sublistView(file, i + 8);
  final frames = v.lengthInBytes ~/ 8;
  double one(int ch) {
    var re = 0.0, im = 0.0, n = 0;
    for (var k = start; k < math.min(frames, start + 40000); k++, n++) {
      final x = v.getFloat32(k * 8 + ch * 4, Endian.little);
      re += x * math.cos(2 * math.pi * hz / _sr * k);
      im += x * math.sin(2 * math.pi * hz / _sr * k);
    }
    return 2 * math.sqrt(re * re + im * im) / n;
  }

  return (l: one(0), r: one(1));
}

double _db(double amp, double ref) => 20 * math.log(math.max(amp, 1e-9) / ref) / math.ln10;

/// Largest sample of the float32 `ao=pcm` output.
double _peak(Uint8List file) {
  var i = 12;
  while (String.fromCharCodes(file.sublist(i, i + 4)) != 'data') {
    i += 8 + ByteData.sublistView(file, i + 4, i + 8).getUint32(0, Endian.little);
  }
  final v = ByteData.sublistView(file, i + 8);
  var m = 0.0;
  for (var k = 0; k + 4 <= v.lengthInBytes; k += 4) {
    m = math.max(m, v.getFloat32(k, Endian.little).abs());
  }
  return m;
}

/// Renders [wav] through mpv to a file. [level] sets `af` before the start; with
/// [thenLevel] the player starts paused and moves the running filter to that
/// level with `af-command`. [chainBuilds] counts how many times mpv built its
/// audio chain.
Future<({Uint8List pcm, String af, List<String> errors, int chainBuilds})> _render(
    String wav, String out, double? level,
    {double speed = 1.0, double? thenLevel}) async {
  final player = Player(configuration: const PlayerConfiguration(pitch: true, logLevel: MPVLogLevel.v));
  final errors = <String>[];
  var builds = 0;
  final subs = [
    player.stream.log.listen((e) {
      if (e.prefix == 'af' && e.text.startsWith('[in]')) builds++;
      if (e.level == 'error' || e.level == 'fatal') errors.add('${e.prefix}: ${e.text}');
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
  if (thenLevel != null) await native.setProperty('pause', 'yes');
  final done = player.stream.completed.firstWhere((c) => c).timeout(const Duration(seconds: 15));
  await player.open(Media(wav), play: thenLevel == null);
  if (thenLevel != null) {
    await Future<void>.delayed(const Duration(seconds: 1));
    final before = builds;
    await native.command(voiceFilterCommand(thenLevel));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print('chain builds before/after the command: $before/$builds');
    expect(builds, before, reason: 'af-command must not rebuild the chain');
    await player.play();
  }
  await done;
  final af = await native.getProperty('af');
  await player.dispose();
  for (final s in subs) {
    await s.cancel();
  }
  return (pcm: File(out).readAsBytesSync(), af: af, errors: errors, chainBuilds: builds);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() {
    JustAudioMediaKit.ensureInitialized();
    dir = Directory.systemTemp.createTempSync('voice_probe');
    File('${dir.path}/t.wav').writeAsBytesSync(_wav(2));
    File('${dir.path}/t6.wav').writeAsBytesSync(_wav(6));
    File('${dir.path}/loud.wav').writeAsBytesSync(_wav(2, loud: true));
    File('${dir.path}/silent.wav').writeAsBytesSync(_wav(2, silent: true));
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  void check(Uint8List pcm,
      {required double centreMaxDb, required double bassTolDb, required String why, int start = 20000}) {
    final c3 = _amp(pcm, 300, start: start),
        c1 = _amp(pcm, 1000, start: start),
        bass = _amp(pcm, 60, start: start),
        side = _amp(pcm, 2000, start: start);
    // ignore: avoid_print
    print('$why: 300 Hz ${_db(c3.l, 0.2).toStringAsFixed(1)} dB, 1 kHz ${_db(c1.l, 0.2).toStringAsFixed(1)} dB, '
        '60 Hz ${_db(bass.l, 0.3).toStringAsFixed(1)} dB, side 2 kHz ${_db(side.l, 0.2).toStringAsFixed(1)} dB, peak ${_peak(pcm).toStringAsFixed(3)}');
    expect(_db(c3.l, 0.2), lessThan(centreMaxDb), reason: '$why: 300 Hz centre');
    expect(_db(c1.l, 0.2), lessThan(centreMaxDb), reason: '$why: 1 kHz centre');
    expect(_db(bass.l, 0.3), inInclusiveRange(-bassTolDb, bassTolDb), reason: '$why: the bass stays');
    expect(_db(bass.r, 0.3), inInclusiveRange(-bassTolDb, bassTolDb), reason: '$why: the bass stays (right)');
    expect(_db(side.l, 0.2), inInclusiveRange(-0.5, 0.5), reason: '$why: the side is untouched');
    if (start == 20000) expect(_peak(pcm), lessThan(0.9 + 0.01), reason: '$why: nothing above the input peak');
  }

  test('libmpv accepts the filter at 0 and 0.5 and 1, and it does what it says', () async {
    final none = await _render('${dir.path}/t.wav', '${dir.path}/o1.wav', 1.0);
    expect(none.errors, isEmpty);
    expect(none.af, isEmpty);
    final half = await _render('${dir.path}/t.wav', '${dir.path}/o5.wav', 0.5);
    expect(half.errors, isEmpty);
    expect(half.af, contains('lavfi'));
    // At 0.5 the centre is about 6 dB down (the bass dips about 2 dB at the crossover).
    expect(_db(_amp(half.pcm, 1000).l, 0.2), inInclusiveRange(-7, -5));
    final zero = await _render('${dir.path}/t.wav', '${dir.path}/o0.wav', 0.0);
    expect(zero.errors, isEmpty);
    check(zero.pcm, centreMaxDb: -20, bassTolDb: 1, why: 'level 0');
  });

  test('no level goes above a 0 dBFS centred bass', () async {
    for (final level in [0.0, 0.25, 0.5, 0.75]) {
      final o = await _render('${dir.path}/loud.wav', '${dir.path}/l$level.wav', level);
      expect(o.errors, isEmpty);
      final peak = _peak(o.pcm);
      // ignore: avoid_print
      print('loud bass at level $level: peak ${peak.toStringAsFixed(3)} (input 0.990)');
      expect(peak, lessThan(0.99 + 0.005), reason: 'level $level');
    }
  });

  test('af-command moves a running filter from 0.5 to 0 without rebuilding the chain', () async {
    final o = await _render('${dir.path}/t6.wav', '${dir.path}/c.wav', 0.5, thenLevel: 0.0);
    expect(o.errors, isEmpty);
    expect(o.chainBuilds, 1, reason: 'the chain was built once, at the start');
    // mpv has already filtered about 1.5 s ahead when the command arrives: look at the end.
    check(o.pcm, centreMaxDb: -20, bassTolDb: 1, why: 'after af-command to 0', start: 4 * _sr);
  });

  test('the filter and scaletempo (speed 1.25) live together', () async {
    final o = await _render('${dir.path}/t.wav', '${dir.path}/s.wav', 0.5, speed: 1.25);
    expect(o.errors, isEmpty);
    expect(o.af, allOf(contains('scaletempo'), contains('lavfi')));
    expect(o.pcm.length, greaterThan(100000));
  });

  test('MediaKitPlayer: after setSpeed the af still has the filter (and the speed)', () async {
    final p = MediaKitPlayer('probe', voiceTag: 900);
    await p.ready();
    final native = p.player.platform! as NativePlayer;
    await p.applyVoiceFilter(voiceFilterString(0.5));
    expect(await native.getProperty('af'), allOf(contains('lavfi'), isNot(contains('scaletempo'))));
    await p.setSpeed(SetSpeedRequest(speed: 1.25));
    expect(await native.getProperty('af'), allOf(contains('scaletempo'), contains('lavfi')));
    await p.applyVoiceFilter('');
    expect(await native.getProperty('af'), allOf(contains('scaletempo'), isNot(contains('lavfi'))));
    await p.release();
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
    await filter.setLevel(0.2); // af-command
    await filter.setLevel(0.0);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await p.setSpeed(1.0);
    await filter.setLevel(1.0); // off: the filter is removed
    await filter.setLevel(0.4); // on again: built once
    await filter.setLevel(double.nan);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(p.position, greaterThan(Duration.zero));
    await p.dispose();
    await sub.cancel();
    expect(logs, isEmpty);
  });

  test('CrossfadeEngine of JustAudioBackends has a voice filter and a level change does not error', () async {
    final logs = <String>[];
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen((r) {
      if (r.level >= Level.WARNING) logs.add('${r.loggerName}: ${r.message}');
    });
    final engine = CrossfadeEngine(() => JustAudioBackend(withEqualizer: true));
    expect(engine.voiceFilter, isNotNull);
    await engine.voiceFilter!.setLevel(0.5);
    await engine.load('${dir.path}/silent.wav');
    await engine.play();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await engine.voiceFilter!.setLevel(0.1);
    await engine.voiceFilter!.setLevel(null);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await engine.dispose();
    await sub.cancel();
    expect(logs, isEmpty);
  });
}
