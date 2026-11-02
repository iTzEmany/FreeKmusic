import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../services/recognition/track_identity.dart';
import 'online_providers.dart';

/// The recognition of one track (proposal, cover); null when it has none.
final trackRecProvider = StreamProvider.autoDispose.family<Recognition?, int>(
  (ref, trackId) => ref.watch(creditsRepositoryProvider).watchRec(trackId),
);

/// The open proposals: «Da confermare».
final proposalsProvider = StreamProvider.autoDispose<List<({Track track, Recognition rec})>>(
  (ref) => ref.watch(creditsRepositoryProvider).watchProposals(),
);
