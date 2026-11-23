import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/track_ops.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/import_providers.dart';
import '../../../providers/library_add_providers.dart';
import '../../../services/import/exportify_reader.dart'
    show CsvTooLargeException;
import '../../../services/import/exportify_zip.dart';
import '../../../services/import/imported_playlist.dart';
import '../../../services/import/read_import_file.dart';
import '../../../services/import/track_matcher.dart';
import 'exportify_sync_screen.dart';
import 'import_intro_sheet.dart';
import 'import_preview_dialog.dart';
import '../../widgets/show_msg.dart';

/// «Importa da Exportify (CSV)»: instructions + file → preview → start.
Future<void> startCsvImport(BuildContext context, WidgetRef ref) async {
  final picked = await ImportIntroSheet.show(context);
  if (picked == null || !context.mounted) return;
  await continueImport(context, ref, picked);
}

/// A file from outside (Android «Apri con», a download found on the desktop):
/// the same flow as the file picker.
Future<void> openImportFile(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final l = context.l10n;
  String? error;
  try {
    final picked = await readImportPath(path);
    if (!context.mounted) return;
    await continueImport(context, ref, picked);
  } on CsvTooLargeException catch (e, st) {
    AppLog.w('incoming file too large', e, st);
    error = l.csvImportTooBig;
  } on FormatException catch (e, st) {
    AppLog.w('incoming file is not Exportify', e, st);
    error = l.csvImportNotExportify;
  } on Object catch (e, st) {
    AppLog.w('incoming file not readable', e, st);
    error = l.csvImportReadFailed;
  }
  if (error != null) {
    if (!context.mounted) return;
    showMsg(context, error);
  }
}

/// [picked] is an [ExportifyZipResult] or an [ImportedPlaylist].
Future<void> continueImport(
  BuildContext context,
  WidgetRef ref,
  Object picked,
) async {
  if (picked is ExportifyZipResult) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ExportifySyncScreen(zip: picked)),
    );
    return;
  }
  final csv = picked as ImportedPlaylist;
  final library = LibraryIndex(await ref.read(trackOpsProvider).liteEntries());
  final known = csv.rows
      .where((r) => library.find(r, baseDir: csv.baseDir) != null)
      .length;
  final lists = await ref.read(playlistsProvider.future);
  if (!context.mounted) return;
  final choice = await showDialog<ImportChoice>(
    context: context,
    builder: (_) => ImportPreviewDialog(
      csv: csv,
      known: known,
      streaming: ref.read(libraryAdderProvider).streaming,
      existing: {for (final p in lists) p.playlist.id: p.playlist.name},
      syncPreview: (id) =>
          ref.read(playlistImportServiceProvider).previewSync(csv, id),
    ),
  );
  if (choice == null || !context.mounted) return;
  final started = context.l10n.csvImportStarted;
  final svc = ref.read(playlistImportServiceProvider);
  if (choice.sync && choice.intoPlaylistId != null) {
    await svc.sync(csv, choice.intoPlaylistId!, options: choice.options);
  } else {
    await svc.start(
      csv,
      name: choice.name,
      intoPlaylistId: choice.intoPlaylistId,
      options: choice.options,
      blockSize: choice.blockSize,
    );
  }
  if (!context.mounted) return;
  showMsg(context, started);
}
