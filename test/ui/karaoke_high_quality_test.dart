import 'dart:io';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/providers/karaoke_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart'
    show networkProbeProvider;
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/karaoke/separation_service.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:codecore/ui/widgets/karaoke_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _Svc extends SeparationService {
  _Svc()
    : super(
        cache: StreamCache(Directory.systemTemp),
        separator: _NoSeparator(),
        modelsRoot: () async => Directory.systemTemp,
      );
  final levels = <double>[];

  @override
  Future<MixResult> mixFor(String k, double level) async {
    levels.add(level);
    return const MixResult(MixStatus.failed);
  }

  var missing = true;
  void poke() => notifyListeners();

  @override
  Future<bool> modelsMissing() async => missing;
}

class _Net extends NetworkProbe {
  _Net(this.m) : super(android: false);
  final bool m;

  @override
  Future<NetworkKind> current() async => NetworkKind(metered: m);
}

class _NoSeparator implements Separator {
  @override
  Future<void> separate({
    required String input,
    required String output,
    required String voiceOutput,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  }) async {}

  final mixes = <double>[];

  @override
  Future<void> mix({
    required String base,
    required String voice,
    required double level,
    required String output,
  }) async => mixes.add(level);

  @override
  Future<void> cancel() async {}
}

void main() {
  Future<Harness> open(
    WidgetTester t, {
    bool engine = true,
    KaraokeTarget? target = const KaraokeTarget('karaoke:k', '/m/a.mp3'),
    SeparationState sep = SeparationState.idle,
    String? basePath,
    bool metered = false,
    bool showKaraoke = true,
    SeparationService? service,
  }) async {
    t.view.physicalSize = const Size(500, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 0);
    final svc = !engine
        ? null
        : service ??
              SeparationService(
                cache: StreamCache(Directory.systemTemp),
                separator: _NoSeparator(),
                modelsRoot: () async => Directory.systemTemp,
              );
    final List<Override> o = [
      separationServiceProvider.overrideWithValue(svc),
      networkProbeProvider.overrideWithValue(_Net(metered)),
      karaokeTargetProvider.overrideWith((ref) async => target),
      separationStateProvider.overrideWithValue(sep),
      karaokeBaseProvider.overrideWith(
        (ref) async => target == null
            ? null
            : KaraokeBase(target.key, basePath, basePath != null),
      ),
    ];
    await h.pump(
      t,
      const Scaffold(body: Center(child: KaraokeButton())),
      extraOverrides: o,
    );
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first))
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(karaokeOn: true, showKaraoke: showKaraoke));
    await t.pump();
    if (!showKaraoke || !engine) return h;
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    return h;
  }

  testWidgets('no «Alta qualità» without the engine', (t) async {
    final h = await open(t, engine: false);
    expect(find.byType(IconButton), findsNothing);
    await h.dispose(t);
  });

  testWidgets('a streamed track not in the cache: the row waits for the file', (
    t,
  ) async {
    final h = await open(t, target: const KaraokeTarget('karaoke:s', null));
    expect(find.text('In attesa che il brano sia scaricato'), findsOneWidget);
    expect(find.text('Alta qualità'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('separating: percent, bar and the note', (t) async {
    final h = await open(
      t,
      sep: const SeparationState(SeparationPhase.separating, fraction: 0.42),
    );
    expect(find.textContaining('42 %'), findsWidgets);
    expect(
      t
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.42,
    );
    expect(find.textContaining('circa 1–2 minuti'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets(
    'stems ready: the «Voce» slider shows and a release asks for the mix',
    (t) async {
      final svc = _Svc();
      final h = await open(
        t,
        service: svc,
        sep: const SeparationState(
          SeparationPhase.ready,
          fraction: 1,
          path: '/c/base.wav',
        ),
        basePath: '/c/base.wav',
      );
      expect(find.text('Voce'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await t.drag(find.byType(Slider), const Offset(60, 0));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pumpAndSettle();
      expect(svc.levels, hasLength(1));
      expect(svc.levels.single, inInclusiveRange(0.05, 0.95));
      await h.dispose(t);
    },
  );

  testWidgets(
    'metered: the row names the model download; not metered: no warning',
    (t) async {
      final h = await open(t, metered: true);
      for (var i = 0; i < 3; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pump();
      }
      expect(find.text('Scarica 78 MB la prima volta'), findsOneWidget);
      await t.tap(find.text('Avvia'));
      await t.pump();
      expect(find.text('Avvia'), findsNothing);
      await h.dispose(t);
    },
  );

  testWidgets('failed: a short message and «Riprova»', (t) async {
    final h = await open(t, sep: const SeparationState(SeparationPhase.failed));
    expect(find.textContaining('Separazione non riuscita'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('the model note goes away once the models are there', (t) async {
    final svc = _Svc();
    final h = await open(t, metered: true, service: svc);
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pump();
      }
    }

    await settle();
    expect(find.text('Scarica 78 MB la prima volta'), findsOneWidget);
    svc
      ..missing = false
      ..poke();
    await settle();
    expect(find.textContaining('78 MB'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('not metered: no data warning', (t) async {
    final h = await open(t);
    expect(find.textContaining('78 MB'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('«Mostra il karaoke» off: no microphone', (t) async {
    final h = await open(t, showKaraoke: false);
    expect(find.byType(IconButton), findsNothing);
    await h.dispose(t);
  });
}
