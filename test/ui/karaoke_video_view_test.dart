import 'package:codecore/core/platform.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/karaoke_video_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/ui/screens/now_playing/karaoke_video_fullscreen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/widgets/karaoke_video_surface.dart';
import 'package:codecore/ui/widgets/karaoke_video_view.dart';
import 'package:codecore/ui/widgets/ring_progress.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../support/app_harness.dart';

class _FakeCtrl implements VideoController {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

final _ctrl = _FakeCtrl();

class _FakeVideo extends KaraokeVideoNotifier {
  _FakeVideo(this.initial);
  final KaraokeVideoState initial;
  @override
  KaraokeVideoState build() => initial;
  void set(KaraokeVideoState s) => state = s;
}

Future<void> _show(
  WidgetTester tester,
  Harness h, {
  required String path,
  required String title,
  required KaraokeVideoStatus status,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(
    () => h.db
        .into(h.db.tracks)
        .insert(
          TracksCompanion.insert(
            path: path,
            title: title,
            albumKey: 'a|b',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            artist: const Value('Artist'),
            durationMs: const Value(185000),
          ),
        ),
  );
  final t = (await tester.runAsync(
    () => h.db.select(h.db.tracks).getSingle(),
  ))!;
  await h.pump(
    tester,
    const NowPlayingScreen(),
    extraOverrides: [
      currentTrackProvider.overrideWith((_) => Stream.value(t)),
      karaokeVideoProvider.overrideWith(
        () => _FakeVideo(
          KaraokeVideoState(
            status,
            status == KaraokeVideoStatus.ready ? _ctrl : null,
          ),
        ),
      ),
      karaokeVideoBuilderProvider.overrideWithValue(
        (_) => const ColoredBox(key: Key('fake-video'), color: Colors.red),
      ),
    ],
  );
}

Finder get _ring => find.descendant(
  of: find.byType(NowPlayingScreen),
  matching: find.byType(RingProgress),
);

void main() {
  testWidgets(
    'karaoke video ready: the frame replaces the ring, with its label',
    (tester) async {
      final h = await Harness.create(tester);
      await _show(
        tester,
        h,
        path: 'online:youtube:abc',
        title: 'Hello (Karaoke)',
        status: KaraokeVideoStatus.ready,
      );
      expect(find.byKey(const Key('fake-video')), findsOneWidget);
      expect(_ring, findsNothing);
      expect(find.bySemanticsLabel('Video karaoke'), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets('karaoke video loading: cover with the loading text, no ring', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    await _show(
      tester,
      h,
      path: 'online:youtube:abc',
      title: 'Hello (Karaoke)',
      status: KaraokeVideoStatus.loading,
    );
    expect(find.text('Carico il video…'), findsOneWidget);
    expect(find.byKey(const Key('fake-video')), findsNothing);
    expect(_ring, findsNothing);
    await h.dispose(tester);
  });

  for (final c in [
    ('plain streaming track', 'online:youtube:abc', 'Hello'),
    ('local file with karaoke in the title', '/m/k.mp3', 'Hello (Karaoke)'),
    (
      'downloaded-like non-youtube stream',
      'online:other:abc',
      'Hello (Karaoke)',
    ),
  ]) {
    testWidgets('${c.$1}: cover and ring as always (F-9)', (tester) async {
      final h = await Harness.create(tester);
      await _show(
        tester,
        h,
        path: c.$2,
        title: c.$3,
        status: KaraokeVideoStatus.ready,
      );
      expect(_ring, findsOneWidget);
      expect(find.byKey(const Key('fake-video')), findsNothing);
      await h.dispose(tester);
    });
  }

  testWidgets('karaoke video failed: cover with ring and a notice', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    await _show(
      tester,
      h,
      path: 'online:youtube:abc',
      title: 'Hello (Karaoke)',
      status: KaraokeVideoStatus.loading,
    );
    final c = ProviderScope.containerOf(
      tester.element(find.byType(NowPlayingScreen)),
    );
    (c.read(karaokeVideoProvider.notifier) as _FakeVideo).set(
      const KaraokeVideoState(KaraokeVideoStatus.failed),
    );
    await tester.pump();
    await tester.pump();
    expect(_ring, findsOneWidget);
    expect(
      find.text('Video non disponibile: suona solo la base.'),
      findsOneWidget,
    );
    await h.dispose(tester);
  });

  testWidgets('tap opens the full screen, Back returns to the player', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    await _show(
      tester,
      h,
      path: 'online:youtube:abc',
      title: 'Hello (Karaoke)',
      status: KaraokeVideoStatus.ready,
    );
    await tester.tap(find.byType(KaraokeVideoView));
    await tester.pumpAndSettle();
    expect(find.byType(KaraokeVideoFullscreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(KaraokeVideoFullscreen), findsNothing);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets(
    'Android full screen: landscape and immersive in; state failed closes it, portrait and bars back',
    (tester) async {
      debugIsAndroidOverride = true;
      addTearDown(() => debugIsAndroidOverride = null);
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (c) async {
          if (c.method.startsWith('SystemChrome.set')) {
            calls.add('${c.method} ${c.arguments}');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            karaokeVideoProvider.overrideWith(
              () => _FakeVideo(
                KaraokeVideoState(KaraokeVideoStatus.ready, _ctrl),
              ),
            ),
            karaokeVideoBuilderProvider.overrideWithValue(
              (_) => const SizedBox(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (c) => TextButton(
                onPressed: () => Navigator.of(c).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const KaraokeVideoFullscreen(),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(
        calls.join('|'),
        allOf(contains('landscapeLeft'), contains('immersiveSticky')),
      );
      calls.clear();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(KaraokeVideoFullscreen)),
      );
      (c.read(karaokeVideoProvider.notifier) as _FakeVideo).set(
        const KaraokeVideoState(KaraokeVideoStatus.failed),
      );
      await tester.pumpAndSettle();
      expect(find.byType(KaraokeVideoFullscreen), findsNothing);
      expect(
        calls.join('|'),
        allOf(
          contains('portraitUp'),
          contains('setEnabledSystemUIOverlays'),
          contains('SystemUiOverlay.top'),
        ),
      );
      expect(calls.join('|'), isNot(contains('edgeToEdge')));
    },
  );
}
