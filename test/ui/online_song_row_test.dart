import 'dart:async';

import 'package:codecore/app.dart';
import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/selection_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/artist_link_resolver.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/online/online_song_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _r = YtResult(
  id: 'v1',
  title: 'Online song',
  channel: 'Chan',
  duration: Duration(seconds: 90),
  artists: ['Ann'],
  artistIds: ['UC1'],
);

class _Ctrl implements PlayerController {
  final calls = <String>[];
  bool failEnqueue = false;
  @override
  bool inJam = false;

  @override
  Future<void> playOnline(YtResult r) async => calls.add('play');
  @override
  Future<bool> playFromSearch({Track? track, YtResult? online}) async {
    calls.add('play');
    return false;
  }
  @override
  Future<void> enqueueOnline(YtResult r) async {
    if (failEnqueue) throw StateError('no');
    calls.add('enqueue');
  }
  @override
  Future<void> playOnlineNext(YtResult r) async => calls.add('next');

  @override
  bool get jamQueueFull => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Downloads extends DownloadsNotifier {
  final adds = <String?>[];
  bool instant = false;
  @override
  List<DownloadItem> build() => [];
  @override
  Future<bool> add(YtResult r, {String? tag}) async {
    adds.add(tag ?? 'plain');
    return instant;
  }
}

void main() {
  late _Ctrl ctrl;
  late _Downloads downloads;
  final askedArtists = <String>[];

  Future<Harness> pumpRow(WidgetTester tester, {bool jam = false, Widget? child}) async {
    askedArtists.clear();
    ctrl = _Ctrl()..inJam = jam;
    downloads = _Downloads();
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      child ??
          const Scaffold(
            body: OnlineSongTile(result: _r, index: 0, selectionKey: 'k'),
          ),
      extraOverrides: [
        playerControllerProvider.overrideWithValue(ctrl),
        downloadsProvider.overrideWith(() => downloads),
        artistLinkResolverProvider.overrideWithValue(ArtistLinkResolver(
          library: (name) async {
            askedArtists.add(name);
            return null;
          },
          search: (_) async => [],
        )),
      ],
    );
    return h;
  }

  testWidgets('tap plays and opens the player; the download button is there', (tester) async {
    final h = await pumpRow(tester);
    expect(find.byTooltip('Scarica'), findsOneWidget);
    await tester.tap(find.text('Online song'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.calls, ['play']);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a double tap pushes the player once', (tester) async {
    late BuildContext ctx;
    late WidgetRef ref;
    final h = await pumpRow(
      tester,
      child: Consumer(builder: (c, r, _) {
        ctx = c;
        ref = r;
        return const Scaffold();
      }),
    );
    unawaited(playOnlineAndOpen(ctx, ref, _r));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    unawaited(playOnlineAndOpen(ctx, ref, _r));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.calls, ['play', 'play']);
    Navigator.of(ctx, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('while picking, tap toggles and there is no swipe or ⋮', (tester) async {
    final h = await pumpRow(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(OnlineSongTile)));
    container.read(selectionProvider('k').notifier).toggle(0);
    await tester.pump();
    expect(find.byTooltip('Altre opzioni'), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
    await tester.tap(find.text('Online song'));
    await tester.pump();
    expect(container.read(selectionProvider('k')).active, isFalse);
    expect(ctrl.calls, isEmpty);
    expect(find.byType(NowPlayingScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('a queueing that fails does not say «Aggiunto in coda»', (tester) async {
    final h = await pumpRow(tester);
    await tester.dragFrom(const Offset(120, 36), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Aggiunto in coda'), findsOneWidget); // control: it shows when it works
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    await tester.pumpAndSettle();
    ctrl.failEnqueue = true;
    await tester.dragFrom(const Offset(120, 36), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Aggiunto in coda'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('swipe queues; a swipe from the edge does not', (tester) async {
    final h = await pumpRow(tester);
    await tester.dragFrom(const Offset(120, 36), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(ctrl.calls, ['enqueue']);
    await tester.dragFrom(const Offset(4, 36), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(ctrl.calls, ['enqueue']);
    await h.dispose(tester);
  });

  testWidgets('with a Jam on, tap and «Riproduci dopo» queue like a swipe (D-89)', (tester) async {
    final h = await pumpRow(tester, jam: true);
    await tester.tap(find.text('Online song'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.calls, ['enqueue']);
    expect(find.byType(NowPlayingScreen), findsNothing);
    await tester.tap(find.byTooltip('Altre opzioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riproduci dopo'));
    await tester.pumpAndSettle();
    expect(ctrl.calls, ['enqueue', 'next']); // the controller does the Jam routing (D-89)
    await h.dispose(tester);
  });

  testWidgets('«Scarica» of an instant promotion says it joined the library', (tester) async {
    final h = await pumpRow(tester);
    downloads.instant = true;
    await tester.tap(find.byTooltip('Altre opzioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();
    expect(find.text('Aggiunto alla libreria'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the ⋮ menu has the 5 actions and each runs', (tester) async {
    final h = await pumpRow(tester);
    await tester.runAsync(() => h.db.customStatement(
        "INSERT INTO playlists (name, created_at, uuid, updated_at) VALUES ('P1', 1, 'u1', 1)"));
    Future<void> open() async {
      await tester.tap(find.byTooltip('Altre opzioni'));
      await tester.pumpAndSettle();
    }

    await open();
    for (final t in ['Riproduci dopo', 'Aggiungi in coda', 'Aggiungi a playlist…', 'Scarica']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Vai all’artista'), findsOneWidget);
    await tester.tap(find.text('Riproduci dopo'));
    await tester.pumpAndSettle();
    await open();
    await tester.tap(find.text('Aggiungi in coda'));
    await tester.pumpAndSettle();
    expect(ctrl.calls, ['next', 'enqueue']);

    await open();
    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();
    expect(downloads.adds, ['plain']);

    await open();
    await tester.tap(find.text('Aggiungi a playlist…'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();
    expect(downloads.adds.length, 2);
    expect(downloads.adds.last, startsWith('addto:'));

    await open();
    await tester.tap(find.text('Vai all’artista'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(askedArtists, ['Ann']); // library first (49.3); the page opens through ShellNav, absent in this harness
    await h.dispose(tester);
  });

  testWidgets('a failed promotion shows a localized snackbar, never the raw message', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final errors = StreamController<PromoteError>();
    addTearDown(errors.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [...h.overrides, promoteErrorsProvider.overrideWith((_) => errors.stream)],
      child: const CodecoreApp(),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    errors.add(PromoteError(noSpace: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Spazio insufficiente per scaricare il brano'), findsOneWidget);
    // The same message again is a second snackbar, queued behind the first.
    errors.add(PromoteError(noSpace: true));
    await tester.pump();
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).hideCurrentSnackBar();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Spazio insufficiente per scaricare il brano'), findsOneWidget);
    await h.dispose(tester);
  });
}
