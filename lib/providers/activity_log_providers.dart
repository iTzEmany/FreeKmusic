import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/clock.dart';
import '../data/db/app_database.dart';
import '../data/repositories/activity_log_repository.dart';
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
    this.item,
    this.importName,
    this.event,
    this.detail,
    this.correction,
  });

  final DateTime at;

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
  bool get stopped => detail?['stopped'] == true || detail?['noAnswer'] == true;

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
  bool get revertible => correction != null && detail?['old'] != null;

  /// A completion stopped for lack of answers is saved as failed but shown as stopped.
  bool get failed =>
      detail?['noAnswer'] != true &&
      ((item?.failed ?? false) ||
          (correction != null && correction!.failed != 0) ||
          (event != null &&
              event != ImportEventKind.completed &&
              event != ImportEventKind.planned));

  static const _importKind = 'import';
  static const _correctionKind = 'correction';

  LogEntry.fromRow(ActivityLogRow r)
    : at = DateTime.fromMillisecondsSinceEpoch(r.at),
      detail = _decode(r.detail),
      correction = r.kind == _correctionKind ? r : null,
      importName = r.kind == _importKind ? r.name : null,
      event = r.kind == _importKind
          ? ImportEventKind.values.asNameMap()[_decode(r.detail)?['event']] ??
                ImportEventKind.completed
          : null,
      item = r.kind == _importKind || r.kind == _correctionKind
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
      failed: failed,
      detail: d.isEmpty ? null : jsonEncode(d),
    );
  }
}

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
  Future<void> _tail = Future.value();
  bool _paging = false;

  ActivityLogRepository get _repo => ref.read(activityLogRepositoryProvider);

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
          at: DateTime.now(),
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
    unawaited(reload());
    return const ActivityLogState([], 0);
  }

  /// Reads the first page again (corrections are written straight to the database).
  Future<void> reload() => _run(() async {
    await _repo.prune(nowMs());
    final rows = await _repo.page(limit: pageSize);
    final total = await _repo.count();
    final counts = await _counts(total);
    if (ref.mounted) {
      state = ActivityLogState([
        for (final r in rows) LogEntry.fromRow(r),
      ], total, counts);
    }
  });

  /// What each filter shows, over every row (not only the loaded pages).
  Future<Map<LogFilter, int>> _counts(int total) async {
    final c = {for (final f in LogFilter.values) f: 0, LogFilter.all: total};
    for (final r in await _repo.countsByKind()) {
      c.update(LogEntry.categoryOfKind(r.kind), (v) => v + r.n);
      if (r.failed && !r.noAnswer) c.update(LogFilter.errors, (v) => v + r.n);
    }
    return c;
  }

  /// Database jobs one after the other, so the lines keep their order.
  Future<void> _run(Future<void> Function() job) =>
      _tail = _tail.then((_) async {
        try {
          await job();
        } on Object catch (e, st) {
          AppLog.w('activity log write failed', e, st);
        }
      });

  void _record(ActivityState? prev, ActivityState s) {
    final now = DateTime.now();
    for (final c in s.completed) {
      if (_logged.add(c.key)) add(LogEntry(at: now, item: c));
    }
    final still = {for (final r in s.running) r.key};
    for (final r in prev?.running ?? const <ActivityItem>[]) {
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

  Future<void> _recordImport(ImportEvent e) async {
    final imp = await ref.read(importRepositoryProvider).get(e.importId);
    if (!ref.mounted) return;
    add(
      LogEntry(
        at: DateTime.now(),
        importName: imp == null ? null : importLabel(imp.sourceName),
        event: e.kind,
      ),
    );
  }

  /// Writes [e] to the database (off the UI thread) and shows it at the top.
  Future<void> add(LogEntry e) => _run(() async {
    await e._save(_repo);
    final counts = await _counts(state.total + 1);
    if (ref.mounted) {
      state = ActivityLogState([e, ...state.entries], state.total + 1, counts);
    }
  });

  /// The next page, when the list reaches its end.
  Future<void> loadMore() async {
    if (_paging || !state.hasMore) return;
    _paging = true;
    await _run(() async {
      final rows = await _repo.page(
        limit: pageSize,
        offset: state.entries.length,
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
