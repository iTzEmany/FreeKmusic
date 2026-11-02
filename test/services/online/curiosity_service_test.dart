import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/artist_info_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/curiosity_finder.dart';
import 'package:codecore/services/online/curiosity_service.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Finder implements CuriosityFinder {
  _Finder(this.pair);

  final CuriosityPair pair;

  @override
  Future<CuriosityPair> find(
    String title,
    String artist,
    String lang, {
    String? isrc,
    int durationMs = 0,
    cancel,
  }) async => pair;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Curiosity _c(String text) =>
    Curiosity(text, Uri.parse('https://it.wikipedia.org/wiki/X'), 'it');

void main() {
  late AppDatabase db;
  late Track track;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final id = await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: '/m/a.mp3',
            title: 'Song',
            artist: const Value('Band'),
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
          ),
        );
    track = await (db.select(
      db.tracks,
    )..where((t) => t.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<CuriosityOutcome> run(CuriosityPair pair) => CuriosityService(
    finder: _Finder(pair),
    tracks: TrackRepository(db),
    artistInfos: ArtistInfoRepository(db),
  ).fetch(track, 'it');

  test('saves the song text and the artist bio without a container', () async {
    final out = await run(CuriosityPair(song: _c('song'), artist: _c('bio')));
    expect(out.nothing, isFalse);
    expect(out.failed, isFalse);
    final t = await (db.select(
      db.tracks,
    )..where((x) => x.id.equals(track.id))).getSingle();
    expect(t.curiosities, startsWith('song\n'));
    expect((await db.select(db.artistInfos).get()).single.body, 'bio');
  });

  test('found empty is told apart from a refusal or an error', () async {
    expect((await run(const CuriosityPair())).foundEmpty, isTrue);
    final limited = await run(
      const CuriosityPair(songError: RateLimitedException(429)),
    );
    expect(limited.foundEmpty, isFalse);
    expect(limited.songLimited, isTrue);
    final failed = await run(CuriosityPair(artistError: Exception('boom')));
    expect(failed.foundEmpty, isFalse);
    expect(failed.failed, isTrue);
  });

  group('a cover (69e)', () {
    const original = {'title': 'Believer', 'artist': 'Imagine Dragons'};
    final bio = Curiosity('bio', Uri.parse('https://it.wikipedia.org/wiki/Y'), 'it');

    Future<(List<String>, CuriosityLookup)> find(CuriosityPair own) async {
      final f = _AskedFinder({'Song': own, 'Believer': CuriosityPair(song: _c('orig'))});
      final l = await CuriosityService(
        finder: f,
        tracks: TrackRepository(db),
        artistInfos: ArtistInfoRepository(db),
      ).find(track, 'it', original: original);
      return (f.asked, l);
    }

    test('no page of its own: the original is searched, the bio stays the cover artist\'s', () async {
      final (asked, l) = await find(CuriosityPair(artist: bio));
      expect(asked, ['Song|Band', 'Believer|Imagine Dragons']);
      expect([l.pair.song?.text, l.pair.artist?.text, l.artist], ['orig', 'bio', 'Band']);
    });

    test('a page of its own is kept and the original is not asked', () async {
      final (asked, l) = await find(CuriosityPair(song: _c('own'), artist: bio));
      expect(asked, ['Song|Band']);
      expect(l.pair.song?.text, 'own');
    });
  });
}

class _AskedFinder implements CuriosityFinder {
  _AskedFinder(this.byTitle);

  final Map<String, CuriosityPair> byTitle;
  final asked = <String>[];

  @override
  Future<CuriosityPair> find(String title, String artist, String lang,
      {String? isrc, int durationMs = 0, cancel}) async {
    asked.add('$title|$artist');
    return byTitle[title]!;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}
