import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/ui/screens/devices/devices_sheet.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import 'devices_sheet_send_test.dart' show FakeHub;

void main() {
  testWidgets('a playlist with a file, a saved stream and a shadow row opens the sheet with all three ids', (t) async {
    t.view.physicalSize = const Size(600, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 3);
    final id = await t.runAsync(() async {
      final rows = await h.db.select(h.db.tracks).get();
      await h.db.update(h.db.tracks).replace(rows[1].copyWith(kind: kStreamKind, path: 'stream:youtube:abcdefghijk'));
      await h.db.update(h.db.tracks).replace(rows[2].copyWith(kind: kStreamKind, path: 'stream:youtube:shadowshado', saved: false));
      final repo = PlaylistRepository(h.db);
      final id = await repo.create('Notte');
      await repo.addStreamTracks(id, [for (final r in rows) r.id]);
      return id;
    });
    final hub = FakeHub(const SendOutcome(SendStatus.sent, total: 3, sent: 1));
    await h.pump(
      t,
      PlaylistDetailScreen(playlist: Playlist(id: id!, name: 'Notte', createdAt: 0, updatedAt: 0)),
      extraOverrides: [shareHubProvider.overrideWith(() => hub)],
    );
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byTooltip('Altre azioni').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Invia a un dispositivo'));
    await t.pumpAndSettle();
    expect(find.byType(DevicesSheet), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Invia'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    expect(hub.sentTracks!.map((e) => e.id).toSet(), {1, 2, 3});
    await t.pumpAndSettle(const Duration(seconds: 10));
    await h.dispose(t);
  });
}
