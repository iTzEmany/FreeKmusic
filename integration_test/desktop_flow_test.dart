import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/providers/selection_providers.dart';
import 'package:codecore/ui/shell/desktop_sidebar.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_driver.dart';

/// The desktop app as a whole on Linux: sidebar, scan, play, context menu,
/// multi-select, shortcuts, resize. Any exception (layout overflow included)
/// fails the test.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop flow: sidebar, scan, play, menu, selection, shortcuts, resize', (tester) async {
    debugIsDesktopOverride = true;
    addTearDown(() => debugIsDesktopOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    final app = await AppUnderTest.create(seconds: 20);
    await tester.runAsync(() async {});
    await app.launch(tester);
    final l = AppLocalizations.of(tester.element(find.byType(DesktopSidebar)));
    final c = app.container(tester);

    Future<void> press(LogicalKeyboardKey key, {bool ctrl = false, bool alt = false}) async {
      if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(key);
      if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester, by: const Duration(milliseconds: 300));
    }

    // Every entry of the sidebar, then back to the library.
    for (final label in [l.navHome, l.navSearch, l.navMemory, l.yourLibrary]) {
      await tester.tap(find.descendant(of: find.byType(DesktopSidebar), matching: find.text(label)));
      await settle(tester);
    }

    // Scan: the folder's files appear in «Tutti i brani».
    await tester.runAsync(() => app.addMusicFolder(tester));
    await settle(tester);
    await tester.tap(find.text(l.allTracks));
    await settle(tester);
    expect(find.byType(TrackRow), findsNWidgets(AppUnderTest.names.length));

    // Play the first row: the bar shows its title and the pause button.
    await tester.tap(find.byType(TrackRow).first);
    await waitFor(tester, () => app.handler.isPlaying, within: const Duration(seconds: 5), reason: 'playing');
    await app.handler.setVolume(0.05);
    final title = app.handler.currentTrack!.title;
    expect(find.text(title), findsWidgets);
    expect(find.byIcon(Icons.pause_rounded), findsWidgets);

    // Space pauses, then plays.
    await press(LogicalKeyboardKey.space);
    await waitFor(tester, () => !app.handler.isPlaying, reason: 'Space pauses');
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
    await press(LogicalKeyboardKey.space);
    await waitFor(tester, () => app.handler.isPlaying, reason: 'Space plays');

    // Ctrl+Right / Ctrl+Left change the track.
    final first = app.handler.currentTrack!.id;
    await press(LogicalKeyboardKey.arrowRight, ctrl: true);
    await waitFor(tester, () => app.handler.currentTrack?.id != first, reason: 'Ctrl+Right is next');
    await press(LogicalKeyboardKey.arrowLeft, ctrl: true);
    await waitFor(tester, () => app.handler.currentTrack?.id == first, reason: 'Ctrl+Left is previous');

    // Right click opens the track menu, Esc closes it.
    final barriers = find.byType(ModalBarrier).evaluate().length;
    await tester.tap(find.byType(TrackRow).at(1), buttons: kSecondaryButton);
    await settle(tester);
    expect(find.byType(ModalBarrier).evaluate().length, greaterThan(barriers), reason: 'a menu opened');
    await press(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(ModalBarrier).evaluate().length, barriers, reason: 'Esc closed it');

    // Ctrl+click picks one by one, Shift+click extends the range.
    Set<int> picked() => c.read(selectionProvider(SelectionKey.all.key)).ids;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byType(TrackRow).at(0));
    await tester.tap(find.byType(TrackRow).at(2));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(picked(), hasLength(2));
    c.read(selectionProvider(SelectionKey.all.key).notifier).clear();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byType(TrackRow).at(0));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byType(TrackRow).at(3));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settle(tester);
    expect(picked(), hasLength(4), reason: 'Shift+click selects the range');
    c.read(selectionProvider(SelectionKey.all.key).notifier).clear();

    // Ctrl+F from Home opens Search; Alt+Left must not throw.
    await tester.tap(find.descendant(of: find.byType(DesktopSidebar), matching: find.text(l.navHome)));
    await settle(tester);
    await press(LogicalKeyboardKey.keyF, ctrl: true);
    expect(c.read(navIndexProvider), NavTab.search.index, reason: 'Ctrl+F from Home opens Search');
    await press(LogicalKeyboardKey.arrowLeft, alt: true);

    // Resize: no layout exception at 1000 and 1920.
    for (final w in [1000.0, 1920.0]) {
      tester.view.physicalSize = Size(w, 800);
      await settle(tester);
      for (final label in [l.navHome, l.yourLibrary]) {
        await tester.tap(find.descendant(of: find.byType(DesktopSidebar), matching: find.text(label)));
        await settle(tester);
      }
    }
    await app.dispose(tester);
  });
}
