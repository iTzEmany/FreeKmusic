import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/services/library/track_corrections.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:codecore/ui/screens/activity/activity_log_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_cards.dart';
import 'package:codecore/ui/screens/now_playing/proposal_card.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Records the calls; `acceptAll` marks every open proposal as accepted, as the real one does.
class _Fix extends Fake implements TrackCorrections {
  _Fix(this.db);

  final AppDatabase db;
  final calls = <String>[];
  var reverted = 0;
  var revertOk = true;

  @override
  Future<bool> apply(Track track, Recognition rec, {required bool byUser}) async {
    calls.add('apply ${track.id} $byUser');
    return true;
  }

  @override
  Future<void> discard(int trackId) async => calls.add('discard $trackId');

  @override
  Future<int> acceptAll() async {
    final repo = CreditsRepository(db);
    final open = await repo.watchProposals().first;
    for (final p in open) {
      await _put(db, p.track.id, p.rec.copyWith(prop: 'accepted'));
    }
    return open.length;
  }

  @override
  Future<bool> revert(ActivityLogRow row) async {
    reverted = row.id;
    return revertOk;
  }
}

Future<void> _put(AppDatabase db, int id, Recognition rec) => db
    .into(db.trackEnrich)
    .insertOnConflictUpdate(TrackEnrichCompanion(trackId: Value(id), details: Value(mergeDetails(null, rec: rec))));

Future<void> _edited(AppDatabase db, int id) =>
    (db.update(db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(userEdited: Value(true)));

Recognition _rec({String prop = 'open', bool cover = false, Map<String, String>? original}) => Recognition(
  at: 1,
  sure: true,
  identity: const TrackIdentity(title: 'Nuovo', artist: 'Band'),
  prop: prop,
  cover: cover,
  original: original,
);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  Future<(Harness, Track, _Fix)> open(WidgetTester tester, Recognition? rec, Widget Function(Track) child) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    final t = (await tester.runAsync(() => h.db.select(h.db.tracks).getSingle()))!;
    if (rec != null) await tester.runAsync(() => _put(h.db, t.id, rec));
    final fix = _Fix(h.db);
    await h.pump(
      tester,
      Scaffold(body: SingleChildScrollView(child: child(t))),
      extraOverrides: [trackCorrectionsProvider.overrideWithValue(fix)],
    );
    await _settle(tester);
    return (h, t, fix);
  }

  testWidgets('an open proposal: Accetta applies it for the user, Scarta discards it', (tester) async {
    final (h, t, fix) = await open(tester, _rec(), (t) => ProposalCard(track: t));
    expect(find.text('Proposta: Nuovo – Band'), findsOneWidget);
    await tester.tap(find.text('Accetta'));
    await tester.tap(find.text('Scarta'));
    expect(fix.calls, ['apply ${t.id} true', 'discard ${t.id}']);
    await h.dispose(tester);
  });

  testWidgets('no proposal card for a track the user edited', (tester) async {
    final (h, t, _) = await open(tester, _rec(), (t) => const SizedBox());
    await tester.runAsync(() => _edited(h.db, t.id));
    final edited = (await tester.runAsync(() => h.db.select(h.db.tracks).getSingle()))!;
    await h.pump(tester, Scaffold(body: ProposalCard(track: edited)),
        extraOverrides: [trackCorrectionsProvider.overrideWithValue(_Fix(h.db))]);
    await _settle(tester);
    expect(find.text('Accetta'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('no proposal card when the decision is already taken', (tester) async {
    final (h, _, _) = await open(tester, _rec(prop: 'accepted'), (t) => ProposalCard(track: t));
    expect(find.text('Accetta'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('a cover shows «Cover di Titolo – Artista» from rec.original', (tester) async {
    final rec = _rec(prop: 'auto', cover: true, original: {'title': 'Origine', 'artist': 'Autore'});
    final (h, _, _) = await open(tester, rec, (t) => InfoCard(track: t));
    expect(find.text('Cover di Origine – Autore'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a cover without a known original shows just «Cover»', (tester) async {
    final (h, _, _) = await open(tester, _rec(prop: 'auto', cover: true), (t) => InfoCard(track: t));
    expect(find.text('Cover'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('«Da confermare (N)» opens the list and «Accetta tutte» empties it', (tester) async {
    final (h, _, _) = await open(tester, _rec(), (_) => const SizedBox());
    await tester.pumpWidget(const SizedBox());
    await h.pump(
      tester,
      const ActivityLogScreen(),
      extraOverrides: [trackCorrectionsProvider.overrideWithValue(_Fix(h.db))],
    );
    await _settle(tester);
    expect(find.text('Da confermare (1)'), findsOneWidget);
    await tester.tap(find.text('Da confermare (1)'));
    await _settle(tester);
    expect(find.textContaining('a Nuovo – Band'), findsOneWidget);
    await tester.tap(find.text('Accetta tutte'));
    await _settle(tester);
    expect(find.textContaining('a Nuovo – Band'), findsNothing);
    expect(find.text('Nessuna proposta da confermare'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a correction in the Registro reads «Corretto da vecchio a nuovo» and can be restored', (tester) async {
    final (h, _, _) = await open(tester, null, (_) => const SizedBox());
    final fix = _Fix(h.db)..revertOk = false;
    await tester.runAsync(
      () => h.db
          .into(h.db.activityLogRows)
          .insert(
            ActivityLogRowsCompanion.insert(
              at: DateTime.now().millisecondsSinceEpoch,
              kind: 'correction',
              name: 'Nuovo',
              detail: const Value(
                '{"trackId":1,"old":{"title":"Vecchio","artist":"Chan"},"new":{"title":"Nuovo","artist":"Band"}}',
              ),
            ),
          ),
    );
    await h.pump(tester, const ActivityLogScreen(), extraOverrides: [trackCorrectionsProvider.overrideWithValue(fix)]);
    await _settle(tester);
    expect(find.text('Corretto da Vecchio – Chan a Nuovo – Band'), findsOneWidget);
    await tester.tap(find.text('Ripristina'));
    await _settle(tester);
    expect(fix.reverted, isNonZero);
    expect(find.text('Impossibile ripristinare questa correzione'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('an online item (video id) of a cover shows «Cover di X – Y»; no id asks nothing', (tester) async {
    final h = await Harness.create(tester);
    final asked = <String>[];
    await h.pump(
      tester,
      const Scaffold(body: Column(children: [CoverLine(videoId: 'abcdefghijk'), CoverLine()])),
      extraOverrides: [
        onlineRecognitionProvider.overrideWith((ref, id) async {
          asked.add(id);
          return _rec(prop: 'auto', cover: true, original: {'title': 'Origine', 'artist': 'Autore'});
        }),
      ],
    );
    await _settle(tester);
    expect(find.text('Cover di Origine – Autore'), findsOneWidget);
    expect(asked, ['abcdefghijk']);
    await h.dispose(tester);
  });
}
