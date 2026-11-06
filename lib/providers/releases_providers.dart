import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform.dart';
import '../data/db/app_database.dart' show ArtistLookup;
import '../data/repositories/follow_repository.dart';
import '../services/android/release_notifier.dart';
import '../data/settings/settings_store.dart' show SettingsStore;
import '../data/repositories/release_repository.dart';
import '../data/repositories/stats_queries.dart';
import '../services/releases/auto_follow_service.dart';
import '../services/releases/release_check_controller.dart';
import '../services/releases/release_checker.dart';
import 'database_providers.dart';
import 'settings_providers.dart';
import 'shuffle_plus_providers.dart' show networkProbeProvider;
import 'startup_providers.dart';
import 'ytm_catalog_providers.dart';

final followRepositoryProvider = Provider<FollowRepository>(
  (ref) => FollowRepository(ref.watch(databaseProvider)),
);

final releaseRepositoryProvider = Provider<ReleaseRepository>(
  (ref) => ReleaseRepository(ref.watch(databaseProvider)),
);

/// Followed and automatic artists (not the excluded), by name.
final followedArtistsProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(followRepositoryProvider).watchFollowed(),
);

/// Whether the artist with this `UC…` id is followed.
final isFollowedProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.watch(followRepositoryProvider).watchIsFollowed(id),
);

/// Releases flagged new in the last 30 days (Home); 90 for the full page.
final recentReleasesProvider = StreamProvider.autoDispose
    .family<List<RecentRelease>, int>(
      (ref, days) =>
          ref.watch(releaseRepositoryProvider).watchRecent(days: days),
    );

final newReleasesCountProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(releaseRepositoryProvider).watchCountNew(),
);

/// A round of checks reading the artist pages in [hl]'s language.
final releaseCheckerProvider = Provider.family<ReleaseChecker, String>((
  ref,
  hl,
) {
  final catalog = ref.watch(ytmCatalogProvider);
  return ReleaseChecker(
    (id) => catalog.releases(id, hl),
    ref.watch(followRepositoryProvider),
    ref.watch(releaseRepositoryProvider),
  );
});

final autoFollowServiceProvider = Provider.family<AutoFollowService, String>((
  ref,
  hl,
) {
  final catalog = ref.watch(ytmCatalogProvider);
  return AutoFollowService(
    stats: StatsQueries(ref.watch(databaseProvider)),
    follows: ref.watch(followRepositoryProvider),
    search: (name) => catalog.searchArtists(name, hl),
    aliases: ref.watch(artistAliasRepositoryProvider),
  );
});

/// The Android notification for new releases (channel `codecore/notify`).
final releaseNotifierProvider = Provider<ReleaseNotifier>(
  (ref) => ReleaseNotifier(),
);

/// Receives the new releases of artists that are not muted, at most once a
/// day: on Android it shows the notification, elsewhere nothing happens.
final releaseNotifyHookProvider = Provider<ReleaseNotifyHook>((ref) {
  if (!isAndroid) return (_) async {};
  return releaseNotifyHookFor(
      ref.watch(releaseNotifierProvider), () => ref.read(settingsProvider).language);
});

/// Where a tap on the notification wants the app to go (`releases`), from the
/// start and from the background. Never emits off Android.
final launchTargetProvider = StreamProvider<String>(
  (ref) => isAndroid
      ? ref.watch(releaseNotifierProvider).targets()
      : const Stream<String>.empty(),
);

/// True while «Controlla ora» runs: it shows in the Activity centre.
class ManualReleaseCheck extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

final manualReleaseCheckProvider = NotifierProvider<ManualReleaseCheck, bool>(
  ManualReleaseCheck.new,
);

/// Most listened names that matched more than one artist («Da confermare»).
final pendingArtistsProvider = FutureProvider.autoDispose<List<ArtistLookup>>(
  (ref) => ref.watch(followRepositoryProvider).pendingLookups(),
);

/// Runs the rounds of release checks: 30 s after the app has settled, then
/// every hour it looks whether one is due. Watch it once from the app root.
final releaseCheckControllerProvider = Provider<ReleaseCheckController>((ref) {
  final probe = ref.watch(networkProbeProvider);
  final c = ReleaseCheckController(
    store: ref.watch(settingsStoreProvider),
    follows: ref.watch(followRepositoryProvider),
    network: probe.current,
    networkChanges: probe.changes,
    buildChecker: () =>
        ref.read(releaseCheckerProvider(ref.read(ytmLanguageProvider))),
    autoFollow: () => ref
        .read(autoFollowServiceProvider(ref.read(ytmLanguageProvider)))
        .run(),
    notify: (fresh) => ref.read(releaseNotifyHookProvider)(fresh),
  );
  ref.onDispose(c.dispose);
  ref.read(startupSettledProvider.future).then((_) => c.start());
  return c;
});

class ReleaseOptions {
  const ReleaseOptions({
    this.topArtists = false,
    this.notify = true,
    this.unmeteredOnly = false,
    this.topCardSeen = false,
  });

  final bool topArtists, notify, unmeteredOnly, topCardSeen;
}

/// The options of «Nuove uscite» (Impostazioni → Online and the Home card).
class ReleaseOptionsNotifier extends Notifier<ReleaseOptions> {
  @override
  ReleaseOptions build() {
    final s = ref.read(settingsStoreProvider);
    return ReleaseOptions(
      topArtists: s.releasesTopArtists,
      notify: s.releasesNotify,
      unmeteredOnly: s.releasesUnmeteredOnly,
      topCardSeen: s.releasesTopCardSeen,
    );
  }

  SettingsStore get _store => ref.read(settingsStoreProvider);

  /// Turning it on follows the most listened artists right away (a round now).
  Future<void> setTopArtists(bool on) async {
    state = ReleaseOptions(
      topArtists: on,
      notify: state.notify,
      unmeteredOnly: state.unmeteredOnly,
      topCardSeen: true,
    );
    await _store.writeReleasesTopArtists(on);
    await _store.writeReleasesTopCardSeen(true);
    if (on) unawaited(ref.read(releaseCheckControllerProvider).checkNow());
  }

  Future<void> setNotify(bool on) async {
    state = ReleaseOptions(
      topArtists: state.topArtists,
      notify: on,
      unmeteredOnly: state.unmeteredOnly,
      topCardSeen: state.topCardSeen,
    );
    await _store.writeReleasesNotify(on);
  }

  Future<void> setUnmeteredOnly(bool on) async {
    state = ReleaseOptions(
      topArtists: state.topArtists,
      notify: state.notify,
      unmeteredOnly: on,
      topCardSeen: state.topCardSeen,
    );
    await _store.writeReleasesUnmeteredOnly(on);
    await ref.read(releaseCheckControllerProvider).optionsChanged();
  }

  /// «No, grazie» on the Home card.
  Future<void> dismissTopCard() async {
    state = ReleaseOptions(
      topArtists: state.topArtists,
      notify: state.notify,
      unmeteredOnly: state.unmeteredOnly,
      topCardSeen: true,
    );
    await _store.writeReleasesTopCardSeen(true);
  }
}

final releaseOptionsProvider =
    NotifierProvider<ReleaseOptionsNotifier, ReleaseOptions>(
      ReleaseOptionsNotifier.new,
    );
