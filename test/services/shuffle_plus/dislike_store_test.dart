import 'dart:io';

import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late File f;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('dl');
    f = File(p.join(dir.path, 'dislikes.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  DislikeStore store() => DislikeStore(file: () async => f, writeDelay: Duration.zero);
  DislikedTrack track(String id) => DislikedTrack(videoId: id, title: 't$id', artist: 'a');

  test('block and unblock, newest first, and they survive a reload', () async {
    final s = store();
    await s.load();
    s.blockTrack(track('1'));
    s.blockTrack(track('2'));
    s.blockTrack(track('2'));
    s.blockArtist(const DislikedArtist(key: 'queen', name: 'Queen'));
    expect([for (final t in s.tracks) t.videoId], ['2', '1']);
    s.unblockTrack('1');
    await s.flush();

    final again = store();
    await again.load();
    expect(again.trackBlocked('2'), isTrue);
    expect(again.trackBlocked('1'), isFalse);
    expect(again.artistBlocked('queen'), isTrue);
    again.unblockArtist('queen');
    expect(again.artists, isEmpty);
  });

  test('nothing is trimmed, however many are blocked', () async {
    final s = store();
    await s.load();
    for (var i = 0; i < 1500; i++) {
      s.blockTrack(track('$i'));
    }
    await s.flush();
    final again = store();
    await again.load();
    expect(again.tracks, hasLength(1500));
  });

  test('the old disliked records become blocked songs, once', () async {
    final logFile = File(p.join(dir.path, 'suggestions.json'));
    final log = SuggestionLog(file: () async => logFile);
    log.add(videoId: 'd', title: 'T', artist: 'A', seedTitle: 's');
    log.add(videoId: 'ok', title: 'T', artist: 'A', seedTitle: 's');
    log.setOutcome('d', SuggestionOutcome.disliked);

    final s = store();
    await s.migrateFrom(log);
    expect([for (final t in s.tracks) t.videoId], ['d']);
    s.unblockTrack('d');
    await s.flush();

    final again = store();
    await again.migrateFrom(log);
    expect(again.trackBlocked('d'), isFalse, reason: 'already migrated: an unblock sticks');

    again.blockTrack(track('keep'));
    await again.flush();
    await log.clear();
    final third = store();
    await third.load();
    expect(
      third.trackBlocked('keep'),
      isTrue,
      reason: 'clearing the log does not touch the store',
    );
  });

  test('a corrupt file starts empty and is kept as .bad', () async {
    f.writeAsStringSync('{nope');
    final s = store();
    await s.load();
    expect(s.tracks, isEmpty);
    s.blockTrack(track('1'));
    await s.flush();
    expect(File('${f.path}.bad').readAsStringSync(), '{nope');
    expect(f.readAsStringSync(), contains('"1"'));
  });

  test('a write before load ends does not wipe the file', () async {
    final first = store();
    await first.load();
    first.blockTrack(track('old'));
    await first.flush();

    final s = store();
    final loading = s.load();
    s.blockTrack(track('new'));
    await s.flush();
    await loading;
    final again = store();
    await again.load();
    expect(again.trackBlocked('old'), isTrue);
  });

  test('mergeJson adds blocks and keeps the current ones', () async {
    final s = store();
    await s.load();
    s.blockTrack(track('a'));
    s.mergeJson({
      'tracks': [track('a').toJson(), track('b').toJson()],
      'artists': [const DislikedArtist(key: 'k', name: 'K').toJson()],
    });
    expect(s.tracks, hasLength(2));
    expect(s.artistBlocked('k'), isTrue);
  });
}
