import '../../widgets/cc_sheet.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/app_log.dart';
import '../../../core/constants.dart';
import '../../../core/file_portal.dart';
import '../../../core/platform.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/exportify_providers.dart';
import '../../../services/import/exportify_reader.dart'
    show CsvTooLargeException;
import '../../../services/import/playlist_reader.dart'
    show supportedPlaylistExtensions;
import '../../../services/import/read_import_file.dart';
import '../../theme/tokens.dart';
import '../../widgets/show_msg.dart';

/// Explains where the CSV comes from (exportify.net) and lets the user pick it.
/// Pops with the parsed playlist, or with an [ExportifyZipResult] for a ZIP.
class ImportIntroSheet extends ConsumerStatefulWidget {
  const ImportIntroSheet({super.key});

  static Future<Object?> show(BuildContext context) => showCcSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ImportIntroSheet(),
  );

  @override
  ConsumerState<ImportIntroSheet> createState() => _ImportIntroSheetState();
}

class _ImportIntroSheetState extends ConsumerState<ImportIntroSheet> {
  bool _busy = false;
  String? _error;

  /// Desktop pickers open in Downloads, where the browser leaves the CSV.
  Future<String?> _startDir() async {
    if (!isDesktop) return null;
    try {
      return (await getDownloadsDirectory())?.path;
    } on Object catch (e, st) {
      AppLog.w('downloads folder unknown', e, st);
      return null;
    }
  }

  Future<void> _pick() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (await filePortalMissing()) {
      if (mounted) setState(() { _busy = false; _error = l.csvImportNoPortal; });
      return;
    }
    String? error;
    try {
      // Some Android file pickers hide .csv behind a MIME filter, so there
      // the whole list is shown and the content is validated instead.
      final files = await FilePicker.pickFiles(
        dialogTitle: l.csvImportPick,
        initialDirectory: await _startDir(),
        type: isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: isAndroid
            ? null
            : [...supportedPlaylistExtensions, 'zip'],
      );
      final path = files.isEmpty ? null : files.first.path;
      if (path == null) {
        if (files.isNotEmpty) error = l.csvImportReadFailed;
      } else {
        final picked = await readImportPath(path);
        if (!mounted) return;
        Navigator.of(context).pop(picked);
        return;
      }
    } on CsvTooLargeException catch (e, st) {
      AppLog.w('CSV too large', e, st);
      error = l.csvImportTooBig;
    } on FormatException catch (e, st) {
      AppLog.w('not an Exportify file', e, st);
      error = l.csvImportNotExportify;
    } on Object catch (e, st) {
      AppLog.w('could not read the CSV', e, st);
      error = l.csvImportReadFailed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _copy() async {
    final text = context.l10n.csvImportCopied;
    await Clipboard.setData(const ClipboardData(text: exportifyAddress));
    if (!mounted) return;
    showMsg(context, text);
  }

  Future<void> _openExportify() async {
    final failed = context.l10n.csvImportOpenFailed;
    if (await openExportify(ref)) return;
    if (!mounted) return;
    showMsg(context, failed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final steps = [
      l.csvImportStep1,
      l.csvImportStep2,
      l.csvImportStep3,
      l.csvImportStep4,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CcDims.margin,
          CcDims.gap8,
          CcDims.margin,
          CcDims.margin,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.csvImportIntroTitle, style: theme.titleMedium),
            const SizedBox(height: 8),
            Text(l.csvImportIntroSource, style: theme.bodyMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${i + 1}.',
                        style: theme.bodyMedium?.copyWith(color: cc.accentSoft),
                      ),
                    ),
                    Expanded(child: Text(steps[i], style: theme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            const SelectableText(exportifyAddress, maxLines: 1),
            Wrap(
              children: [
                TextButton.icon(
                  onPressed: _openExportify,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(l.csvImportOpenExportify),
                ),
                TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(l.csvImportCopy),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.csvImportZipHint,
              style: theme.bodySmall?.copyWith(color: cc.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              l.csvImportAlsoAccepts,
              style: theme.bodySmall?.copyWith(color: cc.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              kEnableYoutube ? l.csvImportNote : l.csvImportNoteOffline,
              style: theme.bodySmall?.copyWith(color: cc.textMuted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: theme.bodyMedium?.copyWith(color: cc.error)),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: Text(l.csvImportPick),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
