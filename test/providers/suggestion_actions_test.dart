import 'dart:io';

import 'package:codecore/providers/pending_playlist_adds.dart';
import 'package:codecore/providers/suggestion_actions.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _song = YtResult(id: 'v1', title: 'Streamed', channel: 'Chan', duration: null);

void main() {
  late Directory dir;
  late OnlineEntries online;
  late SuggestionLog log;
  late DislikeStore store;
  late List<int> queue; // the play order, ids
  late int? current;
  var played = -1;
  late int id;
  late List<(String, String?)> downloads;
  var instant = false; // what the download callback reports
  late List<int> removed;
  late SuggestionActions actions;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('actions');
    online = OnlineEntries();
    id = online.register(_song, seedTitle: 'Seed');
    log = SuggestionLog(
      file: () async => File(p.join(dir.path, 'suggestions.json')),
      writeDelay: const Duration(days: 1),
    );
    await log.load();
    log.add(
      videoId: 'v1',
      title: 'Streamed',
      artist: 'Chan',
      seedTitle: 'Seed',
    );
    store = DislikeStore(
      file: () async => File(p.join(dir.path, 'dislikes.json')),
    );
    queue = [id];
    current = null;
    played = -1;
    downloads = [];
    instant = false;
    removed = [];
    actions = SuggestionActions(
      online: online,
      log: log,
      download: (r, {tag}) async {
        downloads.add((r.id, tag));
        return instant;
      },
      store: store,
      removeQueueId: (i) async {
        removed.add(i);
        queue.remove(i);
      },
      queueIds: () => List.of(queue),
      currentQueueId: () => current,
      insertAt: (i, v) => queue.insert(i, v),
      playIndex: (i) async => played = i,
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('download queues the song and marks it downloaded', () async {
    expect(await actions.downloadEntry(id), isFalse);
    expect(downloads, [('v1', null)]);
    expect(log.latest('v1')?.outcome, SuggestionOutcome.downloaded);
  });

  test('an instant promotion is reported to the caller', () async {
    instant = true;
    expect(await actions.downloadEntry(id), isTrue);
  });

  test('add to playlist downloads with the playlist in the tag', () async {
    expect(await actions.addToPlaylist(id, 5), isFalse);
    expect(downloads, [('v1', addToPlaylistTag(5))]);
    expect(log.latest('v1')?.outcome, SuggestionOutcome.downloaded);
  });

  test('dislikeTrack blocks the song and takes it out of the queue', () async {
    await actions.dislikeTrack(id);
    expect(store.trackBlocked('v1'), isTrue);
    expect(log.latest('v1')?.outcome, SuggestionOutcome.disliked);
    expect(removed, [id]);
  });

  test(
    'dislikeArtist takes out only the suggested songs of that artist',
    () async {
      final other = online.register(
        const YtResult(id: 'v2', title: 'B', channel: 'Chan', duration: null),
        suggested: true,
      );
      final own = online.register(
        const YtResult(id: 'v3', title: 'C', channel: 'Chan', duration: null),
      );
      final stranger = online.register(
        const YtResult(id: 'v4', title: 'D', channel: 'Else', duration: null),
        suggested: true,
      );
      queue = [id, own, other, stranger];
      await actions.dislikeArtist(id);
      expect(store.artistBlocked('chan'), isTrue);
      expect(queue, [own, stranger]);
    },
  );

  test(
    'undo unblocks, puts the entries back and restarts the playing one',
    () async {
      final other = online.register(
        const YtResult(id: 'v2', title: 'B', channel: 'Chan', duration: null),
        suggested: true,
      );
      final stranger = online.register(
        const YtResult(id: 'v4', title: 'D', channel: 'Else', duration: null),
      );
      queue = [stranger, id, other];
      current = id;
      final undo = await actions.dislikeArtist(id);
      expect(queue, [stranger]);
      await actions.undo(undo);
      expect(queue, [stranger, id, other]);
      expect(store.artistBlocked('chan'), isFalse);
      expect(played, 1);
      final t = await actions.dislikeTrack(id);
      await actions.undo(t);
      expect(store.trackBlocked('v1'), isFalse);
      expect(log.latest('v1')?.outcome, SuggestionOutcome.queued);
    },
  );

  test('remove only takes it out of the queue', () async {
    await actions.remove(id);
    expect(removed, [id]);
    expect(log.latest('v1')?.outcome, SuggestionOutcome.queued);
  });

  test('an entry the registry forgot downloads nothing', () async {
    online.forget(id);
    expect(await actions.downloadEntry(id), isNull);
    expect(downloads, isEmpty);
  });
}
