import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/shuffle_plus/shuffle_plus_controller.dart' show ShufflePlusPending;
import 'package:codecore/ui/screens/now_playing/queue_sheet.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The state of the engine, set by the test.
class _Pending extends ShufflePlusPendingNotifier {
  _Pending(this.initial);

  final ShufflePlusPending initial;

  @override
  ShufflePlusPending build() => initial;

  void set(ShufflePlusPending p) => state = p;
}

void main() {
  late _Pending pending;
  late Harness h;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 4, radio: true);
    pending = _Pending(ShufflePlusPending.none);
    final rows = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    final online = h.handler.online!.register(
      const YtResult(id: 'v1', title: 'Streamed', channel: 'Chan', duration: null, artists: ['Ann']),
      seedTitle: 'Seed',
      suggested: true,
    );
    await tester.runAsync(() => h.handler.playQueue([for (final t in rows) t.id, online], 0));
    await h.pump(
      tester,
      Scaffold(body: QueueSheet(scrollController: ScrollController())),
      extraOverrides: [
        shufflePlusPendingProvider.overrideWith(() => pending),
      ],
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('N skeleton rows as tall as queue rows, one node «Shuffle+ sta scegliendo N brani…»; gone when none is incoming',
      (tester) async {
    await open(tester);
    expect(find.byType(Skeleton), findsNothing, reason: 'nothing incoming: no row');

    pending.set(const ShufflePlusPending(incoming: 3));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Skeleton), findsOneWidget);
    expect(tester.getSize(find.byType(Skeleton)).height, 3 * 64);
    expect(find.bySemanticsLabel('Shuffle+ sta scegliendo 3 brani…'), findsOneWidget);
    // The real rows come first.
    expect(tester.getTopLeft(find.text('Streamed')).dy, lessThan(tester.getTopLeft(find.byType(Skeleton)).dy));

    pending.set(const ShufflePlusPending(incoming: 1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getSize(find.byType(Skeleton)).height, 64);
    expect(find.bySemanticsLabel('Shuffle+ sta scegliendo 1 brano…'), findsOneWidget);

    pending.set(ShufflePlusPending.none);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Skeleton), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('a suggestion being enriched is shown dimmed until it is done', (tester) async {
    await open(tester);
    double opacity() => tester.widget<Opacity>(find.ancestor(of: find.text('Streamed'), matching: find.byType(Opacity)).first).opacity;
    expect(opacity(), 1);

    pending.set(ShufflePlusPending(enriching: {h.handler.queueIds.last}));
    await tester.pump(const Duration(milliseconds: 50));
    expect(opacity(), lessThan(1));

    pending.set(ShufflePlusPending.none);
    await tester.pump(const Duration(milliseconds: 50));
    expect(opacity(), 1);
    await h.dispose(tester);
  });
}
