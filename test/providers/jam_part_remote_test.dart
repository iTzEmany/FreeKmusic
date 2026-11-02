import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/jam_part.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/jam_part_feeder.dart' show jamPartKeys;
import 'package:codecore/services/jam/remote/jam_remote_items.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late List<int> ids;
  late JamPart part;
  late Map<String, String?> vids; // title -> video id
  var throwFor = <String>{};

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    ids = [
      for (final t in ['Alpha', 'Beta', 'Gamma'])
        await db.into(db.tracks).insert(TracksCompanion.insert(
              path: '/m/$t.mp3',
              title: t,
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
            )),
    ];
    vids = {'Alpha': 'aaaaaaaaaaa', 'Beta': null, 'Gamma': 'ggggggggggg'};
    throwFor = {};
    part = JamPart(
      ownId: () => 'g',
      tracks: () => TrackRepository(db),
      queries: () => LibraryQueries(db),
      downloads: () async => DownloadIndex(File('/nonexistent/dl.json')),
      remoteItems: () => JamRemoteItems((t) async {
        if (throwFor.contains(t.title)) throw StateError('offline');
        return vids[t.title];
      }),
    );
  });

  const together = JamState(version: 1, hostDeviceId: 'h', outputDeviceId: 'h', mode: JamMode.together);

  test('a remote part is sent as yt: items; the one not found is kept, not sent', () async {
    final sent = <JamItem>[];
    part.start(ids, (c) async {
      sent.add(c.item!);
      return JamResult.ok(together.copyWith(version: 9));
    }, remote: true);
    await part.feeder!.update(together);
    expect(sent.map((i) => i.ref), ['yt:youtube:aaaaaaaaaaa', 'yt:youtube:ggggggggggg']);
    expect(part.feeder!.unsent, contains(jamPartKeys(ids)[1]));
  });

  test('a remote suggestion is a yt: item, never a numeric ref', () async {
    final sent = <JamItem>[];
    part.start(const [], (c) async {
      sent.add(c.item!);
      return JamResult.ok(together.copyWith(version: 9));
    }, remote: true);
    vids['Beta'] = 'bbbbbbbbbbb';
    await part.feeder!.update(together);
    expect(sent, isNotEmpty);
    expect(sent.every((i) => i.ref!.startsWith('yt:youtube:') && i.suggested), true);
  });

  test('a lookup that throws is retried, not skipped, until the third attempt', () async {
    final sent = <JamItem>[];
    part.start([ids.first], (c) async {
      sent.add(c.item!);
      return JamResult.ok(together.copyWith(version: 9));
    }, remote: true);
    throwFor = {'Alpha'};
    await part.feeder!.update(together);
    await part.feeder!.update(together.copyWith(version: 2));
    expect(part.feeder!.unsent, ['${ids.first}']); // back in the part, not given up
    throwFor = {};
    await part.feeder!.update(together.copyWith(version: 3));
    expect(sent.single.ref, 'yt:youtube:aaaaaaaaaaa');
  });
}
