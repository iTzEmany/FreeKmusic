import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/playlist_ops.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/track_ops.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/async_body.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/track_row.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_search_field.dart';

/// Pick saved tracks to put into a playlist: rows with a ＋ / ✓ circle and a
/// fixed «Aggiungi N brani» bar at the bottom.
class AddTracksScreen extends ConsumerStatefulWidget {
  const AddTracksScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<AddTracksScreen> createState() => _AddTracksScreenState();
}

class _AddTracksScreenState extends ConsumerState<AddTracksScreen> {
  static final _key = SelectionKey.addTracks.key;
  final _controller = TextEditingController();
  String _query = '';
  AsyncValue<List<Track>>? _prev;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await ref.read(playlistOpsProvider).addTracks(widget.playlistId, ref.read(selectionProvider(_key)).orderedIds);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final picked = ref.watch(selectionProvider(_key));
    final inPlaylist = {
      for (final t
          in ref.watch(playlistTracksProvider(widget.playlistId)).value ??
              const <Track>[])
        t.id,
    };
    return Scaffold(
      appBar: CcAppBar(title: l.addSongs),
      bottomNavigationBar: !picked.active
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(CcDims.margin),
                child: FilledButton(
                  onPressed: _add,
                  child: Text(l.addNSongs(picked.count)),
                ),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CcDims.margin,
                  CcDims.gap4,
                  CcDims.margin,
                  CcDims.gap8,
                ),
                child: CcSearchField(
                  controller: _controller,
                  hint: l.searchHint,
                  onQuery: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final fresh = ref.watch(trackSearchProvider(_query));
                    final found = keepWhileLoading(fresh, _prev);
                    _prev = found.hasError ? null : found;
                    return AsyncBody(
                      value: found,
                      rowHeight: trackRowExtentOf(context, false),
                      onRetry: () => ref.invalidate(trackSearchProvider(_query)),
                      data: (all) {
                        final tracks = [
                          for (final t in all)
                            if (!inPlaylist.contains(t.id)) t,
                        ];
                        if (tracks.isEmpty) {
                          return EmptyState(
                            icon: Icons.library_music,
                            message: _query.isEmpty
                                ? l.allSongsInPlaylist
                                : l.noResults,
                          );
                        }
                        return ListView.builder(
                          padding: EdgeInsets.zero.withDock(context),
                          itemExtent: trackRowExtentOf(context, false),
                          itemCount: tracks.length,
                          itemBuilder: (_, i) {
                            final t = tracks[i];
                            return TrackRow(
                              track: t,
                              variant: TrackRowVariant.pick,
                              picked: picked.contains(t.id),
                              onTap: () => ref.read(selectionProvider(_key).notifier).toggle(t.id),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
