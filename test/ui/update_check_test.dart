import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/update_providers.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/providers/startup_providers.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';

class _Web implements WebClient {
  _Web(this.tag);
  final String tag;
  int calls = 0;
  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    calls++;
    return [
      {
        'tag_name': tag,
        'html_url': 'https://github.com/me/codecore/releases/tag/$tag',
        'body': '## Novità\n- evidenza | mic | Novità della release | Testo.',
      },
    ];
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 5242880, CancelToken? cancel}) async => null;
}

class _Limited extends _Web {
  _Limited() : super('v1.0.0');
  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) =>
      throw const RateLimitedException(429);
}

class _Broken extends _Web {
  _Broken() : super('v1.0.0');
  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async =>
      null;
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 4300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('no release repository: the update entries are hidden', (tester) async {
    _tall(tester);
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const Scaffold(body: SettingsScreen(initial: SettingsPage.advanced)),
      extraOverrides: [releaseRepoProvider.overrideWithValue('')],
    );
    expect(find.text('Controlla aggiornamenti'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('with a repository: the check shows the new version and its notes page; the start-up switch is off', (
    tester,
  ) async {
    _tall(tester);
    final h = await Harness.create(tester);
    final web = _Web('v9.0.0');
    await h.pump(
      tester,
      const Scaffold(body: SettingsScreen(initial: SettingsPage.advanced)),
      extraOverrides: [releaseRepoProvider.overrideWithValue('me/codecore'), webClientProvider.overrideWithValue(web)],
    );
    expect(web.calls, 0, reason: 'nothing is asked until the user asks');
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Controlla all’avvio')).value, isFalse);

    await tester.ensureVisible(find.text('Controlla aggiornamenti'));
    await tester.tap(find.text('Controlla aggiornamenti'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(web.calls, 1);
    expect(find.text('È arrivata la 9.0.0'), findsOneWidget);
    expect(find.text('Novità della release'), findsOneWidget);
    expect(find.text('Copia indirizzo'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('Informazioni › «Novità della versione» opens the page, with the link when nothing is saved', (
    tester,
  ) async {
    _tall(tester);
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const Scaffold(body: SettingsScreen(initial: SettingsPage.advanced)),
      extraOverrides: [
        releaseRepoProvider.overrideWithValue('me/codecore'),
        webClientProvider.overrideWithValue(_Web('v9.0.0')),
      ],
    );
    await tester.ensureVisible(find.text('Novità della versione'));
    await tester.tap(find.text('Novità della versione'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Aggiornata alla'), findsOneWidget);
    expect(find.text('Inizia'), findsOneWidget);
    await h.dispose(tester);
  });

  for (final (label, web, text) in [
    ('up to date', _Web('v1.0.0'), 'Hai l’ultima versione (1.7.0)'),
    ('rate limited', _Limited(), 'GitHub chiede di aspettare: riprova più tardi.'),
    ('failed', _Broken(), 'Non riesco a leggere l’ultima versione. Controlla la connessione.'),
  ]) {
    testWidgets('the check says «$label» and closes', (tester) async {
      _tall(tester);
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        const Scaffold(body: SettingsScreen(initial: SettingsPage.advanced)),
        extraOverrides: [
          releaseRepoProvider.overrideWithValue('me/codecore'),
          webClientProvider.overrideWithValue(web),
        ],
      );
      await tester.ensureVisible(find.text('Controlla aggiornamenti'));
      await tester.tap(find.text('Controlla aggiornamenti'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(text), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text(text), findsNothing);
      await h.dispose(tester);
    });
  }

  group('check at start-up', () {
    Future<ProviderContainer> container(_Web web, {bool on = false, int lastDay = 0}) async {
      SharedPreferences.setMockInitialValues({'checkUpdatesOnStart': on, 'lastUpdateCheckDay': lastDay});
      final store = await SettingsStore.open();
      final c = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          releaseRepoProvider.overrideWithValue('me/codecore'),
          webClientProvider.overrideWithValue(web),
          // The check waits for the app to be on screen: already so here.
          startupSettledProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('off by default: no request', () async {
      final web = _Web('v9.0.0');
      final c = await container(web);
      expect(await c.read(updateOnStartProvider.future), isNull);
      expect(web.calls, 0);
    });

    test('on: one request, the new version, and not again the same day', () async {
      final web = _Web('v9.0.0');
      final c = await container(web, on: true);
      expect((await c.read(updateOnStartProvider.future))!.version, '9.0.0');
      expect(web.calls, 1);

      final again = await container(web, on: true, lastDay: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000);
      expect(await again.read(updateOnStartProvider.future), isNull);
      expect(web.calls, 1, reason: 'already checked today');
    });

    test('on, but already up to date: nothing to show', () async {
      final web = _Web('v1.0.0');
      final c = await container(web, on: true);
      expect(await c.read(updateOnStartProvider.future), isNull);
    });
  });
}
