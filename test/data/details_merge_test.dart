import 'dart:convert';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/services/online/credits.dart';
import 'package:codecore/services/online/credits_enricher.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../support/enrich_fakes.dart';

const _rec = Recognition(
  at: 7,
  src: RecogSource.acoustid,
  score: 0.97,
  sure: true,
  identity: TrackIdentity(title: 'Believer', artist: 'Imagine Dragons', ms: 204000, mbid: 'm'),
);
const _bpm = TrackDetails(bpm: 120, label: 'L');

void main() {
  late EnrichRig r;
  late int id;
  setUp(() async {
    r = EnrichRig();
    id = await r.add();
  });
  tearDown(() => r.dispose());

  Future<String?> raw() async => (await r.enrichOf(id))?.details;
  Future<void> put(String? details) =>
      r.credits.saveEnrich(TrackEnrichCompanion(trackId: Value(id), details: Value(details)));

  test('rec is saved and read back; the details beside it are kept both ways', () {
    final a = mergeDetails(mergeDetails(null, details: _bpm), rec: _rec);
    final b = mergeDetails(mergeDetails(null, rec: _rec), details: _bpm);
    for (final s in [a, b, mergeDetails(a, details: const TrackDetails(bpm: 90))]) {
      expect(jsonEncode(decodeRec(s)!.toJson()), jsonEncode(_rec.toJson()));
    }
    expect([for (final s in [a, b]) decodeDetails(1, s)?.bpm], [120, 120]);
    expect(decodeDetails(1, mergeDetails(a, details: const TrackDetails(bpm: 90)))?.bpm, 90);
  });

  test('rows from before rec read as they did; a row with only rec has no details', () {
    final old = jsonEncode(_bpm.toJson());
    expect([decodeDetails(1, old)?.label, decodeRec(old)], ['L', null]);
    expect(decodeRec(null), isNull);
    expect(decodeDetails(1, mergeDetails(null, rec: _rec)), isNull);
  });

  test('CreditsEnricher.save after rec does not erase it', () async {
    await put(mergeDetails(null, rec: _rec));
    await r.engine.credits!.save(id, const CreditsPart(details: _bpm));
    expect(decodeRec(await raw())!.src, RecogSource.acoustid);
    expect(decodeDetails(id, await raw())?.bpm, 120);
  });

  test('CreditsEnricher.save without a base reads and writes in one transaction', () async {
    final save = r.engine.credits!.save(id, const CreditsPart(details: _bpm), trackKnown: true);
    // Queued behind save's first read: without one transaction it would be overwritten.
    final recWrite = r.credits.atomic(() async => put(mergeDetails(await raw(), rec: _rec)));
    await Future.wait([save, recWrite]);
    expect([decodeRec(await raw())?.at, decodeDetails(id, await raw())?.bpm], [7, 120]);
  });

  group('saveIfNone', () {
    test('a row with only rec still takes the details, and keeps rec', () async {
      await put(mergeDetails(null, rec: _rec));
      await r.credits.saveIfNone(id, const [], _bpm);
      expect([decodeDetails(id, await raw())?.bpm, decodeRec(await raw())?.at], [120, 7]);
    });

    test('a row with details keeps them, and rec', () async {
      await put(mergeDetails(mergeDetails(null, details: _bpm), rec: _rec));
      await r.credits.saveIfNone(id, const [], const TrackDetails(bpm: 90));
      expect([decodeDetails(id, await raw())?.bpm, decodeRec(await raw())?.at], [120, 7]);
    });
  });

  test('merging duplicates keeps the details of one and the rec of the other', () async {
    final drop = await r.add(path: '/b.mp3');
    await r.credits.saveEnrich(TrackEnrichCompanion(
        trackId: Value(drop), details: Value(mergeDetails(null, details: _bpm))));
    await put(mergeDetails(null, rec: _rec));
    await r.db.transaction(() => r.credits.moveInto(id, {drop}));
    expect([decodeDetails(id, await raw())?.bpm, decodeRec(await raw())?.at], [120, 7]);
  });
}
