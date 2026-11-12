import 'dart:async';
import 'dart:convert';
import 'dart:math' show max;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/clock.dart';
import '../data/db/app_database.dart';
import '../data/repositories/activity_log_repository.dart';
import '../data/repositories/import_repository.dart';
import '../services/import/import_chain.dart';
import '../services/import/playlist_import_service.dart';
import 'activity_providers.dart';
import 'database_providers.dart';
import 'import_providers.dart';
import 'library_providers.dart';
import 'online_providers.dart';
import 'podcast_providers.dart';
import 'second_opinion_providers.dart';
import 'youtube_providers.dart';

/// One line of the Registro: something that ended, and when.
class LogEntry {
  const LogEntry({
    required this.at,
    this.id,
    this.item,
    this.importName,
    this.event,
    this.detail,
    this.correction,
  });

  final DateTime at;

  /// The id of the stored row; null for a line not stored yet.
  final int? id;

  /// A download, an episode, a transfer or a background job that ended.
  final ActivityItem? item;

  /// An import that ended or stopped, with why.
  final String? importName;
  final ImportEventKind? event;

  /// Optional JSON-encodable extras kept with the row (e.g. the song ids of an
  /// enrichment round).
  final Map<String, Object?>? detail;

  /// The stored row of a title/artist correction (D-308), for «Ripristina».
  final ActivityLogRow? correction;

  /// A job that left `running` before its work was done (see [ActivityLogNotifier]).
  bool get stopped => detail?['stopped'] == true || noAnswer;

  /// A completion that stopped for lack of answers.
  bool get noAnswer => detail?['noAnswer'] == true;

  /// An import line still counting (it turns into its ending when it ends).
  bool get progress => detail?['progress'] == true;

  /// Why the file of a correction was not written (a [TagWriteReason] name).
  String? get file => detail?['file'] is String ? detail!['file'] as String : null;

  /// The title and artist a correction replaced, and the ones it put.
  ({String title, String? artist})? get oldIdent => _ident(detail?['old']);
  ({String title, String? artist})? get newIdent => _ident(detail?['new']);

  static ({String title, String? artist})? _ident(Object? m) =>
      m is Map ? (title: '${m['title'] ?? ''}', artist: m['artist'] as String?) : null;

  /// The filter (D-365) this line belongs to, apart from «Errori».
  LogFilter get category => categoryOfKind(correction != null ? _correctionKind : item?.kind.name ?? _importKind);

  /// The filter of a stored `kind` (an unknown one is shown as a scan line, so Libreria).
  static LogFilter categoryOfKind(String kind) => switch (kind) {
    _correctionKind => LogFilter.correction,
    'download' => LogFilter.download,
    'enrich' || 'enrichBackground' || 'secondOpinion' => LogFilter.enrich,
    _ => LogFilter.library,
  };

  /// A correction that can be put back (the failed file write of «Accetta
  /// tutte» is a correction row without old/new).
  bool get revertible => correction != null && oldIdent != null;

  bool get failed => isLogError(stored: _storedFailed, noAnswer: noAnswer);

  /// What the `failed` column holds: the counts in the DB tell «stopped» apart by the detail.
  bool get _storedFailed =>
      (item?.failed ?? false) ||
      (correction != null && correction!.failed != 0) ||
      (event != null &&
          event != ImportEventKind.completed &&
          event != ImportEventKind.planned);

  static const _importKind = 'import';
  static const _correctionKind = 'correction';

  LogEntry.fromRow(ActivityLogRow r)
    : id = r.id,
      at = DateTime.fromMillisecondsSinceEpoch(r.at),
      detail = _decode(r.detail),
      correction = r.kind == _correctionKind ? r : null,
      importName = r.kind == _importKind && _decode(r.detail)?['progress'] != true ? r.name : null,
      event = r.kind == _importKind && _decode(r.detail)?['progress'] != true
          ? ImportEventKind.values.asNameMap()[_decode(r.detail)?['event']] ??
                (r.failed != 0 ? ImportEventKind.failing : ImportEventKind.completed)
          : null,
      item = (r.kind == _importKind && _decode(r.detail)?['progress'] != true) || r.kind == _correctionKind
          ? null
          : ActivityItem(
              kind: _kindOf(r.kind),
              key: 'log-${r.id}',
              name: r.name.isEmpty ? null : r.name,
              done: r.done,
              total: r.total,
              running: false,
              failed: r.failed != 0,
            );

  /// An unknown kind (a newer app wrote it) is shown as a plain scan line.
  static ActivityKind _kindOf(String name) {
    final k = ActivityKind.values.asNameMap()[name];
    if (k == null) AppLog.w('unknown activity_log kind $name');
    return k ?? ActivityKind.scan;
  }

