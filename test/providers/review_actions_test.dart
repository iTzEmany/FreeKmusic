import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/review_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeJob extends EnrichJobNotifier {
  _FakeJob(this.busy);
  final bool busy;
  List<int>? started;

  @override
  EnrichJobState build() => EnrichJobState(running: busy);

  @override
  bool start(List<int> ids, {void Function()? onFinished}) {
    if (busy) return false;
    started = ids;
    return true;
  }
}

void main() {
  late AppDatabase db;
  late SettingsStore store;
  late int id;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await SettingsStore.open();
    db = AppDatabase(NativeDatabase.memory());
    id = await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: '/a.mp3',
            title: 'A',
            albumKey: 'a',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            enrichStatus: const Value(2),
          ),
        );
  });
  tearDown(() => db.close());

  ProviderContainer container(_FakeJob job) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(store),
        enrichJobProvider.overrideWith(() => job),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<int> status() async =>
      (await db.select(db.tracks).getSingle()).enrichStatus;

  test('«Riprova» starts the manual enrichment without touching the status', () async {
    final job = _FakeJob(false);
    final r = await container(job).read(reviewActionsProvider).retry({id});
    expect(r, ReviewRetryResult.started);
    expect(await status(), 2);
    expect(job.started, [id]);
  });

  test('«Riprova» does nothing while another enrichment runs', () async {
    final job = _FakeJob(true);
    final r = await container(job).read(reviewActionsProvider).retry({id});
    expect(r, ReviewRetryResult.busy);
    expect(await status(), 2);
  });

  test('«Va bene così» persists in the settings', () async {
    await container(_FakeJob(false)).read(reviewActionsProvider).dismiss({id});
    expect(store.readReviewDismissed(), {id});
    final again = container(_FakeJob(false));
    expect(again.read(reviewDismissedProvider), {id});
  });

  test('undismiss brings the track back', () async {
    final c = container(_FakeJob(false));
    await c.read(reviewActionsProvider).dismiss({id});
    await c.read(reviewActionsProvider).undismiss({id});
    expect(store.readReviewDismissed(), isEmpty);
  });
}
