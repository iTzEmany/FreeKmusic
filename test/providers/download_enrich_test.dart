import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/library/download_tagger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enrich_fakes.dart';

class _Tagger implements DownloadTagger {
  final tagged = <int>[];

  @override
  Future<void> tag(int id) async => tagged.add(id);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Settings extends SettingsNotifier {
  _Settings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;
}

void main() {
  late EnrichRig r;
  late _Tagger tagger;

  setUp(() {
    r = EnrichRig();
    tagger = _Tagger();
  });
  tearDown(() => r.dispose());

  /// Downloads a song with the switches as given and waits for the enricher.
  Future<(int, bool)> download(AppSettings s) async {
    final id = await r.add();
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(() => _Settings(s)),
        enrichEngineProvider.overrideWithValue(r.engine),
        downloadTaggerProvider.overrideWithValue(tagger),
      ],
    );
    addTearDown(c.dispose);
    final enricher = c.read(downloadEnricherProvider);
    final queued = autoParts(s).isNotEmpty;
    final done = queued ? enricher.changes.firstWhere((p) => p.isEmpty) : null;
    enricher.add(id);
    expect(enricher.pending.isNotEmpty, queued);
    await done?.timeout(const Duration(seconds: 10));
    return (id, queued);
  }

  test('everything on: the song gets tags, lyrics, curiosities and credits, then the file tag', () async {
    final (id, _) = await download(
      AppSettings(
        autoEnrich: true,
        autoLyrics: true,
        autoCuriosities: true,
        creditsDetails: true,
      ),
    );
    final t = (await r.repo.getById(id))!;
    expect(
      [t.album, t.lyricsPlain, t.lyricsSynced],
      ['New Album', 'la la', '[00:01.00]la la'],
    );
    expect(t.curiosities, isNotNull);
    expect(await r.credits.creditsOf(id), isNotEmpty);
    expect(tagger.tagged, [id]);
  });

  test('curiosities off: the curiosity finder is never asked', () async {
    final (id, _) = await download(
      AppSettings(autoEnrich: true, autoLyrics: true, autoCuriosities: false, creditsDetails: true),
    );
    expect(r.finder.calls, 0);
    expect((await r.repo.getById(id))!.curiosities, isNull);
    expect(r.chain.calls, 1);
  });

  test('credits off: neither Deezer nor MusicBrainz is asked', () async {
    final (id, _) = await download(
      AppSettings(autoEnrich: true, autoLyrics: true, autoCuriosities: true, creditsDetails: false),
    );
    expect(r.web.count('musicbrainz'), 0);
    expect(r.web.count('/track/'), 0);
    expect(await r.credits.creditsOf(id), isEmpty);
  });

  test('everything off: nothing is queued and no source is called', () async {
    final (_, queued) = await download(AppSettings(autoEnrich: false, autoLyrics: false, autoCuriosities: false, creditsDetails: false));
    expect(queued, isFalse);
    expect(r.web.urls, isEmpty);
    expect(r.chain.calls + r.finder.calls, 0);
  });

  test('a received song goes to the enricher when a part is on, else to the tagger', () async {
    for (final (s, queued) in [(AppSettings(autoEnrich: false, autoLyrics: true, autoCuriosities: false, creditsDetails: false), true), (AppSettings(autoEnrich: false, autoLyrics: false, autoCuriosities: false, creditsDetails: false), false)]) {
      final id = await r.add(path: '/r$queued.mp3');
      final c = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(() => _Settings(s)),
          enrichEngineProvider.overrideWithValue(r.engine),
          downloadTaggerProvider.overrideWithValue(tagger),
        ],
      );
      addTearDown(c.dispose);
      afterReceive(c.read, id);
      expect(c.read(downloadEnricherProvider).pending.isNotEmpty, queued);
      expect(tagger.tagged.contains(id), !queued);
    }
  });
}
