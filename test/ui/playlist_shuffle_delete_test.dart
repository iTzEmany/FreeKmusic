import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/smart_playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/smart/smart_playlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/menu_support.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('deleting a playlist drops its saved Casuale mode and only its own', (tester) async {
    final h = await Harness.create(tester);
    final id = (await tester.runAsync(() => h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Rock', createdAt: 1))))!;
    await h.pump(tester, PlaylistDetailScreen(playlist: Playlist(id: id, name: 'Rock', createdAt: 1, updatedAt: 1)));
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    c.read(settingsProvider.notifier).update((s) => s.copyWith(playlistShuffles: {'$id': 'plus', 'smart:$id': 'shuffle'}));
    await tester.tap(menuButton());
    await _settle(tester);
    await tester.tap(find.text('Elimina'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await _settle(tester);
    expect(c.read(settingsProvider).playlistShuffles, {'smart:$id': 'shuffle'});
    await h.dispose(tester);
  });

  testWidgets('deleting a smart playlist drops its saved Casuale mode and only its own', (tester) async {
    final h = await Harness.create(tester, tracks: 2);
    final repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
    final id = (await tester.runAsync(() => repo.create(name: 'Via', rules: '', sort: SmartSort.title, limit: null)))!;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await h.pump(tester, Scaffold(body: Builder(builder: (c) => TextButton(
        onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => SmartPlaylistScreen(id: id))),
        child: const Text('open')))));
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    c.read(settingsProvider.notifier).update((s) => s.copyWith(playlistShuffles: {'$id': 'plus', 'smart:$id': 'shuffle'}, smartMixOff: {id, id + 1}));
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Altre azioni').first);
    await _settle(tester);
    await tester.tap(find.text('Elimina'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await _settle(tester);
    expect(c.read(settingsProvider).playlistShuffles, {'$id': 'plus'});
    expect(c.read(settingsProvider).smartMixOff, {id + 1});
    await h.dispose(tester);
  });
}
