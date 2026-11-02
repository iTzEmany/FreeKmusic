import 'dart:async';

import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/enrich_completer_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/startup_providers.dart';
import 'package:codecore/providers/user_activity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codecore/services/recognition/track_identity.dart' show kRecogVersion;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/enrich_fakes.dart';

class _Settings extends SettingsNotifier {
  _Settings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;

  void put(AppSettings s) => state = s;
}

class _Scan extends ScanNotifier {
  void running(bool v) => state = ScanState(running: v);
}

void main() {
  late EnrichRig r;
  late ProviderContainer c;

  Future<void> open({AppSettings? settings}) async {
    SharedPreferences.setMockInitialValues({'recogPassDone': kRecogVersion}); // the re-pass is a test of its own
    final store = SettingsStore(await SharedPreferences.getInstance());
    r = EnrichRig();
    addTearDown(r.dispose);
    c = _container(r, store, settings);
    addTearDown(c.dispose);
    await r.add(path: '/a.mp3');
    // The start provider wires the Registro; the run itself never reads it.
    c.listen(enrichCompleterStartProvider, (_, _) {});
  }

  Future<void> lineWritten() async {
    for (var i = 0; i < 300; i++) {
      if ((await r.db.select(r.db.activityLogRows).get()).isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('no line in the Registro');
  }

  test('a scan that ends starts the completion, with the real providers', () async {
    await open();
    final scan = c.read(scanStateProvider.notifier) as _Scan;
    scan.running(true);
    scan.running(false);
    await lineWritten();
  });

  test('a switch turned on starts the completion, with the real providers', () async {
    await open(settings: AppSettings());
    (c.read(settingsProvider.notifier) as _Settings).put(AppSettings(autoLyrics: true));
    await lineWritten();
  });

  test('the line of the round reaches the Registro with the real activity list', () async {
    await open();
    await c.read(enrichCompleterProvider.notifier).start();
    final rows = await r.db.select(r.db.activityLogRows).get();
    expect(rows.single.kind, 'enrichBackground');
  });

  test('a round that lost every write leaves a failed line', () async {
    await open();
    await r.add(path: '/b.mp3');
    await r.add(path: '/c.mp3');
    await r.db.customStatement(
      "CREATE TRIGGER boom BEFORE UPDATE ON tracks BEGIN SELECT RAISE(ABORT,'boom'); END",
    );
    await c.read(enrichCompleterProvider.notifier).start();
    final rows = await r.db.select(r.db.activityLogRows).get();
    expect(rows.single.kind, 'enrichBackground');
    expect(rows.single.failed, isNot(0));
    expect(rows.single.detail, isNot(contains('noAnswer')));
  });
}

ProviderContainer _container(EnrichRig r, SettingsStore store, AppSettings? settings) =>
    ProviderContainer(
      overrides: [
        scanStateProvider.overrideWith(_Scan.new),
        settingsStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWithValue(r.db),
        enrichEngineProvider.overrideWithValue(r.engine),
        creditsRepositoryProvider.overrideWithValue(r.credits),
        settingsProvider.overrideWith(
          () => _Settings(settings ?? AppSettings(autoLyrics: true)),
        ),
        userActivityProvider.overrideWithValue(UserActivity()),
        // Never settles: the starts under test are the scan and the switch.
        startupSettledProvider.overrideWith((ref) => Completer<void>().future),
      ],
    );
