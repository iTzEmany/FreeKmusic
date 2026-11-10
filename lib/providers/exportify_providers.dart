import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:path_provider/path_provider.dart';

import '../core/app_log.dart';
import '../core/platform.dart';
import '../services/android/incoming_files.dart';
import '../data/db/app_database.dart' show PlaylistImport;
import '../services/import/exportify_hints.dart';
import '../services/import/imported_playlist.dart';
import '../services/import/import_diff.dart' show ImportDiff;
import '../services/import/import_options.dart';
import 'import_providers.dart';
import 'issue_providers.dart';
import 'settings_providers.dart';
import 'startup_providers.dart';

const exportifyAddress = 'https://exportify.net';

/// Opens exportify.net and remembers when, so the desktop can spot the file
/// the browser saves next. Answers whether something could open it.
Future<bool> openExportify(WidgetRef ref) async {
  final ok = await ref.read(linkOpenerProvider).open(exportifyAddress);
  if (ok) {
    await ref
        .read(settingsStoreProvider)
        .writeExportifyOpenedAt(DateTime.now().millisecondsSinceEpoch);
  }
  return ok;
}

/// Writes of the Exportify «Sincronizza» screen.
class ExportifyOps {
  ExportifyOps(this._ref);

  final Ref _ref;

  Future<ImportDiff> previewSync(ImportedPlaylist csv, int playlistId) =>
      _ref.read(playlistImportServiceProvider).previewSync(csv, playlistId);

  /// Imports or syncs each entry in turn (a null playlist = new), with the
  /// options of that playlist's [lastImport]. Returns how many went through.
  Future<int> syncAll(
    List<({ImportedPlaylist csv, int? playlistId})> entries,
    Map<int, PlaylistImport> lastImport,
  ) async {
    final svc = _ref.read(playlistImportServiceProvider);
    var ok = 0;
    for (final e in entries) {
      try {
        final id = e.playlistId;
        final last = id == null ? null : lastImport[id];
        final options = last == null
            ? const ImportOptions()
            : ImportOptions(
                folderPath: last.folderPath,
                numberFiles: last.numberFiles,
                linkOnly: last.linkOnly,
                fetchCovers: last.fetchCovers,
              );
        if (id == null) {
          await svc.start(e.csv, name: e.csv.name);
        } else {
          await svc.sync(e.csv, id, options: options);
        }
        ok++;
      } on Object catch (err, st) {
        AppLog.w('Exportify sync of ${e.csv.name} failed', err, st);
      }
    }
    if (ok > 0) {
      await _ref.read(settingsStoreProvider).writeExportifyLastSyncAt(DateTime.now().millisecondsSinceEpoch);
      _ref.invalidate(exportifyReminderProvider);
    }
    return ok;
  }
}

final exportifyOpsProvider = Provider<ExportifyOps>(ExportifyOps.new);

final incomingFilesProvider = Provider<IncomingFiles>((_) => IncomingFiles());

/// Paths of ZIP/CSV files other apps open with Codecore (Android only).
final incomingPathProvider = StreamProvider<String>(
  (ref) => isAndroid
      ? ref.watch(incomingFilesProvider).paths()
      : const Stream<String>.empty(),
);

/// Text (a link, usually) other apps share with Codecore (Android only).
final incomingTextProvider = StreamProvider<String>(
  (ref) => isAndroid
      ? ref.watch(incomingFilesProvider).texts()
      : const Stream<String>.empty(),
);

/// Days between sync reminders: 0 = off, else 7, 14 or 30.
class ExportifyRemindDays extends Notifier<int> {
  @override
  int build() => ref.read(settingsStoreProvider).readExportifyRemindDays();

  Future<void> set(int days) async {
    final store = ref.read(settingsStoreProvider);
    await store.writeExportifyRemindDays(days);
    // Never synced: the first reminder comes after a full interval. Written
    // before the state changes, so the card does not flash up at once.
    if (days > 0 && store.readExportifyLastSyncAt() == null) {
      await store.writeExportifySnoozeUntil(
        DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch,
      );
    }
    state = days;
  }
}

final exportifyRemindDaysProvider = NotifierProvider<ExportifyRemindDays, int>(
  ExportifyRemindDays.new,
);

/// True when the Home card «è ora di sincronizzare» should show: only after
/// the app has settled, never over the network.
class ExportifyReminder extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final days = ref.watch(exportifyRemindDaysProvider);
    await ref.watch(startupSettledProvider.future);
    final store = ref.read(settingsStoreProvider);
    return exportifyReminderDue(
      remindDays: days,
      lastSyncAt: store.readExportifyLastSyncAt(),
      snoozeUntil: store.readExportifySnoozeUntil(),
      now: DateTime.now(),
    );
  }

  /// «Più tardi»: quiet until this time tomorrow.
  Future<void> snooze() async {
    state = const AsyncData(false);
    await ref
        .read(settingsStoreProvider)
        .writeExportifySnoozeUntil(
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
        );
  }
}

final exportifyReminderProvider =
    AsyncNotifierProvider<ExportifyReminder, bool>(ExportifyReminder.new);

/// Desktop: the Exportify file found in Downloads after the tap on «Apri
/// exportify.net», looked for each time the app comes back to the front.
class ExportifyDownload extends Notifier<File?> {
  @override
  File? build() {
    if (isDesktop) {
      final l = AppLifecycleListener(onResume: check);
      ref.onDispose(l.dispose);
    }
    return null;
  }

  Future<void> check() async {
    final tap = ref.read(settingsStoreProvider).readExportifyOpenedAt();
    if (tap == null) return;
    try {
      final dir = await getDownloadsDirectory();
      if (dir == null) return;
      final f = await findExportifyDownload(
        dir,
        DateTime.fromMillisecondsSinceEpoch(tap),
        DateTime.now(),
      );
      if (f?.path != state?.path) state = f;
    } on Object catch (e, st) {
      AppLog.w('Downloads check failed', e, st);
    }
  }

  /// The file was used (or is not wanted): stop offering it.
  Future<void> consume() async {
    state = null;
    await ref.read(settingsStoreProvider).writeExportifyOpenedAt(null);
  }
}

final exportifyDownloadProvider = NotifierProvider<ExportifyDownload, File?>(
  ExportifyDownload.new,
);
