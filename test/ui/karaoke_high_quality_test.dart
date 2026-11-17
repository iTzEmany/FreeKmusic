import 'dart:io';

import 'package:codecore/providers/karaoke_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/karaoke/separation_service.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:codecore/ui/widgets/karaoke_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_voice_filter.dart';

class _NoSeparator implements Separator {
  @override
  Future<void> separate({
    required String input,
    required String output,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  }) async {}

  @override
  Future<void> cancel() async {}
}

const _jam = JamKaraoke(
  level: 0.5,
  guestsAllowed: true,
  isHost: true,
  remote: false,
  playsHere: true,
  hostName: 'Marco',
);

void main() {
  Future<Harness> open(
    WidgetTester t, {
    bool service = true,
    JamKaraoke? jam,
    KaraokeTarget? target = const KaraokeTarget('karaoke:k', '/m/a.mp3'),
    SeparationState sep = SeparationState.idle,
    String? basePath,
  }) async {
    t.view.physicalSize = const Size(500, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 0);
    final svc = service
        ? SeparationService(
            cache: StreamCache(Directory.systemTemp),
            separator: _NoSeparator(),
            modelsRoot: () async => Directory.systemTemp,
          )
        : null;
    final List<Override> o = [
      voiceFilterProvider.overrideWithValue(FakeVoiceFilter()),
      separationServiceProvider.overrideWithValue(svc),
      jamKaraokeProvider.overrideWithValue(jam),
      karaokeTargetProvider.overrideWith((ref) async => target),
      separationStateProvider.overrideWithValue(sep),
      karaokeBaseProvider.overrideWith(
        (ref) async => target == null
            ? null
            : KaraokeBase(
                target.key,
                basePath,
                basePath != null && ref.watch(karaokeUseBaseProvider),
              ),
      ),
    ];
    await h.pump(t, const Scaffold(body: Center(child: KaraokeButton())), extraOverrides: o);
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first))
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(karaokeOn: true));
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    return h;
  }

  testWidgets('no «Alta qualità» without the engine', (t) async {
    final h = await open(t, service: false);
    expect(find.text('Alta qualità'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('no «Alta qualità» in a Jam', (t) async {
    final h = await open(t, jam: _jam);
    expect(find.text('Alta qualità'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('a streamed track not in the cache: the row waits for the file', (t) async {
    final h = await open(t, target: const KaraokeTarget('karaoke:s', null));
    expect(find.text('In attesa che il brano sia scaricato'), findsOneWidget);
    expect(t.widget<ListTile>(find.widgetWithText(ListTile, 'Alta qualità')).enabled, isFalse);
    await h.dispose(t);
  });

  testWidgets('separating: percent, bar and the note; the filter slider stays', (t) async {
    final h = await open(t, sep: const SeparationState(SeparationPhase.separating, fraction: 0.42));
    expect(find.textContaining('42 %'), findsWidgets);
    expect(t.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.42);
    expect(find.textContaining('Intanto suona il filtro'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('base ready: Base / Originale replaces the slider, Originale brings it back', (t) async {
    final h = await open(
      t,
      sep: const SeparationState(SeparationPhase.ready, fraction: 1, path: '/c/base.wav'),
      basePath: '/c/base.wav',
    );
    expect(find.text('Base'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await t.tap(find.text('Originale'));
    await t.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    await h.dispose(t);
  });
}
