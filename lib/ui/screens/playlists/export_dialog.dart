import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/track_repository.dart' show SortOption;
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/folder_ops.dart';
import '../../../providers/playlist_ops.dart';
import '../../../providers/track_ops.dart';
import '../../../services/export/playlist_exporter.dart';
import '../../../services/export/save_file.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/show_msg.dart';

class _ExportChoice {
  const _ExportChoice(this.format, this.relative);

  final ExportFormat format;
  final bool relative;
}

class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportFormat _format = ExportFormat.m3u8;
  bool _relative = false;

  String _label(AppLocalizations l, ExportFormat f) => switch (f) {
    ExportFormat.m3u8 => l.exportFormatM3u8,
    ExportFormat.csv => l.exportFormatCsv,
    ExportFormat.json => l.exportFormatJson,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.exportPlaylistTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedBlocks<ExportFormat>(
              items: [
                for (final f in ExportFormat.values)
                  BlockItem(
                    value: f,
                    icon: switch (f) {
                      ExportFormat.m3u8 => Icons.queue_music_rounded,
                      ExportFormat.csv => Icons.table_chart_rounded,
                      ExportFormat.json => Icons.data_object_rounded,
                    },
                    label: _label(l, f),
                  ),
              ],
              selected: _format,
              onChanged: (v) => setState(() => _format = v),
            ),
            if (_format == ExportFormat.m3u8)
              CheckboxListTile(
                value: _relative,
                onChanged: (v) => setState(() => _relative = v ?? false),
                title: Text(l.exportRelativePaths),
                subtitle: Text(l.exportRelativeHint),
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
          onPressed: () =>
              Navigator.pop(context, _ExportChoice(_format, _relative)),
          child: Text(l.exportAction),
        ),
      ],
    );
  }
}

/// Asks for the format, then saves the playlist where the user chooses.
Future<void> exportPlaylistFlow(
  BuildContext context,
  WidgetRef ref, {
  required Playlist playlist,
  required String name,
  required List<Track> tracks,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (tracks.isEmpty) {
    showMsgOn(messenger, l.exportEmpty);
    return;
  }
  final choice = await showDialog<_ExportChoice>(
    context: context,
    builder: (_) => const ExportDialog(),
  );
  if (choice == null) return;
  try {
    final text = renderPlaylist(
      choice.format,
      name: name,
      createdAt: playlist.createdAt,
      coverKey: playlist.coverKey,
      tracks: tracks,
      isrcByTrack: await ref.read(playlistOpsProvider).isrcByTrack(playlist.id),
      folders: await ref.read(folderOpsProvider).paths(),
      relativePaths: choice.relative,
    );
    final saved = await saveBytes(
      exportFileName(name, choice.format),
      utf8.encode(text),
      mimeType: choice.format.mimeType,
    );
    if (saved) showMsgOn(messenger, l.exportSaved);
  } on Object catch (e, st) {
    AppLog.e('export playlist failed', e, st);
    showMsgOn(messenger, l.exportFailed);
  }
}

/// One file per playlist (and one for the favourites, when there are any)
/// in [format]. [favoritesName] is the name the UI gives the favourites.
Future<Archive> buildPlaylistsArchive(
  WidgetRef ref, {
  required ExportFormat format,
  required bool relativePaths,
  required String favoritesName,
}) async {
  final folders = await ref.read(folderOpsProvider).paths();
  final plOps = ref.read(playlistOpsProvider);
  final archive = Archive();
  final used = <String>{};
  void add(
    String name,
    int createdAt,
    String? coverKey,
    List<Track> tracks,
    Map<int, String> isrcs,
  ) {
    final text = renderPlaylist(
      format,
      name: name,
      createdAt: createdAt,
      coverKey: coverKey,
      tracks: tracks,
      isrcByTrack: isrcs,
      folders: folders,
      relativePaths: relativePaths,
    );
    var file = exportFileName(name, format);
    for (var n = 2; !used.add(file); n++) {
      file = exportFileName('$name $n', format);
    }
    archive.addFile(ArchiveFile.bytes(file, utf8.encode(text)));
  }

  for (final p in await plOps.visible()) {
    add(
      p.name,
      p.createdAt,
      p.coverKey,
      await plOps.tracksOf(p.id),
      await plOps.isrcByTrack(p.id),
    );
  }
  final favorites = await ref.read(trackOpsProvider).favorites(sort: SortOption.defaultOrder);
  if (favorites.isNotEmpty) {
    add(
      favoritesName,
      DateTime.now().millisecondsSinceEpoch,
      null,
      favorites,
      const {},
    );
  }
  return archive;
}

/// «Esporta tutte le playlist»: one file per playlist (favourites included)
/// in the chosen format, all in a zip.
Future<void> exportAllPlaylistsFlow(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showDialog<_ExportChoice>(
    context: context,
    builder: (_) => const ExportDialog(),
  );
  if (choice == null) return;
  try {
    final archive = await buildPlaylistsArchive(
      ref,
      format: choice.format,
      relativePaths: choice.relative,
      favoritesName: l.navFavorites,
    );
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final saved = await saveBytes(
      'freekmusic-playlists-$stamp.zip',
      Uint8List.fromList(ZipEncoder().encode(archive)),
      mimeType: 'application/zip',
    );
    if (saved) showMsgOn(messenger, l.exportSaved);
  } on Object catch (e, st) {
    AppLog.e('export all playlists failed', e, st);
    showMsgOn(messenger, l.exportFailed);
  }
}
