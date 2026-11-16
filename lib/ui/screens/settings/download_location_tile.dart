import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/platform.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/folder_actions.dart';
import '../../../providers/folder_ops.dart';
import '../../../providers/storage_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/storage_volumes.dart' show sdRootOf;
import '../../../services/online/media_publisher.dart' show publishesToMediaStore;

/// D-579: where downloads (and the stream cache) go. Android: internal or the SD
/// card, only with a card; desktop: a chosen folder, also added to the library.
class DownloadLocationTile extends ConsumerWidget {
  const DownloadLocationTile({super.key});

  /// Stores the new location; the stream cache moves at the next start (`main` then drops the old one).
  Future<void> _set(WidgetRef ref, String v) async =>
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(downloadLocation: v));

  Future<void> _pick(WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    await _set(ref, path);
    await ref.read(folderOpsProvider).libraryFolder(path);
    await scanWithPermission(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final location = ref.watch(settingsProvider.select((s) => s.downloadLocation));
    void set(String v) => _set(ref, v);
    if (!isAndroid) {
      return ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: Text(l.downloadFolder),
        subtitle: Text(location.isEmpty ? l.downloadFolderDefault : location),
        trailing: location.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.restart_alt), tooltip: l.downloadFolderReset, onPressed: () => set('')),
        onTap: () => _pick(ref),
      );
    }
    final sds = ref.watch(sdVolumesProvider).value ?? const [];
    if (sds.isEmpty && location.isEmpty) return const SizedBox.shrink();
    // The chosen card may be gone: say so instead of showing «internal».
    final missing = location.isNotEmpty && !sds.contains(location);
    final legacy = !(ref.watch(_mediaStoreProvider).value ?? true);
    return ListTile(
      leading: const Icon(Icons.sd_storage_outlined),
      title: Text(l.downloadMemory),
      subtitle: Text([
        if (location.isNotEmpty && legacy) l.downloadMemorySdLegacy,
        l.downloadMemoryRestart,
      ].join(' ')),
      trailing: DropdownButton<String>(
        value: location,
        underline: const SizedBox.shrink(),
        items: [
          DropdownMenuItem(value: '', child: Text(l.downloadMemoryInternal)),
          if (missing) DropdownMenuItem(value: location, child: Text(l.downloadMemorySdMissing(p.basename(sdRootOf(location) ?? location)))),
          for (final d in sds) DropdownMenuItem(value: d, child: Text(l.downloadMemorySd(p.basename(sdRootOf(d) ?? d)))),
        ],
        onChanged: (v) => v == null ? null : set(v),
      ),
    );
  }
}

final _mediaStoreProvider = FutureProvider.autoDispose<bool>((ref) => publishesToMediaStore());
