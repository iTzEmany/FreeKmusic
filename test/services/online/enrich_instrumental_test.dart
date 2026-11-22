import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:codecore/services/recognition/track_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart' show CancelToken;

import '../../support/enrich_fakes.dart';

class _Sure implements TrackRecognizer {
  @override
  Future<RecogOutcome> recognize(Track t, {required TextProbe? textProbe, CancelToken? cancel}) async => RecogOutcome(
    rec: Recognition(
      at: 1,
      src: RecogSource.tags,
      sure: true,
      identity: const TrackIdentity(title: 'Other', artist: 'Someone'),
    ),
    asked: true,
  );

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

void main() {
  late EnrichRig r;
  tearDown(() => r.dispose());

  test('LRCLIB says instrumental: the flag is saved by the commit', () async {
    r = EnrichRig();
    r.chain.instrumental = true;
    final id = await r.add();
    await r.engine.completeOne(id, {EnrichPart.lyrics});
    expect(await r.repo.isInstrumental(id), isTrue);
  });

  test('force asks the lyrics of a flagged track; the automatic round does not', () async {
    r = EnrichRig();
    final id = await r.add();
    await r.repo.setInstrumental(id, true);
    await r.engine.completeOne(id, {EnrichPart.lyrics});
    expect(r.chain.calls, 0);
    await r.engine.completeOne(id, {EnrichPart.lyrics}, force: true);
    expect(r.chain.calls, 1);
  });

  test('a sure recognition renames a library row but not a stream row (D-683)', () async {
    final seen = <int>[];
    r = EnrichRig(recognizer: _Sure(), onSure: (t, _) async => seen.add(t.kind));
    final lib = await r.add();
    final stream = await r.add(path: 'online:youtube:x', kind: 2);
    await r.engine.completeOne(lib, {EnrichPart.meta});
    await r.engine.completeOne(stream, {EnrichPart.meta});
    expect(seen, [0]);
  });

  group('SQL and isDue agree on the title', () {
    const titles = {
      'Song (Instrumental)': true,
      'Song [Instrumental]': true,
      'Song (Instrumental Mix)': false,
      'Song - Instrumental': true,
      'Song – Instrumental': true,
      'Song -Instrumental': true,
      'Song Instrumental Version': true,
      'Instrumentality': false,
      'Instrumentalist': false,
      'Song - Instrumentalist': false,
      'Song': false,
    };

    test('same answer for every title, and the flag in the DB excludes', () async {
      r = EnrichRig();
      final ids = <String, int>{};
      for (final t in titles.keys) {
        ids[t] = await r.add(title: t, path: '/$t.mp3');
      }
      final due = await r.credits.dueTrackIds({EnrichPart.lyrics}, DateTime(2026), limit: 99);
      for (final e in titles.entries) {
        final track = (await r.repo.getById(ids[e.key]!))!;
        expect(isDue(EnrichPart.lyrics, track, null, DateTime(2026)), !e.value, reason: e.key);
        expect(due.contains(ids[e.key]), !e.value, reason: e.key);
      }
      await r.repo.setInstrumental(ids['Song']!, true);
      final after = await r.credits.dueTrackIds({EnrichPart.lyrics}, DateTime(2026), limit: 99);
      expect(after.contains(ids['Song']), isFalse);
    });
  });
}
