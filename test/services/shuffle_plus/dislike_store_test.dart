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

  DislikeStore store() =>
      DislikeStore(file: () async => f, writeDelay: Duration.zero);
  DislikedTrack track(String id) =>
      DislikedTrack(videoId: id, title: 't$id', artist: 'a');

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
    expect(
      again.trackBlocked('d'),
      isFalse,
      reason: 'already migrated: an unblock sticks',
    );

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

  test('an artist with an empty key is never blocked', () async {
    final s = store();
    await s.load();
    s.blockArtist(const DislikedArtist(key: '', name: '!!!'));
    expect(s.artists, isEmpty);
    expect(s.artistBlocked(''), isFalse);
    s.mergeJson({
      'artists': [const DislikedArtist(key: '', name: '!').toJson()],
    });
    expect(s.artists, isEmpty);
  });

  test(
    'a valid JSON of the wrong shape is kept as .bad like an unreadable file',
    () async {
      f.writeAsStringSync('[1,2,3]');
      final s = store();
      await s.load();
      s.blockTrack(track('1'));
      await s.flush();
      expect(File('${f.path}.bad').readAsStringSync(), '[1,2,3]');
      expect(f.readAsStringSync(), contains('"1"'));
    },
  );

  test(
    'entries that cannot be read leave a .bad copy before the rewrite',
    () async {
      f.writeAsStringSync(
        '{"tracks":[{"id":"ok","title":"t","artist":"a"},{"nope":1}],"artists":[]}',
      );
      final s = store();
      await s.load();
      expect(s.trackBlocked('ok'), isTrue);
      s.blockTrack(track('2'));
      await s.flush();
      expect(File('${f.path}.bad').readAsStringSync(), contains('"nope"'));
    },
  );

  test(
    'a block made while the file is read is kept, without duplicates',
    () async {
      final first = store();
      await first.load();
      first.blockTrack(track('a'));
      first.blockArtist(const DislikedArtist(key: 'k', name: 'K'));
      await first.flush();

      final s = store();
      final loading = s.load();
      s.blockTrack(track('a'));
      s.blockTrack(track('b'));
      s.blockArtist(const DislikedArtist(key: 'k', name: 'K'));
      await loading;
      expect([
        for (final t in s.tracks) t.videoId,
      ], unorderedEquals(['a', 'b']));
      expect(s.artists, hasLength(1));
    },
  );

  test(
    'mergeJson is saved: a new store from the file sees the block',
    () async {
      final s = store();
      await s.load();
      s.mergeJson({
        'tracks': [track('m').toJson()],
      });
      await s.flush();
      final again = store();
      await again.load();
      expect(again.trackBlocked('m'), isTrue);
    },
  );

  test('a short writeDelay writes by itself, without flush', () async {
    final s = DislikeStore(
      file: () async => f,
      writeDelay: const Duration(milliseconds: 10),
    );
    await s.load();
    s.blockTrack(track('auto'));
    for (
      var i = 0;
      i < 100 && !(f.existsSync() && f.readAsStringSync().contains('auto'));
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(f.readAsStringSync(), contains('auto'));
  });

  test('a flush before load does not empty the file', () async {
    final first = store();
    await first.load();
    first.blockTrack(track('keep'));
    await first.flush();
    final s = store();
    await s.flush();
    expect(f.readAsStringSync(), contains('keep'));
  });

  test('two flushes close together leave the last state', () async {
    final s = store();
    await s.load();
    s.blockTrack(track('1'));
    final a = s.flush();
    s.blockTrack(track('2'));
    final b = s.flush();
    await Future.wait([a, b]);
    final again = store();
    await again.load();
    expect(again.trackBlocked('1'), isTrue);
    expect(again.trackBlocked('2'), isTrue);
  });

  test(
    'a merge or migration of an id already blocked does not duplicate it',
    () async {
      final logFile = File(p.join(dir.path, 'suggestions.json'));
      final log = SuggestionLog(file: () async => logFile);
      log.add(videoId: 'd', title: 'T', artist: 'A', seedTitle: 's');
      log.setOutcome('d', SuggestionOutcome.disliked);
      final s = store();
      s.blockTrack(track('d'));
      await s.migrateFrom(log);
      s.mergeJson({
        'tracks': [track('d').toJson()],
      });
      expect(s.tracks, hasLength(1));
    },
  );
}
