import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/repositories/artist_country_repository.dart';
import '../services/online/artist_country_finder.dart';
import '../services/online/musicbrainz_client.dart' show WikidataClient;
import 'activity_log_providers.dart';
import 'activity_providers.dart';
import 'database_providers.dart';
import 'jam_providers.dart';
import 'library_providers.dart' show scanStateProvider;
import 'online_providers.dart';
import 'settings_providers.dart';
import 'shuffle_plus_providers.dart' show networkProbeProvider, shufflePlusMeteredProvider;
import 'startup_providers.dart' show startupSettledProvider;
import 'user_activity_provider.dart';

/// How long the user must leave the app alone before the next batch (as the enrichment).
const _idleFor = Duration(seconds: 5);

/// Looks up the country of the library's artists in the background (D-390, D-421). It asks
/// the web only while the enrichment is on (some part of `autoParts`; off by default), the
/// network is not metered and no Jam is going. Starts once the app has settled and again when
/// a scan ends, a switch of the enrichment changes, a Jam ends or the network changes.
/// Watched from the app's root.
final artistCountryStartProvider = Provider<void>((ref) {
  var disposed = false;
  var running = false;
  ref.onDispose(() => disposed = true);
  final activity = ref.watch(userActivityProvider);

  Future<void> waitIdle() async {
    while (!disposed && !activity.idleFor(_idleFor)) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<bool> allowed() async =>
      !disposed &&
      await artistCountryAllowed(
        enrichmentOn: autoParts(ref.read(settingsProvider)).isNotEmpty,
        jamActive: ref.read(jamProvider).active,
        meteredOrOffline: ref.read(shufflePlusMeteredProvider),
      );

  Future<void> run() async {
    if (disposed) return;
    if (running) return;
    running = true;
    try {
      if (!await allowed()) return;
      final report = await ArtistCountryFinder(
        repo: ArtistCountryRepository(ref.read(databaseProvider)),
        mb: ref.read(musicBrainzClientProvider),
        wikidata: WikidataClient(ref.read(webClientProvider)),
        allowed: allowed,
        waitIdle: waitIdle,
        cancelled: () => disposed,
      ).run();
      AppLog.i('artist countries: ${report.checked} checked, ${report.found} found, stopped ${report.stopped}');
      if (report.checked == 0 || disposed) return;
      await ref.read(activityLogProvider.notifier).add(
        LogEntry(
          at: DateTime.now(),
          item: ActivityItem(
            kind: ActivityKind.artistCountries,
            key: 'artistCountries-${DateTime.now().microsecondsSinceEpoch}',
            name: null,
            done: report.found,
            total: report.checked,
            running: false,
          ),
          detail: {if (report.stopped) 'stopped': true},
        ),
      );
    } on Object catch (e, st) {
      AppLog.w('artist countries failed, will carry on at the next trigger', e, st);
    } finally {
      running = false;
    }
  }

  ref.listen(scanStateProvider.select((s) => s.running), (was, now) {
    if (was == true && !now) unawaited(run());
  });
  ref.listen(settingsProvider.select((s) => autoParts(s).map((p) => p.name).join(',')), (_, _) => unawaited(run()));
  ref.listen(jamProvider.select((s) => s.active), (was, now) {
    if (was == true && !now) unawaited(run());
  });
  final net = ref.watch(networkProbeProvider).changes.listen((_) => unawaited(run()));
  ref.onDispose(net.cancel);
  ref.read(startupSettledProvider.future).then((_) {
    if (!disposed && !ref.read(scanStateProvider).running) unawaited(run());
  });
});
