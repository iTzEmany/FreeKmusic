import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_song_parser.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test('a yt: item of a cover gives the cover with its original, no file asked', () async {
    final r = Rig()
      ..song = const YtmSong(title: 'Believer (Romy Wave Cover)', artists: ['Romy Wave'], videoType: 'MUSIC_VIDEO_TYPE_UGC', durationMs: 200000)
      ..ytm = [const YtResult(id: 'a', title: 'Believer', channel: 'Imagine Dragons', artists: ['Romy Wave'], duration: Duration(seconds: 200))]
      ..mbSearch = [const MbRecording(id: 'o1', title: 'Believer', artistId: 'a', artistName: 'Imagine Dragons')];
    final rec = (await r.recognizer.recognizeOnline('dQw4w9WgXcQ'))!;
    expect(r.calls, ['songOf:dQw4w9WgXcQ', 'ytm', 'mb.search']);
    expect([rec.src, rec.cover, rec.sure, rec.identity!.vid], [RecogSource.ytid, true, false, 'dQw4w9WgXcQ']);
    expect(rec.original, {'title': 'Believer', 'artist': 'Imagine Dragons', 'mbid': 'o1'});
  });

  test('a video YouTube Music has no song for gives null', () async {
    expect(await Rig().recognizer.recognizeOnline('dQw4w9WgXcQ'), isNull);
  });
}
