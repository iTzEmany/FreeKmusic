import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/jam_part.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/jam_part_feeder.dart';
import 'package:codecore/services/jam/jam_state.dart';
import 'package:codecore/services/jam/remote/jam_remote_items.dart';
import 'package:flutter_test/flutter_test.dart';

Track track(int id, String title) => Track(
  coverSource: 0,
  id: id,
  path: '/m/$id.mp3',
  title: title,
  artist: 'Pink Floyd',
  albumKey: 'k',
  durationMs: 335000,
  format: 'mp3',
  sizeBytes: 1,
  mtimeMs: 1,
  hasCover: false,
  isFavorite: false,
  enrichStatus: 0,
  userEdited: false,
  missing: false,
  ignored: false,
  kind: 0,
  addedAt: 1,
  playCount: 0,
);

void main() {
  final found = {'Time': 'dQw4w9WgXcQ'};
  final items = JamRemoteItems((t) async => found[t.title]);

  test('a found track becomes a yt: item the host can fetch', () async {
    final i = (await items.of(
      track(1, 'Time'),
      'me',
      partKey: '1',
      suggested: true,
    ))!;
    expect(i.ref, 'yt:youtube:dQw4w9WgXcQ');
    expect(i.videoId, 'dQw4w9WgXcQ');
    expect(i.selfFetchable, true);
    expect(
      (i.sizeBytes, i.partKey, i.suggested, i.ownerDeviceId),
      (0, '1', true, 'me'),
    );
  });

  test('not found, or a lookup that fails, is null', () async {
    expect(await items.of(track(2, 'Unknown'), 'me'), isNull);
    final broken = JamRemoteItems((_) async => throw StateError('offline'));
    expect(await broken.of(track(1, 'Time'), 'me'), isNull);
  });

  test('the host accepts that item from a remote guest, small enough for the bridge', () async {
    final i = (await items.of(track(1, 'Time'), 'g'))!;
    final s = const JamState(
      version: 1,
      hostDeviceId: 'h',
      outputDeviceId: 'h',
      participants: [JamParticipant(id: 'g', name: 'G', remote: true)],
    );
    final r = applyCommand(s, JamCommand.add(i), from: 'g', nowMs: 1);
    expect(r.state!.items.single.ref, 'yt:youtube:dQw4w9WgXcQ');
    expect(r.state!.toJson().toString().length, lessThan(2000));
  });

  test('the feeder skips tracks not found and feeds the others', () async {
    final sent = <String>[];
    final tracks = {
      '1': track(1, 'Time'),
      '2': track(2, 'Unknown'),
      '3': track(3, 'Time'),
    };
    final f = JamPartFeeder(
      ownId: 'g',
      part: ['1', '2', '3'],
      send: (c) async {
        sent.add(c.item!.partKey!);
        return JamResult.ok(
          const JamState(version: 9, hostDeviceId: 'h', outputDeviceId: 'h'),
        );
      },
      itemOf: (k) => items.of(tracks[k]!, 'g', partKey: k),
      suggest: (_) async => null,
    );
    await f.update(
      const JamState(
        version: 1,
        hostDeviceId: 'h',
        outputDeviceId: 'h',
        mode: JamMode.together,
      ),
    );
    expect(sent, ['1', '3']);
  });

  test('a library item with a known download carries the video id but is not selfFetchable', () {
    final i = jamItemOfTrack(track(1, 'Time'), 'me', videoId: 'dQw4w9WgXcQ')!;
    expect(i.videoId, 'dQw4w9WgXcQ');
    expect(i.ref, '1');
    expect(i.selfFetchable, false);
  });

  test(
    'an episode not downloaded (an address or a stream key) cannot go in a Jam',
    () {
      expect(
        jamItemOfTrack(
          track(1, 'Ep').copyWith(kind: 1, path: 'https://x/e.mp3'),
          'me',
        ),
        isNull,
      );
      expect(
        jamItemOfTrack(
          track(1, 'Ep').copyWith(kind: 1, path: 'stream:youtube:v1.mp3'),
          'me',
        ),
        isNull,
      );
      expect(
        jamItemOfTrack(
          track(1, 'Ep').copyWith(kind: 1, path: '/data/podcasts/1/e.mp3'),
          'me',
        ),
        isNotNull,
      );
    },
  );

  JamPartFeeder remoteFeeder(List<String> sent, {JamRemoteItems? with_}) {
    final tracks = {
      '1': track(1, 'Time'),
      '2': track(2, 'Unknown'),
      '3': track(3, 'Time'),
    };
    return JamPartFeeder(
      ownId: 'g',
      part: ['1', '2', '3'],
      keepUnavailable: true,
      send: (c) async {
        sent.add(c.item!.partKey!);
        return JamResult.ok(
          const JamState(version: 9, hostDeviceId: 'h', outputDeviceId: 'h'),
        );
      },
      itemOf: (k) =>
          (with_ ?? items).of(tracks[k]!, 'g', partKey: k, rethrowErrors: true),
      suggest: (_) async => null,
    );
  }

  test('a track not found stays in the part for the exit, in its place, and is never sent', () async {
    final sent = <String>[];
    final f = remoteFeeder(sent);
    const s = JamState(
      version: 1,
      hostDeviceId: 'h',
      outputDeviceId: 'h',
      mode: JamMode.together,
    );
    await f.update(s);
    expect(sent, ['1', '3']);
    JamItem yt(String k) => JamItem(
      id: int.parse(k),
      ownerDeviceId: 'g',
      title: k,
      ext: 'webm',
      ref: 'yt:youtube:x$k',
      partKey: k,
    );
    // 1 is playing, 3 waits in the Jam: what is left is the skipped 2 and 3 (from its part key), in part order.
    final after = s.copyWith(
      version: 10,
      items: [yt('1'), yt('3')],
      currentIndex: 0,
    );
    await f.update(after);
    expect(f.remaining(after), [2, 3]);
  });

  test(
    'a network error on the lookup puts the track back instead of dropping it',
    () async {
      final sent = <String>[];
      final f = remoteFeeder(
        sent,
        with_: JamRemoteItems((_) async => throw StateError('offline')),
      );
      await f.update(
        const JamState(
          version: 1,
          hostDeviceId: 'h',
          outputDeviceId: 'h',
          mode: JamMode.together,
        ),
      );
      expect(sent, isEmpty);
      expect(f.unsent, ['1', '2', '3']);
    },
  );

  test('an id that does not look like a video id is not found', () async {
    final bad = JamRemoteItems((_) async => 'a b/../c');
    expect(await bad.of(track(1, 'Time'), 'g'), isNull);
  });

  test(
    'forgetting a skipped track takes it out of unsent and remaining',
    () async {
      final f = remoteFeeder(<String>[]);
      const s = JamState(
        version: 1,
        hostDeviceId: 'h',
        outputDeviceId: 'h',
        mode: JamMode.together,
      );
      await f.update(s);
      expect(f.unsent, contains('2'));
      f.forget('2');
      expect(f.unsent, isNot(contains('2')));
      expect(f.remaining(s), isNot(contains(2)));
    },
  );

  test('a lookup failing three times in a row is skipped, so the part is not blocked', () async {
    final sent = <String>[];
    var calls = 0;
    final flaky = JamRemoteItems((t) async {
      if (t.title == 'Unknown' && ++calls < 99) throw StateError('offline');
      return 'dQw4w9WgXcQ';
    });
    final f = remoteFeeder(sent, with_: flaky);
    const s = JamState(
      version: 1,
      hostDeviceId: 'h',
      outputDeviceId: 'h',
      mode: JamMode.together,
    );
    for (var i = 0; i < 4; i++) {
      await f.update(s.copyWith(version: i + 1));
    }
    expect(calls, 3);
    expect(sent, ['1', '3']);
    expect(f.unsent, contains('2')); // kept for the exit, never sent
  });

  test('a host refusal in remote mode keeps the track in the part', () async {
    final f = JamPartFeeder(
      ownId: 'g',
      part: ['1'],
      keepUnavailable: true,
      send: (_) async => const JamResult.fail(JamError.forbidden),
      itemOf: (k) => items.of(track(1, 'Time'), 'g', partKey: k),
      suggest: (_) async => null,
    );
    await f.update(
      const JamState(
        version: 1,
        hostDeviceId: 'h',
        outputDeviceId: 'h',
        mode: JamMode.together,
      ),
    );
    expect(f.unsent, ['1']);
  });

  test('a feeder stopped during a slow lookup sends nothing', () async {
    final gate = Completer<void>();
    final sent = <String>[];
    late JamPartFeeder f;
    f = JamPartFeeder(
      ownId: 'g',
      part: ['1'],
      send: (c) async {
        sent.add('x');
        return const JamResult.fail(JamError.full);
      },
      itemOf: (k) async {
        await gate.future;
        return items.of(track(1, 'Time'), 'g', partKey: k);
      },
      suggest: (_) async => null,
    );
    final run = f.update(
      const JamState(
        version: 1,
        hostDeviceId: 'h',
        outputDeviceId: 'h',
        mode: JamMode.together,
      ),
    );
    f.dispose();
    gate.complete();
    await run;
    expect(sent, isEmpty);
  });
}
