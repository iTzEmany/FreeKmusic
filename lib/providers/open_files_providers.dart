import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/platform/open_files.dart';
import 'database_providers.dart';
import 'library_providers.dart';
import 'player_providers.dart';

final _outsideController = Provider<StreamController<List<String>>>((ref) {
  final c = StreamController<List<String>>.broadcast();
  ref.onDispose(c.close);
  return c;
});

/// Files opened with the app that sit outside the library folders: the UI offers «Aggiungi alla libreria».
final openOutsideProvider = StreamProvider<List<String>>((ref) => ref.watch(_outsideController).stream);

final _portalController = Provider<StreamController<List<String>>>((ref) {
  final c = StreamController<List<String>>.broadcast();
  ref.onDispose(c.close);
  return c;
});

/// Files opened through the Flatpak documents portal: not playable, the UI says what to do.
final openPortalProvider = StreamProvider<List<String>>((ref) => ref.watch(_portalController).stream);

final openFilesProvider = Provider<OpenFiles>((ref) {
  final folders = ref.read(folderRepositoryProvider);
  return OpenFiles(
    folders: folders.getAll,
    trackAt: ref.read(trackRepositoryProvider).byPath,
    scan: (folder, path) => ref.read(libraryScannerProvider).scanFiles(folder, [path]).drain<void>(),
    play: (tracks) => ref
        .read(playerControllerProvider)
        .playFromList(tracks, 0, context: const PlayContext(PlayContextKind.search)),
    addFolder: (dir) async {
      await folders.add(dir);
      await ref.read(scanStateProvider.notifier).scanAll();
    },
    onOutside: (paths) => ref.read(_outsideController).add(paths),
    onPortal: (paths) => ref.read(_portalController).add(paths),
  );
});
