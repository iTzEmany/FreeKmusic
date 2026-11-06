import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/repositories/track_genre_repository.dart';
import '../services/tags/genre_reread.dart';
import 'activity_log_providers.dart';
import 'activity_providers.dart';
import 'database_providers.dart';
import 'player_providers.dart' show isPlayingProvider;
import 'library_providers.dart' show scanStateProvider, tagReaderProvider;
import 'settings_providers.dart';
import 'startup_providers.dart' show startupSettledProvider;
import 'user_activity_provider.dart';

/// How long the user must leave the app alone before the next batch (as the enrichment).
const _idleFor = Duration(seconds: 5);

/// How often the re-read looks again while paused; tests shorten it.
final genreRereadPollProvider = Provider<Duration>((ref) => const Duration(seconds: 1));

/// Reads the tags of the existing library again for their genres (D-390), once the app
/// has settled and no scan runs, a batch at a time while the user leaves the app alone.
/// The bookmark is in the preferences, so a closed app carries on at the next start.
/// Watched from the app's root.
final genreRereadStartProvider = Provider<void>((ref) {
  var disposed = false;
  var running = false;
  ref.onDispose(() => disposed = true);
  final activity = ref.watch(userActivityProvider);
  final settings = ref.read(settingsStoreProvider);

  Future<void> waitIdle() async {
    // Paused while music plays too (D-390), not only while the user is busy.
    while (!disposed && (!activity.idleFor(_idleFor) || ref.read(isPlayingProvider).value == true)) {
      await Future<void>.delayed(ref.read(genreRereadPollProvider));
    }
  }

  void saved(Future<void> f) => unawaited(
    f.catchError((Object e, StackTrace st) {
      AppLog.w('genre re-read: mark not saved', e, st);
    }),
  );

  Future<void> run() async {
    if (running || disposed || settings.genreRereadDone >= kGenreRereadVersion) return;
    running = true;
    try {
      final report = await GenreReread(
        genres: TrackGenreRepository(ref.read(databaseProvider)),
        reader: ref.read(tagReaderProvider),
        waitIdle: waitIdle,
        loadAfter: () => settings.genreRereadAfter,
        saveAfter: (id) => saved(settings.writeGenreRereadAfter(id)),
        markDone: () => saved(settings.writeGenreRereadDone(kGenreRereadVersion)),
        cancelled: () => disposed,
      ).run();
      AppLog.i('genre re-read: ${report.read} tracks, ${report.changed} changed, finished ${report.finished}');
      if (report.read == 0 || disposed) return;
      await ref.read(activityLogProvider.notifier).add(
        LogEntry(
          at: DateTime.now(),
          item: ActivityItem(
            kind: ActivityKind.genreReread,
            key: 'genreReread-${DateTime.now().microsecondsSinceEpoch}',
            name: null,
            done: report.changed,
            total: report.read,
            running: false,
          ),
          detail: {if (!report.finished) 'stopped': true},
        ),
      );
    } on Object catch (e, st) {
      AppLog.w('genre re-read failed, will carry on at the next start', e, st);
    } finally {
      running = false;
    }
  }

  ref.listen(scanStateProvider.select((s) => s.running), (was, now) {
    if (was == true && !now) unawaited(run());
  });
  ref.read(startupSettledProvider.future).then((_) {
    if (!disposed && !ref.read(scanStateProvider).running) unawaited(run());
  });
});
