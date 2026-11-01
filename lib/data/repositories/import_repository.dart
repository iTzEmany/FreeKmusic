import 'package:drift/drift.dart';

import '../../core/import_row.dart';
import '../db/app_database.dart';

enum ImportStatus { running, paused, finished, cancelled }

enum ImportItemStatus {
  pending,
  queued,
  downloaded,
  linked,
  review,
  notFound,
  failed,
  skipped,
  planned,
  removed,
}

extension PlaylistImportX on PlaylistImport {
  ImportStatus get state => ImportStatus.values[status];
}

extension PlaylistImportItemX on PlaylistImportItem {
  ImportItemStatus get state => ImportItemStatus.values[status];
  List<String> get artistList => [
    for (final a in artists.split(';'))
      if (a.isNotEmpty) a,
  ];
  ImportRow toRow() => ImportRow(
    index: rowIndex,
    title: title,
    artists: artistList,
    album: album,
    durationMs: durationMs,
    isrc: isrc,
    year: year,
  );
}

/// Persistent state of CSV imports: survives closing the app.
class ImportRepository {
  ImportRepository(this._db);

  final AppDatabase _db;

  /// The YouTube video a library track was downloaded from, if a row says so
  /// (a linked or reviewed row only guessed it).
  Future<String?> videoIdOfTrack(int trackId) async =>
      (await (_db.select(_db.playlistImportItems)
                ..where((i) =>
                    i.trackId.equals(trackId) &
                    i.videoId.isNotNull() &
                    i.status.equals(ImportItemStatus.downloaded.index))
                ..limit(1))
              .getSingleOrNull())
          ?.videoId;

  /// Creates the import and all its rows in one transaction.
  Future<int> create({
    required int playlistId,
    required String sourceName,
    required List<ImportRow> rows,
    String sourceKind = 'exportify',
    String? folderPath,
    bool numberFiles = false,
    bool linkOnly = false,
    bool planFirst = false,
    bool fetchCovers = false,
    Map<int, ({String videoId, String candidates, double score})> presets =
        const {},
  }) {
    return _db.transaction(() async {
      final id = await _db
          .into(_db.playlistImports)
          .insert(
            PlaylistImportsCompanion.insert(
              playlistId: playlistId,
              sourceName: sourceName,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              sourceKind: Value(sourceKind),
              folderPath: Value(folderPath),
              numberFiles: Value(numberFiles),
              linkOnly: Value(linkOnly),
              planFirst: Value(planFirst),
              fetchCovers: Value(fetchCovers),
            ),
          );
      await _db.batch((b) {
        b.insertAll(_db.playlistImportItems, [
          for (final r in rows)
            PlaylistImportItemsCompanion.insert(
              importId: id,
              rowIndex: r.index,
              title: r.title,
              artists: r.artists.join(';'),
              album: Value(r.album),
              durationMs: Value(r.durationMs),
              isrc: Value(r.isrc),
              year: Value(r.year),
              location: Value(r.location),
              videoId: Value(presets[r.index]?.videoId),
              candidates: Value(presets[r.index]?.candidates),
              score: Value(presets[r.index]?.score),
            ),
        ]);
      });
      return id;
    });
  }

  Future<PlaylistImport?> get(int id) => (_db.select(
    _db.playlistImports,
  )..where((i) => i.id.equals(id))).getSingleOrNull();

  Stream<PlaylistImport?> watch(int id) => (_db.select(
    _db.playlistImports,
  )..where((i) => i.id.equals(id))).watchSingleOrNull();

  /// Imports still to finish (running or paused), oldest first.
  Stream<List<PlaylistImport>> watchUnfinished() =>
      (_db.select(_db.playlistImports)
            ..where(
              (i) => i.status.isIn([
                ImportStatus.running.index,
                ImportStatus.paused.index,
              ]),
            )
            ..orderBy([(i) => OrderingTerm.asc(i.id)]))
          .watch();

  /// The import currently attached to a playlist (any state), newest first.
  Stream<PlaylistImport?> watchForPlaylist(int playlistId) =>
      (_db.select(_db.playlistImports)
            ..where((i) => i.playlistId.equals(playlistId))
            ..orderBy([(i) => OrderingTerm.desc(i.id)])
            ..limit(1))
          .watchSingleOrNull();

  /// Every import of a playlist (any state), oldest first.
  Stream<List<PlaylistImport>> watchAllForPlaylist(int playlistId) =>
      (_db.select(_db.playlistImports)
            ..where((i) => i.playlistId.equals(playlistId))
            ..orderBy([(i) => OrderingTerm.asc(i.id)]))
          .watch();

  Future<List<PlaylistImport>> forPlaylist(int playlistId) => (_db.select(
    _db.playlistImports,
  )..where((i) => i.playlistId.equals(playlistId))).get();

  Stream<List<PlaylistImportItem>> watchItems(int importId) =>
      (_db.select(_db.playlistImportItems)
            ..where((i) => i.importId.equals(importId))
            ..orderBy([(i) => OrderingTerm.asc(i.rowIndex)]))
          .watch();

  Future<List<PlaylistImportItem>> items(int importId) =>
      (_db.select(_db.playlistImportItems)
            ..where((i) => i.importId.equals(importId))
            ..orderBy([(i) => OrderingTerm.asc(i.rowIndex)]))
          .get();

  Future<PlaylistImportItem?> item(int importId, int rowIndex) =>
      (_db.select(_db.playlistImportItems)..where(
            (i) => i.importId.equals(importId) & i.rowIndex.equals(rowIndex),
          ))
          .getSingleOrNull();

