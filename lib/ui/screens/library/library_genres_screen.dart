import 'package:flutter/material.dart';
import '../../widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/library_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/genre_grid.dart';
import '../search/genre_screen.dart';

/// Library → «Generi»: the genres of the local library, most tracks first (D-593).
class LibraryGenresScreen extends ConsumerWidget {
  const LibraryGenresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final genres = ref.watch(genresProvider).value ?? const [];
    if (genres.isEmpty) {
      return Scaffold(
        appBar: CcAppBar(title: l.genresTitle),
        body: PageFrame(child: EmptyState(icon: Icons.music_note_rounded, message: l.noResults)),
      );
    }
    return Scaffold(
      appBar: CcAppBar(title: l.genresTitle),
      body: PageFrame(child: CustomScrollView(
        slivers: [
          GenreGrid(
            columns: 3,
            wideColumns: 6,
            items: [
              for (final g in genres)
                GenreItem(
                  g.name,
                  g.name,
                  subtitle: l.tracksCount(g.trackCount),
                ),
            ],
            onSelect: (name) =>
                ShellNav.open<void>(context, GenreScreen(genre: name)),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 24 + context.dockInset)),
        ],
      )),
    );
  }
}
