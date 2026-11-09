import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/shuffle_plus/dislike_store.dart';
import 'dislike_store_provider.dart';

typedef DislikeLists = ({
  List<DislikedTrack> tracks,
  List<DislikedArtist> artists,
});

/// The blocked songs and artists, newest first, refreshed on every change of the store.
final dislikeListsProvider = StreamProvider.autoDispose<DislikeLists>((ref) async* {
  final store = ref.watch(dislikeStoreProvider);
  DislikeLists snapshot() => (tracks: store.tracks, artists: store.artists);
  // Listen before the first snapshot so no change is lost; the stream is cancelled with the provider.
  final changes = StreamController<void>();
  final sub = store.changes.listen(changes.add);
  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(changes.close());
  });
  await store.load();
  yield snapshot();
  await for (final _ in changes.stream) {
    yield snapshot();
  }
});
