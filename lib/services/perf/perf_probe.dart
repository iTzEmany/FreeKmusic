import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FrameTiming, PlatformDispatcher;

import 'package:drift/drift.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_log.dart';
import '../../core/frame_stats.dart';
import '../../core/paths.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/folder_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../../data/settings/settings_store.dart';
import '../covers/cover_store.dart';
import '../scanner/library_scanner.dart';
import '../tags/audio_metadata_tag_reader.dart';

/// True only in builds made by `scripts/perf_device.py`
/// (`--dart-define=CODECORE_PERF=true`), installed as the separate app
/// `com.freekmusic.player.perf`: everything below touches that app's own data.
const kPerfBuild = bool.fromEnvironment('CODECORE_PERF');

/// True in builds made by `scripts/perf_device.py --real`
/// (`--dart-define=CODECORE_PERF_REAL=true`) installed over the real app: it only
/// records the frames, and never writes settings or the database.
const kPerfReal = bool.fromEnvironment('CODECORE_PERF_REAL');

/// Recording on (`mark`, `start`); the data preparation stays under [kPerfBuild].
const kPerfProbe = kPerfBuild || kPerfReal;

/// The measures of phase 28, as JSON lines in `perf/events.jsonl` of the app's
/// external folder (adb reads it without root): time from `main` to the first
/// frame, the library scan, and the frames of every burst of activity (a
/// scroll, a page opening) once the screen has been still for 1.2 s.
class PerfProbe {
  PerfProbe._(this._out);

  static final _marks = <String, int>{};

  /// Notes how far `main` has got (perf builds only: call it under
  /// `if (kPerfProbe)`), written with the first frame.
  static void mark(String step, Stopwatch sinceMain) => _marks[step] = sinceMain.elapsedMilliseconds;

  final File _out;
  final _frames = <FrameSample>[];
  Timer? _idle;
  final _burst = Stopwatch();
  Future<void> _writing = Future.value();

  /// Before `runApp`: no onboarding; the background completion on (tags and
  /// credits, phase 53: it must not cost frames), lyrics left to the fake ones.
  static Future<void> prepareSettings(SettingsStore store) => store.writeSettings(
      store.readSettings().copyWith(
          onboardingDone: true, ytNoticeSeen: true, autoEnrich: true, creditsDetails: true,
          autoLyrics: false));

  static Future<void> start({
    required AppDatabase db,
    required CoverStore covers,
    required Stopwatch sinceMain,
    bool prepare = kPerfBuild, // false on the real app: it must stay untouched
  }) async {
    final external = Platform.isAndroid ? (await getExternalStorageDirectory())?.path : null;
    final dir = Directory(p.join(external ?? await appSupportDir(), 'perf'));
    await dir.create(recursive: true);
    final probe = PerfProbe._(File(p.join(dir.path, 'events.jsonl')));
    unawaited(WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
      probe._log({'event': 'firstFrame', 'ms': sinceMain.elapsedMilliseconds});
      probe._log({'event': 'startup', ..._marks});
    }));
    SchedulerBinding.instance.addTimingsCallback(probe._onTimings);
    if (external != null && prepare) unawaited(probe._prepareLibrary(db, covers, external));
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_frames.isEmpty) _burst..reset()..start();
    _frames.addAll(timings.map(FrameSample.of));
    _idle?.cancel();
    // Playback repaints without pause: cut the burst so it lands inside its scenario.
    if (_burst.elapsedMilliseconds > 2000) {
      _flush();
      return;
    }
    _idle = Timer(const Duration(milliseconds: 1200), _flush);
  }

  void _flush() {
    if (_frames.isEmpty) return;
    final display = PlatformDispatcher.instance.displays.firstOrNull;
    final stats = summarizeFrames(_frames, budgetMs: 1000 / (display?.refreshRate ?? 60));
    // The raw times too, so the script can merge the bursts of one scenario.
    final raw = [
      for (final f in _frames)
        [double.parse(f.buildMs.toStringAsFixed(1)), double.parse(f.rasterMs.toStringAsFixed(1))],
    ];
    _frames.clear();
    _log({'event': 'burst', ...stats.toJson(), 'raw': raw});
  }

  void _log(Map<String, Object?> event) {
    final line = jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, ...event});
    _writing = _writing.then((_) async {
      try {
        await _out.writeAsString('$line\n', mode: FileMode.append);
      } on FileSystemException catch (e, st) {
        AppLog.w('perf log write failed', e, st);
      }
    });
  }

  /// The folder the script filled (the app's own `Music`) is added and scanned
  /// once; then every track gets lyrics and curiosities as long as those of an
  /// enriched library, so the lists carry their real weight.
  Future<void> _prepareLibrary(AppDatabase db, CoverStore covers, String external) async {
    try {
      final music = Directory(p.join(external, 'Music'));
      final folders = FolderRepository(db);
      if (!await music.exists() || (await folders.getAll()).isNotEmpty) return;
      final folder = await folders.add(music.path);
      final watch = Stopwatch()..start();
      final tracks = TrackRepository(db);
      await for (final _ in LibraryScanner(const AudioMetadataTagReader(), tracks, covers)
          .scan(folder)) {}
      final n = await tracks.countAll();
      _log({'event': 'scan', 'tracks': n, 'ms': watch.elapsedMilliseconds});
      await (db.update(db.tracks)..where((t) => t.lyricsPlain.isNull())).write(TracksCompanion(
        lyricsPlain: Value(_lyrics),
        lyricsSynced: Value(_synced),
        curiosities: Value(_curiosity),
      ));
      _log({'event': 'heavyColumns', 'tracks': n});
    } on Object catch (e, st) {
      AppLog.e('perf library preparation failed', e, st);
    }
  }
}

final _lyrics = [
  for (var i = 0; i < 40; i++) 'Verso $i della canzone di prova, lungo come quello di un testo vero',
].join('\n');

final _synced = [
  for (var i = 0; i < 40; i++)
    '[${(i * 5 ~/ 60).toString().padLeft(2, '0')}:${(i * 5 % 60).toString().padLeft(2, '0')}.00] '
        'Verso $i della canzone di prova, lungo come quello di un testo vero',
].join('\n');

final _curiosity = '${List.filled(12, 'Una curiosità sul brano, come la prima parte di una '
        'pagina di Wikipedia.').join(' ')}\nhttps://it.wikipedia.org/wiki/Prova';
