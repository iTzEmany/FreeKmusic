import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/services/update/whats_new.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _block = '## Novità\n- evidenza | mic | Karaoke | Testo.';

void main() {
  late SettingsStore store;
  late List<String> loaded;

  Future<WhatsNew> make(Map<String, Object> prefs, {bool data = true, String? notes = _block, bool throws = false}) async {
    SharedPreferences.setMockInitialValues(prefs);
    store = await SettingsStore.open();
    loaded = [];
    return WhatsNew(
      store,
      current: '1.7.0',
      url: 'https://x/rel',
      hasData: () async => data,
      load: (v) async {
        loaded.add(v);
        if (throws) throw Exception('no such asset');
        return notes;
      },
    );
  }

  test('after an update: shown, last seen is the running version, not shown again', () async {
    final w = await make({lastSeenVersionKey: '1.6.0'});
    expect((await w.atStart())!.version, '1.7.0');
    expect(store.readLastSeenVersion(), '1.7.0');
    expect(await w.atStart(), isNull);
    expect(loaded, ['1.7.0']);
  });

  test('last seen key present (older version) with an empty library: the page', () async {
    final w = await make({lastSeenVersionKey: '1.6.0'}, data: false);
    expect(await w.atStart(), isNotNull);
  });

  test('first install (no key, no data): no page, key written', () async {
    final w = await make({}, data: false);
    expect(await w.atStart(), isNull);
    expect(store.readLastSeenVersion(), '1.7.0');
    expect(loaded, isEmpty);
  });

  test('update from a version without the key, data present: the page', () async {
    final w = await make({});
    expect(await w.atStart(), isNotNull);
    expect(store.readLastSeenVersion(), '1.7.0');
  });

  test('missing file, unreadable file or no block: no page, decided all the same', () async {
    for (final c in [
      await make({lastSeenVersionKey: '1.6.0'}, throws: true),
      await make({lastSeenVersionKey: '1.6.0'}, notes: null),
      await make({lastSeenVersionKey: '1.6.0'}, notes: "## What's Changed\n* feat(1): x"),
    ]) {
      expect(await c.atStart(), isNull);
    }
    expect(store.readLastSeenVersion(), '1.7.0');
  });

  test('downgrade (last seen newer than running): no page, key unchanged', () async {
    final w = await make({lastSeenVersionKey: '1.8.0'});
    expect(await w.atStart(), isNull);
    expect(store.readLastSeenVersion(), '1.8.0');
    expect(loaded, isEmpty);
  });

  test('«Novità della versione» without a file: the page with the link and no notes', () async {
    final w = await make({}, throws: true);
    final i = await w.notes();
    expect((i.version, i.notes, i.url), ('1.7.0', '', 'https://x/rel'));
  });
}
