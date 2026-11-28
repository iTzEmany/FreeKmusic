import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
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

/// What the user did in the sheet: a playlist picked or created, the playlists
/// ticked (add and multi-pick modes), or a shortcut.
enum PlaylistSheetShortcut { smart, csv }

class PlaylistSheetResult {
  const PlaylistSheetResult.playlist(PickedPlaylist this.playlist) : shortcut = null, playlists = const [];
  const PlaylistSheetResult.playlists(this.playlists) : playlist = null, shortcut = null;
  const PlaylistSheetResult.shortcut(this.shortcut) : playlist = null, playlists = const [];
  final PickedPlaylist? playlist;
  final List<PickedPlaylist> playlists;
  final PlaylistSheetShortcut? shortcut;
}

/// The one full-height sheet behind «New playlist» and «Add to playlist»
/// (D-405, D-411). Without [tracks]: a tap picks the playlist and «Crea»
/// creates one; with [shortcuts] the smart and CSV rows show too. With
/// [tracks] (add mode, D-751/D-752): taps tick playlists, the field filters
/// them and offers «Crea «text»», and the bottom button adds the tracks to all
/// the ticked ones, says so and closes. With [multi] (no [tracks]): the same
/// ticking but nothing is written; the result lists the ticked playlists.
/// Resolves to null when dismissed (in add mode the adding is done here and
/// the result is the playlists added to).
Future<PlaylistSheetResult?> showPlaylistSheet(
  BuildContext context, {
  List<Track>? tracks,
  bool shortcuts = false,
  bool multi = false,
}) => showCcSheet<PlaylistSheetResult>(
  context: context,
  isScrollControlled: true,
  barrierLabel: context.l10n.close,
  builder: (_) => _PlaylistSheet(tracks: tracks, shortcuts: shortcuts, multi: multi, outer: context),
);

/// Multi-pick without writing: the playlists the user ticked (or created),
/// empty when the sheet is dismissed or nothing is ticked.
Future<List<PickedPlaylist>> pickPlaylistsMulti(BuildContext context) async =>
    (await showPlaylistSheet(context, multi: true))?.playlists ?? const [];

class _PlaylistSheet extends ConsumerStatefulWidget {
  const _PlaylistSheet({required this.tracks, required this.shortcuts, required this.multi, required this.outer});

  final List<Track>? tracks;
  final bool shortcuts;
  final bool multi;
  final BuildContext outer;

  @override
  ConsumerState<_PlaylistSheet> createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends ConsumerState<_PlaylistSheet> {
  final _name = TextEditingController();
  bool _busy = false;
  final _ticked = <int>{};
  // Created here: shown on top, newest first.
  final _created = <PickedPlaylist>[];

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

  /// Without tracks and not multi: a tap picks the playlist and closes.
  void _pickOne(PlaylistSummary p) =>
      _done(PlaylistSheetResult.playlist((id: p.playlist.id, name: p.playlist.name)));

  void _toggle(int id) => setState(() => _ticked.contains(id) ? _ticked.remove(id) : _ticked.add(id));

  Future<void> _create() => _run(() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final ops = ref.read(playlistOpsProvider);
    final id = await ops.create(name);
    if (!(widget.tracks != null || widget.multi)) return _done(PlaylistSheetResult.playlist((id: id, name: name)));
    if (!mounted) return;
    setState(() {
      _created.add((id: id, name: name));
      _ticked.add(id);
      _name.clear();
    });
  });

  /// The ticked playlists that exist and are not locked: what the button counts and what is written.
  List<PickedPlaylist> _pickedNow(List<PlaylistSummary> lists, Set<int> locked) => [
    for (final p in lists)
      if (_ticked.contains(p.playlist.id) && !locked.contains(p.playlist.id)) (id: p.playlist.id, name: p.playlist.name),
  ];

