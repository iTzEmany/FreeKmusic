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
  bool netDown = false;
  @override
  Future<List<YtResult>> search(String query) async {
    asked.add(query);
    if (netDown) throw const YtException(YtErrorKind.network);
    if (query.endsWith('boomboomboo')) throw StateError('network');
    if (query.contains('wonderwall')) return [ytmSong('wwwwwwwwwww', 'Wonderwall', artist: 'Oasis')];
    if (query.contains('nothing')) return [];
    return [ytmSong(query.substring(query.length - 11), 'Song')];
  }

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) => search(query);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _shared = SharedCollection(
  const SharedFragment(SharedKind.playlist, 'Mix', [
    SharedRow.id('abcdefghijk'),
    SharedRow.id('boomboomboo'),
    SharedRow.id('lmnopqrstuv'),
  ]),
);

void main() {
  Future<(Harness, _Yt)> pump(WidgetTester t, {bool netDown = false, SharedCollection? page}) async {
    final h = await Harness.create(t);
    final yt = _Yt()..netDown = netDown;
    await h.pump(
      t,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => handleSharedPage(context, ref, page ?? _shared),
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

  testWidgets('rows without an id are searched by artist and title; the one not found stays in the list', (t) async {
    final (h, yt) = await pump(t,
        page: const SharedCollection(SharedFragment(SharedKind.playlist, 'Locali', [
          SharedRow.id('abcdefghijk'),
          SharedRow.search('Oasis', 'Wonderwall'),
          SharedRow.search('Nobody', 'Nothing'),
        ])));
    await t.tap(find.text('Salva in Libreria'));
    // The matcher paces its searches (a real gap between rows): wait for the result, not a fixed time.
    for (var i = 0; i < 40 && find.textContaining('Salvata').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(yt.asked, contains('oasis wonderwall'));
    expect(find.text('Salvata come «Locali»: 2 su 3'), findsOneWidget);
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

  testWidgets('every lookup failing on the network stops after one batch and says so', (t) async {
    final ids = ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc', 'ddddddddddd', 'eeeeeeeeeee', 'fffffffffff'];
    final (h, yt) = await pump(t,
        netDown: true, page: SharedCollection(SharedFragment(SharedKind.playlist, 'Mix', [for (final i in ids) SharedRow.id(i)])));
    await t.tap(find.text('Salva in Libreria'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 300));
    expect(yt.asked.length, 4);
    expect(find.text('Controlla la connessione e riprova'), findsOneWidget);
    expect(await playlists(t, h), isEmpty);
    await h.dispose(t);
  });

  testWidgets('rows searched by name, all failing on the network: the network message, no playlist', (t) async {
    final (h, _) = await pump(t,
        netDown: true,
        page: const SharedCollection(SharedFragment(SharedKind.playlist, 'Locali', [
          SharedRow.search('Oasis', 'Wonderwall'),
          SharedRow.search('Nobody', 'Nothing'),
        ])));
    await t.tap(find.text('Salva in Libreria'));
    for (var i = 0; i < 40 && find.text('Controlla la connessione e riprova').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Controlla la connessione e riprova'), findsOneWidget);
    expect(await playlists(t, h), isEmpty);
    await h.dispose(t);
  });
}
