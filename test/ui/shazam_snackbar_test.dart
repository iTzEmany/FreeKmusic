import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/shazam_providers.dart';
import 'package:codecore/providers/ui_providers.dart';
import 'package:codecore/services/online/shared_text.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/shell/shazam_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ytm.dart';


class _Ctrl implements PlayerController {
  YtResult? played;
  @override
  Future<bool?> playFromSearch({track, YtResult? online}) async {
    played = online;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Inbox implements ShazamInbox {
  _Inbox(this.results);
  final List<ShazamResult> results;
  int calls = 0;
  @override
  Future<ShazamResult> add(ShazamShare s) async => results[calls++];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _share = ShazamShare('Siren', 'The Chainsmokers');

void main() {
  final song = ytmSong('y1', 'Siren');

  Future<(_Inbox, _Ctrl, ProviderContainer)> pump(WidgetTester tester, List<ShazamResult> results) async {
    final inbox = _Inbox(results);
    final ctrl = _Ctrl();
    final c = ProviderContainer(overrides: [
      shazamInboxProvider.overrideWithValue(inbox),
      playerControllerProvider.overrideWithValue(ctrl),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => handleShazamShare(context, ref, _share),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return (inbox, ctrl, c);
  }

  testWidgets('added: names the song and Ascolta plays it from search', (tester) async {
    final (_, ctrl, _) = await pump(tester, [ShazamAdded('Siren', online: song)]);
    expect(find.text('Aggiunto a Da Shazam: Siren'), findsOneWidget);
    await tester.tap(find.text('Ascolta'));
    expect(ctrl.played, song);
  });

  testWidgets('not found: Cerca fills the search with title and artist', (tester) async {
    final (_, _, c) = await pump(tester, [const ShazamNotFound()]);
    expect(find.text('Non trovato su YouTube Music: Siren'), findsOneWidget);
    await tester.tap(find.text('Cerca'));
    expect(c.read(searchPrefillProvider), 'Siren The Chainsmokers');
  });

  testWidgets('offline: Riprova runs add again', (tester) async {
    final (inbox, _, _) = await pump(tester, [const ShazamRetry(), const ShazamDuplicate('Siren')]);
    await tester.tap(find.text('Riprova'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(inbox.calls, 2);
    expect(find.text('Già in Da Shazam: Siren'), findsOneWidget);
  });
}
