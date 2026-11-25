import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:codecore/app.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/crossfade_engine.dart';
import 'package:codecore/services/audio/just_audio_backend.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// A mono 16-bit WAV of a sine wave, [seconds] long: a real audio file that
/// every platform decoder reads, small and made on the spot.
Uint8List sineWav(double seconds, {double hz = 440, int rate = 22050}) {
  final n = (seconds * rate).round();
  final data = ByteData(44 + n * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(44 + i * 2, (math.sin(2 * math.pi * hz * i / rate) * 8000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// The real app (real audio backend, real scanner) on a database and a music
/// folder in a temporary directory: nothing of the user's is touched.
class AppUnderTest {
  AppUnderTest._(this.dir, this.db, this.handler, this.store, this.musicDir, this.coversDir);

  final Directory dir, musicDir, coversDir;
  final AppDatabase db;
  final CodecoreAudioHandler handler;
  final SettingsStore store;

  /// Four short files, `Tone A.wav` … `Tone D.wav`.
  static const names = ['Tone A', 'Tone B', 'Tone C', 'Tone D'];

  static Future<AppUnderTest> create({double seconds = 2.5}) async {
    // Same as lib/main.dart: desktop has no native just_audio plugin.
    if (Platform.isLinux || Platform.isWindows) JustAudioMediaKit.ensureInitialized();
    SharedPreferences.setMockInitialValues({'onboardingDone': true, 'onboardingFinished': true, 'autoEnrich': false, 'autoLyrics': false});
    final dir = await Directory.systemTemp.createTemp('codecore-it');
    final music = Directory(p.join(dir.path, 'music'))..createSync();
    for (var i = 0; i < names.length; i++) {
      File(p.join(music.path, '${names[i]}.wav')).writeAsBytesSync(sineWav(seconds, hz: 330.0 + i * 110));
    }
    final covers = Directory(p.join(dir.path, 'covers'))..createSync();
    final db = AppDatabase(NativeDatabase(File(p.join(dir.path, 'test.sqlite'))));
    final tracks = TrackRepository(db);
    final handler = CodecoreAudioHandler(
      CrossfadeEngine(() => JustAudioBackend(withEqualizer: false)),
      PlayQueue(),
      tracks,
      onError: (_) {},
      history: PlayHistoryRepository(db),
    );
    return AppUnderTest._(dir, db, handler, await SettingsStore.open(), music, covers);
  }

  List<Override> get overrides => [
        systemDeviceNameProvider.overrideWithValue('Test'),
        databaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(store),
        audioHandlerProvider.overrideWithValue(handler),
        playerErrorsProvider.overrideWithValue(const Stream.empty()),
        coversDirProvider.overrideWithValue(coversDir),
      ];

  Widget get app => ProviderScope(overrides: overrides, child: const CodecoreApp());

  /// Pumps [app]; call again after [restart] to get a fresh `ProviderScope`
  /// over the same database, like a new launch.
  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(app);
    await settle(tester);
  }

  Future<void> restart(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await launch(tester);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await handler.dispose();
    await db.close();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // The platform may still hold a file for a moment; it is a temp folder.
    }
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CodecoreApp)));

  /// Folder added and scanned, as the folder picker would have done.
  Future<void> addMusicFolder(WidgetTester tester) async {
    final c = container(tester);
    await c.read(folderRepositoryProvider).add(musicDir.path);
    await c.read(scanStateProvider.notifier).scanAll();
  }
}

/// Real time: lets the engine, streams and animations move.
Future<void> settle(WidgetTester tester, {Duration by = const Duration(milliseconds: 600)}) async {
  final end = DateTime.now().add(by);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [test] is true, or fails after [within].
Future<void> waitFor(WidgetTester tester, bool Function() test,
    {Duration within = const Duration(seconds: 5), String? reason}) async {
  final end = DateTime.now().add(within);
  while (!test()) {
    if (DateTime.now().isAfter(end)) fail(reason ?? 'condition not met within $within');
    await tester.pump(const Duration(milliseconds: 100));
  }
}
