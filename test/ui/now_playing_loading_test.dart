import 'dart:async';
import 'dart:io';

import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/youtube_providers.dart'
    show downloadIndexProvider;
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_stream_preparer.dart';

const _r = YtResult(
  id: 'v1',
  title: 'Online song',
  channel: 'Chan',
  artists: ['Ann'],
  duration: Duration(minutes: 3),
);

/// Real async work (DB, files) settles in a few event-queue turns; no wall-clock sleep.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.runAsync(() => pumpEventQueue());
    await t.pump();
  }
}

void main() {
  testWidgets(
    'tap on a result: NowPlaying opens in loading with the title, then the ring goes',
    (t) async {
      final h = await Harness.create(t, radio: true);
      final dir = Directory.systemTemp.createTempSync('np_loading');
      addTearDown(() => dir.deleteSync(recursive: true));
      final preparer = FakeStreamPreparer(TrackRepository(h.db), dir);
      final gate = preparer.gates['youtube:v1'] = Completer<void>();
      h.handler.preparer = preparer;
      await h.pump(
        t,
        Consumer(
          builder: (c, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => playOnlineAndOpen(c, ref, _r),
              child: const Text('go'),
            ),
          ),
        ),
        extraOverrides: [
          downloadIndexProvider.overrideWith(
            (ref) async => DownloadIndex(File('${dir.path}/idx.json')),
          ),
        ],
      );
      await t.tap(find.text('go'));
      await _settle(t);
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(NowPlayingScreen), findsOneWidget);
      expect(find.text('Online song'), findsWidgets);
      expect(find.byKey(const ValueKey('np-cover-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('np-controls-loading')), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      gate.complete();
      await _settle(t);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('np-cover-loading')), findsNothing);
      expect(find.byKey(const ValueKey('np-controls-loading')), findsNothing);

      await t.pumpWidget(const SizedBox());
      await h.dispose(t);
    },
  );
}
