import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/app_log.dart';
import '../online/youtube_service.dart' show YtResult;

/// How a suggestion ended.
enum SuggestionOutcome { queued, skipped, heard, downloaded, disliked }

class SuggestionRecord {
  const SuggestionRecord({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.seedTitle,
    required this.at,
    required this.outcome,
  });

  final String videoId, title, artist;

  /// The library song the suggestion is «similar to».
  final String seedTitle;
  final DateTime at;
  final SuggestionOutcome outcome;

  SuggestionRecord withOutcome(SuggestionOutcome o) => SuggestionRecord(
    videoId: videoId,
    title: title,
    artist: artist,
    seedTitle: seedTitle,
    at: at,
    outcome: o,
  );

  Map<String, Object?> toJson() => {
    'id': videoId,
    'title': title,
    'artist': artist,
    'seed': seedTitle,
    'at': at.millisecondsSinceEpoch,
    'out': outcome.name,
  };

  static SuggestionRecord? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['at'] is! int) return null;
    return SuggestionRecord(
      videoId: j['id'] as String,
      title: '${j['title'] ?? ''}',
      artist: '${j['artist'] ?? ''}',
      seedTitle: '${j['seed'] ?? ''}',
      at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      outcome: SuggestionOutcome.values.firstWhere(
        (o) => o.name == j['out'],
        orElse: () => SuggestionOutcome.queued,
      ),
    );
  }
}

/// `suggestions.json`: the last [max] suggestions with their outcome. It
/// keeps a song from coming back for 30 days and remembers «Non mi piace».
/// Queries are synchronous once [load] is done.
class SuggestionLog {
  SuggestionLog({
    required this.file,
    this.max = 500,
    this.writeDelay = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Future<File> Function() file;
  final int max;
  final Duration writeDelay;
  final DateTime Function() _now;

  final List<SuggestionRecord> _records = []; // oldest first
  Future<void>? _loading;
  Timer? _timer;
  Future<void> _writing = Future.value();

  /// Reads the file once; later calls wait for the same read.
  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final f = await file();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is List) {
          _records.insertAll(0, [
            for (final j in raw) ?SuggestionRecord.fromJson(j),
          ]);
        }
      }
    } on Object catch (e, st) {
      AppLog.w('suggestion log unreadable, starting empty', e, st);
    }
  }

  /// Newest first.
  List<SuggestionRecord> get recent => _records.reversed.toList();

  int get length => _records.length;

  /// Suggested (whatever came of it) in the last [days] days.
  bool recentlySuggested(String videoId, {int days = 30}) {
    final limit = _now().subtract(Duration(days: days));
    return _records.any((r) => r.videoId == videoId && r.at.isAfter(limit));
  }

  /// A new suggestion, as «queued».
  void add({
    required String videoId,
    required String title,
    required String artist,
    required String seedTitle,
  }) {
    _records.add(
      SuggestionRecord(
        videoId: videoId,
        title: title,
        artist: artist,
        seedTitle: seedTitle,
        at: _now(),
        outcome: SuggestionOutcome.queued,
      ),
    );
    while (_records.length > max) {
      // A «Non mi piace» goes last: it must outlive the 30 days.
      final i = _records.indexWhere(
        (r) => r.outcome != SuggestionOutcome.disliked,
      );
      _records.removeAt(i < 0 ? 0 : i);
    }
    _scheduleWrite();
  }

  /// [r] was queued (or shown) as a suggestion similar to [seedTitle]. Once
  /// per 30 days: a replay of the list must not crowd out the memory.
  void addSuggestion(YtResult r, String seedTitle) {
    if (recentlySuggested(r.id)) return;
    add(
      videoId: r.id,
      title: r.title,
      artist: r.artists.isEmpty ? r.channel : r.artists.join(', '),
      seedTitle: seedTitle,
    );
  }

  /// The latest record of [videoId], if any.
  SuggestionRecord? latest(String videoId) {
    final i = _records.lastIndexWhere((r) => r.videoId == videoId);
    return i < 0 ? null : _records[i];
  }

  /// Sets the outcome of the latest record of [videoId].
  void setOutcome(String videoId, SuggestionOutcome outcome) {
    final i = _records.lastIndexWhere((r) => r.videoId == videoId);
    if (i < 0) return;
    _records[i] = _records[i].withOutcome(outcome);
    _scheduleWrite();
  }

  /// Forgets the history but keeps «Non mi piace»: those are the user's
  /// choices, not a cache.
  Future<void> clear() async {
    _records.removeWhere((r) => r.outcome != SuggestionOutcome.disliked);
    await flush();
  }

  void _scheduleWrite() {
    _timer?.cancel();
    _timer = Timer(writeDelay, () => unawaited(flush()));
  }

  Future<void> flush() {
    _timer?.cancel();
    // Serialized: a write never starts before the previous one ends, and
    // flush() completes only when the file is closed.
    return _writing = _writing.then((_) => _writeNow());
  }

  /// Cancels the pending debounce, writes what is left and waits for it.
  Future<void> dispose() async {
    await flush();
    _timer?.cancel();
  }

  Future<void> _writeNow() async {
    try {
      final f = await file();
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode([for (final r in _records) r.toJson()]));
    } on Object catch (e, st) {
      AppLog.w('suggestion log write failed', e, st);
    }
  }
}
