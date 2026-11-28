import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// 3 000 tracks of an enriched library: lyrics, synced lyrics and curiosities
/// on every row (~6 KB of text each), as on a phone after «Arricchisci». What
/// the lists read on each change of the table (phase 28.1 baseline, 28.2 goal).
const _tracks = 3000;

final _lyrics = List.filled(40, 'Verso della canzone di prova, lungo come uno vero').join('\n');
final _synced = [for (var i = 0; i < 40; i++) '[00:${(i % 60).toString().padLeft(2, '0')}.00] $_line'].join('\n');
const _line = 'Verso della canzone di prova, lungo come uno vero';
final _curiosity = '${List.filled(12, 'Una curiosità sul brano, come una pagina di Wikipedia.').join(' ')}\nhttps://it.wikipedia.org/wiki/Prova';

TracksCompanion _row(int i) => TracksCompanion.insert(
      path: '/m/artist ${i % 150}/album ${i % 300}/song $i.mp3',
      title: 'Song $i',
      artist: Value('Artist ${i % 150}'),
      album: Value('Album ${i % 300}'),
      albumKey: 'artist ${i % 150}|album ${i % 300}',
      durationMs: Value(120000 + (i % 240) * 1000),
      format: 'mp3',
      sizeBytes: 1000,
      mtimeMs: i,
      addedAt: i,
      lyricsPlain: Value(_lyrics),
      lyricsSynced: Value(_synced),
      curiosities: Value(_curiosity),
    );

/// Characters of text the list rows carry (what the UI isolate keeps in memory).
int _textChars(List<Track> rows) => rows.fold(
    0,
    (n, t) =>
        n +
        t.title.length +
        (t.artist?.length ?? 0) +
        (t.album?.length ?? 0) +
        t.path.length +
        (t.lyricsPlain?.length ?? 0) +
        (t.lyricsSynced?.length ?? 0) +
        (t.curiosities?.length ?? 0));

void main() {
  test('«Tutti i brani» on 3 000 enriched tracks: time and text per refresh', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.batch((b) => b.insertAll(db.tracks, [for (var i = 0; i < _tracks; i++) _row(i)]));
    final repo = TrackRepository(db);
    await repo.watchTracks().first; // warm-up
    final sw = Stopwatch()..start();
    late List<Track> rows;
    for (var i = 0; i < 5; i++) {
      rows = await repo.watchTracks().first;
    }
    final ms = sw.elapsedMilliseconds / 5;
    final mb = _textChars(rows) * 2 / (1024 * 1024);
    // ignore: avoid_print
    print('lists3k: allTracks=${ms.toStringAsFixed(1)} ms per refresh, '
        '${mb.toStringAsFixed(1)} MB of text in the rows');
    expect(rows, hasLength(_tracks));
    // Time is printed for information only: it is not reliable on a loaded machine.
    // 28.2: the lists leave the long texts in the database (29.7 MB before).
    expect(mb, lessThan(1.5), reason: 'only the list columns are read');
  });
}
