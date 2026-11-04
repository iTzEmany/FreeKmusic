// Golden tests of the player states of phase 81: nothing playing, streamed
// cards waiting, queue with suggestions on their way. Linux only.
//   flutter test --update-goldens test/goldens/player_golden_test.dart
import 'dart:async';
import 'dart:io';

import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/shuffle_plus/shuffle_plus_controller.dart'
    show ShufflePlusPending;
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/now_playing/queue_sheet.dart';
import 'package:codecore/ui/widgets/cover_image.dart';
import 'package:codecore/ui/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_shots/support/shot_harness.dart';
import '../support/fake_stream_preparer.dart';
import 'tolerant_comparator.dart';

class _Pending extends ShufflePlusPendingNotifier {
  @override
  ShufflePlusPending build() => const ShufflePlusPending(incoming: 3);
}

/// The seed queue played to its end: nothing plays, the last queue is kept.
Future<void> _endQueue(Shot s) => s.tester.runAsync(() async {
  await s.h.handler.playQueue(s.seed.trackIds.take(3).toList(), 0);
  for (var i = 0; i < 3; i++) {
    await s.h.handler.skipToNext();
  }
});

void main() {
  if (!Platform.isLinux) return;

  setUpAll(() {
    TolerantComparator.install();
    coverImageStub = (key) => const ColoredBox(color: Color(0xFF7480E8));
  });
  tearDownAll(() => coverImageStub = null);

  for (final size in ShotSize.values) {
    for (final scale in const [1.0, 1.5]) {
      final tag = '${size.name}_${(scale * 100).round()}';
      group(tag, () {
        testWidgets(
          'now_playing_empty',
          (tester) => withGoldenShot(tester, size, (s) async {
            await _endQueue(s);
            await s.show(const NowPlayingScreen(), textScale: scale);
            await s.expectGolden('${tag}_now_playing_empty.png');
          }),
        );

        testWidgets(
          'now_playing_waiting',
          (tester) => withGoldenShot(tester, size, radio: true, (s) async {
            final preparer = FakeStreamPreparer(
              TrackRepository(s.h.db),
              s.coversDir,
            );
            s.h.handler.preparer = preparer;
            const r = YtResult(
              id: 'v1',
              title: 'Online song',
              channel: 'Chan',
              artists: ['Ann'],
              duration: Duration(minutes: 3),
            );
            preparer.gates['youtube:v1'] = Completer<void>();
            final id = s.h.handler.online!.register(r);
            unawaited(s.h.handler.playQueue([id], 0)); // waits for the gate
            await s.show(const NowPlayingScreen(), textScale: scale);
            // The cards are under the cover: scroll them into view.
            await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
            await s.settle();
            await s.expectGolden('${tag}_now_playing_waiting.png');
          }),
        );

        testWidgets(
          'queue_incoming',
          (tester) => withGoldenShot(tester, size, (s) async {
            await tester.runAsync(
              () => s.h.handler.playQueue(s.seed.trackIds.take(5).toList(), 1),
            );
            await s.show(
              Scaffold(body: QueueSheet(scrollController: ScrollController())),
              textScale: scale,
              extra: [
                shufflePlusPendingProvider.overrideWith(_Pending.new),
                shuffleModeProvider.overrideWithValue(ShuffleMode.plus),
              ],
            );
            await s.expectGolden('${tag}_queue_incoming.png');
          }),
        );

        if (size == ShotSize.phone) {
          testWidgets(
            'mini_player_empty',
            (tester) => withGoldenShot(tester, size, (s) async {
              await _endQueue(s);
              await s.show(
                const Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: MiniPlayer(),
                  ),
                ),
                textScale: scale,
              );
              await s.expectGolden('${tag}_mini_player_empty.png');
            }),
          );
        }
      });
    }
  }
}
