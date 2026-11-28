// Synced lyrics, the queue sheet and the tag / activity / devices sheets
// (born as the 38.4 safety net). Whoever changes the behaviour updates these
// tests in the same step.
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/tag_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/activity_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/services/share/discovery.dart';
import 'package:codecore/ui/screens/activity/activity_sheet.dart';
import 'package:codecore/ui/screens/devices/devices_sheet.dart';
import 'package:codecore/ui/screens/lyrics/lyrics_view.dart';
import 'package:codecore/ui/screens/now_playing/queue_sheet.dart';
import 'package:codecore/ui/screens/tags/tags_sheet.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

// ---- synced lyrics ------------------------------------------------------

/// 40 lines, one every 5 s: "Line 00" at 0:05 ... "Line 39" at 3:20.
final _lrc = [
  for (var i = 0; i < 40; i++)
    '[${(i * 5 + 5) ~/ 60}:${((i * 5 + 5) % 60).toString().padLeft(2, '0')}.00]Line ${i.toString().padLeft(2, '0')}',
].join('\n');

Future<Harness> _pumpLyrics(
  WidgetTester tester, {
  bool reducedMotion = false,
  bool noAnimations = false,
}) async {
  _phone(tester);
  final h = await Harness.create(tester, tracks: 1);
  if (reducedMotion) {
    await tester.runAsync(() => h.store.writeSettings(const AppSettings(reducedMotion: true)));
  }
  final track = (await tester.runAsync(() async {
    await (h.db.update(h.db.tracks)).write(TracksCompanion(lyricsSynced: Value(_lrc)));
    return h.db.select(h.db.tracks).getSingle();
  }))!;
  final view = Scaffold(body: LyricsView(track: track));
  await h.pump(
    tester,
    noAnimations
        ? Builder(
            builder: (c) => MediaQuery(
              data: MediaQuery.of(c).copyWith(disableAnimations: true),
              child: view,
            ),
          )
        : view,
  );
  return h;
}

Future<void> _at(WidgetTester tester, Harness h, int seconds) async {
  h.backend.posC.add(Duration(seconds: seconds));
  await tester.pump();
  await tester.pump();
}

// The row colour fades (200 ms), so the alpha of the text colour is the highlight.
double _opacity(WidgetTester tester, String line) =>
    tester.widget<Text>(find.text(line)).style!.color!.a;

/// Lets the 200 ms colour fade finish.
Future<void> _fade(WidgetTester tester) => tester.pump(const Duration(milliseconds: 250));

/// A row far from the viewport is not built: the view first jumps to an estimated
/// offset, a frame later it centres the real row.
Future<void> _reached(WidgetTester tester) => tester.pump();

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

// ---- fake hub for the devices sheet ------------------------------------

class _FakeHub extends ShareHubNotifier {
  _FakeHub(this.n);
  final int n;
  @override
  ShareHubState build() => ShareHubState(
        active: true,
        peers: [
          for (var i = 0; i < n; i++)
            Peer(
                id: 'p$i',
                name: 'Dev ${i.toString().padLeft(2, '0')}',
                host: '10.0.0.$i',
                port: 8000,
                platform: 'android'),
        ],
      );
  @override
  Future<void> enter() async {}
  @override
  Future<void> leave() async {}
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 200,
      scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).last);
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text(text), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Widget _opener(void Function(BuildContext, WidgetRef) open) => Consumer(
      builder: (context, ref, _) =>
          TextButton(onPressed: () => open(context, ref), child: const Text('open')),
    );

Future<Harness> _pumpTagsSheet(WidgetTester tester, int tags) async {
  _phone(tester);
  final h = await Harness.create(tester, tracks: 1);
  final rows = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
  await tester.runAsync(() async {
    final repo = TagRepository(h.db);
    for (var i = 0; i < tags; i++) {
      await repo.create('Tag ${i.toString().padLeft(2, '0')}');
    }
  });
  await h.pump(tester, _opener((c, ref) => showTagsSheet(c, ref, rows)));
  await tester.tap(find.text('open'));
  await _settle(tester);
  return h;
}

