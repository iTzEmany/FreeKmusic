import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/track_kinds.dart' show LibraryFilter;
import '../../l10n/l10n_ext.dart';
import '../../providers/library_providers.dart';
import '../theme/tokens.dart';
import 'segmented_blocks.dart';

/// «Tutti / Sul dispositivo / In streaming» on top of Brani, Album and Artisti (D-596).
class LibraryFilterBar extends ConsumerWidget {
  const LibraryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Semantics(
      container: true,
      label: l.libraryFilterLabel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap8),
        child: SegmentedBlocks<LibraryFilter>(
          items: [
            BlockItem(value: LibraryFilter.all, label: l.showAll),
            BlockItem(value: LibraryFilter.device, label: l.storageModeDevice),
            BlockItem(value: LibraryFilter.stream, label: l.storageModeStream),
          ],
          selected: ref.watch(libraryFilterProvider),
          onChanged: ref.read(libraryFilterProvider.notifier).set,
        ),
      ),
    );
  }
}
