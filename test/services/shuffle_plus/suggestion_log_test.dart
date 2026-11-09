import 'dart:io';

import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late DateTime now;

  final opened = <SuggestionLog>[];

  SuggestionLog open({int max = 500}) {
    final l = SuggestionLog(
      file: () async => File(p.join(dir.path, 'suggestions.json')),
      max: max,
      now: () => now,
      writeDelay: Duration.zero,
    );
    opened.add(l);
    return l;
  }

  void add(SuggestionLog log, String id) =>
      log.add(videoId: id, title: 'T$id', artist: 'A', seedTitle: 'S');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sug_log');
    addTearDown(() => dir.deleteSync(recursive: true));
    // Runs first: a write still running keeps the file open (Windows).
    addTearDown(() async {
      for (final l in opened) {
        await l.dispose();
      }
      opened.clear();
    });
    now = DateTime.utc(2026, 1, 1);
  });

  test(
    'a song suggested 10 days ago is recent, 40 days ago it is not',
    () async {
      final log = open();
      await log.load();
      add(log, 'a');
      now = now.add(const Duration(days: 10));
      expect(log.recentlySuggested('a'), isTrue);
      expect(log.recentlySuggested('b'), isFalse);
      now = now.add(const Duration(days: 30));
      expect(log.recentlySuggested('a'), isFalse);
    },
  );

  test('outcomes and dislikes are kept, and read back from the file', () async {
    final log = open();
    await log.load();
    add(log, 'a');
    add(log, 'b');
    log.setOutcome('a', SuggestionOutcome.heard);
    log.setOutcome('b', SuggestionOutcome.disliked);
    await log.flush();

    final again = open();
    await again.load();
    expect(again.recent.map((r) => (r.videoId, r.outcome)), [
      ('b', SuggestionOutcome.disliked),
      ('a', SuggestionOutcome.heard),
    ]);
    expect(again.latest('b')?.outcome == SuggestionOutcome.disliked, isTrue);
    expect(again.latest('a')?.outcome == SuggestionOutcome.disliked, isFalse);
    expect(again.recent.first.seedTitle, 'S');
  });

  test('only the last 500 are kept, a dislike outlives the others', () async {
    final log = open(max: 5);
    await log.load();
    for (var i = 0; i < 4; i++) {
      add(log, 'x$i');
    }
    log.setOutcome('x0', SuggestionOutcome.disliked);
    for (var i = 4; i < 9; i++) {
      add(log, 'x$i');
    }
    expect(log.length, 5);
    expect(log.latest('x0')?.outcome == SuggestionOutcome.disliked, isTrue);
    expect(log.recent.map((r) => r.videoId), ['x8', 'x7', 'x6', 'x5', 'x0']);
  });

  test(
    'clear empties the history and the file but keeps «Non mi piace»',
    () async {
      final log = open();
      await log.load();
      add(log, 'a');
      add(log, 'b');
      log.setOutcome('b', SuggestionOutcome.disliked);
      await log.clear();
      final again = open();
      await again.load();
      expect(again.recent.map((r) => r.videoId), ['b']);
      expect(again.latest('b')?.outcome == SuggestionOutcome.disliked, isTrue);
    },
  );
}
