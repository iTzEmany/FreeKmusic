import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform.dart';
import '../services/android/media_deleter.dart';
import '../services/library/track_deleter.dart';
import 'database_providers.dart';
import 'player_providers.dart';
import 'youtube_providers.dart' show downloadIndexProvider;

/// «Elimina dal dispositivo». Tests replace it with a fake file system.
final trackDeleterProvider = Provider<TrackDeleter>(
  (ref) => TrackDeleter(
    tracks: ref.watch(trackRepositoryProvider),
    removeFromQueue: ref.read(playerControllerProvider).removeTracks,
    db: ref.watch(databaseProvider),
    platform: isAndroid ? deleteWithSystemDialog : null,
    onDeleted: () => ref.invalidate(downloadIndexProvider),
  ),
);
