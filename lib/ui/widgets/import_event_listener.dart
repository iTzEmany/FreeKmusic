import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show PlaylistImportItem;
import '../../data/repositories/import_repository.dart';
import '../../services/import/import_options.dart' show ImportNote;
import '../../l10n/l10n_ext.dart';
import '../../providers/playlist_ops.dart';
import '../../providers/import_providers.dart';
import '../../providers/online_providers.dart' show downloadTaggerProvider;
import '../../services/import/playlist_import_service.dart';
import '../screens/import/import_labels.dart';
import 'show_msg.dart';

/// Starts the import engine at app launch (running imports of the last
/// session become paused) and reports its events as snackbars.
class ImportEventListener extends ConsumerStatefulWidget {
  const ImportEventListener({super.key});

  @override
  ConsumerState<ImportEventListener> createState() => _State();
}

class _State extends ConsumerState<ImportEventListener> {
  @override
  void initState() {
    super.initState();
    ref.read(playlistImportServiceProvider).recoverAfterRestart();
    unawaited(ref.read(downloadTaggerProvider).resumePending());
  }

  Future<void> _report(ImportEvent e) async {
    final l = context.l10n;
    final svc = ref.read(playlistImportServiceProvider);
    String text;
    SnackBarAction? action;
    switch (e.kind) {
      case ImportEventKind.completed:
        // Every block of the import, counted together.
        final items = [
          for (final b in await svc.chainOf(e.importId))
            ...await ref.read(playlistOpsProvider).importItems(b.id),
        ];
        int count(bool Function(PlaylistImportItem) test) =>
            items.where(test).length;
        // Rows a sync found already in the playlist are not «added».
        text = l.csvImportDone(
          count((i) =>
              (i.state == ImportItemStatus.downloaded ||
                  i.state == ImportItemStatus.linked) &&
              i.note != ImportNote.unchanged),
          count((i) => i.state == ImportItemStatus.review),
          count((i) =>
              i.state == ImportItemStatus.notFound ||
              i.state == ImportItemStatus.failed),
        );
      case ImportEventKind.planned:
        text = l.csvImportPlanned;
      case ImportEventKind.rateLimited:
        text = importStopText(l, e.kind)!;
        action = SnackBarAction(
          label: l.csvImportResume,
          onPressed: () => svc.resume(e.importId),
        );
      case ImportEventKind.network:
        text = importStopText(l, e.kind)!;
        action = SnackBarAction(
          label: l.csvImportResume,
          onPressed: () => svc.resume(e.importId),
        );
      case ImportEventKind.toolMissing:
      case ImportEventKind.toolOutdated:
      case ImportEventKind.failing:
        text = importStopText(l, e.kind)!;
    }
    if (!mounted) return;
    showMsg(context, text, action: action, persist: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(importEventsProvider, (_, next) {
      final e = next.value;
      if (e != null) _report(e);
    });
    return const SizedBox.shrink();
  }
}
