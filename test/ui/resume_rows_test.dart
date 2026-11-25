import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/radio_providers.dart';
import 'package:codecore/ui/screens/home/resume_rows.dart';
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Radio taps go to the controller: a spy keeps them off the audio engine.
class _RadioSpy implements PlayerController {
  final played = <(List<String>, int, PlayContext?)>[];
  @override
  Future<void> playStations(
    List<RadioStation> stations,
    int index, {
    PlayContext? context,
  }) async => played.add(([for (final s in stations) s.name], index, context));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  Future<Harness> openResume(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await tester.runAsync(
      () => (h.db.update(h.db.tracks)..where((t) => t.title.equals('Song 2')))
          .write(
            const TracksCompanion(
              resumePositionMs: Value(60000),
              lastPlayedAt: Value(1000),
            ),
          ),
    );
    await h.pump(
      tester,
      const SingleChildScrollView(child: ResumeList()),
      extraOverrides: extra,
    );
    await _settle(tester);
    return h;
  }

  testWidgets('a track left in the middle restarts from its own row', (
    tester,
  ) async {
    final h = await openResume(tester);
    final id = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!
        .firstWhere((t) => t.title == 'Song 2')
        .id;
    await tester.tap(find.byKey(const ValueKey('resume-track')));
    await _settle(tester);
    expect(h.handler.queueIds, [id]);
    expect(h.handler.currentIndex, 0);
    await h.dispose(tester);
  });

  testWidgets('the album tile opens that album', (tester) async {
    final h = await openResume(tester);
    await tester.tap(find.byKey(const ValueKey('resume-album')));
    await _settle(tester);
    expect(find.byType(AlbumDetailScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the radio tile plays that station from index 0', (tester) async {
    final spy = _RadioSpy();
    final h = await openResume(
      tester,
      extra: [
        playerControllerProvider.overrideWithValue(spy),
        savedRadiosProvider.overrideWith(
          (ref) => Stream.value([
            SavedRadio(
              stationId: 's',
              name: 'Radio X',
              streamUrl: 'u',
              homepage: '',
              faviconUrl: '',
              countryCode: '',
              state: '',
              tags: '',
              codec: '',
              bitrate: 0,
              hls: false,
              position: 0,
              addedAt: 1,
              lastPlayedAt: 5,
              unreachable: false,
            ),
          ]),
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('resume-radio')));
    await _settle(tester);
    expect(spy.played, hasLength(1));
    expect(spy.played.single.$1, ['Radio X']);
    expect(spy.played.single.$2, 0);
    expect(spy.played.single.$3?.kind, PlayContextKind.radio);
    await h.dispose(tester);
  });
}
