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

void main() {
  Future<Harness> open(
    WidgetTester t, {
    bool service = true,
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
      separationServiceProvider.overrideWithValue(svc),
      karaokeButtonVisibleProvider.overrideWithValue(true),
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
    await h.dispose(t);
  });

  testWidgets('a streamed track not in the cache: the row waits for the file', (t) async {
    final h = await open(t, target: const KaraokeTarget('karaoke:s', null));
    expect(find.text('In attesa che il brano sia scaricato'), findsOneWidget);
    expect(t.widget<ListTile>(find.widgetWithText(ListTile, 'Alta qualità')).enabled, isFalse);
    await h.dispose(t);
  });

  testWidgets('separating: percent, bar and the note', (t) async {
    final h = await open(t, sep: const SeparationState(SeparationPhase.separating, fraction: 0.42));
    expect(find.textContaining('42 %'), findsWidgets);
    expect(t.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.42);
    expect(find.textContaining('circa 1–2 minuti'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('base ready: Base / Originale choice, no «Alta qualità» row', (t) async {
    final h = await open(
      t,
      sep: const SeparationState(SeparationPhase.ready, fraction: 1, path: '/c/base.wav'),
      basePath: '/c/base.wav',
    );
    expect(find.text('Base'), findsOneWidget);
    expect(find.text('Originale'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await h.dispose(t);
  });
}
