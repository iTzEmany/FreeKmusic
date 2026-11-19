import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/update_checker.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

class _Web implements WebClient {
  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async => [
    {
      'tag_name': 'v1.6.2',
      'html_url': 'https://github.com/iTzEmany/FreeKmusic/releases/tag/v1.6.2',
      'assets': [
        {
          'name': 'freekmusic-full-arm64-v8a-release.apk',
          'size': 84081714,
          'digest': 'sha256:00385C8F382705EA5215323201B4CDABFD2F44E3A49C8439AF019ACC294E2D71',
          'browser_download_url': 'https://github.com/iTzEmany/FreeKmusic/releases/download/v1.6.2/freekmusic-full-arm64-v8a-release.apk',
        },
        {
          'name': 'old.bin',
          'size': 3,
          'digest': null,
          'browser_download_url': 'https://example.com/old.bin',
        },
        {'name': 'no-url'},
      ],
    },
  ];

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 5242880, CancelToken? cancel}) async => null;
}

void main() {
  test('the release assets: name, url, size and the sha256 of the digest', () async {
    final r = await UpdateChecker(_Web(), repo: 'a/b', current: '1.0.0').check();
    final assets = r.info!.assets;
    expect(assets, hasLength(2));
    expect(assets[0].name, 'freekmusic-full-arm64-v8a-release.apk');
    expect(assets[0].size, 84081714);
    expect(assets[0].sha256, '00385c8f382705ea5215323201b4cdabfd2f44e3a49c8439af019acc294e2d71');
    expect(assets[0].url.host, 'github.com');
    expect(assets[1].sha256, isNull);
  });
}
