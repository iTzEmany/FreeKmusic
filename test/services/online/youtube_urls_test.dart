import 'dart:convert';
import 'dart:io';

import 'package:codecore/core/text_utils.dart';
import 'package:codecore/services/online/yt_dlp_process_service.dart';
import 'package:codecore/services/online/youtube_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyYoutubeUrl and listingUrl', () {
    const playlist = 'https://www.youtube.com/playlist?list=PLabc123';
    final table = <String, (YoutubeLinkKind, String?)>{
      playlist: (YoutubeLinkKind.playlist, playlist),
      'https://youtube.com/playlist?list=PLabc123&si=xyz': (YoutubeLinkKind.playlist, playlist),
      'https://m.youtube.com/playlist?list=PLabc123': (YoutubeLinkKind.playlist, playlist),
      'https://www.youtube.com/watch?v=VID&list=PLabc123': (YoutubeLinkKind.playlist, playlist),
      'https://youtu.be/VID?list=PLabc123': (YoutubeLinkKind.playlist, playlist),
      'https://music.youtube.com/playlist?list=OLAK5uy_abc': (
        YoutubeLinkKind.playlist,
        'https://www.youtube.com/playlist?list=OLAK5uy_abc',
      ),
      'https://www.youtube.com/@Computerphile': (
        YoutubeLinkKind.channel,
        'https://www.youtube.com/@Computerphile/videos',
      ),
      'https://www.youtube.com/@Computerphile/playlists': (
        YoutubeLinkKind.channel,
        'https://www.youtube.com/@Computerphile/videos',
      ),
      'https://www.youtube.com/channel/UC9-y-6csu5WGm29I7JiwpnA/featured': (
        YoutubeLinkKind.channel,
        'https://www.youtube.com/channel/UC9-y-6csu5WGm29I7JiwpnA/videos',
      ),
      '  https://www.youtube.com/@x  ': (
        YoutubeLinkKind.channel,
        'https://www.youtube.com/@x/videos',
      ), // pasted with spaces
      'https://www.youtube.com/c/Computerphile': (
        YoutubeLinkKind.channel,
        'https://www.youtube.com/c/Computerphile/videos',
      ),
      'https://www.youtube.com/user/numberphile': (
        YoutubeLinkKind.channel,
        'https://www.youtube.com/user/numberphile/videos',
      ),
      // One video, even with a mix or a personal list attached: not a playlist.
      'https://www.youtube.com/watch?v=VID': (YoutubeLinkKind.video, null),
      'https://www.youtube.com/watch?v=VID&list=RDVID': (YoutubeLinkKind.video, null),
      'https://www.youtube.com/watch?v=VID&list=WL': (YoutubeLinkKind.video, null),
      'https://youtu.be/VID': (YoutubeLinkKind.video, null),
      'https://www.youtube.com/shorts/VID': (YoutubeLinkKind.video, null),
      'https://www.youtube.com/playlist?list=LL': (YoutubeLinkKind.other, null),
      'https://www.youtube.com/playlist?list=': (YoutubeLinkKind.other, null),
      'https://music.youtube.com/browse/MPREb_abc-123': (YoutubeLinkKind.album, null),
      'https://music.youtube.com/browse/MPREb_abc-123?si=xyz': (YoutubeLinkKind.album, null),
      'https://music.youtube.com/browse/MPREb_abc-123/': (YoutubeLinkKind.album, null),
      'https://music.youtube.com/browse/UCabc': (YoutubeLinkKind.other, null),
      'https://music.youtube.com/watch?v=VID': (YoutubeLinkKind.other, null),
      'https://www.youtube.com/': (YoutubeLinkKind.other, null),
      'https://www.youtube.com/@': (YoutubeLinkKind.other, null),
      'https://evil.example/playlist?list=PLabc': (YoutubeLinkKind.other, null),
      'daft punk': (YoutubeLinkKind.other, null),
      '': (YoutubeLinkKind.other, null),
      'ftp://www.youtube.com/playlist?list=PLabc': (YoutubeLinkKind.other, null),
    };
    for (final e in table.entries) {
      test(e.key.isEmpty ? '(empty)' : e.key, () {
        expect(classifyYoutubeUrl(e.key), e.value.$1);
        expect(listingUrl(e.key), e.value.$2);
      });
    }
  });

  test('ytmAlbumBrowseId gives the browse id, params dropped', () {
    expect(ytmAlbumBrowseId('https://music.youtube.com/browse/MPREb_abc-123?si=x'), 'MPREb_abc-123');
    expect(ytmAlbumBrowseId('https://www.youtube.com/browse/MPREb_abc'), isNull);
  });

  group('htmlUnescape', () {
    test('the entities yt-dlp leaves in titles', () {
      expect(htmlUnescape('Tom &amp; Jerry'), 'Tom & Jerry');
      expect(htmlUnescape('&lt;b&gt; &quot;x&quot; &#39;y&#39; &apos;z&apos;'), '<b> "x" \'y\' \'z\'');
      expect(htmlUnescape('caf&#233; &#x2764;'), 'café ❤');
    });

    test('anything else is left alone', () {
      expect(htmlUnescape('Rock & Roll'), 'Rock & Roll');
      expect(htmlUnescape('&nbsp; &#99999999; &amp'), '&nbsp; &#99999999; &amp');
      expect(htmlUnescape('plain'), 'plain');
      expect(htmlUnescape('&amp;amp;'), '&amp;', reason: 'one level only');
    });
  });

  group('parsePlaylistListing', () {
    String fixture(String n) => File('test/fixtures/$n').readAsStringSync();

    test('the real playlist: five videos in order, the private one counted and not listed', () {
      final l = parsePlaylistListing(fixture('yt_playlist_flat.json'));
      expect(l.title, 'Nick Hawes on Computerphile');
      expect(l.owner, 'Computerphile');
      expect(l.entries, hasLength(5));
      expect(l.entries.first.id, '844U9T_SOrA');
      expect(l.entries.map((e) => e.id).toSet(), hasLength(5));
      expect(l.unavailable, 1);
      expect(l.truncated, isFalse);
      expect(l.entries.first.duration, const Duration(seconds: 906));
    });

    test('a channel: the tab is dropped from the title and videos take the channel', () {
      final raw = jsonEncode({
        'title': 'Computerphile - Videos',
        'channel': 'Computerphile',
        'entries': [
          {'id': 'a', 'title': 'Tom &amp; Jerry - Computerphile', 'duration': 60},
          {'id': 'b', 'title': 'B', 'uploader': 'Guest', 'duration': 90},
        ],
      });
      final l = parsePlaylistListing(raw);
      expect(l.title, 'Computerphile');
      expect(l.entries[0].title, 'Tom & Jerry - Computerphile');
      expect(l.entries[0].channel, 'Computerphile');
      expect(l.entries[1].channel, 'Guest', reason: 'a video that has its own channel keeps it');
    });

    test('as many videos as asked for means there may be more', () {
      final raw = jsonEncode({
        'title': 'T',
        'entries': [for (var i = 0; i < 3; i++) {'id': 'v$i', 'title': 'V$i'}],
      });
      expect(parsePlaylistListing(raw, limit: 3).truncated, isTrue);
      expect(parsePlaylistListing(raw, limit: 4).truncated, isFalse);
    });

    test('nothing usable gives an empty listing', () {
      expect(parsePlaylistListing('[]').entries, isEmpty);
      expect(parsePlaylistListing('{"title": "x"}').entries, isEmpty);
    });
  });
}
