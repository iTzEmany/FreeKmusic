import 'package:codecore/data/db/tables.dart' show TombstoneKind;
import 'package:codecore/services/backup/user_data.dart';
import 'package:codecore/services/share/settings_sync.dart';
import 'package:codecore/services/share/tables_sync.dart';
import 'package:codecore/services/share/collection_sync.dart';
import 'package:codecore/services/share/playlist_sync.dart';
import 'package:codecore/ui/screens/share/sync_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

RemotePlaylist _remote(String uuid, String name, int at, List<String> titles) =>
    RemotePlaylist(
        uuid: uuid,
        name: name,
        createdAt: 1,
        updatedAt: at,
        items: [for (final t in titles) TrackRef(title: t, relPath: '$t.mp3')]);

LocalPlaylist _local(String uuid, String name, int at, List<int> ids) =>
    LocalPlaylist(id: 1, uuid: uuid, name: name, updatedAt: at, trackIds: ids);

int? _resolve(TrackRef r) => const {'a': 1, 'b': 2, 'c': 3}[r.title];

void main() {
  testWidgets('shows the counts and one line per playlist that will change', (tester) async {
    final h = await Harness.create(tester);
    final plan = planSync(
      [_local('u2', 'Gym', 10, [1, 2]), _local('u3', 'Newer here', 90, [1])],
      [
        _remote('u1', 'Road', 5, ['a', 'x']),
        _remote('u2', 'Gym', 20, ['c', 'a']),
        _remote('u3', 'Newer here', 50, ['b']),
      ],
      _resolve,
    );
    SyncChoice? result;
    await h.pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showSyncPreview(context, plan, canAsk: true),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sincronizza playlist'), findsOneWidget);
    expect(find.text('1 nuova, 1 aggiornata, 1 brano mancante'), findsOneWidget);
    expect(find.text('Road'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Newer here'), findsNothing, reason: 'it stays as it is: only counted');
    expect(find.textContaining('1 playlist è più recente qui'), findsOneWidget);
    expect(find.textContaining('1 brano tolto'), findsOneWidget, reason: 'Gym loses «b»');
    expect(find.text('Chiedi i brani mancanti'), findsOneWidget);

    await tester.tap(find.text('Applica'));
    await tester.pumpAndSettle();
    expect(result!.decision, SyncDecision.apply);
    await h.dispose(tester);
  });

  testWidgets('asking for the missing tracks returns that decision', (tester) async {
    final h = await Harness.create(tester);
    final plan = planSync([], [_remote('u1', 'Road', 5, ['a', 'x'])], _resolve);
    SyncChoice? result;
    await h.pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showSyncPreview(context, plan, canAsk: true),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chiedi i brani mancanti'));
    await tester.pumpAndSettle();
    expect(result!.decision, SyncDecision.applyAndAsk);
    await h.dispose(tester);
  });

  testWidgets('nothing to do: says so and only offers Close; no ask button without a transport', (tester) async {
    final h = await Harness.create(tester);
    final plan = planSync(
      [_local('u1', 'Road', 10, [1])],
      [_remote('u1', 'Road', 10, ['a', 'x'])],
      _resolve,
    );
    await h.pump(tester, SyncPreviewDialog(plan: plan));
    expect(find.text('1 brano mancante'), findsOneWidget, reason: 'still told what is missing');
    expect(find.text('Applica'), findsNothing);
    expect(find.text('Chiedi i brani mancanti'), findsNothing);
    expect(find.text('Chiudi'), findsOneWidget);

      final empty = planSync([], const [], _resolve);
      await h.pump(tester, SyncPreviewDialog(plan: empty));
      expect(find.text('Le playlist sono già allineate'), findsOneWidget);
      await h.dispose(tester);
    },
  );

  Future<void> open(WidgetTester tester, Harness h, SyncPlan plan, void Function(SyncChoice?) done,
      {bool mine = true}) async {
    await h.pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => done(await showSyncPreview(context, plan, mine: mine)),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final tomb = TombstoneData(kind: TombstoneKind.favoriteAlbum, key: 'a|b', deletedAt: 5);
  final plan = SyncPlan(
    [],
    CollectionPlan(
      favoriteAdds: const [FavoriteCollectionData(kind: 'album', key: 'c|d', addedAt: 1)],
      deletes: [tomb, TombstoneData(kind: TombstoneKind.playlist, key: 'u9', deletedAt: 5)],
      settings: const [SettingChange('theme', 'dark', 'light'), SettingChange('autoLyrics', true, false)],
      tables: TablesBundle(plays: [PlayEntry(ref: TrackRef(title: 'a'), playedAt: 1)]),
    ),
  );

  testWidgets('collections: additions and removals by type, incoming tables, removing button', (tester) async {
    final h = await Harness.create(tester);
    SyncChoice? result;
    var closed = false;
    await open(tester, h, plan, (c) {
      result = c;
      closed = true;
    });
    expect(find.text('1 rimossa'), findsOneWidget);
    expect(find.text('1 preferito aggiunto'), findsOneWidget);
    expect(find.text('1 preferito tolto'), findsOneWidget);
    expect(find.text('In arrivo: 1 ascolto'), findsOneWidget);
    expect(find.text('Applica e togli 2 elementi'), findsOneWidget, reason: 'explicit about removals');
    expect(find.text('Applica'), findsNothing);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull, reason: 'cancelling applies nothing');
    await h.dispose(tester);
  });

  testWidgets('settings: none picked by default, only the ticked ones are returned', (tester) async {
    final h = await Harness.create(tester);
    SyncChoice? result;
    await open(tester, h, plan, (c) => result = c);
    expect(find.text('qui: dark, lì: light'), findsOneWidget);
    expect(find.text('qui: attivo, lì: disattivo'), findsOneWidget);
    expect(tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).any((c) => c.value == true), isFalse);
    await tester.ensureVisible(find.text('auto lyrics'));
    await tester.tap(find.text('auto lyrics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applica e togli 2 elementi'));
    await tester.pumpAndSettle();
    expect(result!.settings, {'autoLyrics'});
    await h.dispose(tester);
  });

  testWidgets('own device but only playlists arrive: a line explains it', (tester) async {
    final h = await Harness.create(tester);
    final only = planSync([], [_remote('u1', 'Road', 5, ['a'])], _resolve);
    await open(tester, h, only, (_) {});
    expect(find.textContaining('Arrivano solo le playlist'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    await open(tester, h, only, (_) {}, mine: false);
    expect(find.textContaining('Arrivano solo le playlist'), findsNothing);
    await h.dispose(tester);
  });
}
