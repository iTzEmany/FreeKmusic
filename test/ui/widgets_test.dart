import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'dart:io';

import 'package:codecore/ui/widgets/empty_state.dart';
import 'package:codecore/ui/widgets/artist_avatar.dart';
import 'package:codecore/ui/widgets/cc_sheet.dart';
import 'package:codecore/ui/widgets/playlist_cover.dart';
import 'package:codecore/ui/widgets/quality_tag.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:codecore/ui/widgets/ring_progress.dart';
import 'package:codecore/ui/widgets/progress_frame.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Track _track({
  String title = 'Futura',
  String? artist = 'Lucio Dalla',
  String? album = 'Dalla',
  bool fav = false,
  int? trackNumber,
  int? bitDepth,
  int? rate,
}) => Track(saved: false, coverSource: 0, 
  id: 1,
  path: '/m/a.mp3',
  title: title,
  artist: artist,
  album: album,
  albumKey: 'k',
  trackNumber: trackNumber,
  durationMs: 185000,
  format: bitDepth == null ? 'mp3' : 'flac',
  bitDepth: bitDepth,
  sampleRateHz: rate,
  sizeBytes: 1,
  mtimeMs: 1,
  hasCover: false,
  isFavorite: fav,
  enrichStatus: 0,
  userEdited: false,
  missing: false,
  ignored: false,
  kind: 0,
  addedAt: 0,
  playCount: 0,
);