  static Map<String, Object?>? _decode(String? s) {
    if (s == null) return null;
    try {
      final j = jsonDecode(s);
      if (j is Map<String, Object?>) return j;
    } on FormatException catch (e, st) {
      AppLog.w('bad activity_log detail', e, st);
    }
    return null;
  }

  Future<int> _save(ActivityLogRepository repo) {
    final i = item;
    final d = {if (event != null) 'event': event!.name, ...?detail};
    return repo.add(
      at: at.millisecondsSinceEpoch,
      kind: i?.kind.name ?? _importKind,
      name: i?.name ?? importName ?? '',
      done: i?.done ?? 0,
      total: i?.total ?? 0,
      failed: _storedFailed,
      detail: d.isEmpty ? null : jsonEncode(d),
    );
  }
}

/// The «Errori» rule, for a line and for the counts over the database: a line
/// that failed, unless it is a completion saved as failed but shown as stopped.
bool isLogError({required bool stored, required bool noAnswer}) => stored && !noAnswer;

/// The chips above the Registro. «Errori» is any line that failed.
enum LogFilter { all, download, library, enrich, correction, errors }

/// One row of a day: a line, or the finished downloads of that day in
/// [group] (newest first, [entry] is the first of them).
class LogRow {
  const LogRow(this.entry, [this.group = const []]);

  final LogEntry entry;
  final List<LogEntry> group;
}

class LogDay {
  const LogDay(this.day, this.rows);

  final DateTime day;
  final List<LogRow> rows;
}

bool _doneDownload(LogEntry e) =>
    e.item?.kind == ActivityKind.download && !e.failed;

bool _inFilter(LogEntry e, LogFilter f) => switch (f) {
  LogFilter.all => true,
  LogFilter.errors => e.failed,
  _ => e.category == f,
};

/// How many lines each filter would show.
Map<LogFilter, int> logCounts(List<LogEntry> entries) => {
  for (final f in LogFilter.values)
    f: entries.where((e) => _inFilter(e, f)).length,
};

/// [entries] (newest first) under [filter], grouped by local day. Two or more
/// finished downloads of one day become one row, where the first sits.
List<LogDay> groupLog(List<LogEntry> entries, LogFilter filter) {
  final byDay = <DateTime, List<LogEntry>>{};
  for (final e in entries.where((e) => _inFilter(e, filter))) {
    byDay.putIfAbsent(DateTime(e.at.year, e.at.month, e.at.day), () => []).add(e);
  }
  return [
    for (final d in byDay.entries)
      LogDay(d.key, () {
        final downloads = d.value.where(_doneDownload).toList();
        var placed = false;
        return [
          for (final e in d.value)
            if (downloads.length < 2 || !_doneDownload(e))
              LogRow(e)
            else if (!placed && (placed = true))
              LogRow(e, downloads),
        ];
      }()),
  ];
}

/// The loaded pages of the Registro (newest first) and how many rows exist.
class ActivityLogState {
  const ActivityLogState(this.entries, this.total, [this.dbCounts]);

  final List<LogEntry> entries;
  final int total;

  /// Per filter over the whole Registro; without it, over the loaded [entries].
  final Map<LogFilter, int>? dbCounts;

  Map<LogFilter, int> get counts => dbCounts ?? logCounts(entries);

  bool get hasMore => entries.length < total;
}

/// What ended in the background, kept in the database for 30 days. Kept alive
/// from the app's root, so the times are the real ones also while the Activity
/// centre is closed. Other code adds a line with [add].
class ActivityLogNotifier extends Notifier<ActivityLogState> {
  static const pageSize = 50;

  /// Jobs that leave one line when they leave `running` (the others write
  /// their own: downloads, episodes, transfers, imports, second opinion, the
  /// podcast refresh and radio check, and the background completion, which
  /// know how they went).
  static const _oneLine = {
    ActivityKind.scan,
    ActivityKind.enrich,
    ActivityKind.cleanup,
    ActivityKind.releases,
  };

  final _logged = <String>{};
  final _importRow = <String, int>{}; // import item key -> its Registro row
  final _lastCount = <String, (int, int)>{}; // import item key -> the N/M its row last got
  final _ended = <String>{}; // finished imports whose item may still tick once
  Future<void> _tail = Future.value();
  bool _paging = false;

  bool _refreshQueued = false;

  ActivityLogRepository get _repo => ref.read(activityLogRepositoryProvider);

  static DateTime _now() => DateTime.fromMillisecondsSinceEpoch(nowMs());

