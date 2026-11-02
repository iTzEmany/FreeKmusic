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
}
