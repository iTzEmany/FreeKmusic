import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/repositories/filter_counts_repository.dart';
import 'database_providers.dart';

final filterCountsRepositoryProvider = Provider<FilterCountsRepository>(
  (ref) => FilterCountsRepository(ref.watch(databaseProvider)),
);

/// A whole list of the editor, loaded once (not per keystroke) and kept for a
/// while after the last listener so typing in the search does not reload it.
final filterListProvider = FutureProvider.autoDispose.family<List<KeyedCount>, FilterList>((ref, list) {
  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() => timer = Timer(const Duration(seconds: 30), link.close));
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
  return ref.watch(filterCountsRepositoryProvider).load(list);
});

/// Values of one editor list with their counts, filtered in memory by a text query.
final filterValueCountsProvider =
    FutureProvider.autoDispose.family<List<ValueCount>, ({FilterList list, String query})>((ref, a) async {
  final all = await ref.watch(filterListProvider(a.list).future);
  return [for (final k in FilterCountsRepository.filterKeyed(all, a.query)) k.value];
});

/// Live count of a rule, capped by the limit. Debounced: a request that is
/// replaced before the delay ends never runs (its provider is disposed).
final liveRuleCountProvider =
    FutureProvider.autoDispose.family<int, ({String rules, int? limit})>((ref, a) async {
  var gone = false;
  ref.onDispose(() => gone = true);
  await Future<void>.delayed(kInputDebounce);
  if (gone) return 0;
  final n = await ref.read(smartPlaylistRepositoryProvider).count(a.rules);
  final limit = a.limit;
  return limit != null && n > limit ? limit : n;
});

