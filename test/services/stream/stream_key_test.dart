import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/stream/stream_key.dart';
import 'package:flutter_test/flutter_test.dart';

Track _row({String? artist = 'A'}) => Track(saved: false, coverSource: 0, 
      id: 1, path: 'stream:x', title: 'T', artist: artist, album: 'Al', albumKey: '',
      durationMs: 5000, format: '', sizeBytes: 0, mtimeMs: 0, hasCover: false,
      isFavorite: false, enrichStatus: 0, userEdited: false, missing: false,
      ignored: false, kind: 2, addedAt: 0, playCount: 0,
    );

void main() {
  test('streamResultOfRow inverts indexKey for every source', () {
    for (final s in MediaSource.values) {
      final r = streamResultOfRow(downloadIndexKey(s, 'id:1'), _row());
      expect((r.source, r.id, r.indexKey), (s, 'id:1', '${s.name}:id:1'));
      expect((r.title, r.album, r.duration), ('T', 'Al', const Duration(seconds: 5)));
      expect(r.artists, ['A']);
    }
  });

  test('streamResultOfRow without artist', () {
    expect(streamResultOfRow('youtube:z', _row(artist: null)).artists, isEmpty);
  });

  test('isStreamKey takes <known source>:<well-formed id> only', () {
    for (final ok in ['youtube:abcdefghijk', 'youtube:A_b-C1d2E3f', 'soundcloud:123456789']) {
      expect(isStreamKey(ok), isTrue, reason: ok);
    }
    for (final bad in [
      '', 'nocolon', ':abc', 'youtube:', 'youtube:abc', 'spotify:abcdefghijk', 'YouTube:abcdefghijk',
      'youtube:abcdefghijkl', 'youtube:abcdefghij&', 'youtube:../../x1234', 'youtube:abcdefg#cc-ep=1',
      'youtube:abcdefghi?v', 'soundcloud:12a', 'soundcloud:${'1' * 21}', 'soundcloud:', 'soundcloud:1:2',
    ]) {
      expect(isStreamKey(bad), isFalse, reason: bad);
    }
  });
}
