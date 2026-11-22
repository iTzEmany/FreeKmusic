import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final _day0 = DateTime(2026, 1, 1);
DateTime _at(int day) => _day0.add(Duration(days: day));
int _ms(int day) => _at(day).millisecondsSinceEpoch;

TrackEnrichData _enrich({
  int? lyricsNone,
  int? syncedNone,
  int? creditsNone,
  bool byUser = false,
}) => TrackEnrichData(
  trackId: 1,
  lyricsNoneAt: lyricsNone,
  syncedNoneAt: syncedNone,
  creditsNoneAt: creditsNone,
  lyricsByUser: byUser,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Track> track({String? plain, String? synced}) async {
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: '/a.mp3',
            title: 'Song',
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            lyricsPlain: Value(plain),
            lyricsSynced: Value(synced),
          ),
        );
    return db.select(db.tracks).getSingle();
  }

  test(
    'never searched: due; none at day 0: not due at 29, due at 31',
    () async {
      final t = await track();
      expect(isDue(EnrichPart.lyrics, t, null, _at(0)), isTrue);
      final e = _enrich(lyricsNone: _ms(0));
      expect(isDue(EnrichPart.lyrics, t, e, _at(29)), isFalse);
      expect(isDue(EnrichPart.lyrics, t, e, _at(31)), isTrue);
    },
  );

  test('instrumental titles are recognised', () {
    for (final t in ['Song (Instrumental)', 'Song [instrumental]', 'Song Instrumental Version', 'Song - Instrumental']) {
      expect(isInstrumentalTitle(t), isTrue, reason: t);
    }
    expect(isInstrumentalTitle('Instrumentality'), isFalse);
    expect(isInstrumentalTitle('Song'), isFalse);
  });

  test('an instrumental (flag or title) has no lyrics or synced part due', () async {
    final t = await track(plain: 'x');
    final flagged = TrackEnrichData(trackId: t.id, lyricsByUser: false, instrumental: true);
    expect(isDue(EnrichPart.synced, t, null, _at(0)), isTrue); // the control
    for (final p in [EnrichPart.lyrics, EnrichPart.synced]) {
      expect(isDue(p, t, flagged, _at(0)), isFalse);
      expect(isDue(p, t.copyWith(title: 'Song (Instrumental)'), null, _at(0)), isFalse);
    }
  });

  test('a filled part is never due', () async {
    final t = await track(plain: 'la la');
    expect(isDue(EnrichPart.lyrics, t, null, _at(99)), isFalse);
    expect(
      isDue(EnrichPart.credits, t, null, _at(0), hasCredits: true),
      isFalse,
    );
    expect(isDue(EnrichPart.credits, t, null, _at(0)), isTrue);
  });

  test(
    'synced: only with a plain text, not the user\'s, and no synced one',
    () async {
      final none = _enrich(syncedNone: _ms(0));
      final withPlain = await track(plain: 'la la');
      expect(isDue(EnrichPart.synced, withPlain, null, _at(0)), isTrue);
      expect(isDue(EnrichPart.synced, withPlain, none, _at(29)), isFalse);
      expect(isDue(EnrichPart.synced, withPlain, none, _at(31)), isTrue);
      expect(
        isDue(EnrichPart.synced, withPlain, _enrich(byUser: true), _at(0)),
        isFalse,
      );
      await db.delete(db.tracks).go();
      expect(isDue(EnrichPart.synced, await track(), null, _at(0)), isFalse);
      await db.delete(db.tracks).go();
      expect(
        isDue(
          EnrichPart.synced,
          await track(plain: 'a', synced: '[0]a'),
          null,
          _at(0),
        ),
        isFalse,
      );
    },
  );

  test('credits follow the same 30 days', () async {
    final t = await track();
    final e = _enrich(creditsNone: _ms(0));
    expect(isDue(EnrichPart.credits, t, e, _at(29)), isFalse);
    expect(isDue(EnrichPart.credits, t, e, _at(31)), isTrue);
  });

  test('exactly 30 days is not yet due', () async {
    final t = await track();
    expect(
      isDue(EnrichPart.lyrics, t, _enrich(lyricsNone: _ms(0)), _at(30)),
      isFalse,
    );
  });

  test('lyrics written by the user are never due', () async {
    final t = await track();
    expect(
      isDue(EnrichPart.lyrics, t, _enrich(byUser: true), _at(99)),
      isFalse,
    );
  });

  test('retryNone asks again over a recent mark; force also over a full curiosity', () async {
    final t = await track();
    final e = _enrich(lyricsNone: _ms(0));
    expect(isDue(EnrichPart.lyrics, t, e, _at(1), mode: AskMode.retryNone), isTrue);
    expect(isDue(EnrichPart.lyrics, t, e, _at(1)), isFalse);
    await db.delete(db.tracks).go();
    final filled = await track(plain: 'la la');
    expect(isDue(EnrichPart.lyrics, filled, e, _at(99), mode: AskMode.retryNone), isFalse);
    expect(isDue(EnrichPart.lyrics, filled, e, _at(99), mode: AskMode.force), isFalse);
  });

  test('a userEdited track keeps its empty album: it is not fillable, nor does it make meta due', () async {
    await db.into(db.tracks).insert(
          TracksCompanion.insert(
            path: '/e.mp3',
            title: 'Song',
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            userEdited: const Value(true),
            year: const Value(2000),
            genre: const Value('G'),
            trackNumber: const Value(1),
            hasCover: const Value(true),
          ),
        );
    final t = await db.select(db.tracks).getSingle();
    expect(fillableFields(t), {EnrichField.lyrics});
    expect(isDue(EnrichPart.meta, t, null, _at(0)), isFalse);
    expect(fillableFields(t.copyWith(userEdited: false)), contains(EnrichField.album));
  });

  group('statusAfter', () {
    const f = PartOutcome.found, n = PartOutcome.none;
    const x = PartOutcome.failed, l = PartOutcome.limited, k = PartOutcome.skipped;
    const u = EnrichStatus.untried, y = EnrichStatus.found, z = EnrichStatus.nothing;
    final cases = <(String, EnrichStatus, Map<EnrichPart, PartOutcome>, EnrichStatus?)>[
      ('one found', u, {EnrichPart.meta: n, EnrichPart.curio: f}, y),
      ('found beats a failure', u, {EnrichPart.meta: x, EnrichPart.lyrics: f}, y),
      ('found from nothing', z, {EnrichPart.lyrics: f}, y),
      ('all none from untried', u, {EnrichPart.meta: n, EnrichPart.lyrics: n}, z),
      ('skipped parts were not asked', u, {EnrichPart.meta: n, EnrichPart.lyrics: k}, z),
      ('curiosity only, none: not nothing', u, {EnrichPart.curio: n}, null),
      ('lyrics only, none: not nothing', u, {EnrichPart.lyrics: n, EnrichPart.synced: n}, null),
      ('none and failed', u, {EnrichPart.meta: n, EnrichPart.lyrics: x}, null),
      ('none and limited', u, {EnrichPart.meta: n, EnrichPart.lyrics: l}, null),
      ('all none from found stays found (D-285)', y, {EnrichPart.meta: n}, null),
      ('all none from nothing', z, {EnrichPart.meta: n}, null),
      ('nothing asked', u, {EnrichPart.meta: k}, null),
      ('no parts', u, <EnrichPart, PartOutcome>{}, null),
      ('credits found do not count', u, {EnrichPart.credits: f}, null),
      ('a credits failure does not block nothing', u, {EnrichPart.meta: n, EnrichPart.credits: x}, z),
      ('credits none do not count', u, {EnrichPart.meta: n, EnrichPart.credits: n}, z),
    ];
    for (final (name, before, out, want) in cases) {
      test(name, () => expect(statusAfter(before, out), want));
    }

    test('codes match the database', () {
      expect([for (final s in EnrichStatus.values) s.code], [0, 1, 2]);
      expect(EnrichStatus.fromCode(2), EnrichStatus.nothing);
      expect(EnrichStatus.fromCode(7), EnrichStatus.untried);
    });
  });
}
