import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/youtube_providers.dart' show youtubeServiceProvider;
import 'package:codecore/services/online/shared_text.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/share/share_fragment.dart';
import 'package:codecore/ui/shell/shared_collection_import.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';

class _Yt implements YoutubeService {
  final asked = <String>[];
  @override
  Future<List<YtResult>> search(String query) async {
    asked.add(query);
    if (query.endsWith('boomboomboo')) throw StateError('network');
    return [ytmSong(query.substring(query.length - 11), 'Song')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _shared = SharedCollection(
  const SharedFragment(SharedKind.playlist, 'Mix', ['abcdefghijk', 'boomboomboo', 'lmnopqrstuv']),
);

void main() {
  Future<(Harness, _Yt)> pump(WidgetTester t) async {
    final h = await Harness.create(t);
    final yt = _Yt();
    await h.pump(
      t,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => handleSharedPage(context, ref, _shared),
            child: const Text('go'),
          ),
        ),
      ),
      extraOverrides: [youtubeServiceProvider.overrideWithValue(yt)],
    );
    await t.tap(find.text('go'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    return (h, yt);
  }

  Future<List<Playlist>> playlists(WidgetTester t, Harness h) =>
      t.runAsync(() => h.db.select(h.db.playlists).get()).then((v) => v!);

  testWidgets('asks first, then saves the found tracks and says how many', (t) async {
    final (h, yt) = await pump(t);
    expect(yt.asked, isEmpty);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('3 brani'), findsOneWidget);
    await t.tap(find.text('Salva in Libreria'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 300));
    expect(yt.asked.length, 3);
    expect(find.text('Salvata come «Mix»: 2 su 3'), findsOneWidget);
    expect((await playlists(t, h)).map((p) => p.name), ['Mix']);
    await h.dispose(t);
  });

  testWidgets('Annulla does nothing: no lookup, no playlist', (t) async {
    final (h, yt) = await pump(t);
    await t.tap(find.text('Annulla'));
    await t.pump(const Duration(milliseconds: 300));
    expect(yt.asked, isEmpty);
    expect(await playlists(t, h), isEmpty);
    await h.dispose(t);
  });
}
