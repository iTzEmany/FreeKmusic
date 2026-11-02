import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/paths.dart';
import '../services/shuffle_plus/seed_index.dart';

import '../services/shuffle_plus/seed_resolver.dart';
import 'youtube_providers.dart';

final seedIndexProvider = Provider<SeedIndex>((ref) {
  final index = SeedIndex(
    file: () async => File(p.join(await appSupportDir(), 'seed_ids.json')),
  );
  ref.onDispose(() => unawaited(index.flush()));
  return index;
});

/// Finds the YouTube Music id of a library track (also for a remote Jam guest, R-152).
final seedResolverProvider = FutureProvider<SeedResolver>(
  (ref) async => SeedResolver(
    downloads: await ref.watch(downloadIndexProvider.future),
    index: ref.watch(seedIndexProvider),
    searchSongs: (q) => ref.read(youtubeServiceProvider).searchSongs(q),
  ),
);
