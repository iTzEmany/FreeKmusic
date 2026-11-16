import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/providers/free_space_providers.dart';
import 'package:codecore/services/library/free_space.dart';
import 'package:codecore/ui/screens/memory/free_space_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _Service implements FreeSpaceService {
  _Service(this.items);
  final List<FreeSpaceCandidate> items;
  final asked = <List<int>>[];
  FreeSpaceReport report = const FreeSpaceReport(freedIds: [], failedIds: [], freedBytes: 0);

  @override
  Future<List<FreeSpaceCandidate>> freeSpaceCandidates() async => items;

  @override
  Future<FreeSpaceReport> freeSpace(Iterable<int> ids) async {
    asked.add(ids.toList()..sort());
    return report;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Future<FreeSpaceCandidate> _cand(Harness h, WidgetTester tester, int i, {required bool stale, required int size}) async {
  final all = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
  final t = all[i];
  return FreeSpaceCandidate(_withSize(t, size), 'youtube:k$i', stale);
}

Track _withSize(Track t, int size) => t.copyWith(sizeBytes: size);

void main() {
  testWidgets('list, preselection, size sum; confirming frees the ids and says the result', (tester) async {
    final h = await Harness.create(tester, tracks: 3);
    final svc = _Service([
      await _cand(h, tester, 0, stale: true, size: 10 * 1024 * 1024),
      await _cand(h, tester, 1, stale: true, size: 5 * 1024 * 1024),
      await _cand(h, tester, 2, stale: false, size: 2 * 1024 * 1024),
    ]);
    svc.report = FreeSpaceReport(freedIds: [1, 2], failedIds: [3], freedBytes: 15 * 1024 * 1024);
    await h.pump(tester, const FreeSpaceScreen(), extraOverrides: [freeSpaceServiceProvider.overrideWith((ref) async => svc)]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Non ascoltati da 90 giorni'), findsOneWidget);
    expect(find.text('Song 0'), findsOneWidget);
    expect(find.text('Song 2'), findsOneWidget);
    expect(find.text('Libera 15,0 MB'), findsOneWidget, reason: 'the two stale ones are preselected');

    await tester.tap(find.text('Song 2'));
    await tester.pump();
    expect(find.text('Libera 17,0 MB'), findsOneWidget);

    await tester.tap(find.text('Libera 17,0 MB'));
    await tester.pumpAndSettle();
    expect(svc.asked, isEmpty, reason: 'nothing happens before the confirmation');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Libera spazio')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final ids = [for (final c in svc.items) c.track.id]..sort();
    expect(svc.asked.single, ids);
    expect(find.textContaining('2 brani liberati'), findsOneWidget);
    expect(find.textContaining('1 brano non è stato liberato'), findsOneWidget);
    await h.dispose(tester);
  });
}
