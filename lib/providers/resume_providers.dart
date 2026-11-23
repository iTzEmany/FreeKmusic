import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/home_sections.dart';
import '../data/repositories/library_queries.dart';
import 'library_providers.dart';
import 'player_providers.dart';
import 'radio_providers.dart';

final lastPlaysProvider = StreamProvider.autoDispose<List<LastPlay>>(
  (ref) => ref.watch(libraryQueriesProvider).watchLastPlayPerContext(),
);

/// The area a play context belongs to; albums and playlists are read from the
/// library (their last play), radio from the stations. A kind from a newer
/// version reads as the library.
ResumeArea? resumeAreaOf(PlayContextKind kind) => switch (kind) {
  PlayContextKind.album ||
  PlayContextKind.playlist ||
  PlayContextKind.radio => null,
  PlayContextKind.podcast => ResumeArea.podcast,
  PlayContextKind.daylist => ResumeArea.daylist,
  _ => ResumeArea.track,
};

/// Home «Riprendi»: the latest item of each area.
final resumeItemsProvider = Provider.autoDispose<List<ResumeItem>>((ref) {
  final source = ref.watch(playContextProvider);
  ResumeArea? area(int? raw) {
    final known =
        raw != null && raw >= 0 && raw < PlayContextKind.values.length;
    return resumeAreaOf(
      known ? PlayContextKind.values[raw] : PlayContextKind.library,
    );
  }

  return lastPerArea(
    current: ref.watch(currentTrackProvider).value,
    queue: ref.watch(queueProvider).value ?? const [],
    queueArea: source == null
        ? null
        : switch (source.kind) {
            PlayContextKind.album => ResumeArea.album,
            PlayContextKind.playlist => ResumeArea.playlist,
            PlayContextKind.radio => ResumeArea.radio,
            final k => resumeAreaOf(k),
          },
    plays: [
      for (final p in ref.watch(lastPlaysProvider).value ?? const <LastPlay>[])
        if (area(p.context) case final a?) (area: a, track: p.track, at: p.at),
    ],
    resumable: ref.watch(resumableTracksProvider).value ?? const [],
    entries: ref.watch(recentEntriesProvider),
    radios: ref.watch(savedRadiosProvider).value ?? const [],
  );
});
