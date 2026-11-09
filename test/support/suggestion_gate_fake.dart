import 'dart:io';

import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:codecore/services/shuffle_plus/suggestion_gate.dart';

/// A gate over an empty store (nothing blocked), or with [tracks]/[artists] blocked.
SuggestionGate testGate({
  List<String> tracks = const [],
  List<String> artists = const [],
}) {
  final store = DislikeStore(
    file: () async => File('/nonexistent/dislikes.json'),
  );
  for (final t in tracks) {
    store.blockTrack(DislikedTrack(videoId: t, title: t, artist: ''));
  }
  for (final a in artists) {
    store.blockArtist(DislikedArtist(key: a, name: a));
  }
  return SuggestionGate(store);
}
