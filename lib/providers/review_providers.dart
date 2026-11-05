import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/review_queries.dart';
import '../data/db/app_database.dart';
import 'database_providers.dart';
import 'online_providers.dart';
import 'second_opinion_providers.dart';
import 'settings_providers.dart';

final reviewQueriesProvider = Provider<ReviewQueries>(
  (ref) => ReviewQueries(ref.watch(databaseProvider)),
);

/// The tracks the user dismissed with «Va bene così», kept in the settings.
class ReviewDismissedNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => ref.read(settingsStoreProvider).readReviewDismissed();

  Future<void> add(Set<int> ids) async {
    state = {...state, ...ids};
    await ref.read(settingsStoreProvider).writeReviewDismissed(state);
  }

  Future<void> remove(Set<int> ids) async {
    state = state.difference(ids);
    await ref.read(settingsStoreProvider).writeReviewDismissed(state);
  }
}

final reviewDismissedProvider =
    NotifierProvider<ReviewDismissedNotifier, Set<int>>(
      ReviewDismissedNotifier.new,
    );

/// The tracks to review (see [ReviewQueries]), minus the dismissed ones.
final reviewTracksProvider = StreamProvider.autoDispose<List<Track>>(
  (ref) => ref
      .watch(reviewQueriesProvider)
      .watch(dismissed: ref.watch(reviewDismissedProvider)),
);

/// Only the number, for the Library entry.
final reviewCountProvider = StreamProvider.autoDispose<int>(
  (ref) => ref
      .watch(reviewQueriesProvider)
      .watchCount(dismissed: ref.watch(reviewDismissedProvider)),
);

enum ReviewRetryResult { started, busy }

class ReviewActions {
  ReviewActions(this._ref);

  final Ref _ref;

  /// «Riprova»: the manual enrichment job (the same as «Arricchisci») asks the
  /// online sources again, even for tracks it gave up on; then YouTube Music
  /// gives its second opinion on the ones that still have holes.
  Future<ReviewRetryResult> retry(Set<int> ids) async {
    if (_ref.read(enrichJobProvider).running ||
        _ref.read(secondOpinionJobProvider).running) {
      return ReviewRetryResult.busy;
    }
    final list = ids.toList();
    final started = _ref.read(enrichJobProvider.notifier).start(
          list,
          onFinished: () => unawaited(
              _ref.read(secondOpinionJobProvider.notifier).run(list, force: true)),
        );
    return started ? ReviewRetryResult.started : ReviewRetryResult.busy;
  }

  /// On opening the list: the second opinion on the tracks never checked.
  Future<void> secondOpinionOnOpen() async {
    if (_ref.read(enrichJobProvider).running) return;
    final list = await _ref.read(reviewTracksProvider.future);
    await _ref
        .read(secondOpinionJobProvider.notifier)
        .run([for (final t in list) t.id]);
  }

  Future<void> dismiss(Set<int> ids) =>
      _ref.read(reviewDismissedProvider.notifier).add(ids);

  Future<void> undismiss(Set<int> ids) =>
      _ref.read(reviewDismissedProvider.notifier).remove(ids);
}

final reviewActionsProvider = Provider<ReviewActions>(ReviewActions.new);
