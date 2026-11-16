import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform.dart';
import '../services/android/media_deleter.dart';
import '../services/library/free_space.dart';
import 'database_providers.dart';
import 'youtube_providers.dart' show downloadIndexProvider;

/// «Libera spazio»: converts downloads back to streams and deletes the files.
final freeSpaceServiceProvider = FutureProvider<FreeSpaceService>(
  (ref) async => FreeSpaceService(
    tracks: ref.watch(trackRepositoryProvider),
    index: await ref.watch(downloadIndexProvider.future),
    platform: isAndroid ? deleteWithSystemDialog : null,
  ),
);
