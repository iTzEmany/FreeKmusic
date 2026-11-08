import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/request_budget.dart' show WindowLimiter;
import 'package:codecore/services/online/source_cooldown.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/ui/screens/online/artist_picker_sheet.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Throwing429 implements YtmCatalog {
  int calls = 0;

  @override
  Future<List<YtmArtistRef>> searchArtists(String query, String hl, {CancelToken? cancel}) async {
    calls++;
    throw const YtException(YtErrorKind.rateLimited);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('picker sheet scrolls without overflow on a small screen at 150% text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final artists = [
      for (var i = 0; i < 12; i++)
        YtmArtistRef(
          id: 'UC$i',
          name: 'Un artista dal nome molto molto lungo numero $i',
          audience: '25.9M ascoltatori mensili, un testo piuttosto lungo',
        ),
    ];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildThemeFromColors(CcColors.notte, false),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => ArtistPickerSheet(artists: artists),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.byKey(const ValueKey('pick-UC11')).hitTestable(), findsOneWidget);
  });

  testWidgets('mergeArtistWith: a 429 is shown in the sheet, trips the pause and costs 1 slot', (tester) async {
    final cat = _Throwing429();
    final limiter = WindowLimiter(perMinute: 20);
    final cooldown = SourceCooldown();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ytmCatalogProvider.overrideWithValue(cat),
        ytmLanguageProvider.overrideWithValue('it'),
        searchRowsLimiterProvider.overrideWithValue(limiter),
        sourceCooldownProvider.overrideWithValue(cooldown),
      ],
      child: MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildThemeFromColors(CcColors.notte, false),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => mergeArtistWith(context, ref, const YtmArtistRef(id: 'UC1', name: 'Queen'), ['UC1']),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final shown = tester.widget<Text>(find.byKey(const ValueKey('merge-message'))).data;
    expect(shown, lookupAppLocalizations(const Locale('it')).ytErrRateLimited);
    expect(cat.calls, 1);
    expect(cooldown.isPaused(MediaKind.ytmSong), isTrue);
    expect(limiter.recent, 1); // today one search spends one slot (the analysis said 2)
  });
}
