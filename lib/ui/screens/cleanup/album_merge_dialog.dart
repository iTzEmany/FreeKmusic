import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text_utils.dart';
import '../../../data/repositories/library_queries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/track_ops.dart';
import '../../../providers/library_providers.dart';
import '../../../services/tags/tag_writer.dart';
import '../../widgets/confirm.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tag_write_ui.dart';

/// «Unisci con…» on an album: pick the albums to fold into [main], name the
/// result (title and artist), and every track goes to that one album with the
/// cover of [main]. Resolves to true when it merged. The edit lives only in
/// the library (files are never touched) and the snackbar can undo it.
Future<bool> showAlbumMergeDialog(
  BuildContext context,
  WidgetRef ref,
  AlbumSummary main,
) async {
  final done = await showDialog<_Picked>(
    context: context,
    builder: (_) => _AlbumMergeDialog(main: main),
  );
  if (done == null || !context.mounted) return false;
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final editor = ref.read(trackEditorProvider);
  final tracks = await ref.read(trackOpsProvider).ofAlbums([
    main.albumKey,
    ...done.keys,
  ]);
  final before = await editor.saveMany(
    tracks,
    album: done.title,
    albumArtist: done.artist,
    cover: main.coverKey == null
        ? null
        : (hasCover: true, coverKey: main.coverKey),
  );
  final outcome = await editor.writeToFiles(
    tracks,
    (_) => TagChanges(album: done.title, albumArtist: done.artist),
  );
  showTagFileOutcome(messenger, l, outcome);
  if (context.mounted) {
    showUndoSnack(
      context,
      l.albumMerged(done.keys.length + 1, done.title),
      () => editor.restoreMany(before),
    );
  }
  return true;
}

class _Picked {
  const _Picked(this.keys, this.title, this.artist);

  final List<String> keys;
  final String title, artist;
}

class _AlbumMergeDialog extends ConsumerStatefulWidget {
  const _AlbumMergeDialog({required this.main});

  final AlbumSummary main;

  @override
  ConsumerState<_AlbumMergeDialog> createState() => _AlbumMergeDialogState();
}

class _AlbumMergeDialogState extends ConsumerState<_AlbumMergeDialog> {
  late final _title = TextEditingController(text: widget.main.title ?? '');
  late final _artist = TextEditingController(text: widget.main.artist ?? '');
  final _search = TextEditingController();
  final _picked = <String>{};
  String _query = '';

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _ok =>
      _picked.isNotEmpty &&
      _title.text.trim().isNotEmpty &&
      _artist.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = normalize(_query);
    final others = [
      for (final a in ref.watch(albumsProvider).value ?? const <AlbumSummary>[])
        if (a.albumKey != widget.main.albumKey &&
            a.title != null &&
            (q.isEmpty || normalize('${a.title} ${a.artist ?? ''}').contains(q)))
          a,
    ];
    final name = widget.main.title ?? l.unknownAlbum;
    return AlertDialog(
      title: Text(l.albumMergeTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.albumMergeIntro(name)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('merge-title'),
              controller: _title,
              decoration: InputDecoration(labelText: l.albumFieldTitle),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              key: const ValueKey('merge-artist'),
              controller: _artist,
              decoration: InputDecoration(labelText: l.albumFieldArtist),
              onChanged: (_) => setState(() {}),
            ),
            const AlsoInFileTile(),
            TextField(
              key: const ValueKey('merge-search'),
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l.albumMergeSearch,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            Flexible(
              child: SizedBox(
                height: 240,
                child: others.isEmpty
                    ? EmptyState(icon: Icons.album_rounded, message: l.albumMergeNone)
                    : ListView(
                        children: [
                          for (final a in others)
                            CheckboxListTile(
                              key: ValueKey('merge-${a.albumKey}'),
                              dense: true,
                              value: _picked.contains(a.albumKey),
                              onChanged: (v) => setState(() {
                                v == true
                                    ? _picked.add(a.albumKey)
                                    : _picked.remove(a.albumKey);
                              }),
                              secondary: CoverImage(
                                coverKey: a.coverKey,
                                size: 40,
                              ),
                              title: Text(
                                a.title ?? l.unknownAlbum,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                a.variousArtists
                                    ? l.variousArtists
                                    : (a.artist ?? l.unknownArtist),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('merge-go'),
          onPressed: _ok
              ? () => Navigator.pop(
                  context,
                  _Picked(_picked.toList(), _title.text.trim(), _artist.text.trim()),
                )
              : null,
          child: Text(l.albumMergeAction),
        ),
      ],
    );
  }
}
