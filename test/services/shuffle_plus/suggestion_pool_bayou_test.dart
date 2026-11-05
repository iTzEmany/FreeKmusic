import 'dart:io';

import 'package:codecore/core/import_row.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SuggestionCandidate?> suggest(int ms) async {
  final log = SuggestionLog(
    file: () async => File('/nonexistent/none.json'),
    now: () => DateTime.utc(2026, 1, 1),
    writeDelay: const Duration(days: 1),
  );
  await log.load();
  final library = LibraryIndex(const [
    LibraryEntryLite(id: 1, title: 'Born On The Bayou', artist: 'Creedence Clearwater Revival', durationMs: 315222),
  ]);
  final pool = SuggestionPool()
    ..addPage('s', 'Seed', RadioPage([
      RadioItem(
        YtResult(
            id: 'bayou',
            title: 'Born On The Bayou',
            channel: 'Creedence Clearwater Revival',
            duration: Duration(milliseconds: ms),
            artists: const ['Creedence Clearwater Revival'],
            album: 'Bayou Country'),
        RadioKind.song,
      ),
    ]));
  return pool.take(
    inLibrary: inLibraryTest(hasDownload: (_) => false, library: library),
    inQueue: (_) => false,
    log: log,
  );
}

void main() {
  test('a suggestion of a library song with a different length is not excluded today', () async {
    // flips in phase 88.1 (D-389)
    expect((await suggest(231000))?.result.id, 'bayou');
  });

  test('the 5 s edge: 5000 ms apart is excluded, 5001 ms is offered', () async {
    expect(await suggest(315222 + 5000), isNull);
    expect((await suggest(315222 + 5001))?.result.id, 'bayou');
  });

  test('control: the same suggestion within 5 s of the library length is excluded', () async {
    expect(await suggest(315222 + 4000), isNull);
  });
}
