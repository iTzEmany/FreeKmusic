import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:codecore/services/online/enrich_runner.dart';
import 'package:codecore/services/online/enrichment_service.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';

void main() {
  late EnrichRig r;

  setUp(() => r = EnrichRig());
  tearDown(() => r.dispose());

  Future<Track> row(int id) async => (await r.repo.getById(id))!;

  test('a track with nothing left to ask is not asked again', () async {
    final id = await r.add();
    await r.runManual([id], parts: manualParts(AppSettings()));
    r.web.urls.clear();
    final round = await r.runManual([id], parts: manualParts(AppSettings()));
    expect(round.updatedTracks, 0);
    expect(r.web.count('itunes'), 0);
  });

  test('a track missing something is asked', () async {
    final id = await r.add();
    final round = await r.runManual([id], parts: manualParts(AppSettings()));
    expect(round.updatedTracks, 1);
    expect((await row(id)).lyricsPlain, isNotNull);
  });

  test('the manual parts ask the curiosities', () async {
    final id = await r.add();
    await r.runManual([id], parts: manualParts(AppSettings()));
    expect((await row(id)).curiosities, isNotNull);
  });

  test('credits are asked by a manual job only with «Crediti e dettagli»', () async {
    await r.runManual([await r.add(path: '/a.mp3')], parts: manualParts(AppSettings()));
    expect(r.web.count('musicbrainz'), 0);
    await r.runManual([await r.add(path: '/b.mp3')], parts: manualParts(AppSettings(creditsDetails: true)));
    expect(r.web.count('musicbrainz'), greaterThan(0));
  });

  test('every part refused before the list is used up: the round says so', () async {
    r.web.itunes = ItunesMode.limited;
    r.chain.limited = true;
    final ids = [for (var i = 0; i < 4; i++) await r.add(path: '/$i.mp3')];
    final round = await r.runManual(ids, parts: {EnrichPart.meta, EnrichPart.lyrics});
    expect([round.allRefused, round.processed], [true, 1]);
  });

  test('every part refused by the last track: the list is used up, the round is not stopped', () async {
    r.web.itunes = ItunesMode.limited;
    r.chain.limited = true;
    final round = await r.runManual([await r.add()], parts: {EnrichPart.meta, EnrichPart.lyrics});
    expect([round.allRefused, round.processed], [false, 1]);
  });

  test('a track refused by its only source is alive: neither silent nor failed', () async {
    r.web.itunes = ItunesMode.limited;
    r.chain.limited = true;
    final round = await r.runManual([await r.add()], parts: {EnrichPart.meta, EnrichPart.lyrics});
    expect([round.limited, round.endedSilent, round.failed, round.worked], [true, false, false, 0]);
  });

  test('a single offline track ends silent', () async {
    r.chain.failed = true;
    final round = await r.runManual([await r.add()], parts: {EnrichPart.lyrics});
    expect([round.endedSilent, round.failed, round.worked], [true, false, 0]);
  });

  test('an answer resets the count of silent tracks', () async {
    r.chain.during = () async => r.chain.failed = r.chain.calls != 5; // only the fifth answers
    final ids = [for (var i = 0; i < 9; i++) await r.add(path: '/$i.mp3')];
    final round = await r.runManual(ids, parts: {EnrichPart.lyrics});
    expect([round.noAnswer, round.processed, round.worked], [false, 9, 1]);
  });

  test('«in attesa» is shown while the run waits for the user, then hidden', () async {
    final gate = Completer<void>();
    final calls = <bool>[];
    final run = EnrichRunner(
      engine: r.engine,
      ids: FixedIds([await r.add()]),
      parts: () => {EnrichPart.lyrics},
      waitIdle: () => gate.future,
      onWaiting: calls.add,
    ).run();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calls, [true]);
    gate.complete();
    await run;
    expect(calls, [true, false]);
  });

  test('a waitIdle that throws still hides «in attesa»', () async {
    final calls = <bool>[];
    final gate = Completer<void>();
    final run = EnrichRunner(
      engine: r.engine,
      ids: FixedIds([await r.add()]),
      parts: () => {EnrichPart.lyrics},
      waitIdle: () => gate.future,
      onWaiting: calls.add,
    ).run();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    gate.completeError(StateError('idle broke'));
    final round = await run;
    expect([calls, round.failed], [[true, false], true]);
  });

  test('a cancelled job leaves the track it did not reach as it was', () async {
    final ids = [for (var i = 0; i < 12; i++) await r.add(path: '/$i.mp3')];
    late final EnrichRunner run;
    run = EnrichRunner(
      engine: r.engine,
      ids: FixedIds(ids),
      parts: () => {EnrichPart.meta},
      waitIdle: () async {},
      mode: AskMode.retryNone,
      onProgress: (d, t) => run.cancel(),
    );
    await run.run();
    final last = await row(ids.last);
    expect(last.enrichStatus, 0);
  });
}
