import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/services/library/track_corrections.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:codecore/ui/screens/activity/activity_log_screen.dart';
import 'package:codecore/ui/screens/activity/proposals_screen.dart';
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
  final revertedAll = <int>[];
  var revertOk = true;
  final undone = <List<int>>[];
  var lastLog = <ActivityLogRow>[];

  /// Holds back the file part of `acceptAll` until completed.
  Completer<void>? filesGate;

  /// The next `acceptAll` accepts nothing.
  var emptyNext = false;

  @override
  Future<bool> apply(Track track, Recognition rec, {required bool byUser}) async {
    calls.add('apply ${track.id} $byUser');
    return true;
  }

  @override
  Future<void> discard(int trackId) async => calls.add('discard $trackId');

  @override
  Future<AcceptedAll> acceptAll({int logChunk = 500}) async {
    if (emptyNext) return AcceptedAll(const [], Future.value());
    final repo = CreditsRepository(db);
    final open = await repo.watchProposals().first;
    for (final p in open) {
      await _put(db, p.track.id, p.rec.copyWith(prop: 'accepted'));
    }
    lastLog = [
      for (final p in open)
        ActivityLogRow(id: p.track.id, at: 1, kind: 'correction', name: 'x', done: 0, total: 0, failed: 0),
    ];
    return AcceptedAll(lastLog, filesGate?.future ?? Future.value());
  }

  @override
  Future<bool> revert(ActivityLogRow row, {bool reopen = false}) async {
    reverted = row.id;
    revertedAll.add(row.id);
    return revertOk;
  }

  @override
  Future<RevertedAll> revertAll(AcceptedAll done) async {
    undone.add([for (final r in done.log) r.id]);
    revertedAll.addAll(undone.last);
    return RevertedAll(revertOk ? done.count : 0, done.files);
  }
}

Future<void> _put(AppDatabase db, int id, Recognition rec) => db
    .into(db.trackEnrich)
    .insertOnConflictUpdate(TrackEnrichCompanion(trackId: Value(id), details: Value(mergeDetails(null, rec: rec))));

Future<void> _edited(AppDatabase db, int id) =>
    (db.update(db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(userEdited: Value(true)));

Recognition _rec({String prop = 'open', bool cover = false, Map<String, String>? original, RecogSource? src}) => Recognition(
  at: 1,
  src: src,
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

  /// «Da confermare» with [n] open proposals.
  Future<(Harness, _Fix)> proposals(WidgetTester tester, {int n = 2, double textScale = 1, }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: n);
    final ts = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    for (final t in ts) {
      await tester.runAsync(() => _put(h.db, t.id, _rec(src: RecogSource.acoustid)));
    }
    final fix = _Fix(h.db);
    await h.pump(
      tester,
      const ProposalsScreen(),
      extraOverrides: [
        trackCorrectionsProvider.overrideWithValue(fix),
      ],
      textScale: textScale,
    );
    await _settle(tester);
    return (h, fix);
  }

  testWidgets('a proposal card shows old and new values, the source, and 48 dp buttons', (tester) async {
    final (h, _) = await proposals(tester, n: 1);
    expect(find.text('Song 0 – Artist'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Song 0 – Artist')).style?.decoration, TextDecoration.lineThrough);
    expect(find.text('Nuovo'), findsOneWidget);
    expect(find.text('Band'), findsOneWidget);
    expect(find.text('AcoustID'), findsOneWidget);
    expect(find.text('Accetta tutte (1)'), findsOneWidget);
    for (final label in ['Accetta', 'Scarta', 'Accetta tutte (1)']) {
      expect(tester.getSize(find.widgetWithText(FilledButton, label)).height, greaterThanOrEqualTo(48));
    }
    await h.dispose(tester);
  });

  testWidgets('«Accetta tutte» empties the list at once and says how many, with Annulla', (tester) async {
    final (h, _) = await proposals(tester);
    await tester.tap(find.text('Accetta tutte (2)'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('proposal-1')), findsNothing);
    expect(find.text('Tutto confermato'), findsOneWidget);
    expect(find.text('2 correzioni accettate. I file si aggiornano in sottofondo.'), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Annulla after «Accetta tutte» puts back every correction', (tester) async {
    final (h, fix) = await proposals(tester);
    await tester.tap(find.text('Accetta tutte (2)'));
    await _settle(tester);
    await tester.tap(find.text('Annulla'));
    await _settle(tester);
    expect(fix.revertedAll.toSet(), {1, 2});
    await h.dispose(tester);
  });

  testWidgets('Annulla puts every correction back in one call, without waiting for the files', (tester) async {
    final (h, fix) = await proposals(tester);
    fix.filesGate = Completer<void>();
    await tester.tap(find.text('Accetta tutte (2)'));
    await _settle(tester);
    await tester.tap(find.text('Annulla'));
    await _settle(tester); // the files are still being written
    expect(fix.lastLog, hasLength(2));
    expect(fix.undone, [fix.lastLog.map((r) => r.id).toList()]);
    fix.filesGate!.complete();
    expect(find.text('Impossibile ripristinare questa correzione'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('Annulla says so when a correction cannot be put back', (tester) async {
    final (h, fix) = await proposals(tester);
    await tester.tap(find.text('Accetta tutte (2)'));
    await _settle(tester);
    fix.revertOk = false;
    await tester.tap(find.text('Annulla'));
    await _settle(tester);
    expect(find.text('Impossibile ripristinare questa correzione'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a new «Accetta tutte» closes the Annulla of the previous one', (tester) async {
    final (h, fix) = await proposals(tester, n: 1);
    await tester.tap(find.text('Accetta tutte (1)'));
    await _settle(tester);
    expect(find.text('Annulla'), findsOneWidget);
    await tester.runAsync(() => _put(h.db, 1, _rec()));
    await _settle(tester);
    fix.emptyNext = true;
    await tester.tap(find.text('Accetta tutte (1)'));
    await _settle(tester);
    expect(find.text('Annulla'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the cards and the buttons do not overflow at text scale 2,0', (tester) async {
    final (h, _) = await proposals(tester, textScale: 2);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Vecchio – Chan'), findsOneWidget);
    expect(find.text('Nuovo – Band'), findsOneWidget);
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
