import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../services/library/rules/rule_parser.dart' show hasOperators;
import '../services/online/credits.dart';
import 'library_providers.dart';
import 'online_providers.dart';

typedef TrackCreditsData = ({List<TrackCredit> credits, TrackDetails? details});

/// Credits and details of one track, read on their own (not from the `tracks`
/// streams); emits again when credits arrive in the background.
final trackCreditsProvider = StreamProvider.autoDispose
    .family<TrackCreditsData, int>(
      (ref, trackId) =>
          ref.watch(creditsRepositoryProvider).watchPortableOf(trackId),
    );

/// Tracks found only through a credit; not for operators.
final searchCreditedProvider = FutureProvider.autoDispose
    .family<List<Track>, String>((ref, query) async {
      final text = query.trim();
      if (text.isEmpty || hasOperators(text)) return const [];
      final found = ref.watch(searchTracksProvider(query)).value ?? const <Track>[];
      final r = await ref
          .watch(creditsRepositoryProvider)
          .creditedTracks(
            creditNameKey(text),
            prefix: true,
            exclude: {for (final t in found) t.id},
            limit: 20,
          );
      return [for (final e in r) e.track];
    });

/// Tracks where the artist is only credited (producer, author...), by role.
final artistCreditedProvider = StreamProvider.autoDispose
    .family<List<({String role, Track track})>, String>(
      (ref, name) => ref
          .watch(creditsRepositoryProvider)
          .watchCreditedTracks(creditNameKey(name)),
    );