  @override
  ActivityLogState build() {
    ref.listen<ActivityState>(activityProvider, (prev, s) => _record(prev, s));
    ref.listen<AsyncValue<ImportEvent>>(importEventsProvider, (_, e) {
      final event = e.value;
      if (event != null) unawaited(_recordImport(event));
    });
    ref.listen<SecondOpinionState>(secondOpinionJobProvider, (prev, s) {
      if (prev == null || !prev.running || s.running) return;
      add(
        LogEntry(
          at: _now(),
          item: ActivityItem(
            kind: ActivityKind.secondOpinion,
            key: 'secondOpinion-${DateTime.now().microsecondsSinceEpoch}',
            name: null,
            done: s.done,
            total: s.total,
            running: false,
            failed: s.throttled,
          ),
        ),
      );
    });
    // Corrections are written straight to the database: the table tells when to read again.
    final sub = _repo.changes().listen((_) => unawaited(_refresh()));
    ref.onDispose(sub.cancel);
    unawaited(prune());
    return const ActivityLogState([], 0);
  }

  /// Drops what is older than 30 days (at start and when the Registro opens); the loaded pages are read again if rows went.
  Future<void> prune() => _run(() async {
    final gone = await _repo.prune(nowMs());
    if (gone > 0 || state.entries.isEmpty) await _reloadPages();
  });

  /// Reads the pages loaded so far again (at least the first).
  Future<void> _reloadPages() async {
    final rows = await _repo.page(limit: max(pageSize, state.entries.length));
    final total = await _repo.count();
    final counts = await _counts(total);
    if (ref.mounted) state = ActivityLogState([for (final r in rows) LogEntry.fromRow(r)], total, counts);
  }

  /// Reads only the rows written since the newest one loaded and puts them in place; the
  /// counts are read once for the lot. A call while one is waiting joins it.
  Future<void> _refresh() {
    if (_refreshQueued) return _tail;
    _refreshQueued = true;
    return _run(() async {
      _refreshQueued = false;
      final known = state.entries;
      if (known.isEmpty) return _reloadPages(); // not the whole table: only a page
      final fresh = await _repo.newerThan(known.map((e) => e.id!).fold(0, max));
      if (fresh.isEmpty) return;
      final total = await _repo.count();
      final counts = await _counts(total);
      if (!ref.mounted) return;
      final all = [...known, for (final r in fresh) LogEntry.fromRow(r)]
        ..sort((a, b) => b.at != a.at ? b.at.compareTo(a.at) : b.id!.compareTo(a.id!));
      state = ActivityLogState(all, total, counts);
    });
  }

  /// What each filter shows, over every row (not only the loaded pages).
  Future<Map<LogFilter, int>> _counts(int total) async {
    final c = {for (final f in LogFilter.values) f: 0, LogFilter.all: total};
    for (final r in await _repo.countsByKind()) {
      c.update(LogEntry.categoryOfKind(r.kind), (v) => v + r.n);
      if (isLogError(stored: r.failed, noAnswer: r.noAnswer)) c.update(LogFilter.errors, (v) => v + r.n);
    }
    return c;
  }

  /// Database jobs one after the other, so the lines keep their order.
  Future<T?> _run<T>(Future<T> Function() job) {
    final done = _tail.then((_) async {
      try {
        return await job();
      } on Object catch (e, st) {
        AppLog.w('activity log write failed', e, st);
        return null;
      }
    });
    _tail = done;
    return done;
  }

  void _record(ActivityState? prev, ActivityState s) {
    final now = _now();
    for (final c in s.completed) {
      if (_logged.add(c.key)) add(LogEntry(at: now, item: c));
    }
    for (final r in s.running.where((r) => r.kind == ActivityKind.import)) {
      unawaited(_importProgress(r));
    }
    final still = {for (final r in s.running) r.key};
    _ended.removeWhere((k) => !still.contains(k));
    for (final r in prev?.running ?? const <ActivityItem>[]) {
      if (r.kind == ActivityKind.import && !still.contains(r.key)) unawaited(_dropIfCancelled(r.key));
      if (_oneLine.contains(r.kind) && !still.contains(r.key)) {
        // The last snapshot seen may be the one before the end: the batch
        // enrichment knows how it ended, so that is read instead.
        final end = r.kind == ActivityKind.enrich
            ? ref.read(enrichJobProvider).result
            : null;
        // Likewise the scan: its state keeps the last progress, which says «all done».
        final scanned = r.kind == ActivityKind.scan ? ref.read(scanStateProvider).progress : null;
        final done = end?.done ?? scanned?.done ?? r.done;
        final total = end?.total ?? scanned?.total ?? r.total;
        final failed = end?.failed ?? false;
        add(
          LogEntry(
            at: now,
            detail: end == null
                ? (total > 0 && done < total ? const {'stopped': true} : null)
                : end.logDetail,
            item: ActivityItem(
              kind: r.kind,
              key: r.key,
              name: r.name,
              done: done,
              total: total,
              running: false,
              // A scan that ended on an error says so in its line.
              failed:
                  failed ||
                  r.kind == ActivityKind.scan &&
                      ref.read(scanStateProvider).error != null,
            ),
          ),
        );
      }
    }
  }

