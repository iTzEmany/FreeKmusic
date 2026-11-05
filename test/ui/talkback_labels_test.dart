// TalkBack labels fixed after the phone round of phase 83 (D-381): one node per
// control, each with its own name.
import 'dart:ui' show SemanticsAction;

import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/screens/home/cover_fan.dart';
import 'package:codecore/ui/screens/home/home_blocks.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/cc_search_field.dart';
import 'package:codecore/ui/screens/library/library_shortcuts.dart';
import 'package:codecore/ui/widgets/shuffle_button.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  late SemanticsHandle handle;
  setUp(
    () => handle = TestWidgetsFlutterBinding.ensureInitialized()
        .ensureSemantics(),
  );
  tearDown(() => handle.dispose());

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'track row: one tappable node named by title and artist; queue handle hidden',
    (tester) async {
      phone(tester);
      var taps = 0;
      final h = await Harness.create(tester, tracks: 1);
      final t = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!
          .first;
      await h.pump(
        tester,
        Scaffold(
          body: SizedBox(
            height: 64,
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              onReorderItem: (_, _) {},
              children: [
                LiveTrackRow(
                  key: const ValueKey('r'),
                  track: t,
                  variant: TrackRowVariant.queue,
                  reorderIndex: 0,
                  onTap: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Song 0, Artist'), findsOneWidget);
      // TalkBack's double tap is the tap action of the named node: it plays.
      tester.semantics.tap(find.semantics.byLabel('Song 0, Artist'));
      expect(taps, 1);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(
        find.ancestor(
          of: find.byIcon(Icons.drag_handle_rounded),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      await h.dispose(tester);
    },
  );

  testWidgets('shuffle: the state is announced once, as a button', (
    tester,
  ) async {
    final h = await Harness.create(tester, tracks: 1);
    await h.pump(
      tester,
      Scaffold(
        body: Column(
          children: [
            ShufflePill(ids: const []),
            const ShuffleModeButton(),
          ],
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Casuale: spenta'),
      findsNWidgets(2),
    ); // one per control
    expect(
      tester.getSemantics(find.byType(ShufflePill)).flagsCollection.isButton,
      isTrue,
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await h.dispose(tester);
  });

  testWidgets('home: Play next to «Casuale su tutto» is its own button', (
    tester,
  ) async {
    final h = await Harness.create(tester, tracks: 1);
    await h.pump(tester, const Scaffold(body: ShuffleHero()));
    final play = tester.getSemantics(find.bySemanticsLabel('Riproduci'));
    expect(play.flagsCollection.isButton, isTrue);
    expect(play.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await h.dispose(tester);
  });

  testWidgets('search field is named by its hint', (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CcSearchField(controller: c, hint: 'Cerca…'),
          ),
        ),
      ),
    );
    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Cerca…')).first,
    );
    expect(node.flagsCollection.isTextField, isTrue);
  });

  testWidgets('cover fan: the closed fan says what it shows', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildThemeFromColors(CcColors.notte, false),
          home: const Scaffold(
            body: CoverFan(
              albums: [
                AlbumSummary(
                  albumKey: 'k',
                  title: 'T',
                  artist: 'A',
                  variousArtists: false,
                  trackCount: 1,
                  durationMs: 1000,
                  year: null,
                  coverKey: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Mostra i brani aggiunti da poco'),
      findsOneWidget,
    );
  });

  testWidgets('library shortcut without a count is read by name only', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      Scaffold(
        body: LibraryShortcuts(
          items: [LibraryShortcut(label: 'Cronologia', onTap: () {})],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Cronologia'), findsOneWidget);
    await h.dispose(tester);
  });
}
