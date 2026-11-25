// Contract D-721 (150.3): the phone gestures as they are TODAY. The refactor
// of the desktop UI must leave each of them as it is. One short test per gesture.
import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/preview_providers.dart';
import 'package:codecore/providers/selection_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/now_playing/queue_sheet.dart';
import 'package:codecore/ui/screens/online/online_song_row.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/widgets/cover_image.dart';
import 'package:codecore/ui/widgets/net_thumbnail.dart';
import 'package:codecore/ui/widgets/ring_progress.dart';
import 'package:codecore/ui/widgets/selection_bar.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:codecore/ui/widgets/track_row_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_backend.dart';

const _key = 'd721';
const _r = YtResult(
  id: 'v1',
  title: 'Online song',
  channel: 'Chan',
  duration: Duration(seconds: 90),
  artists: ['Ann'],
  artistIds: ['UC1'],
);

class _Spy implements PlayerController {
  final seeks = <Duration>[];
  final calls = <String>[];
  @override
  bool inJam = false;
  @override
  bool get jamQueueFull => false;
  @override
  Future<void> seek(Duration position) async => seeks.add(position);
  @override
  Future<void> playOnline(YtResult r) async => calls.add('play');
  @override
  Future<bool?> playFromSearch({Track? track, YtResult? online}) async {
    calls.add('play');
    return false;
  }

