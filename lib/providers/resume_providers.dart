import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/home_sections.dart';
import '../data/repositories/library_queries.dart';
import 'daylist_providers.dart';
import 'library_providers.dart';
import 'player_providers.dart';
import 'radio_providers.dart';

final lastPlaysProvider = StreamProvider.autoDispose<List<LastPlay>>(
  (ref) => ref.watch(libraryQueriesProvider).watchLastPlayPerContext(),
);

/// Home «Riprendi» (phone and desktop): the latest distinct things played, mixed (D-725).
final resumeItemsProvider = Provider.autoDispose<List<ResumeItem>>((ref) {
  final source = ref.watch(playContextProvider);
  return recentResumeItems(
    current: ref.watch(currentTrackProvider).value,
    queue: ref.watch(queueProvider).value ?? const [],
    queueKind: source?.kind,
    plays: [
      for (final p in ref.watch(lastPlaysProvider).value ?? const <LastPlay>[])
        (
          kind: PlayContextKind.fromIndex(p.context),
          track: p.track,
          at: p.at,
          name: p.contextName,
        ),
    ],
    resumable: ref.watch(resumableTracksProvider).value ?? const [],
    entries: ref.watch(recentEntriesProvider),
    radios: ref.watch(savedRadiosProvider).value ?? const [],
    // The daylist card of Home already says it (F-17).
    daylist: ref.watch(daylistVisibleProvider)?.result.tooFew ?? true,
  );
});
