import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/update_checker.dart';
import 'package:codecore/services/update/whats_new.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _block = '## Novità\n- evidenza | mic | Karaoke | Testo.';

class _Web implements WebClient {
  _Web(this.body);
  final Object? body;
  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async => body;
  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 5242880, CancelToken? cancel}) async => null;
}

void main() {
  late SettingsStore store;
  late List<String> fetched;

  Future<WhatsNew> make(Map<String, Object> prefs, {bool data = true, UpdateInfo? remote, bool offline = false}) async {
    SharedPreferences.setMockInitialValues(prefs);
    store = await SettingsStore.open();
    fetched = [];
    return WhatsNew(
      store,
      current: '1.7.0',
      hasData: () async => data,
      fetch: (v) async {
        fetched.add(v);
        if (offline) throw const WebUnavailableException('x');
        return remote;
      },
    );
  }

  UpdateInfo info(String notes, {String v = '1.7.0'}) => UpdateInfo(version: v, url: 'https://x/rel', notes: notes);

  test('after an update with saved notes: shown, last seen is the running version, not shown again', () async {
    final w = await make({lastSeenVersionKey: '1.6.0'});
    await saveNewVersionNotes(store, info(_block));
    expect((await w.atStart())!.version, '1.7.0');
    expect(store.readLastSeenVersion(), '1.7.0');
    expect(await w.atStart(), isNull);
    expect(fetched, isEmpty);
  });

  test('first install (no key, no data): no page, key written', () async {
    final w = await make({}, data: false, remote: info(_block));
    expect(await w.atStart(), isNull);
    expect(store.readLastSeenVersion(), '1.7.0');
    expect(fetched, isEmpty);
  });

  test('update from a version without the key, data present: the page', () async {
    final w = await make({}, remote: info(_block));
    expect(await w.atStart(), isNotNull);
    expect(store.readLastSeenVersion(), '1.7.0');
  });

  test('notes missing: one read of the release; offline, error or no block: no page', () async {
    var w = await make({lastSeenVersionKey: '1.6.0'}, remote: info(_block));
    expect(await w.atStart(), isNotNull);
    expect(fetched, ['1.7.0']);
    for (final args in [
      (offline: true, remote: null),
      (offline: false, remote: null),
      (offline: false, remote: info("## What's Changed\n* feat(1): x")),
    ]) {
      final c = await make({lastSeenVersionKey: '1.6.0'}, offline: args.offline, remote: args.remote);
      expect(await c.atStart(), isNull);
      expect(store.readLastSeenVersion(), '1.7.0', reason: 'decided all the same');
    }
    w = await make({lastSeenVersionKey: '1.6.0'});
    await saveNewVersionNotes(store, info(_block, v: '1.8.0'));
    await w.atStart();
    expect(fetched, ['1.7.0'], reason: 'notes of another version are not used');
  });

  test('a check that finds a newer version saves its notes', () async {
    await make({});
    final body = [{'tag_name': 'v9.0.0', 'html_url': 'https://x/9', 'body': _block}];
    final checker = UpdateChecker(_Web(body), repo: 'me/r', current: '1.7.0', onNewer: (i) => saveNewVersionNotes(store, i));
    await checker.check();
    expect(store.readNewVersionNotes(), contains('"version":"9.0.0"'));
  });

  test('a restore sets last seen to the running version: no page', () async {
    final w = await make({lastSeenVersionKey: '1.7.0'}, remote: info(_block));
    expect(await w.atStart(), isNull);
  });
}
