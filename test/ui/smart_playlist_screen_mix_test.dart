import 'dart:io';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/data/repositories/smart_playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/database_providers.dart' show smartPlaylistRepositoryProvider;
import 'package:codecore/providers/seed_resolver_provider.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/providers/smart_playlist_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/online/ytm_radio_service.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/ui/screens/smart/smart_playlist_screen.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/track_actions.dart' show TrackMenuHost;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../services/shuffle_plus/genre_mix_test.dart' as fixture show page;
import '../support/app_harness.dart';

class _Radio implements YtmRadioService {
  @override
  Future<RadioPage> page(String videoId, {String? continuation}) async => fixture.page(videoId);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

void main() {
  for (final (warm, slow) in [(false, false), (true, false), (false, true)]) {
  testWidgets('smart playlist page with the real mix chain shows the suggested rows (warm: $warm, slow db: $slow)', (tester) async {
    final h = await Harness.create(tester, tracks: 6, radio: true);
    final dir = Directory.systemTemp.createTempSync('smart_screen_mix');
    addTearDown(() => dir.deleteSync(recursive: true));
    final downloads = DownloadIndex(File(p.join(dir.path, 'd.json')));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => downloads.add('dl$i', '/m/t$i.mp3'));
    }
    final repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
    final id = (await tester.runAsync(() => repo.create(name: 'Mix', rules: '')))!;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = [
      for (final o in h.overrides)
        if (![smartMixProvider, downloadIndexProvider].contains((o as dynamic).origin)) o,
      // The real db answers on a later turn of the event loop than a memory one.
      if (slow) smartPlaylistProvider.overrideWith((ref, id) => ref.watch(smartPlaylistRepositoryProvider).watch(id).asyncMap((p) async {
            await Future<void>.delayed(const Duration(milliseconds: 80));
            return p;
          })),
      downloadIndexProvider.overrideWith((ref) async => downloads),
      seedResolverProvider.overrideWith((ref) async => SeedResolver(
            downloads: downloads,
            index: SeedIndex(file: () async => File(p.join(dir.path, 'seeds.json'))),
            searchSongs: (q) async => const [],
          )),
      ytDlpStatusProvider.overrideWith((ref) async => YtDlpStatus('2026.01.01')),
      networkProbeProvider.overrideWithValue(NetworkProbe(android: false)),
      ytmRadioServiceProvider.overrideWithValue(_Radio()),
      suggestionLogProvider.overrideWithValue(SuggestionLog(
        file: () async => File(p.join(dir.path, 'suggestions.json')),
        writeDelay: const Duration(days: 1),
      )),
    ];
    final container = ProviderContainer(overrides: overrides);
    if (warm) {
      container.listen(smartTracksProvider(id), (_, _) {});
      await tester.runAsync(() => container.read(smartPlaylistProvider(id).future));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildThemeFromColors(CcColors.notte, false),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrackMenuHost(child: SmartPlaylistScreen(id: id)),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Suggerito'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await h.dispose(tester);
  });
}
}
