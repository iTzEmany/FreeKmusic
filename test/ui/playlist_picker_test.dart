import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/library_add_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/playlists/playlist_picker.dart';
import 'package:codecore/ui/widgets/action_catalog.dart';
import 'package:codecore/ui/widgets/track_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _Adder extends LibraryAdder {
  _Adder(super.ref);
  final calls = <String?>[];
  @override
  Future<bool?> add(YtResult r, {String? tag}) async {
    calls.add(tag);
    return true;
  }
}

const _r = YtResult(id: 'v1', title: 'Song', channel: 'Chan', duration: Duration(seconds: 90));

void main() {
  Future<Harness> open(WidgetTester tester, Future<void> Function(BuildContext, WidgetRef) run,
      {List<Override> extra = const []}) async {
    final h = await Harness.create(tester);
    for (final n in ['Rock', 'Jazz']) {
      await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: n, createdAt: 1));
    }
    await h.pump(
      tester,
      Consumer(
        builder: (c, ref, _) => Scaffold(body: TextButton(onPressed: () => run(c, ref), child: const Text('open'))),
      ),
      extraOverrides: extra,
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return h;
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('pickPlaylist returns the ticked playlists without writing', (tester) async {
    List<PickedPlaylist>? got;
    final h = await open(tester, (c, ref) async => got = await pickPlaylist(c, ref));
    await tester.tap(find.text('Rock'));
    await tester.tap(find.text('Jazz'));
    await tester.pump();
    await confirm(tester);
    expect(got!.map((p) => p.name).toSet(), {'Rock', 'Jazz'});
    expect(await h.db.select(h.db.playlistTracks).get(), isEmpty);

    await h.dispose(tester);
  });

  testWidgets('pickPlaylist is empty when the sheet is closed', (tester) async {
    List<PickedPlaylist>? got;
    final h = await open(tester, (c, ref) async => got = await pickPlaylist(c, ref));
    await tester.tap(find.byTooltip('Chiudi'));
    await tester.pump(const Duration(seconds: 1));
    expect(got, isEmpty);
    await h.dispose(tester);
  });

  testWidgets('an online result goes to two playlists with one add and one multi tag', (tester) async {
    late _Adder adder;
    final h = await open(
      tester,
      (c, ref) async {
        final a = onlineResultActions(c, ref, _r).firstWhere((a) => a.icon == CatalogAction.playlist.icon);
        await a.run();
      },
      extra: [libraryAdderProvider.overrideWith((ref) => adder = _Adder(ref))],
    );
    await tester.tap(find.text('Rock'));
    await tester.tap(find.text('Jazz'));
    await tester.pump();
    await confirm(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(adder.calls, hasLength(1));
    expect(adder.calls.single, matches(RegExp(r'^addto:\d+,\d+$')));
    expect(find.text('Aggiunto a 2 playlist'), findsOneWidget);
    await h.dispose(tester);
  });
}
