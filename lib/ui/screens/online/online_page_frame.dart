import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/selection_providers.dart';
import '../../../services/online/youtube_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/activity_button.dart';
import 'online_selection_scope.dart';
import 'online_song_row.dart';

/// The frame of every online page (artist, album, long song list): a pinned
/// bar with the activity button, the page's [slivers], the selection bar with
/// «Scarica» while songs are picked.
class OnlinePageFrame extends ConsumerWidget {
  const OnlinePageFrame({
    super.key,
    required this.title,
    required this.slivers,
    this.selectionKey,
    this.pickable = const [],
    this.onRefresh,
    this.actions = const [],
  });

  /// Shown in the pinned bar.
  final String title;
  final List<Widget> slivers;

  /// The pick list of the page (`ytm-artist:<id>`); null = songs not pickable.
  /// The songs are ids `0…` of [pickable], in the order shown.
  final String? selectionKey;
  final List<YtResult> pickable;

  /// Pull down to ask again.
  final Future<void> Function()? onRefresh;

  /// Extra buttons of the bar, before the activity button.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final key = selectionKey;
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: cc.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            ...actions,
            const ActivityButton(),
            const SizedBox(width: 8),
          ],
        ),
        ...slivers,
        SliverToBoxAdapter(child: SizedBox(height: 24 + context.dockInset)),
      ],
    );
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: onRefresh == null
            ? scroll
            // The spinner starts under the pinned bar, not behind the status bar.
            : RefreshIndicator(
                onRefresh: onRefresh!,
                edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
                child: scroll,
              ),
      ),
    );
    return Scaffold(
      backgroundColor: cc.bg,
      body: Column(
        children: [
          Expanded(
            child: key == null
                ? body
                : OnlineSelectionScope(
                    selectionKey: key,
                    overlay: true,
                    ids: [for (var i = 0; i < pickable.length; i++) i],
                    actions: (picked) => [
                      IconButton(
                        tooltip: l.ytDownload,
                        icon: const Icon(Icons.download_rounded),
                        onPressed: () {
                          startOnlineDownloads(context, ref, [
                            for (final i in picked.orderedIds)
                              if (i < pickable.length) pickable[i],
                          ]);
                          ref.read(selectionProvider(key).notifier).clear();
                        },
                      ),
                    ],
                    child: body,
                  ),
          ),
        ],
      ),
    );
  }
}
