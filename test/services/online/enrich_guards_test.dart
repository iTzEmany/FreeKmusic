import 'package:codecore/core/clock.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/online/curiosity_finder.dart';
import 'package:codecore/services/online/itunes_client.dart' show ItunesMatch;
import 'package:codecore/services/online/wikipedia_client.dart' show Curiosity;
import 'package:codecore/services/online/enrichment_service.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';

const _all = {
  EnrichPart.meta,
  EnrichPart.lyrics,
  EnrichPart.synced,
  EnrichPart.curio,
  EnrichPart.credits,
};

void main() {
  late EnrichRig r;

  setUp(() => r = EnrichRig());
  tearDown(() => r.dispose());

  Future<void> markUserLyrics(int id) => r.db
      .into(r.db.trackEnrich)
      .insert(
        TrackEnrichCompanion(
          trackId: Value(id),
          lyricsByUser: const Value(true),
        ),
      );

  group('guards', () {
    test('lyrics chosen by hand: no lyrics client is called, not even for the synced one', () async {
      final id = await r.add(plain: 'mine');
      await markUserLyrics(id);
      final out = await r.engine.completeOne(id, {
        EnrichPart.lyrics,
        EnrichPart.synced,
      });
      expect(r.chain.calls, 0);
      expect(out, {
        EnrichPart.lyrics: PartOutcome.skipped,
        EnrichPart.synced: PartOutcome.skipped,
      });
      expect((await r.repo.getById(id))!.lyricsPlain, 'mine');
    });

    test(
      'userEdited: title, artist and album stay, the empty year is filled',
      () async {
        final id = await r.add(userEdited: true);
        await r.engine.completeOne(id, {EnrichPart.meta});
        final t = (await r.repo.getById(id))!;
        expect([t.title, t.artist, t.album], ['Song', 'Band', null]);
        expect(t.year, 2019);
      },
    );

    test('cover_source > 0: no cover is fetched or written', () async {
      final id = await r.add(coverSource: 2);
      await r.engine.completeOne(id, {EnrichPart.meta});
      expect(r.web.bytes, 0);
      expect((await r.repo.getById(id))!.hasCover, isFalse);
    });

    test('a row on the shared unknown|dir cover still fetches its real one', () async {
      final id = await r.add();
      const old = 'unknown|/';
      await (r.db.update(r.db.tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(
          albumKey: const Value(old),
          hasCover: const Value(true),
          coverKey: Value(CoverStore.coverKeyFor(old)),
        ),
      );
      await r.engine.completeOne(id, {EnrichPart.meta});
      final t = (await r.repo.getById(id))!;
      expect(t.hasCover, isTrue);
      expect(t.coverKey, isNot(CoverStore.coverKeyFor(old)));
    });

    test(
      'an empty cover is filled when no hand-made one protects it',
      () async {
        final id = await r.add();
        await r.engine.completeOne(id, {EnrichPart.meta});
        expect((await r.repo.getById(id))!.hasCover, isTrue);
      },
    );

    test('a genre already there is not replaced', () async {
      final id = await r.add(genre: 'Jazz');
      await r.engine.completeOne(id, {EnrichPart.meta});
      final t = (await r.repo.getById(id))!;
      expect(t.genre, 'Jazz');
      expect(t.album, 'New Album');
    });
  });

  group('state per part', () {
    int? none(TrackEnrichData? e, EnrichPart p) => switch (p) {
      EnrichPart.meta => e?.metaNoneAt,
      EnrichPart.lyrics => e?.lyricsNoneAt,
      EnrichPart.synced => e?.syncedNoneAt,
      EnrichPart.curio => e?.curioNoneAt,
      EnrichPart.credits => e?.creditsNoneAt,
    };

    test(
      'a network error leaves no «nothing» mark, an empty answer does',
      () async {
        final id = await r.add();
        r.web.itunes = ItunesMode.down;
        r.chain.failed = true;
        final bad = await r.engine.completeOne(id, {
          EnrichPart.meta,
          EnrichPart.lyrics,
        });
        expect(bad, {
          EnrichPart.meta: PartOutcome.failed,
          EnrichPart.lyrics: PartOutcome.failed,
        });
        expect(await r.enrichOf(id), isNull);

        r.web.itunes = ItunesMode.empty;
        r.chain
          ..failed = false
          ..result = null;
        final empty = await r.engine.completeOne(id, {
          EnrichPart.meta,
          EnrichPart.lyrics,
        });
        expect(empty, {
          EnrichPart.meta: PartOutcome.none,
          EnrichPart.lyrics: PartOutcome.none,
        });
        final e = await r.enrichOf(id);
        expect(none(e, EnrichPart.meta), closeTo(nowMs(), 60000));
        expect(none(e, EnrichPart.lyrics), closeTo(nowMs(), 60000));
        expect(
          e!.syncedNoneAt,
          isNull,
          reason: 'no plain text: nothing to synchronise',
        );
      },
    );

    test('a recent «nothing» is not asked again, force asks, found clears the mark', () async {
      final id = await r.add();
      r.web.itunes = ItunesMode.empty;
      await r.engine.completeOne(id, {EnrichPart.meta});
      final asked = r.web.count('itunes');
      expect(await r.engine.completeOne(id, {EnrichPart.meta}), {
        EnrichPart.meta: PartOutcome.skipped,
      });
      expect(r.web.count('itunes'), asked);

      r.web.itunes = ItunesMode.match;
      final out = await r.engine.completeOne(id, {EnrichPart.meta}, force: true);
      expect(out, {EnrichPart.meta: PartOutcome.found});
      expect((await r.enrichOf(id))!.metaNoneAt, isNull);
      expect((await r.repo.getById(id))!.album, 'New Album');
    });

    test('a «nothing» older than 30 days is asked again', () async {
      final id = await r.add();
      final old = DateTime.now()
          .subtract(const Duration(days: 31))
          .millisecondsSinceEpoch;
      await r.db
          .into(r.db.trackEnrich)
          .insert(
            TrackEnrichCompanion(trackId: Value(id), metaNoneAt: Value(old)),
          );
      expect(await r.engine.completeOne(id, {EnrichPart.meta}), {
        EnrichPart.meta: PartOutcome.found,
      });
      expect((await r.enrichOf(id))!.metaNoneAt, isNull);
    });

    test(
      'plain lyrics only: the synced part is asked and, with nothing, marked',
      () async {
        final id = await r.add(plain: 'words');
        r.chain.result = const LyricsResult(plain: 'words');
        final out = await r.engine.completeOne(id, {
          EnrichPart.lyrics,
          EnrichPart.synced,
        });
        expect(out, {
          EnrichPart.lyrics: PartOutcome.skipped,
          EnrichPart.synced: PartOutcome.none,
        });
        expect((await r.enrichOf(id))!.syncedNoneAt, isNotNull);
        expect((await r.repo.getById(id))!.lyricsPlain, 'words');

        r.chain.result = const LyricsResult(
          plain: 'other',
          synced: '[00:01.00]words',
        );
        expect(await r.engine.completeOne(id, {EnrichPart.synced}, force: true), {
          EnrichPart.synced: PartOutcome.found,
        });
        final t = (await r.repo.getById(id))!;
        expect([t.lyricsPlain, t.lyricsSynced], ['words', '[00:01.00]words']);
      },
    );

    test(
      'plain lyrics found while NetEase errored: text saved, no synced mark',
      () async {
        final id = await r.add();
        r.chain
          ..result = const LyricsResult(plain: 'words')
          ..syncedFailed = true;
        final out = await r.engine.completeOne(id, {
          EnrichPart.lyrics,
          EnrichPart.synced,
        });
        expect(out, {
          EnrichPart.lyrics: PartOutcome.found,
          EnrichPart.synced: PartOutcome.failed,
        });
        expect((await r.repo.getById(id))!.lyricsPlain, 'words');
        expect((await r.enrichOf(id))!.syncedNoneAt, isNull);
      },
    );

    test('force redoes the curiosities over a text already there; without force it does not', () async {
      final id = await r.add(curiosities: 'old\nhttps://x');
      expect(await r.engine.completeOne(id, {EnrichPart.curio}), {
        EnrichPart.curio: PartOutcome.skipped,
      });
      expect(r.finder.calls, 0);
      expect(await r.engine.completeOne(id, {EnrichPart.curio}, force: true), {
        EnrichPart.curio: PartOutcome.found,
      });
      expect(r.finder.calls, 1);
      expect((await r.repo.getById(id))!.curiosities, startsWith('A story'));
    });

    test(
      'metadata: nothing found → status 2; a filled field → status 1',
      () async {
        final id = await r.add();
        r.web.itunes = ItunesMode.empty;
        await r.engine.completeOne(id, {EnrichPart.meta});
        expect((await r.repo.getById(id))!.enrichStatus, 2);
        r.web.itunes = ItunesMode.match;
        await r.engine.completeOne(id, {EnrichPart.meta}, force: true);
        expect((await r.repo.getById(id))!.enrichStatus, 1);
      },
    );

    test('a match that fills nothing empty is «nothing», with its mark and status 2', () async {
      final id = await r.add(
        album: 'Mine',
        genre: 'Jazz',
        year: 1999,
        trackNumber: 1,
        coverSource: 1,
      );
      final out = await r.engine.completeOne(id, {EnrichPart.meta});
      expect(out, {EnrichPart.meta: PartOutcome.none});
      expect((await r.enrichOf(id))!.metaNoneAt, isNotNull);
      final t = (await r.repo.getById(id))!;
      expect(
        [t.album, t.genre, t.year, t.enrichStatus],
        ['Mine', 'Jazz', 1999, 2],
      );
    });

    test('Deezer on but resting or unreachable: the metadata part failed, not «nothing»', () async {
      final id = await r.add();
      r.deezerMeta = true;
      r.web.deezerDown = true;
      expect(await r.engine.completeOne(id, {EnrichPart.meta}), {
        EnrichPart.meta: PartOutcome.failed,
      });
      expect(await r.enrichOf(id), isNull);
    });

    test(
      'lyrics saved by the user while the sources were asked are not replaced',
      () async {
        final id = await r.add();
        r.chain.during = () =>
            r.repo.setLyrics(id, plain: 'mine', byUser: true);
        await r.engine.completeOne(id, {EnrichPart.lyrics, EnrichPart.synced});
        final t = (await r.repo.getById(id))!;
        expect([t.lyricsPlain, t.lyricsSynced], ['mine', null]);
      },
    );

    test('a generic curiosity error is failed and leaves no mark', () async {
      final id = await r.add();
      r.finder.pair = CuriosityPair(songError: Exception('boom'));
      final out = await r.engine.completeOne(id, {EnrichPart.curio});
      expect(out[EnrichPart.curio], PartOutcome.failed);
      expect(await r.enrichOf(id), isNull);
    });

    test('a failed song lookup under force leaves the old curiosity', () async {
      final id = await r.add(curiosities: 'old\nsrc');
      r.finder.pair = CuriosityPair(songError: Exception('boom'));
      await r.engine.completeOne(id, {EnrichPart.curio}, force: true);
      expect((await r.repo.getById(id))!.curiosities, 'old\nsrc');
    });

    test(
      'no lyrics at all: the lyrics part is marked, the synced one is not',
      () async {
        final id = await r.add();
        r.chain.result = null;
        await r.engine.completeOne(id, {EnrichPart.lyrics, EnrichPart.synced});
        final e = (await r.enrichOf(id))!;
        expect([e.lyricsNoneAt != null, e.syncedNoneAt], [true, null]);
      },
    );

    test(
      'lyrics asked without synced: the chain is told not to look for it',
      () async {
        final id = await r.add();
        await r.engine.completeOne(id, {EnrichPart.lyrics});
        expect(r.chain.wantSyncedSeen, isFalse);
      },
    );

    test('only a synced text saved by the user meanwhile: the plain one is not added', () async {
      final id = await r.add();
      r.chain.during = () =>
          r.repo.setLyrics(id, synced: '[00:01.00]mine', byUser: true);
      await r.engine.completeOne(id, {EnrichPart.lyrics, EnrichPart.synced});
      final t = (await r.repo.getById(id))!;
      expect([t.lyricsPlain, t.lyricsSynced], [null, '[00:01.00]mine']);
    });

    test('a refused curiosity search leaves no mark; an empty page marks, even with a bio', () async {
      final id = await r.add();
      r.finder.pair = CuriosityPair(songError: const RateLimitedException(429));
      expect(await r.engine.completeOne(id, {EnrichPart.curio}), {
        EnrichPart.curio: PartOutcome.limited,
      });
      expect(await r.enrichOf(id), isNull);

      r.finder.pair = const CuriosityPair();
      expect(await r.engine.completeOne(id, {EnrichPart.curio}), {
        EnrichPart.curio: PartOutcome.none,
      });
      expect((await r.enrichOf(id))!.curioNoneAt, isNotNull);
    });

    test('artist refused but the song text found: found, mark cleared', () async {
      final id = await r.add();
      await r.credits.saveEnrich(
        TrackEnrichCompanion(trackId: Value(id), curioNoneAt: const Value(1)),
      );
      r.finder.pair = CuriosityPair(
        song: Curiosity('A story', Uri.parse('https://it.wikipedia.org/wiki/X'), 'it'),
        artistError: const RateLimitedException(429),
      );
      expect(await r.engine.completeOne(id, {EnrichPart.curio}), {
        EnrichPart.curio: PartOutcome.found,
      });
      expect((await r.enrichOf(id))!.curioNoneAt, isNull);
    });

    test(
      'every part found: columns, credits and marks are all written',
      () async {
        final id = await r.add();
        final out = await r.engine.completeOne(id, _all);
        expect(out, {for (final p in _all) p: PartOutcome.found});
        final t = (await r.repo.getById(id))!;
        expect(
          [t.album, t.lyricsPlain, t.lyricsSynced],
          ['New Album', 'la la', '[00:01.00]la la'],
        );
        expect(t.curiosities, isNotNull);
        expect(await r.credits.creditsOf(id), isNotEmpty);
        final e = (await r.enrichOf(id))!;
        expect([
          e.metaNoneAt,
          e.lyricsNoneAt,
          e.syncedNoneAt,
          e.curioNoneAt,
          e.creditsNoneAt,
        ], everyElement(isNull));
        expect(e.details, isNotNull);
      },
    );
  });

  group('refused, cancelled, cover', () {
    test(
      'a refusal (429) is «limited», never «nothing», and leaves no mark',
      () async {
        final id = await r.add(plain: 'x'); // synced alone is asked for
        r.web.itunes = ItunesMode.limited;
        r.chain.limited = true;
        r.web.musicBrainzLimited = true;
        r.web.deezerDown = true;
        final out = await r.engine.completeOne(id, _all);
        expect(out[EnrichPart.meta], PartOutcome.limited);
        expect(out[EnrichPart.synced], PartOutcome.limited);
        expect(out[EnrichPart.credits], PartOutcome.limited);
        expect(out[EnrichPart.curio], PartOutcome.found);
        final e = await r.enrichOf(id);
        expect([
          e?.metaNoneAt,
          e?.syncedNoneAt,
          e?.creditsNoneAt,
        ], everyElement(isNull));
      },
    );

    test(
      'a refused lyrics search is limited, a broken one is failed',
      () async {
        final id = await r.add();
        r.chain.limited = true;
        expect(await r.engine.completeOne(id, {EnrichPart.lyrics}), {
          EnrichPart.lyrics: PartOutcome.limited,
        });
        r.chain
          ..limited = false
          ..failed = true;
        expect(await r.engine.completeOne(id, {EnrichPart.lyrics}), {
          EnrichPart.lyrics: PartOutcome.failed,
        });
      },
    );

    test('cancelled while the lyrics are asked: neither credits nor curiosities are asked', () async {
      final id = await r.add();
      final token = CancelToken();
      r.chain.during = () async => token.cancel();
      await expectLater(
        r.engine.completeOne(id, {
          EnrichPart.lyrics,
          EnrichPart.credits,
          EnrichPart.curio,
        }, cancel: token),
        throwsA(
          isA<DioException>().having(
            (e) => CancelToken.isCancel(e),
            'cancel',
            isTrue,
          ),
        ),
      );
      expect(r.web.count('musicbrainz'), 0);
      expect(r.finder.calls, 0);
      expect(await r.enrichOf(id), isNull);
    });

    test(
      'cancelled while the credits are asked: the curiosities are not',
      () async {
        final id = await r.add();
        final token = CancelToken();
        r.web.onUrl = (u) {
          if (u.contains('musicbrainz')) token.cancel();
        };
        await expectLater(
          r.engine.completeOne(id, {
            EnrichPart.credits,
            EnrichPart.curio,
          }, cancel: token),
          throwsA(isA<DioException>()),
        );
        expect(r.finder.calls, 0);
      },
    );

    test('the cover is the only thing to fill and its download fails: failed, no mark cleared', () async {
      final id = await r.add(
        album: 'A',
        genre: 'G',
        year: 2000,
        trackNumber: 1,
      );
      await r.credits.saveEnrich(
        TrackEnrichCompanion(trackId: Value(id), metaNoneAt: const Value(1)),
      );
      r.web.coverDown = true;
      final out = await r.engine.completeOne(id, {EnrichPart.meta}, force: true);
      expect(out, {EnrichPart.meta: PartOutcome.failed});
      expect((await r.enrichOf(id))!.metaNoneAt, 1);
      expect((await r.repo.getById(id))!.hasCover, isFalse);
    });

    test('apply with the cover download down: fields written, no cover, no throw', () async {
      final id = await r.add();
      final t = (await r.repo.getById(id))!;
      r.web.coverDown = true;
      final ok = await r.svc.apply(
        EnrichmentProposal(
          track: t,
          meta: const ItunesMatch(
            title: 'T',
            artist: 'A',
            album: 'Alb',
            artworkUrl: 'https://x/c.jpg',
          ),
        ),
        {EnrichField.album, EnrichField.cover},
      );
      expect(ok, isTrue);
      final u = (await r.repo.getById(id))!;
      expect([u.album, u.hasCover], ['Alb', false]);
    });

    test('the cover does not exist but a lyrics text is found: the status stays 1', () async {
      final id = await r.add(album: 'A', genre: 'G', year: 2000, trackNumber: 1);
      r.web.coverMissing = true;
      await r.engine.completeOne(id, {EnrichPart.meta, EnrichPart.lyrics}, force: true);
      final t = (await r.repo.getById(id))!;
      expect([t.lyricsPlain, t.enrichStatus], ['la la', isNot(2)]);
    });

    test('propose: a refused lyrics search without text says limited, nothing thrown', () async {
      final id = await r.add();
      r.chain.limited = true;
      final p = await r.svc.propose((await r.repo.getById(id))!);
      expect(p.limited, isTrue);
      expect(p.lyrics, isNull);
    });

    test('propose: a refused source (iTunes) says limited too', () async {
      r.web.itunes = ItunesMode.limited;
      final p = await r.svc.propose((await r.repo.getById(await r.add()))!);
      expect([p.limited, p.meta], [true, isNull]);
    });

    test('the song answered nothing and the artist was refused: none, marked', () async {
      final id = await r.add();
      r.finder.pair = const CuriosityPair(artistError: RateLimitedException(429));
      expect(await r.engine.completeOne(id, {EnrichPart.curio}), {
        EnrichPart.curio: PartOutcome.none,
      });
      expect((await r.enrichOf(id))!.curioNoneAt, isNotNull);
    });

    test('the cover does not exist (404): nothing, mark set', () async {
      final id = await r.add(
        album: 'A',
        genre: 'G',
        year: 2000,
        trackNumber: 1,
      );
      r.web.coverMissing = true;
      final out = await r.engine.completeOne(id, {EnrichPart.meta}, force: true);
      expect(out, {EnrichPart.meta: PartOutcome.none});
      expect((await r.enrichOf(id))!.metaNoneAt, isNotNull);
    });

    test('the cover is the only thing to fill and it is saved: found, mark cleared', () async {
      final id = await r.add(
        album: 'A',
        genre: 'G',
        year: 2000,
        trackNumber: 1,
      );
      await r.credits.saveEnrich(
        TrackEnrichCompanion(trackId: Value(id), metaNoneAt: const Value(1)),
      );
      final out = await r.engine.completeOne(id, {EnrichPart.meta}, force: true);
      expect(out, {EnrichPart.meta: PartOutcome.found});
      expect((await r.enrichOf(id))!.metaNoneAt, isNull);
      final t = (await r.repo.getById(id))!;
      expect([t.hasCover, t.enrichStatus], [true, 1]);
    });
  });
}
