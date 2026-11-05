// Golden tests of the three screens of phase 82: Registro, Da confermare, Da
// revisionare. Linux only; the lines sit at fixed hours of today and yesterday.
//   flutter test --update-goldens test/goldens/activity_golden_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:codecore/core/clock.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/activity_log_repository.dart';
import 'package:codecore/data/repositories/credits_repository.dart' show mergeDetails;
import 'package:codecore/providers/second_opinion_providers.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:codecore/ui/screens/activity/activity_log_screen.dart';
import 'package:codecore/ui/screens/activity/proposals_screen.dart';
import 'package:codecore/ui/screens/library/review_screen.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/widgets/cover_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_shots/support/shot_harness.dart';
import 'tolerant_comparator.dart';

/// The day every shot lives on, so the goldens never change with the date.
final _today = DateTime(2026, 11, 5, 12, 40);

/// The second opinion never runs: no network in a golden.
class _NoJob extends SecondOpinionNotifier {
  @override
  Future<void> run(List<int> ids, {bool force = false}) async {}
}

/// Same colour for the same cover key, on every run.
Color _colourOf(String key) {
  var h = 0x811C9DC5;
  for (final c in key.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFF;
  }
  return Color(0xFF000000 | h | 0x303030);
}

Future<void> _putProposal(AppDatabase db, int id, String title, String artist, RecogSource src) =>
    db.into(db.trackEnrich).insertOnConflictUpdate(
          TrackEnrichCompanion(
            trackId: Value(id),
            details: Value(mergeDetails(
              null,
              rec: Recognition(
                at: 1,
                src: src,
                sure: true,
                identity: TrackIdentity(title: title, artist: artist),
                prop: 'open',
              ),
            )),
          ),
        );

Future<void> _seedProposals(Shot s) => s.tester.runAsync(() async {
      final ids = s.seed.trackIds;
      await _putProposal(s.h.db, ids[0], 'Nuvole Bianche', 'Ludovico Einaudi', RecogSource.acoustid);
      await _putProposal(s.h.db, ids[1], 'Get Lucky', 'Daft Punk', RecogSource.ytm);
      await _putProposal(s.h.db, ids[2], 'Volare', 'Domenico Modugno', RecogSource.tags);
    });

Future<void> _seedLog(Shot s) async {
  final n = _today;
  int at(int daysAgo, int h, int m) => DateTime(n.year, n.month, n.day - daysAgo, h, m).millisecondsSinceEpoch;
  final repo = ActivityLogRepository(s.h.db);
  await s.tester.runAsync(() async {
    await repo.add(at: at(0, 12, 40), kind: 'download', name: 'Volare', done: 1, total: 1);
    await repo.add(at: at(0, 12, 30), kind: 'download', name: 'Blue Monday', done: 1, total: 1);
    await repo.add(at: at(0, 12, 20), kind: 'download', name: 'Futura', done: 1, total: 1);
    await repo.add(
      at: at(0, 11, 50),
      kind: 'correction',
      name: 'Titolo e artista corretti',
      detail: jsonEncode({
        'trackId': s.seed.trackIds[3],
        'old': {'title': 'Track 03', 'artist': 'Sconosciuto'},
        'new': {'title': 'Nuvole Bianche', 'artist': 'Ludovico Einaudi'},
      }),
    );
    await repo.add(
      at: at(0, 9, 15),
      kind: 'import',
      name: 'Spotify',
      failed: true,
      detail: jsonEncode({'event': 'toolMissing'}),
    );
    await repo.add(at: at(1, 21, 5), kind: 'scan', name: '', done: 340, total: 340);
    await repo.add(at: at(1, 18, 30), kind: 'download', name: 'Get Lucky', done: 1, total: 1);
  });
}

/// Tracks of «Da revisionare» with different reasons.
Future<void> _seedReview(Shot s) => s.tester.runAsync(() async {
      final ids = s.seed.trackIds;
      Future<void> set(int id, String sql) => s.h.db.customUpdate('UPDATE tracks SET $sql WHERE id = $id');
      await set(ids[0], 'enrich_status = 2');
      await set(ids[1], "enrich_status = 1, lyrics_plain = NULL, lyrics_synced = NULL, has_cover = 1, year = 2000, genre = 'Rock'");
      await set(ids[2], "enrich_status = 1, lyrics_plain = 'x', has_cover = 0, year = 2000, genre = 'Rock'");
      await set(ids[3], 'enrich_status = 2, has_cover = 0, lyrics_plain = NULL, lyrics_synced = NULL');
      await set(ids[4], "enrich_status = 1, lyrics_plain = 'x', has_cover = 1, year = NULL, genre = NULL");
    });

void main() {
  if (!Platform.isLinux) return;

  setUpAll(() {
    nowMsOverride = () => _today.millisecondsSinceEpoch;
    TolerantComparator.install();
    coverImageStub = (key) => ColoredBox(color: _colourOf(key));
  });
  tearDownAll(() {
    coverImageStub = null;
    nowMsOverride = null;
  });

  for (final size in ShotSize.values) {
    for (final scale in const [1.0, 1.5]) {
      final tag = '${size.name}_${(scale * 100).round()}';
      group(tag, () {
        for (final light in [
          false,
          if (size == ShotSize.phone && scale == 1.0) true,
        ]) {
          final t = light ? '${tag}_light' : tag;
          final theme = light ? AppThemeId.chiaro : AppThemeId.notte;
          final accent = light ? CcAccent.blu : CcAccent.viola;

          testWidgets('${light ? 'light_' : ''}activity_log', (tester) => withGoldenShot(tester, size, (s) async {
                await _seedLog(s);
                await _seedProposals(s);
                await s.show(const ActivityLogScreen(), textScale: scale, theme: theme, accent: accent);
                await s.expectGolden('${t}_activity_log.png');
              }));

          testWidgets('${light ? 'light_' : ''}proposals', (tester) => withGoldenShot(tester, size, (s) async {
                await _seedProposals(s);
                await s.show(const ProposalsScreen(), textScale: scale, theme: theme, accent: accent);
                await s.expectGolden('${t}_proposals.png');
              }));

          testWidgets('${light ? 'light_' : ''}review', (tester) => withGoldenShot(tester, size, (s) async {
                await _seedReview(s);
                await s.show(const ReviewScreen(), textScale: scale, theme: theme, accent: accent, extra: [
                  secondOpinionJobProvider.overrideWith(_NoJob.new),
                ]);
                await s.expectGolden('${t}_review.png');
              }));
        }
      });
    }
  }
}
