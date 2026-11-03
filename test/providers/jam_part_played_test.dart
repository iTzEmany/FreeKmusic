import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/jam_part.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/remote/jam_remote_items.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('played tracks trimmed before the first suggestion are still not suggested', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = [
      for (final t in ['Alpha', 'Beta'])
        await db.into(db.tracks).insert(TracksCompanion.insert(
              path: '/m/$t.mp3', title: t, albumKey: 'k', format: 'mp3',
              sizeBytes: 1, mtimeMs: 1, addedAt: 1)),
    ];
    JamItem item(int n, String title) => JamItem(
        id: n, ownerDeviceId: 'g', title: title, ext: 'mp3', ref: '${ids[n - 1]}');
    const empty = JamState(
        version: 1, hostDeviceId: 'h', outputDeviceId: 'h', mode: JamMode.together);
    for (var n = 0; n < 15; n++) {
      final part = JamPart(
        ownId: () => 'g',
        tracks: () => TrackRepository(db),
        queries: () => LibraryQueries(db),
        downloads: () async => DownloadIndex(File('/nonexistent/dl.json')),
        remoteItems: () => JamRemoteItems((t) async => null),
      );
      final sent = <JamItem>[];
      part.start(const [], (c) async {
        sent.add(c.item!);
        return JamResult.ok(empty.copyWith(version: 100));
      });
      // Alpha played, then trimmed by the host; the first suggestion comes only now.
      part.notePlayed(empty.copyWith(version: 2, items: [item(1, 'Alpha')], currentIndex: 0));
      final trimmed = empty.copyWith(version: 3, items: [item(2, 'Beta')], currentIndex: 0);
      part.notePlayed(trimmed);
      await part.feeder!.update(trimmed);
      expect(sent, isEmpty);
    }
  });

  test('a played track is not suggested again after the host trimmed it from the Jam', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = [
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
    JamItem played(int n, String title) => JamItem(
        id: n, ownerDeviceId: 'g', title: title, ext: 'mp3', ref: '${ids[n - 1]}');
    const empty = JamState(version: 1, hostDeviceId: 'h', outputDeviceId: 'h', mode: JamMode.together);

    // The draw is unseeded: repeat so that a missing memory cannot pass by luck.
    for (var n = 0; n < 15; n++) {
      final part = JamPart(
        ownId: () => 'g',
        tracks: () => TrackRepository(db),
        queries: () => LibraryQueries(db),
        downloads: () async => DownloadIndex(File('/nonexistent/dl.json')),
        remoteItems: () => JamRemoteItems((t) async => null),
      );
      final sent = <JamItem>[];
      part.start(const [], (c) async {
        sent.add(c.item!);
        return JamResult.ok(empty.copyWith(version: 100));
      });
      final both = empty.copyWith(
          version: 2, items: [played(1, 'Alpha'), played(2, 'Beta')], currentIndex: 1);
      part.notePlayed(both);
      await part.feeder!.update(both); // Alpha and Beta played, Gamma suggested
      expect(sent.map((i) => i.title), ['Gamma']);
      sent.clear();
      // The host trimmed Alpha and Beta; only Gamma, now playing, is left: nothing new to suggest.
      final left = empty.copyWith(version: 200, items: [played(3, 'Gamma')], currentIndex: 0);
      part.notePlayed(left);
      await part.feeder!.update(left);
      expect(sent, isEmpty);
    }
  });
}