  /// First row still to search, in playlist order.
  Future<PlaylistImportItem?> nextPending(int importId) =>
      (_db.select(_db.playlistImportItems)
            ..where(
              (i) =>
                  i.importId.equals(importId) &
                  i.status.equals(ImportItemStatus.pending.index),
            )
            ..orderBy([(i) => OrderingTerm.asc(i.rowIndex)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> setItem(
    int importId,
    int rowIndex, {
    required ImportItemStatus status,
    Value<String?> videoId = const Value.absent(),
    Value<String?> candidates = const Value.absent(),
    Value<int?> trackId = const Value.absent(),
    Value<double?> score = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) async {
    await (_db.update(_db.playlistImportItems)..where(
          (i) => i.importId.equals(importId) & i.rowIndex.equals(rowIndex),
        ))
        .write(
          PlaylistImportItemsCompanion(
            status: Value(status.index),
            videoId: videoId,
            candidates: candidates,
            trackId: trackId,
            score: score,
            note: note,
          ),
        );
    final linked = trackId.present ? trackId.value : null;
    if (linked == null) return;
    // Only fills an empty ISRC: an existing one is never overwritten.
    await _db.customUpdate(
      'UPDATE tracks SET isrc = (SELECT isrc FROM playlist_import_items '
      'WHERE import_id = ? AND row_index = ?) '
      "WHERE id = ? AND (isrc IS NULL OR isrc = '') AND "
      "(SELECT isrc FROM playlist_import_items WHERE import_id = ? AND row_index = ?) <> ''",
      variables: [
        Variable<int>(importId),
        Variable<int>(rowIndex),
        Variable<int>(linked),
        Variable<int>(importId),
        Variable<int>(rowIndex),
      ],
      updates: {_db.tracks},
    );
  }

  Future<void> setStatus(int importId, ImportStatus status) =>
      (_db.update(_db.playlistImports)..where((i) => i.id.equals(importId)))
          .write(PlaylistImportsCompanion(status: Value(status.index)));

  Selectable<QueryRow> _countsQuery(int importId) => _db.customSelect(
    'SELECT status, COUNT(*) AS n FROM playlist_import_items '
    'WHERE import_id = ? GROUP BY status',
    variables: [Variable<int>(importId)],
    readsFrom: {_db.playlistImportItems},
  );

  static Map<ImportItemStatus, int> _toCounts(List<QueryRow> rows) => {
    for (final r in rows)
      ImportItemStatus.values[r.read<int>('status')]: r.read<int>('n'),
  };

  /// Rows per [ImportItemStatus] index.
  Future<Map<ImportItemStatus, int>> counts(int importId) async =>
      _toCounts(await _countsQuery(importId).get());

  /// [counts], kept up to date. Counters watch this, not [watchItems]: every
  /// change of any import row reruns every watch on the table, and a long
  /// import has thousands of rows to copy again each time.
  Stream<Map<ImportItemStatus, int>> watchCounts(int importId) =>
      _countsQuery(importId).watch().map(_toCounts);

  /// App start: nothing runs by itself; queued downloads were in memory only.
  Future<void> recoverAfterRestart() => _db.transaction(() async {
    await (_db.update(
      _db.playlistImports,
    )..where((i) => i.status.equals(ImportStatus.running.index))).write(
      PlaylistImportsCompanion(status: Value(ImportStatus.paused.index)),
    );
    await (_db.update(
      _db.playlistImportItems,
    )..where((i) => i.status.equals(ImportItemStatus.queued.index))).write(
      PlaylistImportItemsCompanion(
        status: Value(ImportItemStatus.pending.index),
      ),
    );
  });

  /// Puts rows with [from] status back to "to search" (retry).
  Future<void> resetItems(int importId, Set<ImportItemStatus> from) =>
      (_db.update(_db.playlistImportItems)..where(
            (i) =>
                i.importId.equals(importId) &
                i.status.isIn([for (final s in from) s.index]),
          ))
          .write(
            PlaylistImportItemsCompanion(
              status: Value(ImportItemStatus.pending.index),
              candidates: const Value(null),
            ),
          );

  Future<void> delete(int importId) => (_db.delete(
    _db.playlistImports,
  )..where((i) => i.id.equals(importId))).go();

  /// ISRC of the tracks that entered [playlistId] through a CSV import.
  Future<Map<int, String>> isrcByTrack(int playlistId) async {
    final rows = await _db
        .customSelect(
          'SELECT i.track_id AS track_id, i.isrc AS isrc '
          'FROM playlist_import_items i JOIN playlist_imports m ON m.id = i.import_id '
          'WHERE m.playlist_id = ? AND i.track_id IS NOT NULL AND i.isrc IS NOT NULL',
          variables: [Variable<int>(playlistId)],
          readsFrom: {_db.playlistImportItems, _db.playlistImports},
        )
        .get();
    return {
      for (final r in rows) r.read<int>('track_id'): r.read<String>('isrc'),
    };
  }

  /// Highest row number over every import of [playlistId] (blocks included),
  /// to size the numbers in file names; -1 when there are none.
  Future<int> maxRowIndexForPlaylist(int playlistId) async {
    final r = await _db
        .customSelect(
          'SELECT MAX(i.row_index) AS m FROM playlist_import_items i '
          'JOIN playlist_imports m ON m.id = i.import_id WHERE m.playlist_id = ?',
          variables: [Variable<int>(playlistId)],
          readsFrom: {_db.playlistImportItems, _db.playlistImports},
        )
        .getSingle();
    return r.read<int?>('m') ?? -1;
  }
}
