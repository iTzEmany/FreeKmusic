import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/filter_counts_repository.dart';
import 'database_providers.dart';

final filterCountsRepositoryProvider = Provider<FilterCountsRepository>(
  (ref) => FilterCountsRepository(ref.watch(databaseProvider), ref.watch(trackRepositoryProvider)),
);

/// Values of one editor list with their counts, filtered by a text query.
final filterValueCountsProvider =
    FutureProvider.autoDispose.family<List<ValueCount>, ({FilterList list, String query})>(
  (ref, a) => ref.watch(filterCountsRepositoryProvider).counts(a.list, query: a.query),
);

/// Live count of a rule (debounced); null while superseded by a newer request.
final liveRuleCountProvider =
    FutureProvider.autoDispose.family<int?, ({String rules, int? limit})>(
  (ref, a) => ref.watch(filterCountsRepositoryProvider).liveCount(a.rules, limit: a.limit),
);