  @override
  Future<void> enqueueOnline(YtResult r) async => calls.add('enqueue');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets real async work (DB, files) and the animations run, with no wall-clock wait.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [done] holds, at most 40 rounds.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 40 && !done(); i++) {
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => debugIsDesktopOverride = false);
  tearDown(() => debugIsDesktopOverride = null);

  /// Four local rows in a selection list.
  Future<(Harness, List<Track>, List<int>)> rows(WidgetTester tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    final tracks = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    final tapped = <int>[];
    final ids = [for (final t in tracks) t.id];
    await h.pump(
      tester,
      Scaffold(
        body: ListView(
          children: [
            for (final t in tracks)
              SizedBox(
                height: 64,
                child: LiveTrackRow(
                  track: t,
                  onTap: () => tapped.add(t.id),
                  selection: RowSelection(listKey: _key, visibleIds: ids),
                ),
              ),
          ],
        ),
      ),
      extraOverrides: [
        previewBackendFactoryProvider.overrideWithValue(FakeBackend.new),
      ],
    );
    return (h, tracks, tapped);
  }

  Selection selection(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ListView)))
          .read(selectionProvider(_key));

  testWidgets('swipe on a queue row removes it, «Annulla» puts it back', (
    tester,
  ) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 6);
    final all = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    final ids = [for (final t in all) t.id];
    await tester.runAsync(() => h.handler.playQueue(ids, 0));
    await h.pump(
      tester,
      Scaffold(body: QueueSheet(scrollController: ScrollController())),
    );
    await _settle(tester);
    final before = h.handler.queueIds;
    await tester.fling(find.text(all[3].title).first, const Offset(-300, 0), 1500);
    await _settle(tester);
    await _settle(tester);
    expect(h.handler.queueIds.length, before.length - 1);
    await tester.tap(find.byType(SnackBarAction));
    await _settle(tester);
    expect(h.handler.queueIds, before);
    await h.dispose(tester);
  });

  testWidgets('long press starts a selection; a tap on another row adds it', (
    tester,
  ) async {
    final (h, tracks, tapped) = await rows(tester);
    await tester.longPress(find.text('Song 0'));
    await _settle(tester);
    expect(selection(tester).ids, {tracks[0].id});
    await tester.tap(find.text('Song 2'));
    await _settle(tester);
    expect(selection(tester).ids, {tracks[0].id, tracks[2].id});
    expect(tapped, isEmpty);
    await h.dispose(tester);
  });

  testWidgets('a single tap on a row runs its onTap', (
    tester,
  ) async {
    final (h, tracks, tapped) = await rows(tester);
    await tester.tap(find.text('Song 1'));
    expect(tapped, [tracks[1].id]);
    await h.dispose(tester);
  });

  testWidgets('two quick taps on an online row push the player once', (
    tester,
  ) async {
    _phone(tester);
    final spy = _Spy();
    late BuildContext ctx;
    late WidgetRef ref;
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      Consumer(
        builder: (c, r, _) {
          ctx = c;
          ref = r;
          return const Scaffold();
        },
      ),
      extraOverrides: [playerControllerProvider.overrideWithValue(spy)],
    );
    // What the row's onTap does, twice with no frame between: the second one
    // finds the player already on the navigator and plays without pushing.
    tapOnline(ctx, ref, _r);
    tapOnline(ctx, ref, _r);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(spy.calls, ['play', 'play']);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a drag on the ring band of the player seeks on release', (
    tester,
  ) async {
    _phone(tester);
    final spy = _Spy();
    final h = await Harness.create(tester, tracks: 2);
    final all = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    await tester.runAsync(() => h.handler.playQueue([all.first.id], 0));
    await h.pump(
      tester,
      const NowPlayingScreen(),
      extraOverrides: [
        playerControllerProvider.overrideWithValue(spy),
        positionProvider.overrideWith((_) => Stream.value(Duration.zero)),
        durationProvider.overrideWith(
          (_) => Stream.value(const Duration(seconds: 100)),
        ),
      ],
    );
    final ring = find.descendant(
      of: find.byType(NowPlayingScreen),
      matching: find.byType(RingProgress),
    );
    final size = tester.getSize(ring).width;
    final coverR = RingProgress.innerSize(size, stroke: 12) / 2;
    final g = await tester.startGesture(
      tester.getCenter(ring) + Offset(0, coverR + 30),
    );
    await g.moveBy(const Offset(0, 4));
    await tester.pump();
    await g.up();
    expect(spy.seeks, hasLength(1));
    expect(spy.seeks.single.inSeconds, inInclusiveRange(33, 39));
    await h.dispose(tester);
  });

  testWidgets('holding the cover of a local row previews it; letting go stops', (
    tester,
  ) async {
    final (h, tracks, _) = await rows(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(ListView)));
    final g = await tester.startGesture(
      tester.getCenter(find.byType(CoverImage).first),
    );
    await tester.pump(const Duration(milliseconds: 700)); // past the long-press delay
    await _until(tester, () => c.read(previewProvider).trackId == tracks[0].id);
    expect(c.read(previewProvider).trackId, tracks[0].id);
    await g.up();
    await _until(tester, () => !c.read(previewProvider).active);
    expect(c.read(previewProvider).active, isFalse);
    await h.dispose(tester);
  });

  testWidgets('a long press on an online row (cover included) starts a selection, no preview', (
    tester,
  ) async {
    _phone(tester);
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const Scaffold(body: OnlineSongTile(result: _r, index: 0, selectionKey: 'k')),
      extraOverrides: [
        previewBackendFactoryProvider.overrideWithValue(FakeBackend.new),
      ],
    );
    final c = ProviderScope.containerOf(tester.element(find.byType(OnlineSongTile)));
    await tester.longPress(find.byType(NetThumbnail).first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.read(selectionProvider('k')).active, isTrue);
    expect(c.read(previewProvider).active, isFalse);
    await h.dispose(tester);
  });

  testWidgets('system back from an inner page returns to the previous one', (
    tester,
  ) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    await h.pump(tester, const AppShell());
    await tester.tap(find.text('Libreria'));
    await _settle(tester);
    await tester.tap(find.text('Tutti i brani'));
    await _settle(tester);
    expect(find.byType(AllTracksScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    await _settle(tester);
    expect(find.byType(AllTracksScreen), findsNothing);
    expect(find.text('Tutti i brani'), findsWidgets, reason: 'back on the Library');
    expect(find.byType(SelectionBar), findsNothing);
    await h.dispose(tester);
  });
}
