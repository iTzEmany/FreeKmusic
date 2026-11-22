import 'package:codecore/providers/online_providers.dart' show autoParts;
import 'package:codecore/services/online/enrich_engine.dart' show GatherSignal;
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:codecore/services/online/enrich_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';

void main() {
  late EnrichRig r;

  setUp(() => r = EnrichRig());
  tearDown(() => r.dispose());

  const lyrics = {EnrichPart.lyrics};

  group('in flight', () {
    test('download and background on the same id ask the sources once', () async {
      final id = await r.add();
      final background = await r.engine.gather(id, lyrics);
      var ended = false;
      final download = r.engine.completeOne(id, lyrics).whenComplete(() => ended = true); // waits for the commit
      await Future<void>.delayed(Duration.zero);
      expect([r.chain.calls, ended], [1, false]);
      await r.engine.commit([background]);
      final out = await download;
      expect(r.chain.calls, 1, reason: 'the text is there: nothing is due');
      expect(out[EnrichPart.lyrics], PartOutcome.skipped);
      expect((await r.repo.getById(id))!.lyricsPlain, 'la la');
    });

    test('committing a gather that owns nothing does not free the track in flight', () async {
      final id = await r.add();
      final owner = await r.engine.gather(id, lyrics);
      final second = await r.engine.gather(id, lyrics);
      await r.engine.commit([second]);
      expect((await r.engine.gather(id, lyrics)).signal, GatherSignal.askedNothing);
      await r.engine.commit([owner]);
    });

    test('a gather of a track in flight asks nothing; once committed it is free again', () async {
      final id = await r.add();
      final first = r.engine.completeOne(id, lyrics);
      final second = await r.engine.gather(id, lyrics);
      expect(second.signal, GatherSignal.askedNothing);
      await first;
      expect(r.chain.calls, 1);
      expect((await r.engine.gather(id, lyrics)).signal, GatherSignal.askedNothing,
          reason: 'filled by the first');
    });
  });

  group('what completeOne writes today', () {
    const meta = {EnrichPart.meta};

    test('only the empty fields: a filled album and year stay, the empty genre is filled', () async {
      final id = await r.add(album: 'Mine', year: 1999);
      await r.engine.completeOne(id, meta);
      final t = (await r.repo.getById(id))!;
      expect([t.album, t.year, t.genre], ['Mine', 1999, 'Rock']);
    });

    test('all switches off: no part, no request', () async {
      final id = await r.add();
      expect(autoParts(helpersOff()), isEmpty);
      await r.engine.completeOne(id, autoParts(helpersOff()));
      expect([r.web.urls, r.chain.calls, r.finder.calls], [isEmpty, 0, 0]);
    });

    test('only autoLyrics on: lyrics are asked, metadata is not', () async {
      final id = await r.add();
      await r.engine.completeOne(id, autoParts(helpersOff(autoLyrics: true)));
      expect(r.chain.calls, 1);
      expect(r.web.count('itunes'), 0);
    });

    test('nothing found leaves the «nothing» marks on the asked parts only', () async {
      r.web.itunes = ItunesMode.empty;
      r.chain.result = null;
      final id = await r.add();
      await r.engine.completeOne(id, {EnrichPart.meta, EnrichPart.lyrics});
      final e = (await r.enrichOf(id))!;
      expect([e.metaNoneAt, e.lyricsNoneAt], [isNotNull, isNotNull]);
      expect([e.curioNoneAt, e.syncedNoneAt], [isNull, isNull]);
    });
  });

  test('runner over a fixed list: «N of M» progress and counts', () async {
    final ids = [
      for (var n = 0; n < 3; n++) await r.add(path: '/t$n.mp3'),
    ];
    final seen = <(int, int)>[];
    final round = await EnrichRunner(
      engine: r.engine,
      ids: FixedIds(ids),
      parts: () => lyrics,
      waitIdle: () async {},
      mode: AskMode.retryNone,
      onProgress: (d, t) => seen.add((d, t)),
    ).run();
    expect(seen, [(1, 3), (2, 3), (3, 3), (3, 3)]); // each track, then the block
    expect(round.worked, 3);
    expect(round.updated[EnrichPart.lyrics], ids);
    expect(round.failed, isFalse);
  });
}
