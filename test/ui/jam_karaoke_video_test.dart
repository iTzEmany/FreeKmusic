import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/karaoke_video_providers.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/ui/screens/jam/jam_parts.dart';
import 'package:codecore/ui/screens/jam/jam_screen.dart';
import 'package:codecore/ui/widgets/karaoke_video_view.dart';
import 'package:codecore/ui/widgets/ring_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _FakeJam extends JamController {
  _FakeJam(this.initial);
  final JamUiState initial;
  @override
  JamUiState build() => initial;
}

class _FakeVideo extends JamKaraokeVideoNotifier {
  static int built = 0;
  @override
  KaraokeVideoState build() {
    built++;
    return const KaraokeVideoState(KaraokeVideoStatus.loading);
  }

  void set(KaraokeVideoStatus s) => state = KaraokeVideoState(s);
}

JamUiState _jam(String title, {String? ref, String? videoId}) => JamUiState(
  phase: JamPhase.active,
  role: JamRole.host,
  peerName: 'Telefono',
  peerId: 'peer',
  jam: JamState(
    version: 1,
    items: [
      JamItem(
        id: 1,
        ownerDeviceId: 'host',
        title: title,
        ext: 'mp3',
        durationMs: 180000,
        ref: ref,
        videoId: videoId,
      ),
    ],
    currentIndex: 0,
    playing: true,
    hostDeviceId: 'host',
    outputDeviceId: 'host',
  ),
);

final _karaoke = _jam('Hello (Karaoke)', ref: 'yt:youtube:abc', videoId: 'abc');

Future<ProviderContainer> _open(WidgetTester tester, JamUiState s) async {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _FakeVideo.built = 0;
  final h = await Harness.create(tester);
  await h.pump(
    tester,
    const JamScreen(),
    extraOverrides: [
      jamProvider.overrideWith(() => _FakeJam(s)),
      jamKaraokeVideoProvider.overrideWith(_FakeVideo.new),
    ],
  );
  addTearDown(() => h.dispose(tester));
  return ProviderScope.containerOf(tester.element(find.byType(JamScreen)));
}

void main() {
  testWidgets('a karaoke item shows the video instead of the ring', (tester) async {
    final sem = tester.ensureSemantics();
    await _open(tester, _karaoke);
    expect(find.byType(KaraokeVideoView), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Video karaoke')), findsOneWidget);
    expect(find.text('Carico il video…'), findsOneWidget);
    expect(find.byType(RingProgress), findsNothing);
    sem.dispose();
  });

  testWidgets('a normal item keeps cover and ring and builds no video', (tester) async {
    await _open(tester, _jam('Hello'));
    expect(find.byType(RingProgress), findsOneWidget);
    expect(find.byType(JamCover), findsWidgets);
    expect(find.byType(KaraokeVideoView), findsNothing);
    expect(_FakeVideo.built, 0);
  });

  testWidgets('an ended Jam builds no video', (tester) async {
    await _open(tester, _karaoke.copyWith(phase: JamPhase.ended));
    expect(find.byType(KaraokeVideoView), findsNothing);
    expect(_FakeVideo.built, 0);
  });

  testWidgets('a failed video shows the message once and the ring is back', (tester) async {
    final c = await _open(tester, _karaoke);
    (c.read(jamKaraokeVideoProvider.notifier) as _FakeVideo).set(KaraokeVideoStatus.failed);
    await tester.pump();
    expect(find.text('Video non disponibile: suona solo la base.'), findsOneWidget);
    expect(find.byType(RingProgress), findsOneWidget);
    expect(find.byType(KaraokeVideoView), findsNothing);
  });
}
