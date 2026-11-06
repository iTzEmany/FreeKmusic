import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import 'create_flows.dart';

/// The «+» button: opens the new-playlist sheet. How the smart editor opens
/// depends on the caller ([onSmart]).
class NewPlaylistMenu extends ConsumerWidget {
  const NewPlaylistMenu({super.key, required this.onSmart});

  final VoidCallback onSmart;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: context.l10n.newPlaylist,
    icon: const Icon(Icons.add_rounded),
    onPressed: () => createPlaylistFlow(context, ref, onSmart: onSmart),
  );
}
