import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/l10n/app_localizations_it.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/providers/share_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  final l = AppLocalizationsIt();

  test('buildShareEntriesCounted counts the dropped tracks by reason', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final tmp = await Directory.systemTemp.createTemp('outcome');
    addTearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      coversDirProvider.overrideWithValue(tmp),
    ]);
    addTearDown(c.dispose);
    Future<int> add(String path, {int kind = kMusicKind, bool saved = true, bool missing = false}) =>
        db.into(db.tracks).insert(TracksCompanion.insert(
              path: path, title: path, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
              kind: Value(kind), saved: Value(saved), missing: Value(missing)));
    final ids = [
      await add('/m/ok.mp3'),
      await add('/m/gone.mp3', missing: true),
      await add('stream:youtube:abcdefghijk', kind: kStreamKind),
      await add('stream:soundcloud:123', kind: kStreamKind),
      await add('stream:youtube:shadowshado', kind: kStreamKind, saved: false),
    ];
    final rows = await (db.select(db.tracks)..where((t) => t.id.isIn(ids))).get();
    rows.sort((a, b) => a.id.compareTo(b.id));
    final r = await buildShareEntriesCounted(c.read(_refProvider), rows);
    expect(r.entries.map((e) => e.id), [ids[0], ids[2]]);
    expect((r.missing, r.unsupported, r.shadow), (1, 1, 1));
  });

  group('SendOutcome.message', () {
    test('all sent: «Richiesta inviata» as today', () {
      const o = SendOutcome(SendStatus.sent, total: 3, sent: 3);
      expect(o.complete, isTrue);
      expect(o.message(l, 'Pc'), l.offerSent('Pc'));
    });
    test('some dropped: N of M and the most frequent reason', () {
      const o = SendOutcome(SendStatus.sent, total: 5, sent: 2, shadow: 3);
      expect(o.complete, isFalse);
      expect(o.message(l, 'Pc'), 'Inviati 2 brani su 5 a Pc: 3 non disponibili su questo dispositivo');
      const x = SendOutcome(SendStatus.sent, total: 5, sent: 2, missing: 1, shadow: 2);
      expect(x.message(l, 'Pc'), 'Inviati 2 brani su 5 a Pc: 3 non si possono inviare');
      const one = SendOutcome(SendStatus.sent, total: 3, sent: 1, missing: 2);
      expect(one.message(l, 'Pc'), 'Inviato 1 brano su 3 a Pc: 2 file mancanti');
    });
    test('nothing to send', () {
      const o = SendOutcome(SendStatus.nothingToSend, total: 2, shadow: 2);
      expect(o.message(l, 'Pc'), 'Nessuno di questi brani si può inviare');
    });
    test('unreachable: as today', () {
      expect(const SendOutcome.unreachable(2).message(l, 'Pc'), l.shareErrUnreachable);
    });
  });
}