void main() {
  group('synced lyrics', () {
    testWidgets('the line of the position is the bright one, earlier ones are dimmer, later dimmest',
        (tester) async {
      final h = await _pumpLyrics(tester);
      expect(_opacity(tester, 'Line 00'), 0.55, reason: 'before the first timestamp nothing is current');
      await _at(tester, h, 52); // Line 09 starts at 50 s
      await _fade(tester);
      expect(_opacity(tester, 'Line 09'), 1.0);
      expect(_opacity(tester, 'Line 08'), 0.55);
      expect(_opacity(tester, 'Line 10'), 0.35);
      await h.dispose(tester);
    });

    testWidgets('tapping a line seeks to its timestamp', (tester) async {
      final h = await _pumpLyrics(tester);
      await tester.tap(find.text('Line 03')); // 20 s
      await tester.pump();
      expect(h.backend.seeks.last, const Duration(seconds: 20));
      await h.dispose(tester);
    });

    testWidgets('the list scrolls by itself to keep the current line in view', (tester) async {
      final h = await _pumpLyrics(tester);
      expect(_offset(tester), 0);
      await _at(tester, h, 105); // Line 20
      await _reached(tester);
      await tester.pump(const Duration(milliseconds: 400)); // first tick
      await tester.pump(const Duration(milliseconds: 400));
      // The reach of a row not built yet now animates (250 ms per attempt), then ensureVisible.
      for (var k = 0; k < 4; k++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(_offset(tester), greaterThan(0));
      // ensureVisible(alignment: 0.35): the line's row (8 px padding) sits at 35 % of the viewport.
      expect(tester.getTopLeft(find.text('Line 20')).dy, closeTo(640 * 0.35 + 8, 40));
      await h.dispose(tester);
    });

    testWidgets('with reduced motion the scroll is already final right after the first frame',
        (tester) async {
      final h = await _pumpLyrics(tester, noAnimations: true);
      await _at(tester, h, 105);
      await _reached(tester);
      final o = _offset(tester);
      expect(o, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_offset(tester), o);
      await h.dispose(tester);
    });

    // F-30 (39.8): the highlight used to switch at once (plain Opacity); now the colour fades.
    testWidgets('the highlight fades over 200 ms instead of switching at once', (tester) async {
      final h = await _pumpLyrics(tester);
      await _at(tester, h, 52); // Line 09
      await _fade(tester);
      await _at(tester, h, 57); // Line 10, built and in view
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester, 'Line 10'), inExclusiveRange(0.35, 1.0));
      await _fade(tester);
      expect(_opacity(tester, 'Line 10'), 1.0);
      expect(_opacity(tester, 'Line 09'), 0.55);
      await h.dispose(tester);
    });

    testWidgets('with reduced animations the highlight switches at once', (tester) async {
      final h = await _pumpLyrics(tester, noAnimations: true);
      await _at(tester, h, 52);
      expect(_opacity(tester, 'Line 09'), 1.0);
      await h.dispose(tester);
    });

    testWidgets('tall rows in a long song: the current line ends up in view', (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 1);
      final long = 'wrapping words ' * 12;
      final lrc = [
        for (var i = 0; i < 80; i++)
          '[${i ~/ 60}:${(i % 60).toString().padLeft(2, '0')}.00]L$i $long',
      ].join('\n');
      final track = (await tester.runAsync(() async {
        await (h.db.update(h.db.tracks)).write(TracksCompanion(lyricsSynced: Value(lrc)));
        return h.db.select(h.db.tracks).getSingle();
      }))!;
      await h.pump(tester, Scaffold(body: LyricsView(track: track)));
      await _at(tester, h, 70);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      // A row taller than the viewport is centred, so only part of it shows.
      final r = tester.getRect(find.textContaining('L70 '));
      expect(r.top < 640 && r.bottom > 0, isTrue);
      await h.dispose(tester);
    });

    testWidgets('the lyrics changing before the scroll callback does not throw', (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 1);
      final track = (await tester.runAsync(() async {
        await (h.db.update(h.db.tracks)).write(TracksCompanion(lyricsSynced: Value(_lrc)));
        return h.db.select(h.db.tracks).getSingle();
      }))!;
      await h.pump(tester, Scaffold(body: LyricsView(track: track)));
      h.backend.posC.add(const Duration(seconds: 105));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });
  });

  group('queue sheet', () {
    Future<Harness> pumpQueue(WidgetTester tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 6);
      final rows = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
      await tester.runAsync(() => h.handler.playQueue([for (final t in rows) t.id], 0));
      final sc = ScrollController();
      addTearDown(sc.dispose);
      await h.pump(tester, Scaffold(body: QueueSheet(scrollController: sc)));
      await _settle(tester);
      return h;
    }

    testWidgets('tapping an upcoming row jumps to it', (tester) async {
      final h = await pumpQueue(tester);
      await tester.tap(find.text('Song 3'));
      await _settle(tester);
      expect(h.handler.currentIndex, 3);
      await h.dispose(tester);
    });

  });

  group('sheets with 30 entries on 360x640', () {
    testWidgets('tags sheet: reaches the last tag by scrolling', (tester) async {
      final h = await _pumpTagsSheet(tester, 30);
      expect(find.text('Tag 00'), findsOneWidget);
      await _scrollTo(tester, 'Tag 29');
      await h.dispose(tester);
    });

    testWidgets('tags sheet: with 3 tags it is not 70 % tall', (tester) async {
      final h = await _pumpTagsSheet(tester, 3);
      expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(640 * 0.7));
      await h.dispose(tester);
    });

    testWidgets('activity sheet: reaches the last running activity by scrolling', (tester) async {
      _phone(tester);
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        _opener((c, _) => ActivitySheet.show(c)),
        extraOverrides: [
          activityProvider.overrideWithValue(ActivityState([
            for (var i = 0; i < 30; i++)
              ActivityItem(
                  kind: ActivityKind.download,
                  key: 'dl-$i',
                  name: 'Brano ${i.toString().padLeft(2, '0')}',
                  progress: 0.5,
                  ref: i),
          ], const [])),
        ],
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.text('Download, Brano 00'), findsOneWidget);
      await _scrollTo(tester, 'Download, Brano 29');
      await h.dispose(tester);
    });

    testWidgets('devices sheet: reaches the last nearby device by scrolling', (tester) async {
      _phone(tester);
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        _opener((c, _) => DevicesSheet.show(c)),
        extraOverrides: [shareHubProvider.overrideWith(() => _FakeHub(30))],
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.text('Dev 00'), findsOneWidget);
      await _scrollTo(tester, 'Dev 29');
      await h.dispose(tester);
    });

    testWidgets('with 100 rows not all are built', (tester) async {
      // Synced lyrics are a lazy ListView.builder: off-screen lines are not built.
      _phone(tester);
      final h = await Harness.create(tester, tracks: 1);
      final lrc = [
        for (var i = 0; i < 100; i++)
          '[${i ~/ 60}:${(i % 60).toString().padLeft(2, '0')}.00]Line $i',
      ].join('\n');
      final track = (await tester.runAsync(() async {
        await (h.db.update(h.db.tracks)).write(TracksCompanion(lyricsSynced: Value(lrc)));
        return h.db.select(h.db.tracks).getSingle();
      }))!;
      await h.pump(tester, Scaffold(body: LyricsView(track: track)));
      expect(find.textContaining('Line ', skipOffstage: false).evaluate().length, lessThan(40));
      expect(find.text('Line 99', skipOffstage: false), findsNothing);
      await h.dispose(tester);
    });
  });
}
