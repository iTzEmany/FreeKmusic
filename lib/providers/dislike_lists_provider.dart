import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/shuffle_plus/dislike_store.dart';
import 'dislike_store_provider.dart';

typedef DislikeLists = ({
  List<DislikedTrack> tracks,
  List<DislikedArtist> artists,
});

/// The blocked songs and artists, newest first, refreshed on every change of the store.
final dislikeListsProvider = StreamProvider.autoDispose<DislikeLists>((
  ref,
) async* {
  final store = ref.watch(dislikeStoreProvider);
  await store.load();
  DislikeLists snapshot() => (tracks: store.tracks, artists: store.artists);
  yield snapshot();
  await for (final _ in store.changes) {
    yield snapshot();
  }
});
