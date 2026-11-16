import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/platform.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/folder_actions.dart';
import '../../../providers/folder_ops.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/online/media_publisher.dart';

/// App folders of the SD cards in the device (empty without one, D-579).
final sdVolumesProvider = FutureProvider.autoDispose<List<String>>((ref) => sdVolumeDirs());

/// D-579: where downloads (and the stream cache) go. Android: internal or the SD
/// card, only with a card; desktop: a chosen folder, also added to the library.
class DownloadLocationTile extends ConsumerWidget {
  const DownloadLocationTile({super.key});

  Future<void> _pick(WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(downloadLocation: path));
    await ref.read(folderOpsProvider).add(path);
    await scanWithPermission(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final location = ref.watch(settingsProvider.select((s) => s.downloadLocation));
    void set(String v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(downloadLocation: v));
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
    if (sds.isEmpty) return const SizedBox.shrink();
    final legacy = !(ref.watch(_mediaStoreProvider).value ?? true);
    return ListTile(
      leading: const Icon(Icons.sd_storage_outlined),
      title: Text(l.downloadMemory),
      subtitle: location.isNotEmpty && legacy ? Text(l.downloadMemorySdLegacy) : null,
      trailing: DropdownButton<String>(
        value: sds.contains(location) ? location : '',
        underline: const SizedBox.shrink(),
        items: [
          DropdownMenuItem(value: '', child: Text(l.downloadMemoryInternal)),
          for (final d in sds) DropdownMenuItem(value: d, child: Text(l.downloadMemorySd(p.basename(sdRootOf(d) ?? d)))),
        ],
        onChanged: (v) => v == null ? null : set(v),
      ),
    );
  }
}

final _mediaStoreProvider = FutureProvider.autoDispose<bool>((ref) => publishesToMediaStore());
