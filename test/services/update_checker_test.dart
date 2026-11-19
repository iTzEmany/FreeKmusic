import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/update_checker.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

class _Web implements WebClient {
  _Web(this.answer);
  final Object? Function() answer;
  final urls = <String>[];
  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    urls.add(url);
    return answer();
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 5242880, CancelToken? cancel}) async => null;
}

void main() {
  group('compareVersions', () {
    test('plain numbers, numerically', () {
      expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });
    test('a leading v, missing parts and build numbers are ignored', () {
      expect(compareVersions('v1.2.0', '1.2.0'), 0);
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.0+7', '1.2.0+3'), 0);
      expect(compareVersions('V1.3', '1.2.9'), greaterThan(0));
    });
    test('a pre-release is older than its release, and they order among themselves', () {
      expect(compareVersions('1.2.0-beta.1', '1.2.0'), lessThan(0));
      expect(compareVersions('1.2.0', '1.2.0-rc.2'), greaterThan(0));
      expect(compareVersions('1.2.0-beta.2', '1.2.0-beta.10'), lessThan(0));
      expect(compareVersions('1.2.0-alpha', '1.2.0-beta'), lessThan(0));
      expect(compareVersions('1.2.0-beta', '1.2.0-beta.1'), lessThan(0));
    });
    test('garbage reads as 0.0.0', () {
      expect(compareVersions('abc', '0.0.0'), 0);
      expect(compareVersions('', '0.0.1'), lessThan(0));
    });
  });

  group('UpdateChecker', () {
    UpdateChecker checker(Object? Function() a, {String repo = 'me/codecore'}) =>
        UpdateChecker(_Web(a), repo: repo, current: '1.1.0');

    test('a newer release: version without v, page and notes', () async {
      final r = await checker(() => [{'tag_name': 'v1.2.0', 'html_url': 'https://github.com/me/codecore/releases/tag/v1.2.0', 'body': ' Novità\n- uno '}]).check();
      expect(r.status, UpdateStatus.newer);
      expect(r.info!.version, '1.2.0');
      expect(r.info!.url, endsWith('v1.2.0'));
      expect(r.info!.notes, 'Novità\n- uno');
    });
    test('the same version: up to date, still tells which', () async {
      final r = await checker(() => [{'tag_name': 'v1.1.0'}]).check();
      expect(r.status, UpdateStatus.upToDate);
      expect(r.info!.version, '1.1.0');
      expect(r.info!.url, 'https://github.com/me/codecore/releases');
    });
    test('an older release is up to date too', () async {
      expect((await checker(() => [{'tag_name': '1.0.0'}]).check()).status, UpdateStatus.upToDate);
    });
    test('no answer, wrong shape or no repository: failed, no request without a repository', () async {
      expect((await checker(() => null).check()).status, UpdateStatus.failed);
      expect((await checker(() => {'tag_name': 'v2'}).check()).status, UpdateStatus.failed);
      expect((await checker(() => [{'tag_name': ''}]).check()).status, UpdateStatus.failed);
      final web = _Web(() => [{'tag_name': 'v9'}]);
      expect((await UpdateChecker(web, repo: '', current: '1.0.0').check()).status, UpdateStatus.failed);
      expect(web.urls, isEmpty);
    });
    test('no releases yet, or only drafts and pre-releases: up to date, no info', () async {
      for (final answer in <List<Object?>>[
        [],
        [{'tag_name': 'v9.0.0', 'draft': true}, {'tag_name': 'v8.0.0', 'prerelease': true}],
      ]) {
        final r = await checker(() => answer).check();
        expect(r.status, UpdateStatus.upToDate);
        expect(r.info, isNull);
      }
    });
    test('skips drafts and pre-releases and takes the first published one', () async {
      final r = await checker(() => [
            {'tag_name': 'v3.0.0', 'draft': true},
            {'tag_name': 'v2.0.0-rc.1', 'prerelease': true},
            {'tag_name': 'v1.5.0'},
            {'tag_name': 'v1.4.0'},
          ]).check();
      expect(r.status, UpdateStatus.newer);
      expect(r.info!.version, '1.5.0');
    });
    test('GitHub 403/429 is reported as rate limited, once', () async {
      final web = _Web(() => throw const RateLimitedException(403));
      final r = await UpdateChecker(web, repo: 'me/codecore', current: '1.0.0').check();
      expect(r.status, UpdateStatus.rateLimited);
      expect(web.urls, hasLength(1));
    });
    test('asks the releases endpoint of the repository', () async {
      final web = _Web(() => [{'tag_name': 'v1.1.0'}]);
      await UpdateChecker(web, repo: 'me/codecore', current: '1.1.0').check();
      expect(web.urls.single, 'https://api.github.com/repos/me/codecore/releases?per_page=10');
    });
    test('the release assets: name, url, size and the sha256 of the digest', () async {
      final web = _Web(() => [
        {
          'tag_name': 'v1.6.2',
          'assets': [
            {
              'name': 'freekmusic-full-arm64-v8a-release.apk',
              'size': 84081714,
              'digest': 'sha256:00385C8F382705EA5215323201B4CDABFD2F44E3A49C8439AF019ACC294E2D71',
              'browser_download_url': 'https://github.com/iTzEmany/FreeKmusic/releases/download/v1.6.2/freekmusic-full-arm64-v8a-release.apk',
            },
            {'name': 'old.bin', 'size': 3, 'digest': null, 'browser_download_url': 'https://example.com/old.bin'},
            {'name': 'no-url'},
          ],
        },
      ]);
      final assets = (await UpdateChecker(web, repo: 'a/b', current: '1.0.0').check()).info!.assets;
      expect(assets, hasLength(2));
      expect(assets[0].name, 'freekmusic-full-arm64-v8a-release.apk');
      expect(assets[0].size, 84081714);
      expect(assets[0].sha256, '00385c8f382705ea5215323201b4cdabfd2f44e3a49c8439af019acc294e2d71');
      expect(assets[0].url.host, 'github.com');
      expect(assets[1].sha256, isNull);
    });
  });
}
