import 'package:audio_service/audio_service.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/ui/screens/settings/shuffle_plus_tiles.dart';
import 'package:codecore/ui/widgets/shuffle_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _ActiveJam extends JamController {
  @override
  JamUiState build() =>
      const JamUiState(phase: JamPhase.active, role: JamRole.host);
}

void main() {
  setUp(resetShuffleExplained);

  testWidgets(
    'ShufflePill: accent when on, badge with Shuffle+, long press opens the sheet',
    (tester) async {
      final h = await Harness.create(tester, tracks: 2);
      await h.pump(tester, Scaffold(body: ShufflePill(ids: const [])));
      final c = ProviderScope.containerOf(
        tester.element(find.byType(ShufflePill)),
      );
      c.read(shufflePlusConfigProvider);
      final cc = CcColors.notte;
      Color iconColor() =>
          tester.widget<Icon>(find.byIcon(Icons.shuffle_rounded)).color!;
      expect(iconColor(), isNot(cc.accent));
      expect(find.byKey(const ValueKey('shuffle-plus-badge')), findsNothing);

      await tester.runAsync(
        () => h.handler.setShuffleMode(AudioServiceShuffleMode.all),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(iconColor(), cc.accent);

      c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(shufflePlus: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('shuffle-plus-badge')), findsOneWidget);

      await tester.longPress(find.byType(ShufflePill));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShufflePlusTiles), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'the shuffle button goes off → shuffle → Shuffle+ → off and drives the engine config',
    (tester) async {
      final h = await Harness.create(tester, tracks: 2);
      await h.pump(tester, const Scaffold(body: ShuffleModeButton()));
      final c = ProviderScope.containerOf(
        tester.element(find.byType(ShuffleModeButton)),
      );
      c.read(shufflePlusConfigProvider);

      Future<void> tap() async {
        await tester.runAsync(() async {
          await tester.tap(find.byType(IconButton));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      }

      ShuffleMode mode() => c.read(shuffleModeProvider);
      expect(mode(), ShuffleMode.off);
      expect(find.byKey(const ValueKey('shuffle-plus-badge')), findsNothing);

      await tap();
      expect(mode(), ShuffleMode.shuffle);
      expect(h.handler.shuffleEnabled, isTrue);
      expect(c.read(shufflePlusConfigProvider).enabled, isFalse);

      await tap();
      expect(mode(), ShuffleMode.plus);
      expect(c.read(shufflePlusConfigProvider).enabled, isTrue);
      expect(find.byKey(const ValueKey('shuffle-plus-badge')), findsOneWidget);
      expect(c.read(settingsProvider).shufflePlus, isTrue);

      await tap();
      expect(mode(), ShuffleMode.off);
      expect(h.handler.shuffleEnabled, isFalse);
      expect(c.read(shufflePlusConfigProvider).enabled, isFalse);
      await h.dispose(tester);
    },
  );

  testWidgets('turning shuffle off from outside also drops the «+»', (
    tester,
  ) async {
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const Scaffold(body: ShuffleModeButton()));
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ShuffleModeButton)),
    );
    c.read(shufflePlusConfigProvider);
    await tester.runAsync(() async {
      await h.handler.setShuffleMode(AudioServiceShuffleMode.all);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 100));
    c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(shufflePlus: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(shuffleModeProvider), ShuffleMode.plus);

    await tester.runAsync(() async {
      await h.handler.setShuffleMode(AudioServiceShuffleMode.none);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(settingsProvider).shufflePlus, isFalse);
    await h.dispose(tester);
  });

  testWidgets(
    'a long press opens the Shuffle+ sheet (the tooltip does not take it)',
    (tester) async {
      final h = await Harness.create(tester, tracks: 2);
      await h.pump(tester, const Scaffold(body: ShuffleModeButton()));
      await tester.longPress(find.byType(IconButton));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShufflePlusTiles), findsOneWidget);
      await h.dispose(tester);
    },
  );

  // Taps the button [taps] times; returns the mode after each tap.
  Future<List<ShuffleMode>> cycle(
    WidgetTester tester,
    ProviderContainer c,
    int taps, {
    Finder? button,
  }) async {
    final modes = <ShuffleMode>[];
    for (var i = 0; i < taps; i++) {
      await tester.runAsync(() async {
        await tester.tap(button ?? find.byType(IconButton));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      modes.add(c.read(shuffleModeProvider));
    }
    return modes;
  }

  const blocked = [ShuffleMode.shuffle, ShuffleMode.off, ShuffleMode.shuffle];
  const full = [ShuffleMode.shuffle, ShuffleMode.plus, ShuffleMode.off];

  Future<ProviderContainer> start(
    WidgetTester tester,
    Harness h,
    List<int> queue, {
    List<Override> extra = const [],
    PlayContextKind? context,
  }) async {
    await h.pump(
      tester,
      const Scaffold(body: ShuffleModeButton()),
      extraOverrides: extra,
    );
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ShuffleModeButton)),
    );
    c.read(shufflePlusConfigProvider);
    if (context != null) {
      h.handler.setPlayContext(context.index, null);
    }
    await tester.runAsync(() => h.handler.playQueue(queue, 0));
    return c;
  }

  Future<List<int>> localIds(WidgetTester tester, Harness h) async =>
      (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!
          .map((t) => t.id)
          .toList();

  testWidgets('an online album queue skips Shuffle+', (tester) async {
    final h = await Harness.create(tester, tracks: 0, radio: true);
    final ids = [
      for (var i = 0; i < 6; i++)
        h.handler.online!.register(
          YtResult(id: 'v$i', title: 'T$i', channel: 'C', duration: null),
        ),
    ];
    final c = await start(tester, h, ids);
    expect(await cycle(tester, c, 3), blocked);
    await h.dispose(tester);
  });

  testWidgets('a Jam skips Shuffle+', (tester) async {
    final h = await Harness.create(tester, tracks: 6);
    final c = await start(
      tester,
      h,
      await localIds(tester, h),
      extra: [jamProvider.overrideWith(_ActiveJam.new)],
    );
    expect(await cycle(tester, c, 3), blocked);
    await h.dispose(tester);
  });

  testWidgets('a radio skips Shuffle+', (tester) async {
    final h = await Harness.create(tester, tracks: 6);
    final c = await start(
      tester,
      h,
      await localIds(tester, h),
      context: PlayContextKind.radio,
    );
    expect(await cycle(tester, c, 3), blocked);
    await h.dispose(tester);
  });

  testWidgets('4 local tracks skip Shuffle+, 6 do not', (tester) async {
    final h = await Harness.create(tester, tracks: 6);
    final all = await localIds(tester, h);
    final c = await start(tester, h, all.take(4).toList());
    expect(await cycle(tester, c, 3), blocked);
    await tester.runAsync(() => h.handler.playQueue(all, 0));
    expect(await cycle(tester, c, 2), [ShuffleMode.plus, ShuffleMode.off]);
    expect(await cycle(tester, c, 3), full);
    await h.dispose(tester);
  });

  // D-137: the control judges the list it plays, not the queue of before.
  Future<ProviderContainer> startWith(
    WidgetTester tester,
    Harness h,
    Widget control,
    List<int> queue,
  ) async {
    await h.pump(tester, Scaffold(body: control));
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    c.read(shufflePlusConfigProvider);
    await tester.runAsync(() => h.handler.playQueue(queue, 0));
    return c;
  }

  testWidgets(
    'the Casuale pill reaches Shuffle+ for a 6-track list while 3 tracks play',
    (tester) async {
      final h = await Harness.create(tester, tracks: 6);
      final all = await localIds(tester, h);
      final c = await startWith(
        tester,
        h,
        ShufflePill(ids: all),
        all.take(3).toList(),
      );
      expect(
        await cycle(tester, c, 3, button: find.byType(OutlinedButton)),
        full,
      );
      await h.dispose(tester);
    },
  );

  testWidgets(
    'the Casuale pill of a 4-track list skips Shuffle+ even if 6 play',
    (tester) async {
      final h = await Harness.create(tester, tracks: 6);
      final all = await localIds(tester, h);
      final c = await startWith(
        tester,
        h,
        ShufflePill(ids: all.take(4).toList()),
        all,
      );
      expect(
        await cycle(tester, c, 3, button: find.byType(OutlinedButton)),
        blocked,
      );
      await h.dispose(tester);
    },
  );

  testWidgets(
    'the Home shuffle button judges the whole library, not the queue',
    (tester) async {
      final h = await Harness.create(tester, tracks: 6);
      final all = await localIds(tester, h);
      final c = await startWith(
        tester,
        h,
        ShuffleModeButton(listIds: () async => all),
        all.take(3).toList(),
      );
      expect(await cycle(tester, c, 3), full);
      await h.dispose(tester);
    },
  );

  testWidgets('the reason is shown once per session', (tester) async {
    final h = await Harness.create(tester, tracks: 6);
    final c = await start(
      tester,
      h,
      (await localIds(tester, h)).take(4).toList(),
    );
    await cycle(tester, c, 2); // shuffle, then the skip
    expect(find.byType(SnackBar), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
        .clearSnackBars();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await cycle(tester, c, 2);
    expect(find.byType(SnackBar), findsNothing);
    await h.dispose(tester);
  });
}
