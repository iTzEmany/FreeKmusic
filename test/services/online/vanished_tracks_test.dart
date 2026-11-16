import 'package:codecore/core/import_row.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/vanished_tracks.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

YtResult yt(String id, {String title = 'Time', String artist = 'Pink Floyd', int sec = 413}) =>
    YtResult(id: id, title: title, channel: artist, artists: [artist], duration: Duration(seconds: sec));

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late int id;
  late List<ImportRow> asked;
  late List<(String, YtResult?)> logged;
  YtResult? found;
  Object? searchError;

  var fileFor = <String>{};

  VanishedTracks make() => VanishedTracks(
        tracks: repo,
        hasFile: (k) async => fileFor.contains(k),
        search: (row) async {
          asked.add(row);
          if (searchError != null) throw searchError!;
          return found;
        },
        log: (row, to) async => logged.add((row.title, to)),
      );

  Future<Track> row() async => (await repo.getById(id))!;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    asked = [];
    logged = [];
    found = null;
    searchError = null;
    fileFor = {};
    id = (await repo.saveStream(yt('old')))!;
    await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(playCount: Value(3)));
  });
  tearDown(() => db.close());

  test('same title, artist and duration within 2 s: the same row moves and the log says so', () async {
    found = yt('new', sec: 415);
    expect(await make().handle(await row()), true);
    final t = await row();
    expect([t.path, t.playCount, t.saved], ['stream:youtube:new', 3, true]);
    expect(logged, [('Time', found)]);
    expect(asked.single.title, 'Time');
  });

  test('duration 3 s away, other title or other artist: only the log entry, the row stays', () async {
    for (final c in [yt('n1', sec: 416), yt('n2', title: 'Money'), yt('n3', artist: 'Roger Waters')]) {
      found = c;
      expect(await make().handle(await row()), false);
    }
    expect((await row()).path, 'stream:youtube:old');
    expect(logged.map((e) => e.$2), [null, null, null]);
  });

  test('nothing found: one search and one log entry per row per session, however often it plays', () async {
    final v = make();
    expect(await v.handle(await row()), false);
    expect(await v.handle(await row()), false);
    expect(asked.length, 1);
    expect(logged.length, 1);
    expect((await row()).path, 'stream:youtube:old');
  });

  test('the old video as best match: not gone, nothing logged or moved', () async {
    found = yt('old');
    expect(await make().handle(await row()), false);
    expect(logged, isEmpty);
  });

  test('a replacement that is already a downloaded file does not make a second row', () async {
    found = yt('new');
    fileFor = {'youtube:new'};
    expect(await make().handle(await row()), false);
    expect((await row()).path, 'stream:youtube:old');
    expect(logged.single.$2, null);
  });

  test('isVideoGone: only a definitive reason, with the real yt-dlp lines', () {
    const u = YtErrorKind.unavailable;
    bool gone(String s) => isVideoGone(YtException(u, s));
    expect(gone('ERROR: [youtube] abc: Video unavailable'), true);
    expect(gone('ERROR: [youtube] abc: Video unavailable. This video has been removed by the uploader'), true);
    expect(gone('ERROR: [youtube] abc: Video unavailable. This video is no longer available because the YouTube account associated with this video has been terminated.'), true);
    expect(gone('ERROR: [youtube] abc: Private video. Sign in if you\'ve been granted access to this video'), true);
    expect(gone('ERROR: [youtube] abc: This content isn\'t available, try again later. The current session has been rate-limited by YouTube'), false);
    expect(gone('ERROR: [youtube] abc: Video unavailable. The uploader has not made this video available in your country'), false);
    expect(gone('ERROR: [youtube] abc: Join this channel to get access to members-only content like this video'), false);
    expect(gone('ERROR: [youtube] abc: Sign in to confirm your age'), false);
    expect(isVideoGone(const YtException(YtErrorKind.network, 'Video unavailable')), false);
  });

  test('only saved stream rows are touched', () async {
    await repo.setSaved('youtube:old', false);
    found = yt('new');
    expect(await make().handle(await row()), false);
    expect(asked, isEmpty);
    expect(logged, isEmpty);
    expect((await row()).path, 'stream:youtube:old');
  });

  test('a failing search is not logged as vanished and leaves the row alone', () async {
    searchError = const YtException(YtErrorKind.network);
    expect(await make().handle(await row()), false);
    expect(logged, isEmpty);
    expect((await row()).path, 'stream:youtube:old');
  });

  test('a second call for the same row while one runs does nothing', () async {
    found = yt('new');
    final v = make();
    final r = await row();
    final results = await Future.wait([v.handle(r), v.handle(r)]);
    expect(results, [true, false]);
    expect(asked.length, 1);
  });
}
