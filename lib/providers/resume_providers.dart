import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/home_sections.dart';
import '../data/repositories/library_queries.dart';
import 'library_providers.dart';
import 'player_providers.dart';
import 'radio_providers.dart';

final lastPlaysProvider = StreamProvider.autoDispose<List<LastPlay>>(
  (ref) => ref.watch(libraryQueriesProvider).watchLastPlayPerContext(),
);

/// Home «Riprendi»: the latest item of each area.
final resumeItemsProvider = Provider.autoDispose<List<ResumeItem>>((ref) {
  final source = ref.watch(playContextProvider);
  return lastPerArea(
    current: ref.watch(currentTrackProvider).value,
    queue: ref.watch(queueProvider).value ?? const [],
    queueKind: source?.kind,
    plays: [
      for (final p in ref.watch(lastPlaysProvider).value ?? const <LastPlay>[])
        (kind: PlayContextKind.fromIndex(p.context), track: p.track, at: p.at, name: p.contextName),
    ],
    resumable: ref.watch(resumableTracksProvider).value ?? const [],
    entries: ref.watch(recentEntriesProvider),
    radios: ref.watch(savedRadiosProvider).value ?? const [],
  );
});
