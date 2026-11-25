import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/ui/widgets/play_buttons.dart';
import 'package:flutter/rendering.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/collection_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:codecore/providers/keep_offline_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

ThemeData _theme(AppThemeId id) => buildThemeFromColors(
    buildPalette(id, accentFromName('')), false);

Future<void> _pump(WidgetTester tester, Widget child,
    {AppThemeId id = AppThemeId.notte, double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: _theme(id),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: w!),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
}

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('long single word title shrinks instead of breaking ($scale)',
        (tester) async {
      await _pump(tester,
          const CollectionHeader(name: 'Supercalifragilis'),
          scale: scale);
      final text = tester.widget<Text>(find.byKey(const ValueKey('collection-name')));
      final box = tester.renderObject<RenderParagraph>(
          find.byKey(const ValueKey('collection-name')));
      expect(box.size.height, lessThan(text.style!.fontSize! * scale * 1.6));
      final base = _theme(AppThemeId.notte).textTheme.headlineSmall!.fontSize!;
      expect(text.style!.fontSize!, lessThan(base));
    });
  }

  testWidgets('normal title keeps theme size', (tester) async {
    await _pump(tester, const CollectionHeader(name: 'Corsa del sabato'));
    final text = tester.widget<Text>(find.byKey(const ValueKey('collection-name')));
    expect(text.style!.fontSize,
        _theme(AppThemeId.notte).textTheme.headlineSmall!.fontSize);
  });

  for (final id in [AppThemeId.notte, AppThemeId.chiaro]) {
    testWidgets('selected chip is the text-coloured block ($id)', (tester) async {
      late CcColors cc;
      await _pump(
          tester,
          Builder(builder: (context) {
            cc = context.cc;
            return Column(children: [
              const ChoiceChip(label: Text('On'), selected: true, onSelected: null),
              ChoiceChip(label: const Text('Off'), selected: false, onSelected: (_) {}),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Uno')),
                  ButtonSegment(value: 2, label: Text('Due')),
                ],
                selected: const {1},
              ),
            ]);
          }),
          id: id);
      final chipTheme = Theme.of(tester.element(find.text('On'))).chipTheme;
      expect(chipTheme.secondaryLabelStyle!.color, cc.bg);
      expect(chipTheme.selectedColor, cc.text);
      expect(chipTheme.backgroundColor, cc.surface2);
      final seg = Theme.of(tester.element(find.text('Uno'))).segmentedButtonTheme.style!;
      expect(seg.backgroundColor!.resolve({WidgetState.selected}), cc.text);
      expect(seg.foregroundColor!.resolve({WidgetState.selected}), cc.bg);
      expect(seg.backgroundColor!.resolve({}), cc.surface2);
    });
  }

  group('icon row', () {
    Future<Harness> pumpScaffold(WidgetTester tester, {int? kind, ValueChanged<Rect?>? onShare}) async {
      final h = await Harness.create(tester, tracks: 0);
      final downloadTracks = kind == null
          ? null
          : [
              await tester.runAsync(() => h.db.into(h.db.tracks).insertReturning(TracksCompanion.insert(
                  path: 'x', title: 'x', albumKey: 'k', format: '', sizeBytes: 0, mtimeMs: 0, addedAt: 1, kind: Value(kind)))) as Track,
            ];
      await h.pump(
        tester,
        CollectionScaffold(
          title: 'T',
          name: 'Nome',
          slivers: const [],
          onPlay: () {},
          shuffleIds: const [1, 2],
          downloadTracks: downloadTracks,
          onShare: onShare,
          menu: const SizedBox.square(dimension: 48),
        ),
      );
      return h;
    }

    testWidgets('Condividi icon: 48 dp, tooltip, hands its rectangle to onShare; hidden without onShare', (tester) async {
      Rect? got;
      var h = await pumpScaffold(tester, onShare: (r) => got = r);
      expect(tester.getSize(find.byTooltip('Condividi')), const Size.square(48));
      await tester.tap(find.byTooltip('Condividi'));
      expect(got, tester.getRect(find.byTooltip('Condividi')));
      await h.dispose(tester);
      h = await pumpScaffold(tester);
      expect(find.byTooltip('Condividi'), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('sizes, labels and tooltips', (tester) async {
      final sem = tester.ensureSemantics();
      final h = await pumpScaffold(tester, kind: kStreamKind);
      expect(tester.getSize(find.byType(PlayCircleButton)), const Size(56, 56));
      expect(tester.getSize(find.byIcon(Icons.shuffle_rounded).hitTestable()).width, lessThan(48));
      expect(find.bySemanticsLabel('Riproduci'), findsOneWidget);
      expect(find.byTooltip('Riproduci'), findsOneWidget);
      // IconButton hands its tooltip to the semantics node as its name.
      expect(find.byTooltip('Scarica'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('[Cc]asuale|[Ss]huffle|mescol', caseSensitive: false)), findsWidgets);
      final shuffle = tester.getSize(find.ancestor(
          of: find.byIcon(Icons.shuffle_rounded), matching: find.byType(SizedBox)).first);
      expect(shuffle, const Size(48, 48));
      expect(tester.getSize(find.ancestor(
          of: find.byIcon(Icons.download_rounded), matching: find.byType(SizedBox)).first),
          const Size(48, 48));
      sem.dispose();
      await h.dispose(tester);
    });

    testWidgets('a small menu is padded to 48 dp', (tester) async {
      final h = await Harness.create(tester, tracks: 0);
      await h.pump(
        tester,
        const CollectionScaffold(
          title: 'T',
          name: 'Nome',
          slivers: [],
          menu: SizedBox.square(key: ValueKey('menu'), dimension: 20),
        ),
      );
      final box = tester.getSize(find.ancestor(
          of: find.byKey(const ValueKey('menu')),
          matching: find.byType(ConstrainedBox)).first);
      expect(box, const Size(48, 48));
      await h.dispose(tester);
    });

    testWidgets('scrollerCount changes keep the offset and toggle the bar', (tester) async {
      final h = await Harness.create(tester, tracks: 0);
      Future<void> show(int? n) => h.pump(
            tester,
            CollectionScaffold(
              title: 'T',
              name: 'Nome',
              scrollerCount: n,
              slivers: [
                SliverList.builder(
                  itemCount: 200,
                  itemBuilder: (_, i) => SizedBox(height: 56, child: Text('r$i')),
                ),
              ],
            ),
          );
      final handle = find.byKey(const ValueKey('scroller-handle'));
      await show(null);
      final c = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
      c.jumpTo(500);
      await tester.pump();
      expect(handle, findsNothing);
      await show(150);
      expect(c.offset, 500);
      expect(handle, findsOneWidget);
      await show(50);
      expect(c.offset, 500);
      expect(handle, findsNothing);
      await h.dispose(tester);
    });

    testWidgets('the heart toggles through onFavorite and «Annulla» restores; hidden without onFavorite (D-726)', (tester) async {
      var fav = false;
      var calls = 0;
      final h = await Harness.create(tester, tracks: 0);
      Future<void> show({required bool withHeart}) => h.pump(
            tester,
            StatefulBuilder(
              builder: (_, set) => CollectionScaffold(
                title: 'T',
                name: 'Nome',
                slivers: const [],
                favorite: fav,
                onFavorite: withHeart
                    ? () async {
                        calls++;
                        set(() => fav = !fav);
                      }
                    : null,
              ),
            ),
          );
      await show(withHeart: false);
      expect(find.byKey(const ValueKey('collection-favorite')), findsNothing);
      await h.dispose(tester);
      await show(withHeart: true);
      await tester.tap(find.byKey(const ValueKey('collection-favorite')));
      await tester.pump();
      expect(fav, isTrue);
      expect(find.text('Aggiunto ai preferiti'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Annulla'));
      await tester.pump();
      expect((fav, calls), (false, 2));
      await h.dispose(tester);
    });

    testWidgets('the download icon shows only when a stream is among the tracks', (tester) async {
      var h = await pumpScaffold(tester);
      expect(find.byIcon(Icons.download_rounded), findsNothing);
      await h.dispose(tester);
      h = await pumpScaffold(tester, kind: kMusicKind);
      expect(find.byIcon(Icons.download_rounded), findsNothing, reason: 'files only: nothing to download');
      await h.dispose(tester);
    });

    group('actions', () {
      Future<Harness> pumpActions(WidgetTester tester,
          {VoidCallback? onPlay, List<Track>? downloads, List<Override> extra = const []}) async {
        final h = await Harness.create(tester, tracks: 0);
        await h.pump(
          tester,
          CollectionScaffold(
            title: 'T',
            name: 'Nome',
            slivers: const [],
            onPlay: onPlay,
            shuffleIds: const [1, 2],
            downloadTracks: downloads,
          ),
          extraOverrides: extra,
        );
        return h;
      }

      testWidgets('Play calls onPlay', (tester) async {
        var played = 0;
        final h = await pumpActions(tester, onPlay: () => played++);
        await tester.tap(find.byType(PlayCircleButton));
        expect(played, 1);
        await h.dispose(tester);
      });

      testWidgets('Casuale moves the list from off to shuffle', (tester) async {
        final h = await pumpActions(tester);
        final c = ProviderScope.containerOf(tester.element(find.byType(CollectionScaffold)));
        final key = listKeyOf(const [1, 2]);
        expect(c.read(listShuffleProvider(key)), ShuffleMode.off);
        await tester.tap(find.byIcon(Icons.shuffle_rounded));
        for (var i = 0; i < 40 && c.read(listShuffleProvider(key)) == ShuffleMode.off; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(c.read(listShuffleProvider(key)), ShuffleMode.shuffle);
        await h.dispose(tester);
      });

      testWidgets('Scarica hands the page tracks to «tieni offline»', (tester) async {
        final h0 = await Harness.create(tester, tracks: 0);
        final stream = (await tester.runAsync(() => h0.db.into(h0.db.tracks).insertReturning(TracksCompanion.insert(
            path: 'x', title: 'x', albumKey: 'k', format: '', sizeBytes: 0, mtimeMs: 0, addedAt: 1, kind: Value(kStreamKind))))) as Track;
        Iterable<Track>? got;
        final h = await pumpActions(tester, downloads: [stream], extra: [
          keepOfflineMeteredAskProvider.overrideWithValue((_) async => null),
          keepOfflineProvider.overrideWithValue((tracks) async {
            got = tracks;
            return 1;
          }),
        ]);
        await tester.tap(find.byTooltip('Scarica'));
        await tester.pump();
        expect(got?.map((t) => t.id), [stream.id]);
        await tester.pump(const Duration(seconds: 5));
        await h.dispose(tester);
        await h0.dispose(tester);
      });
    });
  });
}
