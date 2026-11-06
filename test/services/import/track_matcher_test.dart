import 'package:codecore/core/import_row.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

ImportRow row(String title, List<String> artists,
        {int? ms, String? album, int index = 0}) =>
    ImportRow(
        index: index,
        title: title,
        artists: artists,
        durationMs: ms,
        album: album);

YtResult yt(String id, String title, String channel,
        {int? seconds, List<String> artists = const [], String? album}) =>
    YtResult(
      id: id,
      title: title,
      channel: channel,
      duration: seconds == null ? null : Duration(seconds: seconds),
      artists: artists,
      album: album,
    );

void main() {
  group('matchTitleKey', () {
    const table = {
      'Singalong Junk - Remastered 2011': 'singalong junk',
      'Going to California - Remaster': 'going to california',
      "Blowin' in the Wind": 'blowin in the wind',
      'Out On A Limb (feat. Teena Marie)': 'out on a limb',
      'Felicità': 'felicita',
      'Song - Radio Edit': 'song',
      'Let It Be (Remastered 2009)': 'let it be',
      'Stairway to Heaven - (Live at MSG 1973) [Remaster]':
          'stairway to heaven live at msg 1973',
      'Idea 22 (Slowed + Reverb)': 'idea 22 slowed reverb',
    };
    for (final e in table.entries) {
      test(e.key, () => expect(matchTitleKey(e.key), e.value));
    }
  });

  group('decide', () {
    final felicita = row('Felicità', ['Lucio Dalla'], ms: 345360);

    test('official audio beats the video clip with a long intro', () {
      final d = decide(felicita, [
        yt('clip', 'Lucio Dalla - Felicità (Videoclip)', 'LucioDallaVEVO',
            seconds: 385),
        yt('topic', 'Felicità', 'Lucio Dalla - Topic',
            seconds: 345, artists: ['Lucio Dalla'], album: 'Dalla/Morandi'),
      ]);
      expect(d.kind, MatchKind.sure);
      expect(d.best!.result.id, 'topic');
    });

    test('live version is not chosen when the CSV asks for the studio one', () {
      final r = row('Bohemian Rhapsody', ['Queen'], ms: 355000);
      final d = decide(r, [
        yt('live', 'Bohemian Rhapsody (Live at Wembley)', 'Queen Official',
            seconds: 356, artists: ['Queen']),
        yt('studio', 'Bohemian Rhapsody', 'Queen - Topic',
            seconds: 355, artists: ['Queen']),
      ]);
      expect(d.kind, MatchKind.sure);
      expect(d.best!.result.id, 'studio');
      expect(d.top.last.score, lessThan(sureThreshold));
    });

    test('only a live upload available: not sure', () {
      final r = row('Bohemian Rhapsody', ['Queen'], ms: 355000);
      final d = decide(r, [
        yt('live', 'Bohemian Rhapsody (Live at Wembley)', 'Queen',
            seconds: 356, artists: ['Queen']),
      ]);
      expect(d.kind, isNot(MatchKind.sure));
    });

    test('slowed + reverb is accepted when the CSV title says so', () {
      final r = row('Idea 22 (Slowed + Reverb)', ['Gibran Alcocer'],
          ms: 178823);
      final d = decide(r, [
        yt('a', 'Idea 22 (Slowed + Reverb)', 'Gibran Alcocer - Topic',
            seconds: 179, artists: ['Gibran Alcocer']),
      ]);
      expect(d.kind, MatchKind.sure);
    });

    test('sped up upload is penalised for a normal song', () {
      final r = row('Piano Man', ['Billy Joel'], ms: 339000);
      final fast = scoreCandidate(
          r, yt('a', 'Piano Man (Sped Up)', 'Billy Joel', seconds: 339));
      final normal = scoreCandidate(
          r, yt('b', 'Piano Man', 'Billy Joel', seconds: 339));
      expect(fast, lessThan(normal * 0.5));
    });

    test('feat. in the YouTube title does not hurt', () {
      final r = row('Out On A Limb', ['Furacão 2000', 'Teena Marie'],
          ms: 332040);
      final d = decide(r, [
        yt('a', 'Out On A Limb (feat. Teena Marie)', 'Furacão 2000 - Topic',
            seconds: 332, artists: ['Furacão 2000', 'Teena Marie']),
      ]);
      expect(d.kind, MatchKind.sure);
    });

    test('accents and punctuation are ignored', () {
      final r = row("Blowin' in the Wind", ['Bob Dylan'], ms: 168756);
      final d = decide(r, [
        yt('a', 'Blowin in the Wind', 'Bob Dylan', seconds: 169,
            artists: ['Bob Dylan']),
      ]);
      expect(d.kind, MatchKind.sure);
    });

    test('unknown duration and unknown channel needs a review', () {
      final r = row('Mother', ['Pink Floyd'], ms: 334880);
      final d = decide(r, [yt('a', 'Pink Floyd - Mother', 'SomeUploader')]);
      expect(d.kind, MatchKind.review);
    });

    test('two credited artists are matched', () {
      final r = row('Girl from the North Country',
          ['Bob Dylan', 'Johnny Cash'], ms: 224153);
      final d = decide(r, [
        yt('a', 'Girl from the North Country', 'Bob Dylan - Topic',
            seconds: 224, artists: ['Bob Dylan', 'Johnny Cash']),
      ]);
      expect(d.kind, MatchKind.sure);
    });

    test('another song by the same artist is not found', () {
      final r = row('Mother', ['Pink Floyd'], ms: 334880);
      final d = decide(r, [
        yt('a', 'Another Brick in the Wall, Pt. 2', 'Pink Floyd - Topic',
            seconds: 239, artists: ['Pink Floyd']),
      ]);
      expect(d.kind, MatchKind.notFound);
      expect(d.top, isEmpty);
    });

    test('a cover by someone else is not found', () {
      final r = row('Imagine', ['John Lennon'], ms: 187866);
      final d = decide(r, [
        yt('a', 'Imagine (Cover)', 'Some Guy', seconds: 188, artists: ['Some Guy']),
      ]);
      expect(d.kind, MatchKind.notFound);
    });

    test('very different length is never sure', () {
      final r = row('Mother', ['Pink Floyd'], ms: 334880);
      final d = decide(r, [
        yt('a', 'Mother', 'Pink Floyd - Topic', seconds: 120,
            artists: ['Pink Floyd']),
      ]);
      expect(d.kind, isNot(MatchKind.sure));
    });

    test('at most 3 candidates, best first', () {
      final r = row('Mother', ['Pink Floyd'], ms: 334000);
      final d = decide(r, [
        for (var i = 0; i < 5; i++)
          yt('c$i', 'Mother', 'Pink Floyd - Topic',
              seconds: 334 + i * 3, artists: ['Pink Floyd']),
      ]);
      expect(d.top, hasLength(3));
      expect(d.top.first.score, greaterThanOrEqualTo(d.top.last.score));
      expect(d.best!.result.id, 'c0');
    });

    test('empty candidate list', () {
      expect(decide(felicita, const []).kind, MatchKind.notFound);
    });
  });

  group('LibraryIndex', () {
    final lib = LibraryIndex(const [
      LibraryEntryLite(
          id: 1, title: 'Let It Be', artist: 'The Beatles', durationMs: 243000),
      LibraryEntryLite(
          id: 2, title: 'Felicita', artist: 'Lucio Dalla', durationMs: 345000),
      LibraryEntryLite(id: 3, title: 'Mother', artist: 'Pink Floyd', durationMs: 0),
    ]);

    test('matches ignoring remaster suffix and accents', () {
      expect(
          lib.find(row('Let It Be - Remastered 2009', ['The Beatles'],
                  ms: 243026))
              ?.id,
          1);
      expect(lib.find(row('Felicità', ['Lucio Dalla'], ms: 345360))?.id, 2);
    });

    test('the same title and artist matches whatever the length (D-389)', () {
      expect(lib.find(row('Let It Be', ['The Beatles'], ms: 247500))?.id, 1);
      expect(lib.find(row('Let It Be', ['The Beatles'], ms: 249500))?.id, 1);
    });

    test('unknown library duration still matches', () {
      expect(lib.find(row('Mother', ['Pink Floyd'], ms: 334880))?.id, 3);
    });

    test('other artist does not match', () {
      expect(lib.find(row('Let It Be', ['Someone Else'], ms: 243000)), isNull);
    });
  });

  group('adjustable thresholds', () {
    // Right title and artist but 7 s off: a doubtful match with the defaults.
    final r = row('Song', ['Band'], ms: 200000);
    final cands = [yt('x', 'Song', 'Band - Topic', seconds: 207, artists: ['Band'])];

    test('the default cut-offs are 0.80 and 0.55', () {
      const t = MatchThresholds();
      expect([t.sure, t.review], [0.80, 0.55]);
      expect(decide(r, cands).kind, MatchKind.sure);
    });

    test('a cut-off just over the score demotes the match, just under keeps it',
        () {
      final score = decide(r, cands).best!.score;
      expect(
          decide(r, cands,
                  thresholds: MatchThresholds(sure: score - 0.01, review: 0.4))
              .kind,
          MatchKind.sure);
      expect(
          decide(r, cands,
                  thresholds: MatchThresholds(sure: score + 0.01, review: 0.4))
              .kind,
          MatchKind.review);
    });

    test('a higher «review» sends weak matches to «not found»', () {
      final score = decide(r, cands).best!.score;
      expect(
          decide(r, cands,
                  thresholds: MatchThresholds(sure: 0.98, review: score + 0.01))
              .kind,
          MatchKind.notFound);
    });

    test('clamped keeps review at least 0.05 under sure, inside the limits', () {
      final t = const MatchThresholds(sure: 0.6, review: 0.7).clamped();
      expect(t.sure, 0.6);
      expect(t.review, closeTo(0.55, 1e-9));
      final lo = const MatchThresholds(sure: 0.1, review: 0.0).clamped();
      expect(lo.sure, closeTo(0.35, 1e-9));
      expect(lo.review, 0.30);
      final hi = const MatchThresholds(sure: 2, review: 5).clamped();
      expect(hi.sure, 0.98);
      expect(hi.review, closeTo(0.93, 1e-9));
    });
  });

  test('matchKey: an ʻokina or a modifier apostrophe is the same as a plain one', () {
    expect(matchKey("Israel Kamakawiwoʻole"), matchKey("Israel Kamakawiwo'ole"));
    expect(matchKey('Hawaiʻi'), matchKey("Hawai'i"));
    expect(matchKey('rockʼnʼroll'), matchKey("rock'n'roll"));
  });
}
