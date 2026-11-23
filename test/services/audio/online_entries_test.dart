import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

YtResult result(String id) => YtResult(
  id: id,
  title: 'Title $id',
  channel: 'Channel',
  duration: const Duration(minutes: 3, seconds: 20),
  artists: const ['A', 'B'],
  album: 'Album',
);

void main() {
  test('ids are negative and never reused, even after forget', () {
    final e = OnlineEntries();
    final a = e.register(result('a'));
    final b = e.register(result('b'));
    e.forget(b);
    final c = e.register(result('c'));
    expect({a, b, c}.length, 3);
    expect([a, b, c].every(isOnlineId), isTrue);
    expect(isOnlineId(5), isFalse);
    expect(e[b], isNull);
    expect(e[a]!.result.id, 'a');
  });

  test('trackOf builds a synthetic track from the result', () {
    final e = OnlineEntries();
    final id = e.register(result('xyz'), seedTitle: 'Seed');
    final t = e.trackOf(id)!;
    expect(t.id, id);
    expect(t.path, 'online:youtube:xyz');
    expect(t.title, 'Title xyz');
    expect(t.artist, 'A, B');
    expect(t.album, 'Album');
    expect(t.durationMs, 200000);
    expect(t.kind, 0);
    expect(t.coverKey, isNull);
    expect(e[id]!.seedTitle, 'Seed');
  });

  test('trackOf of an unknown id is null', () {
    expect(OnlineEntries().trackOf(-7), isNull);
  });

  test(
    'rebindRow moves every entry bound to the merged row, and only those',
    () {
      final e = OnlineEntries();
      final a = e.register(result('a'));
      final b = e.register(result('b'));
      final c = e.register(result('c'));
      e.bindRow(a, 10);
      e.bindRow(b, 10);
      e.bindRow(c, 11);
      e.rebindRow(10, 20);
      expect([e[a]!.trackId, e[b]!.trackId, e[c]!.trackId], [20, 20, 11]);
    },
  );
}