Future<void> _pump(WidgetTester tester, Widget child, {double width = 400}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ProviderScope(
      overrides: const [],
      child: MaterialApp(
        theme: buildThemeFromColors(CcColors.notte, false),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('TrackRow: title, artist only, heart only if favourite', (
    tester,
  ) async {
    await _pump(
      tester,
      TrackRow(track: _track(fav: true), onTap: () {}, onMore: () {}),
    );
    expect(find.text('Futura'), findsOneWidget);
    expect(find.text('Lucio Dalla'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
    expect(find.text('Dalla'), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await _pump(tester, TrackRow(track: _track(), onTap: () {}));
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('EmptyState: top left, no icon, one filled action', (
    tester,
  ) async {
    await _pump(
      tester,
      EmptyState(
        icon: Icons.favorite_border_rounded,
        message: 'Niente qui',
        help: 'Aiuto',
        actionLabel: 'A',
        onAction: () {},
      ),
    );
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.widgetWithText(FilledButton, 'A'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Niente qui')).dx, CcDims.margin);
  });

  testWidgets('dot only on the current row', (tester) async {
    final sem = tester.ensureSemantics();
    await _pump(
      tester,
      Column(
        children: [
          SizedBox(
            height: 64,
            child: TrackRow(track: _track(), onTap: () {}),
          ),
          SizedBox(
            height: 64,
            child: TrackRow(track: _track(), onTap: () {}, isCurrent: true),
          ),
          SizedBox(
            height: 64,
            child: TrackRow(track: _track(), onTap: () {}),
          ),
        ],
      ),
    );
    expect(find.byType(LiveProgressFrame), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('In riproduzione')), findsOneWidget);
    sem.dispose();
  });

  testWidgets('TrackRow: current title takes the accent', (tester) async {
    await _pump(
      tester,
      TrackRow(track: _track(), onTap: () {}, isCurrent: true),
    );
    final title = tester.widget<Text>(find.text('Futura'));
    expect(title.style?.color, CcColors.notte.accent);
  });

  testWidgets(
    'TrackRow album variant: number instead of cover, artist hidden',
    (tester) async {
      await _pump(
        tester,
        TrackRow(
          track: _track(trackNumber: 7),
          onTap: () {},
          variant: TrackRowVariant.album,
          albumArtist: 'lucio dalla',
        ),
      );
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Lucio Dalla'), findsNothing);
      expect(find.byIcon(Icons.music_note_rounded), findsNothing);
    },
  );

  testWidgets('TrackRow wide: duration and album columns', (tester) async {
    await _pump(
      tester,
      TrackRow(track: _track(), onTap: () {}, index: 3),
      width: 1200,
    );
    expect(find.text('3:05'), findsOneWidget);
    expect(find.text('Dalla'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('wide row shows dot and album column', (tester) async {
    await _pump(
      tester,
      TrackRow(track: _track(), onTap: () {}, isCurrent: true),
      width: 1000,
    );
    expect(find.byType(NowPlayingDot), findsOneWidget);
    expect(find.text('Dalla'), findsOneWidget);
  });

  test('artist monogram and hue are deterministic', () {
    expect(artistMonogram('Lucio Dalla'), 'LD');
    expect(artistMonogram('daft punk'), 'DP');
    expect(artistMonogram('Nina'), 'N');
    expect(artistMonogram('  '), '?');
    expect(artistHue('Lucio Dalla'), artistHue('lucio dalla'));
    for (final n in ['a', 'Daft Punk', 'Ludovico Einaudi', 'Ø']) {
      expect(artistHue(n), inInclusiveRange(250, 320));
    }
  });

  test('playlist cover keys: custom wins, then up to 4 distinct', () {
    expect(playlistCoverKeys('c', ['a', 'b']), ['c']);
    expect(playlistCoverKeys(null, [null, 'a', 'a', 'b']), ['a', 'b']);
    expect(playlistCoverKeys(null, ['a', 'b', 'c', 'd', 'e']), [
      'a',
      'b',
      'c',
      'd',
    ]);
    expect(playlistCoverKeys(null, <String?>[null]), isEmpty);
  });

  testWidgets('PlaylistCover renders 0, 1 and 4 covers', (tester) async {
    final h = await Harness.create(tester);
    for (final keys in [
      <String>[],
      ['a'],
      ['a', 'b', 'c', 'd'],
    ]) {
      await h.pump(
        tester,
        Scaffold(body: PlaylistCover(size: 80, coverKeys: keys)),
      );
      expect(tester.takeException(), isNull);
    }
    await h.pump(
      tester,
      const Scaffold(body: PlaylistCover(size: 80, favorites: true)),
    );
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await h.dispose(tester);
  });

  group('SegmentedBlocks', () {
    Widget blocks(int sel, ValueChanged<int> on) => SegmentedBlocks<int>(
          items: const [
            BlockItem(value: 0, icon: Icons.apps_rounded, label: 'Tutto'),
            BlockItem(value: 1, icon: Icons.queue_music_rounded, label: 'Playlist'),
            BlockItem(value: 2, icon: Icons.album_rounded, label: 'Album'),
            BlockItem(value: 3, icon: Icons.person_rounded, label: 'Artisti'),
          ],
          selected: sel,
          onChanged: on,
        );

    testWidgets('tapping a block selects it', (t) async {
      int? got;
      await _pump(t, blocks(0, (v) => got = v));
      await t.tap(find.text('Album'));
      expect(got, 2);
    });

    testWidgets('falls back to 2x2 when the row does not fit', (t) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: buildThemeFromColors(CcColors.notte, false),
        home: MediaQuery(
          data: const MediaQueryData(
              size: Size(360, 780), textScaler: TextScaler.linear(1.5)),
          child: Scaffold(body: blocks(0, (_) {})),
        ),
      ));
      final a = t.getRect(find.text('Tutto'));
      final c = t.getRect(find.text('Album'));
      expect(c.top, greaterThan(a.bottom));
      expect(find.byType(Scrollable), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('falls back to 2x2 when a single word is wider than a block',
        (t) async {
      await _pump(
        t,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: SegmentedBlocks<int>(
              items: const [
                BlockItem(value: 0, icon: Icons.apps_rounded, label: 'Predefinitissimo'),
                BlockItem(value: 1, icon: Icons.title_rounded, label: 'Titolo'),
                BlockItem(value: 2, icon: Icons.person_rounded, label: 'Artista'),
                BlockItem(value: 3, icon: Icons.schedule_rounded, label: 'Recenti'),
              ],
              selected: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(t.getRect(find.text('Artista')).top,
          greaterThan(t.getRect(find.text('Predefinitissimo')).bottom));
      expect(t.takeException(), isNull);
    });

    testWidgets('reduced motion: no slide', (t) async {
      Widget app(int sel) => MaterialApp(
            theme: buildThemeFromColors(CcColors.notte, false),
            home: MediaQuery(
              data: const MediaQueryData(
                  size: Size(400, 800), disableAnimations: true),
              child: Scaffold(body: blocks(sel, (_) {})),
            ),
          );
      await t.pumpWidget(app(0));
      await t.pumpWidget(app(2));
      await t.pump(const Duration(milliseconds: 1));
      expect(t.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
          Duration.zero);
    });

    testWidgets('blocks are focusable and announce selected', (t) async {
      final h = t.ensureSemantics();
      await _pump(t, blocks(2, (_) {}));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(
          Focus.of(t.element(find.byType(InkWell).first), scopeOk: true)
              .hasFocus,
          isTrue);
      expect(
          t.getSemantics(find.text('Album')),
          matchesSemantics(
              label: 'Album',
              isButton: true,
              isSelected: true,
              hasSelectedState: true,
              hasTapAction: true));
      h.dispose();
    });
  });

  test('Hi-Res threshold', () {
    expect(isHiRes(_track(bitDepth: 24, rate: 96000)), isTrue);
    expect(isHiRes(_track(bitDepth: 16, rate: 44100)), isFalse);
    expect(isHiRes(_track(bitDepth: 16, rate: 96000)), isTrue);
    expect(isHiRes(_track()), isFalse);
  });

  group('showCcSheet', () {
    testWidgets('showCcSheet honours reduced motion', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCcSheet<void>(
                  context: context, builder: (_) => const Text('body')),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final firstTop = tester.getTopLeft(find.text('body')).dy;
      await tester.pumpAndSettle();
      expect(firstTop, tester.getTopLeft(find.text('body')).dy,
          reason: 'already at its final position, no slide');
    });

    test('no raw showModalBottomSheet outside cc_sheet and car mode', () {
      final bad = [
        for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart') &&
              !f.path.endsWith('cc_sheet.dart') &&
              !f.path.endsWith('car_playlists_sheet.dart') &&
              f.readAsStringSync().contains('showModalBottomSheet'))
            f.path,
      ];
      expect(bad, isEmpty);
    });
  });
}
