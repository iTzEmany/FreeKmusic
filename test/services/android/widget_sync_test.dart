import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/android/widget_bridge.dart';
import 'package:codecore/services/android/widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBridge implements WidgetBridge {
  final updates = <WidgetSnapshot>[];
  var ready = 0;
  @override
  Future<void> update(WidgetSnapshot s) async => updates.add(s);
  @override
  Future<void> markReady() async => ready++;
}

Track _track(int id, String title, {String? artist = 'Art', String? cover}) => Track(saved: false, coverSource: 0, 
      id: id,
      path: '/m/$id.mp3',
      title: title,
      artist: artist,
      albumKey: 'k',
      durationMs: 1000,
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      hasCover: cover != null,
      coverKey: cover,
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
  late StreamController<Track?> tracks;
  late StreamController<bool> playing;
  late _FakeBridge bridge;

  setUp(() {
    tracks = StreamController<Track?>.broadcast();
    playing = StreamController<bool>.broadcast();
    bridge = _FakeBridge();
  });
  tearDown(() async {
    await tracks.close();
    await playing.close();
  });

  WidgetSync sync({Track? track, bool isPlaying = false}) => WidgetSync(
        tracks: tracks.stream,
        playing: playing.stream,
        bridge: bridge,
        coverPath: (t) => t.coverKey == null ? null : '/covers/${t.coverKey}',
        initialTrack: track,
        initialPlaying: isPlaying,
      );

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('writes once when it starts and once per change of track or state', () async {
    final s = sync(track: _track(1, 'One', cover: 'c1'));
    await pump();
    expect(bridge.updates, hasLength(1));
    expect(bridge.updates.single.title, 'One');
    expect(bridge.updates.single.coverPath, '/covers/c1');
    expect(bridge.updates.single.playing, isFalse);

    playing.add(true);
    await pump();
    tracks.add(_track(2, 'Two'));
    await pump();
    playing.add(false);
    await pump();
    expect(bridge.updates.map((u) => (u.title, u.playing)), [('One', false), ('One', true), ('Two', true), ('Two', false)]);
    await s.dispose();
  });

  test('the same snapshot again writes nothing (a position tick is not even heard)', () async {
    final s = sync(track: _track(1, 'One'), isPlaying: true);
    await pump();
    for (var i = 0; i < 20; i++) {
      playing.add(true); // the stream repeating itself
      tracks.add(_track(1, 'One')); // the same track announced again
    }
    await pump();
    expect(bridge.updates, hasLength(1));
    await s.dispose();
  });

  test('no track: an empty snapshot, whatever the play state', () async {
    final s = sync();
    await pump();
    expect(bridge.updates.single, WidgetSnapshot.empty);
    playing.add(true);
    await pump();
    expect(bridge.updates, hasLength(1), reason: 'still nothing to show');
    tracks.add(null);
    await pump();
    expect(bridge.updates, hasLength(1));
    await s.dispose();
  });

  test('after dispose it stops writing', () async {
    final s = sync(track: _track(1, 'One'));
    await pump();
    await s.dispose();
    tracks.add(_track(2, 'Two'));
    await pump();
    expect(bridge.updates, hasLength(1));
  });

  group('PrefsWidgetBridge', () {
    test('writes the fields, then the stamp; removes what is gone', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var clock = 100;
      final b = PrefsWidgetBridge(prefs, now: () => clock++);
      await b.update(const WidgetSnapshot(title: 'T', artist: 'A', coverPath: '/c.jpg', playing: true));
      expect(prefs.getString(WidgetKeys.title), 'T');
      expect(prefs.getString(WidgetKeys.artist), 'A');
      expect(prefs.getString(WidgetKeys.cover), '/c.jpg');
      expect(prefs.getBool(WidgetKeys.playing), isTrue);
      expect(prefs.getInt(WidgetKeys.stamp), 100);

      await b.update(const WidgetSnapshot(title: 'T2'));
      expect(prefs.containsKey(WidgetKeys.artist), isFalse);
      expect(prefs.containsKey(WidgetKeys.cover), isFalse);
      expect(prefs.getBool(WidgetKeys.playing), isFalse);
      expect(prefs.getInt(WidgetKeys.stamp), 101, reason: 'always a new stamp');

      await b.markReady();
      expect(prefs.getInt(WidgetKeys.readyAt), 102);
    });
  });
}
