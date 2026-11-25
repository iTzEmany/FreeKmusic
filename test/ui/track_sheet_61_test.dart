import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/menu_support.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void _size(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final desktop in [false, true]) {
  testWidgets('playlist row sheet: «Rimuovi dalla playlist» first, no second sheet, desktop: $desktop', (tester) async {
    debugIsDesktopOverride = desktop;
    addTearDown(() => debugIsDesktopOverride = null);
    _size(tester, const Size(400, 900));
    final h = await Harness.create(tester, tracks: 2);
    final playlist = (await tester.runAsync(() async {
      final repo = PlaylistRepository(h.db);
      final id = await repo.create('Notte');
      await repo.addTracks(id, [1, 2]);
      return (await h.db.select(h.db.playlists).get()).single;
    }))!;
    await h.pump(tester, PlaylistDetailScreen(playlist: playlist));
    await _settle(tester);
    await tester.tap(find.byTooltip('Altre azioni').last);
    await _settle(tester);
    final entries = shownMenuEntries(
      tester,
      named: (v) => v is Enum ? v.name : (v as dynamic).label as String,
    );
    expect(entries.first, 'Rimuovi dalla playlist');
    expect(entries, contains('Aggiungi in coda'));
    await tester.tap(find.text('Rimuovi dalla playlist'));
    await _settle(tester);
    final left = (await tester.runAsync(
      () => PlaylistRepository(h.db).watchTracks(playlist.id).first,
    ))!;
    expect(left.length, 1);
    await h.dispose(tester);
  });
  }

  // The harness theme is a phone's: desktop rows need the platform said.
  Future<void> row(
    WidgetTester tester,
    Harness h,
    Track t, {
    TargetPlatform platform = TargetPlatform.android,
  }) => h.pump(
    tester,
    Builder(
      builder: (c) => Theme(
        data: Theme.of(c).copyWith(platform: platform),
        child: Scaffold(
          body: SizedBox(
            height: 64,
            child: LiveTrackRow(track: t, onTap: () {}),
          ),
        ),
      ),
    ),
  );

  testWidgets('⋮ on a phone is at least 48 dp', (tester) async {
    _size(tester, const Size(400, 900));
    final h = await Harness.create(tester, tracks: 1);
    final t = (await tester.runAsync(() => h.db.select(h.db.tracks).getSingle()))!;
    await row(tester, h, t);
    await _settle(tester);
    final size = tester.getSize(find.byTooltip('Altre azioni').first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await h.dispose(tester);
  });

  testWidgets('hidden ⋮ on a wide row is out of semantics and focus; hover shows it at 48 dp', (tester) async {
    _size(tester, const Size(1400, 900));
    final h = await Harness.create(tester, tracks: 1);
    final t = (await tester.runAsync(() => h.db.select(h.db.tracks).getSingle()))!;
    await row(tester, h, t, platform: TargetPlatform.linux);
    await _settle(tester);
    expect(find.byTooltip('Altre azioni'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(TrackRow)));
    await _settle(tester);
    final size = tester.getSize(find.byTooltip('Altre azioni').first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await h.dispose(tester);
  });

  testWidgets('wide row: ⋮ shows on a touch platform, and on keyboard focus', (tester) async {
    _size(tester, const Size(1400, 900));
    final h = await Harness.create(tester, tracks: 1);
    final t = (await tester.runAsync(() => h.db.select(h.db.tracks).getSingle()))!;
    await row(tester, h, t, platform: TargetPlatform.linux);
    await _settle(tester);
    expect(find.byTooltip('Altre azioni'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byTooltip('Altre azioni'), findsOneWidget);
    await h.dispose(tester);

    final h2 = await Harness.create(tester, tracks: 1);
    final t2 = (await tester.runAsync(() => h2.db.select(h2.db.tracks).getSingle()))!;
    await row(tester, h2, t2);
    await _settle(tester);
    expect(find.byTooltip('Altre azioni'), findsOneWidget);
    await h2.dispose(tester);
  });
}