  Future<void> _confirm(List<PickedPlaylist> picked) => _run(() async {
    final tracks = widget.tracks;
    if (tracks == null) return _done(PlaylistSheetResult.playlists(picked));
    final ops = ref.read(playlistOpsProvider);
    final ids = [for (final t in tracks) t.id];
    final done = <PickedPlaylist>[];
    final added = <int>[];
    var failed = false;
    for (final p in picked) {
      try {
        added.add(await ops.addTracks(p.id, ids));
        done.add(p);
      } on Object catch (e, st) {
        AppLog.w('add to playlist ${p.id} failed', e, st);
        failed = true;
      }
    }
    final outer = widget.outer;
    if (mounted) done.isEmpty ? Navigator.of(context).pop() : _done(PlaylistSheetResult.playlists(done));
    if (!outer.mounted) return;
    final l = outer.l10n;
    final changed = added.where((n) => n > 0).length;
    showMsg(
      outer,
      failed
          ? l.playlistAddFailed
          : done.length == 1
          ? addedToPlaylistText(l, total: tracks.length, added: added.first, name: done.first.name)
          : changed == 0
          ? l.allAlreadyInPlaylist(done.first.name)
          : l.addedToNPlaylists(changed),
    );
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final adding = widget.tracks != null;
    final ticking = adding || widget.multi;
    // Smart playlists live in their own table: they never reach this list.
    final all = ref.watch(playlistsProvider).value ?? const <PlaylistSummary>[];
    final contains = adding
        ? ref.watch(playlistsContainingProvider(widget.tracks!.map((t) => t.id).join(','))).value ?? const <int>{}
        : const <int>{};
    final text = _name.text.trim();
    final createdIds = [for (final c in _created.reversed) c.id];
    final byId = {for (final p in all) p.playlist.id: p};
    // The ones created here go first.
    final ordered = ticking
        ? [for (final id in createdIds) ?byId[id], for (final p in all) if (!createdIds.contains(p.playlist.id)) p]
        : all;
    final lists = ticking ? filterByText(ordered, text, (p) => [p.playlist.name]) : ordered;
    final canCreate = text.isNotEmpty;
    final identical = all.any((p) => p.playlist.name.toLowerCase() == text.toLowerCase());
    final pickedNow = _pickedNow(all, contains);
    final count = pickedNow.length;
    // In the wide desktop dialog the sheet is as tall as its content; on a phone it fills.
    final dialog = ccSheetIsDialog(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: ticking ? l.addToPlaylist : l.newPlaylist,
      child: Column(
        mainAxisSize: dialog ? MainAxisSize.min : MainAxisSize.max,
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
                      ticking ? l.addToPlaylist : l.newPlaylist,
                      style: theme.textTheme.titleMedium,
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
                    maxLength: 60,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: ticking ? l.playlistSearchOrCreate : l.playlistName,
                      prefixIcon: ticking ? const Icon(Icons.search_rounded) : null,
                      suffixIcon: ticking && _name.text.isNotEmpty
                          ? IconButton(
                              tooltip: l.clearSearch,
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(_name.clear),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => canCreate && !(ticking && identical) ? _create() : null,
                  ),
                ),
                if (!ticking) ...[
                  const SizedBox(width: CcDims.gap8),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                    onPressed: canCreate && !_busy ? _create : null,
                    child: Text(l.create),
                  ),
                ],
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
          if (ticking && canCreate && !identical)
            _Shortcut(
              icon: Icons.add_rounded,
              label: l.playlistCreateNamed(text),
              onTap: _busy ? () {} : _create,
              chevron: false,
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, CcDims.gap4),
              child: Semantics(
                header: true,
                child: Text(l.navPlaylists, style: theme.textTheme.titleSmall),
              ),
            ),
          ),
          if (ticking && canCreate && lists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(CcDims.margin),
              child: Text(l.noPlaylistNamed(text), style: theme.textTheme.bodyMedium),
            ),
          Flexible(
            fit: dialog ? FlexFit.loose : FlexFit.tight,
            child: ListView.builder(
              shrinkWrap: dialog,
              itemCount: lists.length,
              itemExtent: 64,
              itemBuilder: (_, i) {
                final p = lists[i];
                final id = p.playlist.id;
                final locked = contains.contains(id);
                final on = locked || _ticked.contains(id);
                return MergeSemantics(
                  child: ListTile(
                    minTileHeight: 64,
                    leading: PlaylistCover(
                      size: 40,
                      coverKeys: playlistCoverKeys(p.playlist.coverKey, [p.autoCoverKey]),
                    ),
                    title: Text(p.playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(locked ? l.alreadyPresent : l.playlistCountLabel(p.trackCount)),
                    trailing: ticking
                        ? Checkbox(value: on, onChanged: locked ? null : (_) => _toggle(id))
                        : null,
                    enabled: !locked,
                    onTap: ticking ? () => _toggle(id) : () => _pickOne(p),
                  ),
                );
              },
            ),
          ),
          if (ticking)
            Padding(
              padding: const EdgeInsets.all(CcDims.margin),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: count > 0 && !_busy ? () => _confirm(pickedNow) : null,
                  child: Text(l.addToNPlaylists(count)),
                ),
              ),
            ),
        ],
      ),
    ));
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap, this.chevron = true});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool chevron;

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
            if (chevron) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
