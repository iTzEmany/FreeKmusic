import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/hidden_playlists.dart' show ytmAlbumSourceKind;
import '../../data/repositories/import_repository.dart';
import '../../data/repositories/playlist_repository.dart';
import '../online/download_queue.dart';
import '../online/query_cleaner.dart';
import '../online/youtube_service.dart';
import 'exportify_reader.dart';
import 'import_candidate.dart';
import 'import_chain.dart';
import 'import_diff.dart';
import 'eta_estimator.dart';
import 'import_options.dart';
import 'playlist_paths.dart';
import 'row_search.dart';
import 'track_matcher.dart';
import '../../core/artist_key.dart';

export '../../data/repositories/hidden_playlists.dart' show ytmAlbumSourceKind;

const _tagPrefix = 'import:';

String importTag(int importId, int rowIndex) =>
    '$_tagPrefix$importId:$rowIndex';

/// `(importId, rowIndex)` of a download tag made by [importTag], else null.
(int, int)? parseImportTag(String? tag) {
  if (tag == null || !tag.startsWith(_tagPrefix)) return null;
  final parts = tag.substring(_tagPrefix.length).split(':');
  if (parts.length != 2) return null;
  final a = int.tryParse(parts[0]), b = int.tryParse(parts[1]);
  return a == null || b == null ? null : (a, b);
}

enum ImportEventKind {
  planned,
  rateLimited,
  network,
  toolMissing,
  toolOutdated,
  failing,
  completed,
}

class ImportEvent {
  const ImportEvent(this.kind, this.importId);

  final ImportEventKind kind;
  final int importId;
}

/// What the engine is doing on one row that no status in the database says:
/// searching it, or putting the playlist's tags and cover on the file.
enum ImportStepKind { searching, enriching }

/// The rows in a step, by (import id, row index).
typedef ImportSteps = Map<(int, int), ImportStepKind>;

/// The engine waits before it tries again: YouTube asked to slow down
/// ([ImportEventKind.rateLimited]) or the network is gone ([ImportEventKind.network]).
typedef ImportWait = ({ImportEventKind reason, DateTime until});

/// A downloaded file this far (ms) from the CSV length is asked about.
const durationMismatchMs = 10000;

