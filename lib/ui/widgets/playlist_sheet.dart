import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/playlist_repository.dart' show PlaylistSummary;
import '../../l10n/l10n_ext.dart';
import '../../providers/database_providers.dart';
import '../../providers/playlist_ops.dart';
import '../screens/playlists/playlist_dialogs.dart' show addedToPlaylistText;
import '../screens/playlists/playlist_picker.dart' show PickedPlaylist;
import '../theme/tokens.dart';
import 'cc_sheet.dart';
import 'cc_tile.dart';
import 'playlist_cover.dart';
import 'show_msg.dart';

/// What the user did in the sheet: a playlist picked or created, or a shortcut.
enum PlaylistSheetShortcut { smart, csv }

class PlaylistSheetResult {
  const PlaylistSheetResult.playlist(this.playlist) : shortcut = null;
  const PlaylistSheetResult.shortcut(this.shortcut) : playlist = null;
  final PickedPlaylist? playlist;
  final PlaylistSheetShortcut? shortcut;
}

/// The one full-height sheet behind «New playlist» and «Add to playlist»
/// (D-405, D-411). Without [tracks]: a tap picks the playlist and «Crea»
/// creates one; with [shortcuts] the smart and CSV rows show too. With
/// [tracks]: a tap adds them, says so and closes; «Crea» makes a new playlist
/// holding them. Resolves to null when dismissed (in add mode the adding is
/// done here and the result is the playlist added to).
Future<PlaylistSheetResult?> showPlaylistSheet(
  BuildContext context, {
  List<Track>? tracks,
  bool shortcuts = false,
}) => showCcSheet<PlaylistSheetResult>(
  context: context,
  isScrollControlled: true,
  barrierLabel: context.l10n.close,
  builder: (_) => _PlaylistSheet(tracks: tracks, shortcuts: shortcuts, outer: context),
);

class _PlaylistSheet extends ConsumerStatefulWidget {
  const _PlaylistSheet({required this.tracks, required this.shortcuts, required this.outer});

  final List<Track>? tracks;
  final bool shortcuts;
  final BuildContext outer;

  @override
  ConsumerState<_PlaylistSheet> createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends ConsumerState<_PlaylistSheet> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done(PlaylistSheetResult r) => Navigator.of(context).pop(r);

  // Guards against a second tap while the first is still writing.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(int id, String name, int added) async {
    final tracks = widget.tracks!;
    final outer = widget.outer;
    if (mounted) _done(PlaylistSheetResult.playlist((id: id, name: name)));
    if (outer.mounted) {
      showMsg(outer, addedToPlaylistText(outer.l10n, total: tracks.length, added: added, name: name));
    }
  }

  Future<void> _pick(PlaylistSummary p) => _run(() async {
    final tracks = widget.tracks;
    if (tracks == null) return _done(PlaylistSheetResult.playlist((id: p.playlist.id, name: p.playlist.name)));
    final added = await ref.read(playlistOpsProvider).addTracks(p.playlist.id, [for (final t in tracks) t.id]);
    await _add(p.playlist.id, p.playlist.name, added);
  });

  Future<void> _create() => _run(() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final tracks = widget.tracks;
    final ops = ref.read(playlistOpsProvider);
    if (tracks == null) return _done(PlaylistSheetResult.playlist((id: await ops.create(name), name: name)));
    final id = await ops.createWith(name, [for (final t in tracks) t.id]);
    await _add(id, name, tracks.length);
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final adding = widget.tracks != null;
    // Smart playlists live in their own table: they never reach this list.
    final lists = ref.watch(playlistsProvider).value ?? const <PlaylistSummary>[];
    final contains = adding
        ? ref.watch(playlistsContainingProvider(widget.tracks!.map((t) => t.id).join(','))).value ?? const <int>{}
        : const <int>{};
    final canCreate = _name.text.trim().isNotEmpty;
    return SafeArea(
      child: Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: adding ? l.addToPlaylist : l.newPlaylist,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  tooltip: l.close,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      adding ? l.addToPlaylist : l.newPlaylist,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: true,
                    maxLength: 60,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(hintText: adding ? l.newPlaylist : l.playlistName),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => canCreate ? _create() : null,
                  ),
                ),
                const SizedBox(width: CcDims.gap8),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: canCreate && !_busy ? _create : null,
                  child: Text(l.create),
                ),
              ],
            ),
          ),
          if (widget.shortcuts) ...[
            _Shortcut(
              icon: Icons.auto_awesome_rounded,
              label: l.smartPlaylistNew,
              onTap: () => _done(const PlaylistSheetResult.shortcut(PlaylistSheetShortcut.smart)),
            ),
            _Shortcut(
              icon: Icons.upload_file_rounded,
              label: l.csvImportMenu,
              onTap: () => _done(const PlaylistSheetResult.shortcut(PlaylistSheetShortcut.csv)),
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, CcDims.gap4),
              child: Semantics(
                header: true,
                child: Text(l.navPlaylists, style: Theme.of(context).textTheme.titleSmall),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: lists.length,
              itemExtent: 64,
              itemBuilder: (_, i) {
                final p = lists[i];
                return ListTile(
                  minTileHeight: 64,
                  leading: PlaylistCover(
                    size: 40,
                    coverKeys: playlistCoverKeys(p.playlist.coverKey, [p.autoCoverKey]),
                  ),
                  title: Text(p.playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(l.playlistCountLabel(p.trackCount)),
                  trailing: contains.contains(p.playlist.id)
                      ? Icon(Icons.check_circle_rounded, color: context.cc.accent, semanticLabel: l.allAlreadyInPlaylist(p.playlist.name))
                      : null,
                  onTap: () => _pick(p),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CcDims.margin, vertical: 2),
    child: CcTile(
      minHeight: 64,
      onTap: onTap,
      semanticsLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CcDims.gap16),
        child: Row(
          children: [
            Icon(icon, color: context.cc.accent),
            const SizedBox(width: CcDims.gap16),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
