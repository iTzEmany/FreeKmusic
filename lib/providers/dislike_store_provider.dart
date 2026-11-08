import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/paths.dart';
import '../services/shuffle_plus/dislike_store.dart';
import '../services/shuffle_plus/suggestion_gate.dart';
import 'suggestion_log_provider.dart';

/// `dislikes.json`: songs and artists marked «Non mi piace». A leaf file.
/// Readers `await store.load()`; that also waits for the one-time import of
/// the old `disliked` records of the suggestion log.
final dislikeStoreProvider = Provider<DislikeStore>((ref) {
  final store = DislikeStore(file: () async => File(p.join(await appSupportDir(), 'dislikes.json')));
  unawaited(store.migrateFrom(ref.watch(suggestionLogProvider)));
  ref.onDispose(() => unawaited(store.flush()));
  return store;
});

/// The «Non mi piace» filter of every suggestion source (101.2).
final suggestionGateProvider = Provider<SuggestionGate>(
  (ref) => SuggestionGate(ref.watch(dislikeStoreProvider)),
);