/// Turns the rows of a CSV into a playlist: links what the library already
/// has, searches the rest, downloads it and puts it at its place.
class PlaylistImportService {
  PlaylistImportService({
    required this.imports,
    required this.playlists,
    required this.loadLibrary,
    required this.youtube,
    required this.enqueue,
    required this.cancelDownloads,
    required this.settled,
    required this.trackIdForPath,
    required this.pathForVideo,
    required this.applyTags,
    this.forgetSearches,
    this.trackDurationMs,
    this.fetchCover,
    this.enrichLater,
    this.thresholds,
    this.youtubeEnabled = true,
    this.searchGap = const Duration(milliseconds: 1500),
    this.pollDelay = const Duration(milliseconds: 400),
    this.maxInFlight = 3,
    this.networkBackoff = const [
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 10),
      Duration(minutes: 10),
    ],
    this.rateLimitBackoff = const [
      Duration(minutes: 15),
      Duration(minutes: 30),
      Duration(minutes: 60),
    ],
  }) {
    _sub = settled.listen((i) => unawaited(_onSettled(i)));
  }

  final ImportRepository imports;
  final PlaylistRepository playlists;
  final Future<List<LibraryEntryLite>> Function() loadLibrary;
  final YoutubeService youtube;
  final void Function(YtResult result, String tag) enqueue;
  final void Function(bool Function(DownloadItem item) test) cancelDownloads;
  final Stream<DownloadItem> settled;
  final Future<int?> Function(String path) trackIdForPath;
  final Future<String?> Function(YtResult video) pathForVideo;
  final Future<void> Function(int trackId, ImportRow row) applyTags;
  final bool youtubeEnabled;

  /// Length of the downloaded file as read by the scanner; without it the
  /// «wrong length» check is skipped.
  final Future<int?> Function(int trackId)? trackDurationMs;

  /// Looks the album cover up after a download (only for imports that asked).
  final Future<void> Function(int trackId, ImportRow row)? fetchCover;

  /// Hands a saved song over to the background enrichment (lyrics, missing
  /// tags), once the CSV tags are on it.
  final void Function(int trackId)? enrichLater;

  /// Cut-offs read at each search, so a change in the settings applies at once.
  final MatchThresholds Function()? thresholds;

  MatchThresholds get _cutoffs => thresholds?.call() ?? const MatchThresholds();

  /// Drops cached search answers; called when a chosen video proved unavailable.
  final void Function(List<String> queries)? forgetSearches;

  /// Pause between two YouTube searches (be gentle: 429 is the main risk).
  final Duration searchGap;
  final Duration pollDelay;

  /// Downloads of one import allowed to wait in the queue at the same time.
  final int maxInFlight;

  /// Waits before trying again after a network error or a rate limit, one
  /// after the other while the failures go on; past the last the import
  /// pauses (an import left alone at night must not stop at the first error).
  final List<Duration> networkBackoff, rateLimitBackoff;

  final _events = StreamController<ImportEvent>.broadcast();
  late final StreamSubscription<DownloadItem> _sub;
  bool _looping = false;
  bool _again = false;
  bool _disposed = false;
  int _failStreak = 0;

  Stream<ImportEvent> get events => _events.stream;

  final _stepChanges = StreamController<ImportSteps>.broadcast();
  final ImportSteps _steps = {};

  /// The rows being searched or enriched right now (a search and the tags of
  /// finished downloads go on at the same time).
  ImportSteps get currentSteps => Map.unmodifiable(_steps);
  Stream<ImportSteps> get steps => _stepChanges.stream;

  void _setStep(int importId, int rowIndex, ImportStepKind? kind) {
    final key = (importId, rowIndex);
    if (kind == null ? _steps.remove(key) == null : _steps[key] == kind) return;
    if (kind != null) _steps[key] = kind;
    if (!_stepChanges.isClosed) _stepChanges.add(currentSteps);
  }

  final _waitChanges = StreamController<ImportWait?>.broadcast();
  ImportWait? _wait;
  int _retries = 0;
  Completer<void>? _wake;

  /// What the engine waits for before it tries again (null = not waiting).
  ImportWait? get currentWait => _wait;
  Stream<ImportWait?> get waits => _waitChanges.stream;

  void _setWait(ImportWait? wait) {
    _wait = wait;
    if (!_waitChanges.isClosed) _waitChanges.add(wait);
  }

  /// Starts the next wait for [reason]; false when the waits are used up.
  bool _waitBeforeRetry(ImportEventKind reason) {
    final steps = reason == ImportEventKind.rateLimited
        ? rateLimitBackoff
        : networkBackoff;
    if (_retries >= steps.length) {
      _retries = 0;
      return false;
    }
    final d = steps[_retries++];
    AppLog.i(
      'import: waiting ${d.inSeconds} s (${reason.name}), try $_retries/${steps.length}',
    );
    _setWait((reason: reason, until: DateTime.now().add(d)));
    return true;
  }

  Future<void> _sleepUntil(DateTime until) async {
    final d = until.difference(DateTime.now());
    if (d <= Duration.zero) return;
    final wake = _wake = Completer<void>();
    await Future.any([Future<void>.delayed(d), wake.future]);
    _wake = null;
  }

  /// Ends a wait at once (the user resumed, paused or cancelled).
  void _wakeUp() {
    final w = _wake;
    if (w != null && !w.isCompleted) w.complete();
  }

  void dispose() {
    _disposed = true;
    _wakeUp();
    _sub.cancel();
    _events.close();
    _stepChanges.close();
    _waitChanges.close();
  }

  /// Creates the playlist (or reuses [intoPlaylistId]) and starts the import.
  /// Rows already imported into that playlist are left out. With [blockSize]
  /// the rows are split in several imports run one after the other (row
  /// numbers are kept); returns the id of the first.
  Future<int> start(
    ImportedPlaylist csv, {
    String? name,
    int? intoPlaylistId,
    ImportOptions options = const ImportOptions(),
    int? blockSize,
  }) async {
    final label = (name?.trim().isNotEmpty ?? false) ? name!.trim() : csv.name;
    final playlistId = intoPlaylistId ?? await playlists.create(label);
    var rows = _withAbsoluteLocations(csv);
    if (intoPlaylistId != null) {
      rows = await _withoutAlreadyImported(intoPlaylistId, rows);
    }
    final size = blockSize != null && blockSize > 0 ? blockSize : rows.length;
    final blocks = rows.isEmpty || rows.length <= size
        ? [rows]
        : [
            for (var i = 0; i < rows.length; i += size)
              rows.sublist(i, i + size > rows.length ? rows.length : i + size),
          ];
    int? first, previous;
    for (var n = 0; n < blocks.length; n++) {
      final id = await imports.create(
        playlistId: playlistId,
        sourceName: blocks.length == 1
            ? label
            : '$label (${n + 1}/${blocks.length})',
        rows: blocks[n],
        sourceKind: csv.kind,
        folderPath: options.folderPath,
        numberFiles: options.numberFiles,
        linkOnly: options.linkOnly,
        planFirst: options.planFirst,
        fetchCovers: options.fetchCovers,
      );
      first ??= id;
      if (previous != null) {
        // Waits for the block before it: the playlist order stays right.
        await imports.setStatus(id, ImportStatus.paused);
        _nextBlock[previous] = id;
      }
      previous = id;
    }
    _eta(first!).start();
    if (rows.isEmpty) {
      await imports.setStatus(first, ImportStatus.finished);
      _emit(ImportEvent(ImportEventKind.completed, first));
    } else {
      _kick();
    }
    return first;
  }

  /// Starts a playlist from videos that are already known (a pasted YouTube
  /// playlist or channel): nothing is searched, each row downloads the video
  /// it came from, in the order given, with the usual pause, resume and cancel.
  /// Videos already in the library are linked, not downloaded again.
  Future<int> startFromResults(
    String name,
    List<YtResult> results, {
    ImportOptions options = const ImportOptions(),
    String sourceKind = 'youtube',
  }) async {
    final label = name.trim().isEmpty ? 'YouTube' : name.trim();
    final playlistId = await playlists.create(label);
    final rows = [
      for (var i = 0; i < results.length; i++) rowFromResult(i, results[i]),
    ];
    final id = await imports.create(
      playlistId: playlistId,
      sourceName: label,
      rows: rows,
      sourceKind: sourceKind,
      folderPath: options.folderPath,
      numberFiles: options.numberFiles,
      linkOnly: options.linkOnly,
      fetchCovers: options.fetchCovers,
      presets: {
        for (var i = 0; i < results.length; i++)
          i: (
            videoId: results[i].id,
            candidates: encodeCandidates([ScoredCandidate(results[i], 1)]),
            score: 1.0,
          ),
      },
    );
    _eta(id).start();
    if (rows.isEmpty) {
      await imports.setStatus(id, ImportStatus.finished);
      _emit(ImportEvent(ImportEventKind.completed, id));
    } else {
      _kick();
    }
    return id;
  }

  /// The row a listed video stands for: its title read as «Artist - Title»,
  /// with the channel as the artist when the title does not say.
  static ImportRow rowFromResult(int index, YtResult r) {
    final c = cleanSearchQuery(r.title, r.channel);
    final artist = r.artists.isNotEmpty
        ? r.artists
        : [if (c.artist.isNotEmpty) c.artist];
    return ImportRow(
      index: index,
      title: c.title.isEmpty ? r.title : c.title,
      artists: artist,
      durationMs: r.duration?.inMilliseconds,
      album: r.album,
    );
  }

  final _etas = <int, EtaEstimator>{};

  EtaEstimator _eta(int importId) =>
      _etas.putIfAbsent(importId, EtaEstimator.new);

  /// Time left for [left] more rows of an import; null until it has a pace.
  Duration? etaFor(int importId, int left) => _etas[importId]?.remaining(left);

  /// Import -> the block that starts when it finishes (lost on restart: the
  /// blocks are then paused, and resumed by hand like any paused import).
  final _nextBlock = <int, int>{};

  // ---- sync ---------------------------------------------------------------

  /// The tracks of [playlistId] that an earlier import put there, one item per
  /// track (the latest import wins), in their old row order.
  Future<List<PlaylistImportItem>> _trackedItems(int playlistId) async {
    final inPlaylist = (await playlists.watchTracks(playlistId).first)
        .map((t) => t.id)
        .toSet();
    final all = await imports.forPlaylist(playlistId)
      ..sort((a, b) => a.id.compareTo(b.id));
    final latest = <int, PlaylistImportItem>{};
    for (final imp in all) {
      for (final it in await imports.items(imp.id)) {
        final t = it.trackId;
        if (t != null &&
            inPlaylist.contains(t) &&
            it.state != ImportItemStatus.removed) {
          latest[t] = it;
        }
      }
    }
    return latest.values.toList()
      ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
  }

  /// Rows of earlier imports of [playlistId] that ended «not found» or
  /// «skipped» (the latest import wins): a sync does not count them as new.
  Future<List<PlaylistImportItem>> _parkedItems(int playlistId) async {
    final all = await imports.forPlaylist(playlistId)
      ..sort((a, b) => a.id.compareTo(b.id));
    final latest = <String, PlaylistImportItem>{};
    for (final imp in all) {
      for (final it in await imports.items(imp.id)) {
        final key =
            '${matchTitleKey(it.title)}|${matchKey(it.toRow().primaryArtist)}';
        if (it.state == ImportItemStatus.notFound ||
            it.state == ImportItemStatus.skipped) {
          latest[key] = it;
        } else {
          latest.remove(key);
        }
      }
    }
    return latest.values.toList();
  }

  Future<ImportDiff> _diffFor(ImportedPlaylist csv, int playlistId) async =>
      diffImport(
        await _trackedItems(playlistId),
        _withAbsoluteLocations(csv),
        parked: await _parkedItems(playlistId),
      );

  /// What a sync of [csv] into [playlistId] would add and take out.
  Future<ImportDiff> previewSync(ImportedPlaylist csv, int playlistId) =>
      _diffFor(csv, playlistId);

  /// Makes [playlistId] follow [csv]: new rows are imported, rows that left the
  /// file leave the playlist (their files and library entries stay), and the
  /// order is the file's. Tracks added by hand are kept. Returns the new import.
  Future<int> sync(
    ImportedPlaylist csv,
    int playlistId, {
    ImportOptions options = const ImportOptions(),
  }) async {
    final rows = _withAbsoluteLocations(csv);
    final diff = await _diffFor(csv, playlistId);
    for (final gone in diff.removed) {
      await playlists.removeTrack(playlistId, gone.trackId!);
      await imports.setItem(
        gone.importId,
        gone.rowIndex,
        status: ImportItemStatus.removed,
      );
    }
    final label = await playlists.nameOf(playlistId) ?? csv.name;
    // The new import holds the whole file: the rows kept from before are
    // already linked, so a new row lands next to its neighbours in the file.
    final id = await imports.create(
      playlistId: playlistId,
      sourceName: label,
      rows: rows,
      sourceKind: csv.kind,
      folderPath: options.folderPath,
      numberFiles: options.numberFiles,
      linkOnly: options.linkOnly,
      planFirst: options.planFirst,
      fetchCovers: options.fetchCovers,
    );
    for (final k in diff.kept) {
      await imports.setItem(
        id,
        k.fresh.index,
        status: ImportItemStatus.linked,
        trackId: Value(k.old.trackId),
        note: const Value(ImportNote.unchanged),
      );
    }
    for (final k in diff.parked) {
      await imports.setItem(
        id,
        k.fresh.index,
        status: k.old.state,
        videoId: Value(k.old.videoId),
        candidates: Value(k.old.candidates),
        score: Value(k.old.score),
        note: Value(k.old.note),
      );
    }
    await playlists.reorderBy(playlistId, {
      for (final k in diff.kept) k.old.trackId!: k.fresh.index,
    });
    _eta(id).start();
    if (diff.added.isEmpty) {
      await imports.setStatus(id, ImportStatus.finished);
      _emit(ImportEvent(ImportEventKind.completed, id));
    } else {
      _kick();
    }
    return id;
  }

  /// Relative entries of a playlist file are saved relative to its folder, so
  /// resuming later does not depend on where the file was.
  List<ImportRow> _withAbsoluteLocations(ImportedPlaylist list) {
    final base = list.baseDir;
    if (base == null) return list.rows;
    return [
      for (final r in list.rows)
        r.location != null && !isAbsoluteLocalPath(r.location!)
            ? r.withLocation(
                p.posix.normalize(
                  '${base.replaceAll(r'\', '/')}/${r.location}',
                ),
              )
            : r,
    ];
  }

  Future<List<ImportRow>> _withoutAlreadyImported(
    int playlistId,
    List<ImportRow> rows,
  ) async {
    final inPlaylist = (await playlists.watchTracks(playlistId).first)
        .map((t) => t.id)
        .toSet();
    final isrcs = <String>{}, keys = <String>{};
    for (final imp in await imports.forPlaylist(playlistId)) {
      for (final it in await imports.items(imp.id)) {
        if (it.trackId == null || !inPlaylist.contains(it.trackId)) continue;
        if (it.isrc != null) isrcs.add(it.isrc!);
        keys.add(_rowKey(it.toRow()));
      }
    }
    return [
      for (final r in rows)
        if (!(r.isrc != null && isrcs.contains(r.isrc)) &&
            !keys.contains(_rowKey(r)))
          r,
    ];
  }

  String _rowKey(ImportRow r) =>
      '${matchTitleKey(r.title)}|${matchKey(r.primaryArtist)}';

  // ---- user actions -------------------------------------------------------

  Future<void> pause(int importId) async {
    final imp = await imports.get(importId);
    if (imp?.state == ImportStatus.running) {
      await imports.setStatus(importId, ImportStatus.paused);
      _etas[importId]?.pause();
    }
    _wakeUp();
  }

  Future<void> resume(int importId) async {
    final imp = await imports.get(importId);
    if (imp == null || imp.state != ImportStatus.paused) return;
    await imports.setStatus(importId, ImportStatus.running);
    _eta(importId).start();
    // «Riprendi» during a wait means «try now».
    _retries = 0;
    _wakeUp();
    _kick();
  }

  /// Stops searching and drops the downloads still waiting; tracks already
  /// downloaded stay in the playlist.
  Future<void> cancel(int importId) async {
    _nextBlock.remove(importId);
    await imports.setStatus(importId, ImportStatus.cancelled);
    cancelDownloads((i) => parseImportTag(i.tag)?.$1 == importId);
    _wakeUp();
  }

  /// "Retry all": rows not found or failed are searched again.
  Future<void> retry(int importId) async {
    await imports.resetItems(importId, {
      ImportItemStatus.notFound,
      ImportItemStatus.failed,
    });
    await imports.setStatus(importId, ImportStatus.running);
    _kick();
  }

  Future<void> skip(int importId, int rowIndex) => imports.setItem(
    importId,
    rowIndex,
    status: ImportItemStatus.skipped,
    candidates: const Value(null),
  );

  /// Download [result] for a row (a candidate picked by the user, or one found
  /// with the normal search).
  Future<void> download(int importId, int rowIndex, YtResult result) async {
    final it = await imports.item(importId, rowIndex);
    if (it == null) return;
    await _queueDownload(it.toRow(), importId, result);
    final imp = await imports.get(importId);
    if (imp != null && imp.state != ImportStatus.running) {
      await imports.setStatus(importId, ImportStatus.running);
    }
  }

  /// App start: a block still «running» in the database was cut off by the app
  /// closing (a user pause is stored as paused), so it goes on by itself; the
  /// paused ones, and the blocks waiting in a chain, stay as they are.
  Future<void> recoverAfterRestart() async {
    final cut = [for (final i in await _runningImports()) i.id];
    await imports.recoverAfterRestart();
    for (final id in cut) {
      await resume(id);
    }
  }

  // ---- engine -------------------------------------------------------------

  void _kick() {
    if (_disposed) return;
    // A loop about to end may have read the imports before this change: it
    // goes round once more instead of leaving a resumed import waiting.
    if (_looping) {
      _again = true;
      return;
    }
    unawaited(_loop());
  }

  Future<void> _loop() async {
    if (_looping) return;
    _looping = true;
    try {
      final library = LibraryIndex(await loadLibrary());
      while (!_disposed) {
        final wait = _wait;
        if (wait != null) {
          await _sleepUntil(wait.until);
          _setWait(null);
          continue;
        }
        final running = await _runningImports();
        if (running.isEmpty) break;
        var worked = false, waiting = false;
        for (final imp in running) {
          final item = await imports.nextPending(imp.id);
          if (item == null) {
            // A finished import may have woken the next block: look again.
            if (await _checkFinished(imp.id)) worked = true;
            continue;
          }
          final counts = await imports.counts(imp.id);
          if ((counts[ImportItemStatus.queued] ?? 0) >= maxInFlight) {
            waiting = true;
            continue;
          }
          try {
            await _process(imp.id, item, library);
          } on Object catch (e, st) {
            // One row that goes wrong must not stop the whole import.
            AppLog.e('import: row ${item.rowIndex} of ${imp.id} failed', e, st);
            await imports.setItem(
              imp.id,
              item.rowIndex,
              status: ImportItemStatus.failed,
            );
          }
          worked = true;
          break;
        }
        // Only waiting for downloads to leave the queue: look again soon.
        if (!worked) {
          if (!waiting) break;
          await Future<void>.delayed(pollDelay);
        }
      }
    } on Object catch (e, st) {
      AppLog.e('import loop crashed', e, st);
    } finally {
      _looping = false;
      if (_again) {
        _again = false;
        _kick();
      }
    }
  }

  Future<List<PlaylistImport>> _runningImports() async {
    final all = await imports.watchUnfinished().first;
    return [
      for (final i in all)
        if (i.state == ImportStatus.running) i,
    ];
  }

  Future<void> _process(
    int importId,
    PlaylistImportItem item,
    LibraryIndex library,
  ) async {
    final row = item.toRow();
    final hit = library.find(row);
    if (hit != null) {
      await _link(importId, row, hit.id);
      return;
    }
    final imp = await imports.get(importId);
    if (!youtubeEnabled || (imp?.linkOnly ?? false)) {
      await imports.setItem(
        importId,
        row.index,
        status: ImportItemStatus.notFound,
        note: Value(
          youtubeEnabled ? ImportNote.linkOnly : ImportNote.youtubeOff,
        ),
      );
      return;
    }
    // Approved in the plan screen: the choice is already made, no search.
    final approved = _approvedChoice(item);
    if (approved != null) {
      await _queueDownload(
        row,
        importId,
        approved.toYtResult(),
        score: item.score,
      );
      return;
    }
    try {
      _setStep(importId, row.index, ImportStepKind.searching);
      final MatchDecision decision;
      try {
        // A sure match by ISRC comes first: it is one quick request. Songs
        // from one album are then looked up on the album page, one search for
        // all of them; only a sure match counts there, the rest goes the
        // usual way.
        decision = await searchRow(
          row,
          youtube,
          thresholds: () => _cutoffs,
          gap: searchGap,
          afterIsrc: () => _fromAlbum(importId, row),
        );
      } finally {
        _setStep(importId, row.index, null);
      }
      _failStreak = 0;
      _retries = 0;
      switch (decision.kind) {
        case MatchKind.sure when imp?.planFirst ?? false:
          _eta(importId).rowDone();
          await imports.setItem(
            importId,
            row.index,
            status: ImportItemStatus.planned,
            videoId: Value(decision.best!.result.id),
            candidates: Value(encodeCandidates(decision.top)),
            score: Value(decision.best!.score),
          );
        case MatchKind.sure:
          await _queueDownload(
            row,
            importId,
            decision.best!.result,
            score: decision.best!.score,
          );
        case MatchKind.review:
          _eta(importId).rowDone();
          await imports.setItem(
            importId,
            row.index,
            status: ImportItemStatus.review,
            candidates: Value(encodeCandidates(decision.top)),
            score: Value(decision.best!.score),
            note: const Value(ImportNote.lowScore),
          );
        case MatchKind.notFound:
          _eta(importId).rowDone();
          await imports.setItem(
            importId,
            row.index,
            status: ImportItemStatus.notFound,
            note: const Value(ImportNote.noResults),
          );
      }
    } on YtException catch (e, st) {
      AppLog.w('import search failed for "${row.title}"', e, st);
      await _onSearchError(importId, row, e);
      return;
    }
    await Future<void>.delayed(searchGap);
  }

  // ---- albums -------------------------------------------------------------

  /// Rows that must share an album before it is worth looking the album up.
  static const albumMinRows = 3;

  final _albumCounts = <int, Map<String, int>>{};
  final _albumTracks = <String, Future<List<YtResult>>>{};

  String _albumKey(ImportRow r) => matchKey(r.album ?? '');

  Future<Map<String, int>> _countAlbums(int importId) async {
    final counts = <String, int>{};
    for (final it in await imports.items(importId)) {
      if (it.state != ImportItemStatus.pending) continue;
      final k = _albumKey(it.toRow());
      if (k.isNotEmpty) counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts;
  }

  Future<MatchDecision?> _fromAlbum(int importId, ImportRow row) async {
    final key = _albumKey(row);
    if (key.isEmpty) return null;
    final counts = _albumCounts[importId] ??= await _countAlbums(importId);
    if ((counts[key] ?? 0) < albumMinRows) return null;
    final id = '$importId|$key';
    final tracks = await (_albumTracks[id] ??= _loadAlbum(row)
        .catchError((Object e) {
          // A rate limit must be retried after the wait, not remembered.
          if (e is YtException && e.kind == YtErrorKind.rateLimited) {
            _albumTracks.remove(id);
            throw e;
          }
          // The album page is only a shortcut: without it each song is looked
          // up on its own (a page that took too long used to pause the import).
          AppLog.w('import: album page for "${row.album}" not read', e);
          return const <YtResult>[];
        }));
    // On an album page the song is the one with the same title; a similar
    // title (the next track) must not win on artist and length alone.
    final want = matchTitleKey(row.title);
    final same = [
      for (final t in tracks)
        if (matchTitleKey(t.title) == want) t,
    ];
    if (same.isEmpty) return null;
    final d = decide(row, same, thresholds: _cutoffs);
    return d.kind == MatchKind.sure ? d : null;
  }

  /// The tracks of the album [row] belongs to, or none when the best album
  /// found is not the one named in the file.
  Future<List<YtResult>> _loadAlbum(ImportRow row) async {
    final album = row.album!;
    final hits = await youtube.searchAlbums(
      '${row.primaryArtist} $album',
      limit: 3,
    );
    if (hits.isEmpty) return const [];
    await Future<void>.delayed(searchGap);
    final tracks = await youtube.albumTracks(hits.first.id);
    final name = matchKey(tracks.isEmpty ? '' : tracks.first.album ?? '');
    final want = matchKey(album);
    final same =
        name.isNotEmpty &&
        (name == want || name.contains(want) || want.contains(name));
    await Future<void>.delayed(searchGap);
    return same ? tracks : const [];
  }

  /// A row put back to «pending» by [startPlanned] still carries the candidates
  /// it was planned with; its chosen video is the one to download.
  ImportCandidate? _approvedChoice(PlaylistImportItem item) {
    final id = item.videoId;
    if (id == null || item.candidates == null) return null;
    final all = decodeCandidates(item.candidates);
    for (final c in all) {
      if (c.id == id) return c;
    }
    return all.isEmpty ? null : all.first;
  }

  // ---- planning -----------------------------------------------------------

  /// The user picked another of the planned candidates for a row.
  Future<void> choosePlanned(
    int importId,
    int rowIndex,
    ImportCandidate choice,
  ) => imports.setItem(
    importId,
    rowIndex,
    status: ImportItemStatus.planned,
    videoId: Value(choice.id),
    score: Value(choice.score),
  );

  /// «Scarica N brani»: every planned row goes back to the engine as already
  /// decided, so the usual throttling and pausing apply. Returns how many.
  Future<int> startPlanned(int importId) async {
    var n = 0;
    for (final it in await imports.items(importId)) {
      if (it.state != ImportItemStatus.planned) continue;
      await imports.setItem(
        importId,
        it.rowIndex,
        status: ImportItemStatus.pending,
      );
      n++;
    }
    await imports.setStatus(importId, ImportStatus.running);
    _eta(importId).start();
    _kick();
    return n;
  }

  Future<void> _onSearchError(
    int importId,
    ImportRow row,
    YtException e,
  ) async {
    ImportEventKind? stop;
    switch (e.kind) {
      // The row stays to do: the engine waits and searches it again.
      case YtErrorKind.rateLimited:
        if (_waitBeforeRetry(ImportEventKind.rateLimited)) return;
        stop = ImportEventKind.rateLimited;
      case YtErrorKind.network:
        if (_waitBeforeRetry(ImportEventKind.network)) return;
        stop = ImportEventKind.network;
      case YtErrorKind.toolMissing:
        stop = ImportEventKind.toolMissing;
      case YtErrorKind.toolOutdated:
        stop = ImportEventKind.toolOutdated;
      case YtErrorKind.unavailable:
      case YtErrorKind.changed:
        _failStreak++;
        await imports.setItem(
          importId,
          row.index,
          status: ImportItemStatus.failed,
        );
        if (_failStreak >= 3) {
          _failStreak = 0;
          stop = ImportEventKind.failing;
        }
    }
    if (stop != null) {
      await imports.setStatus(importId, ImportStatus.paused);
      _etas[importId]?.pause();
      _emit(ImportEvent(stop, importId));
    }
  }

  Future<void> _link(int importId, ImportRow row, int trackId) async {
    _eta(importId).rowDone(linked: true);
    await imports.setItem(
      importId,
      row.index,
      status: ImportItemStatus.linked,
      trackId: Value(trackId),
    );
    final imp = await imports.get(importId);
    if (imp != null) {
      await playlists.placeImported(
        imp.playlistId,
        importId,
        row.index,
        trackId,
      );
    }
  }

  Future<void> _queueDownload(
    ImportRow row,
    int importId,
    YtResult r, {
    double? score,
  }) async {
    final existing = await pathForVideo(r);
    if (existing != null) {
      final id = await trackIdForPath(existing);
      if (id != null) {
        await _link(importId, row, id);
        return;
      }
    }
    final imp = await imports.get(importId);
    final total = imp == null || !imp.numberFiles
        ? 0
        : await imports.maxRowIndexForPlaylist(imp.playlistId) + 1;
    await imports.setItem(
      importId,
      row.index,
      status: ImportItemStatus.queued,
      videoId: Value(r.id),
      candidates: const Value(null),
      score: Value(score),
    );
    enqueue(
      YtResult(
        id: r.id,
        title: r.title,
        channel: r.channel,
        duration: r.duration,
        thumbnailUrl: r.thumbnailUrl,
        artists: r.artists,
        album: r.album,
        source: r.source,
        webpageUrl: r.webpageUrl,
        downloadName: importDownloadName(
          row,
          number: imp?.numberFiles ?? false,
          total: total,
        ),
        subdir: imp?.folderPath,
      ),
      importTag(importId, row.index),
    );
  }

  Future<void> _onSettled(DownloadItem item) async {
    final ref = parseImportTag(item.tag);
    if (ref == null || _disposed) return;
    final (importId, rowIndex) = ref;
    try {
      final imp = await imports.get(importId);
      final it = await imports.item(importId, rowIndex);
      if (imp == null || it == null) return;
      if (imp.state == ImportStatus.cancelled) return;
      switch (item.status) {
        case DownloadStatus.done:
          _retries = 0;
          _eta(importId).rowDone();
          await _finishDownload(imp, it, item.path);
        case DownloadStatus.failed
            when item.error == YtErrorKind.rateLimited &&
                _waitBeforeRetry(ImportEventKind.rateLimited):
          // YouTube asked to slow down: the song is done again after the wait.
          await imports.setItem(
            importId,
            rowIndex,
            status: ImportItemStatus.pending,
          );
        case DownloadStatus.failed:
          _eta(importId).rowDone();
          await imports.setItem(
            importId,
            rowIndex,
            status: ImportItemStatus.failed,
            note: const Value(ImportNote.downloadFailed),
          );
          if (item.error == YtErrorKind.unavailable) {
            forgetSearches?.call(searchQueries(it.toRow()));
          }
          if (item.error == YtErrorKind.rateLimited) {
            await imports.setStatus(importId, ImportStatus.paused);
            _etas[importId]?.pause();
            _emit(ImportEvent(ImportEventKind.rateLimited, importId));
          }
        case DownloadStatus.cancelled:
          await imports.setItem(
            importId,
            rowIndex,
            status: ImportItemStatus.failed,
          );
        case DownloadStatus.queued:
        case DownloadStatus.downloading:
        case DownloadStatus.waitingRetry:
          return;
      }
      await _checkFinished(importId);
      _kick();
    } on Object catch (e, st) {
      AppLog.e('import: handling a finished download failed', e, st);
    }
  }

  Future<void> _finishDownload(
    PlaylistImport imp,
    PlaylistImportItem it,
    String? path,
  ) async {
    final trackId = path == null ? null : await trackIdForPath(path);
    if (trackId == null) {
      await imports.setItem(
        imp.id,
        it.rowIndex,
        status: ImportItemStatus.failed,
      );
      return;
    }
    _setStep(imp.id, it.rowIndex, ImportStepKind.enriching);
    try {
      await _tagAndPlace(imp, it, trackId);
    } finally {
      _setStep(imp.id, it.rowIndex, null);
    }
    enrichLater?.call(trackId);
  }

  /// The CSV tags, the place in the playlist, the length check and the cover.
  Future<void> _tagAndPlace(
    PlaylistImport imp,
    PlaylistImportItem it,
    int trackId,
  ) async {
    try {
      // The rows of an album import are in the album's order: that is the track number.
      await applyTags(
        trackId,
        imp.sourceKind == ytmAlbumSourceKind
            ? it.toRow().withTrackNumber(it.rowIndex + 1)
            : it.toRow(),
      );
    } on Object catch (e, st) {
      AppLog.w('import: could not apply CSV tags to track $trackId', e, st);
    }
    await playlists.placeImported(imp.playlistId, imp.id, it.rowIndex, trackId);
    // The file stays and the track stays in the playlist; a very different
    // length just asks the user to confirm it was the right version.
    final off = await _lengthIsOff(it, trackId);
    await imports.setItem(
      imp.id,
      it.rowIndex,
      status: off ? ImportItemStatus.review : ImportItemStatus.downloaded,
      trackId: Value(trackId),
      note: off ? const Value(ImportNote.lengthOff) : const Value.absent(),
    );
    final row = it.toRow();
    if (imp.fetchCovers && fetchCover != null && row.album != null) {
      try {
        await fetchCover!(trackId, row);
      } on Object catch (e, st) {
        // A missing cover must never fail the import.
        AppLog.w('import: cover lookup failed for "${row.title}"', e, st);
      }
    }
  }

  Future<bool> _lengthIsOff(PlaylistImportItem it, int trackId) async {
    final want = it.durationMs;
    final read = trackDurationMs;
    if (want == null || want <= 0 || read == null) return false;
    final got = await read(trackId);
    return got != null && got > 0 && (got - want).abs() > durationMismatchMs;
  }

  /// The user confirms a downloaded file whose length differed from the CSV.
  Future<void> keepDownloaded(int importId, int rowIndex) =>
      imports.setItem(importId, rowIndex, status: ImportItemStatus.downloaded);

  /// Finishes (or pauses for planning) an import with nothing left to do;
  /// true when its state changed.
  Future<bool> _checkFinished(int importId) async {
    final imp = await imports.get(importId);
    if (imp == null || imp.state != ImportStatus.running) return false;
    final c = await imports.counts(importId);
    if ((c[ImportItemStatus.pending] ?? 0) != 0 ||
        (c[ImportItemStatus.queued] ?? 0) != 0) {
      return false;
    }
    if ((c[ImportItemStatus.planned] ?? 0) > 0) {
      await imports.setStatus(importId, ImportStatus.paused);
      _etas[importId]?.pause();
      _emit(ImportEvent(ImportEventKind.planned, importId));
      return true;
    }
    await imports.setStatus(importId, ImportStatus.finished);
    // The album pages read for this block serve no other: a long import in
    // blocks would keep every one of them for the session.
    _albumCounts.remove(importId);
    _albumTracks.removeWhere((k, _) => k.startsWith('$importId|'));
    // In memory while the app stays open; from the blocks' names after a
    // restart, so the chain goes on without the user resuming every block.
    final next = _nextBlock.remove(importId) ?? await _nextBlockOf(importId);
    if (next != null) {
      await resume(next);
    } else {
      // Once for the whole import, not for every block.
      _emit(ImportEvent(ImportEventKind.completed, importId));
    }
    return true;
  }

  Future<int?> _nextBlockOf(int importId) async {
    final imp = await imports.get(importId);
    if (imp == null) return null;
    return nextBlockAfter(imp, await imports.forPlaylist(imp.playlistId))?.id;
  }

  /// The blocks [importId] belongs to, in order (just itself when the import
  /// was made in one piece).
  Future<List<PlaylistImport>> chainOf(int importId) async {
    final imp = await imports.get(importId);
    if (imp == null) return const [];
    final chains = groupImportChains(await imports.forPlaylist(imp.playlistId));
    return chains.firstWhere(
      (c) => c.any((i) => i.id == importId),
      orElse: () => [imp],
    );
  }

  /// Pause for the whole import: the block that runs stops, the next ones wait.
  Future<void> pauseChain(int importId) async {
    for (final b in await chainOf(importId)) {
      if (b.state == ImportStatus.running) await pause(b.id);
    }
  }

  /// Goes on from the first block not finished; the others follow by themselves.
  Future<void> resumeChain(int importId) async {
    for (final b in await chainOf(importId)) {
      if (b.state == ImportStatus.paused) {
        await resume(b.id);
        return;
      }
    }
  }

  /// Cancels every block not finished yet; what was downloaded stays.
  Future<void> cancelChain(int importId) async {
    for (final b in await chainOf(importId)) {
      if (b.state == ImportStatus.running || b.state == ImportStatus.paused) {
        await cancel(b.id);
      }
    }
  }

  void _emit(ImportEvent e) {
    if (!_events.isClosed) _events.add(e);
  }
}
