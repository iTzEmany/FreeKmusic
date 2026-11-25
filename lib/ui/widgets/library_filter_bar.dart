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
    final filter = ref.watch(libraryFilterProvider);
    final names = {
      LibraryFilter.all: l.showAll,
      LibraryFilter.device: l.storageModeDevice,
      LibraryFilter.stream: l.storageModeStream,
    };
    // Wide: chips as wide as their text, like the other chips (F-108).
    final wide = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    return Semantics(
      container: true,
      label: l.libraryFilterLabel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CcDims.margin,
          0,
          CcDims.margin,
          CcDims.gap8,
        ),
        child: wide
            ? Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: CcDims.gap8,
                  runSpacing: CcDims.gap4,
                  children: [
                    for (final f in LibraryFilter.values)
                      ChoiceChip(
                        label: Text(names[f]!),
                        selected: filter == f,
                        onSelected: (_) =>
                            ref.read(libraryFilterProvider.notifier).set(f),
                      ),
                  ],
                ),
              )
            : SegmentedBlocks<LibraryFilter>(
                items: [
                  for (final f in LibraryFilter.values)
                    BlockItem(value: f, label: names[f]!),
                ],
                selected: filter,
                onChanged: ref.read(libraryFilterProvider.notifier).set,
              ),
      ),
    );
  }
}
