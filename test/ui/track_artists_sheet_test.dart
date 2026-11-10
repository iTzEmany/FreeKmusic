import 'dart:async';

import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/l10n/l10n_ext.dart';
import 'package:codecore/services/online/artist_link_resolver.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/ui/widgets/track_artists_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _pump(WidgetTester tester, List<ArtistName> artists,
    {Future<List<YtmArtistRef>> Function(String)? search}) async {
  final asked = <String>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      artistLinkResolverProvider.overrideWithValue(ArtistLinkResolver(
        library: (name) async {
          asked.add(name);
          return null;
        },
        search: search ?? (_) async => [],
      )),
    ],
    child: MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => goToArtists(context, ref, artists),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  ));
  return asked;
}

void main() {
  testWidgets('several artists: a sheet with one name each, a tap opens that artist', (tester) async {
    final asked = await _pump(tester, const [ArtistName('Alfa'), ArtistName('Beta')]);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackArtistsSheet), findsOneWidget);
    expect(find.text('Alfa'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackArtistsSheet), findsNothing);
    expect(asked, ["Beta"]);
  });

  testWidgets('one artist: opens it at once, no sheet', (tester) async {
    final asked = await _pump(tester, const [ArtistName('Alfa')]);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackArtistsSheet), findsNothing);
    expect(asked, ["Alfa"]);
  });

  testWidgets('sheet dismissed without a choice: nothing is opened', (tester) async {
    final asked = await _pump(tester, const [ArtistName('Alfa'), ArtistName('Beta')]);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // the barrier
    await tester.pumpAndSettle();
    expect(find.byType(TrackArtistsSheet), findsNothing);
    expect(asked, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a network error while searching shows the network text', (tester) async {
    await _pump(tester, const [ArtistName('Alfa')],
        search: (_) async => throw const YtException(YtErrorKind.network));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // not settle: the snackbar ring animates until it closes
    final ctx = tester.element(find.text('go'));
    expect(find.text(ctx.l10n.ytErrNetwork), findsOneWidget);
  });

  testWidgets('a double tap starts one search', (tester) async {
    var searches = 0;
    final gate = Completer<List<YtmArtistRef>>();
    await _pump(tester, const [ArtistName('Alfa')], search: (_) {
      searches++;
      return gate.future;
    });
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(searches, 1);
    gate.complete([]);
    await tester.pumpAndSettle();
  });
}
