import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/ui/widgets/track_kind.dart';
import 'package:flutter_test/flutter_test.dart';

Track _t(int id, {int kind = 0}) => Track(saved: false, coverSource: 0, 
      id: id,
      path: '/m/$id.mp3',
      title: 't',
      albumKey: 'k',
      durationMs: 1000,
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      hasCover: false,
      isFavorite: false,
      enrichStatus: 0,
      userEdited: false,
      missing: false,
      ignored: false,
      kind: kind,
      addedAt: 1,
      playCount: 0,
    );

void main() {
  test('trackKind: negative ids are online, kind 1 rows are episodes, the rest local', () {
    const table = {
      -2147483648: TrackKind.online,
      -1: TrackKind.online,
      0: TrackKind.local,
      1: TrackKind.local,
      2147483647: TrackKind.local,
    };
    table.forEach((id, kind) => expect(_t(id).trackKind, kind, reason: 'id $id'));
    expect(_t(5, kind: 1).trackKind, TrackKind.episode);
  });
}