  /// The one line of a running import: written once, then rewritten with the count.
  Future<void> _importProgress(ActivityItem r) => _run(() async {
    if (_ended.contains(r.key) || _lastCount[r.key] == (r.done, r.total)) return; // an event row stays until N/M move
    final row = _importRow[r.key] ?? await _repo.idOfImport(r.key);
    final detail = jsonEncode({'progress': true, 'key': r.key});
    _lastCount[r.key] = (r.done, r.total);
    if (row == null) {
      _importRow[r.key] = await _repo.add(
          at: _now().millisecondsSinceEpoch, kind: 'import', name: r.name ?? '', done: r.done, total: r.total, detail: detail);
      return; // the table change reads it
    }
    _importRow[r.key] = row;
    await _repo.update(row, at: _now().millisecondsSinceEpoch, done: r.done, total: r.total, failed: false, detail: detail);
    return _replace(row);
  });

  /// A cancelled or deleted import never gets an ending event: its progress line goes away.
  Future<void> _dropIfCancelled(String key) async {
    final imp = await ref.read(importRepositoryProvider).get(int.parse(key.substring(4)));
    if (!ref.mounted || imp != null && imp.state != ImportStatus.cancelled) return;
    _importRow.remove(key);
    _lastCount.remove(key);
    await _run(() => _repo.dropImportProgress(key));
  }

  /// Puts the stored row [id] back in the loaded list (it changed in place).
  Future<void> _replace(int id) async {
    final fresh = (await _repo.byIds([id])).firstOrNull;
    if (fresh == null || !ref.mounted || !state.entries.any((e) => e.id == id)) return;
    state = ActivityLogState(
        [for (final e in state.entries) e.id == id ? LogEntry.fromRow(fresh) : e], state.total, state.dbCounts);
  }

  /// The ending of an import takes the place of its progress line (or is a new line when it never had one).
  Future<void> _recordImport(ImportEvent e) async {
    final repo = ref.read(importRepositoryProvider);
    final imp = await repo.get(e.importId);
    if (imp == null) AppLog.w('import ${e.importId} not found for its Registro line');
    final chain = await ref.read(playlistImportServiceProvider).chainOf(e.importId);
    if (!ref.mounted) return;
    final entry = LogEntry(
      at: _now(),
      importName: imp == null ? null : importLabel(imp.sourceName),
      event: e.kind,
    );
    final key = 'imp-${chain.isEmpty ? e.importId : chain.first.id}';
    if (e.kind == ImportEventKind.completed) _ended.add(key);
    final row = await _run(() async => _importRow[key] ?? await _repo.idOfImport(key));
    if (row == null) return add(entry);
    await _run(() async {
      final d = jsonEncode({'event': e.kind.name, 'key': key});
      await _repo.update(row, at: entry.at.millisecondsSinceEpoch, done: 0, total: 0, failed: entry._storedFailed, detail: d);
      await _reloadPages();
    });
  }

  /// Writes [e] to the database (off the UI thread); it then shows where its time puts it.
  Future<void> add(LogEntry e) async {
    await _run(() async {
      await e._save(_repo);
    });
    await _refresh();
  }

  /// The next page, when the list reaches its end.
  Future<void> loadMore() async {
    if (_paging || !state.hasMore) return;
    _paging = true;
    await _run(() async {
      final last = state.entries.last; // the rows after the last one seen: a row added meanwhile shifts nothing
      final rows = await _repo.page(
        limit: pageSize,
        before: (at: last.at.millisecondsSinceEpoch, id: last.id!),
      );
      if (ref.mounted) {
        state = ActivityLogState([
          ...state.entries,
          for (final r in rows) LogEntry.fromRow(r),
        ], state.total, state.dbCounts);
      }
    });
    _paging = false;
  }

  /// Empties the Registro and forgets the finished downloads behind it.
  Future<void> clear() {
    ref.read(downloadsProvider.notifier).clearFinished();
    ref.read(podcastDownloadsProvider.notifier).clearFinished();
    return _run(() async {
      await _repo.clear();
      if (ref.mounted) state = const ActivityLogState([], 0);
    });
  }
}

final activityLogRepositoryProvider = Provider<ActivityLogRepository>(
  (ref) => ActivityLogRepository(ref.watch(databaseProvider)),
);

final activityLogProvider =
    NotifierProvider<ActivityLogNotifier, ActivityLogState>(
      ActivityLogNotifier.new,
    );
