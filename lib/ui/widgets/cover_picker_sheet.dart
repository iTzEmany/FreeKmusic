import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_log.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/cover_ops.dart';
import '../../providers/cover_picker_providers.dart';
import '../../providers/library_providers.dart';
import '../theme/tokens.dart';
import '../../services/covers/cover_store.dart';
import 'cc_sheet.dart';
import 'cover_image.dart';
import 'section_header.dart';
import 'show_msg.dart';
import 'skeleton.dart';

typedef CoverSave = Future<bool> Function(CoverOps ops, List<int> bytes, String? mime);

/// One picker for track, album and playlist covers. [save] stores the pick;
/// [online] (album title, artist) turns on the online proposals; [libraryKeys]
/// limits «Dalla libreria» (the playlist's own tracks), else every album's cover.
Future<void> showCoverPicker(
  BuildContext context, {
  required CoverSave save,
  ({String album, String artist})? online,
  List<String>? libraryKeys,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showCcSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CoverPickerSheet(save: save, online: online, libraryKeys: libraryKeys, messenger: messenger),
  );
}

String _mimeOf(String path) => path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

class _CoverPickerSheet extends ConsumerStatefulWidget {
  const _CoverPickerSheet({required this.save, required this.online, required this.libraryKeys, required this.messenger});

  final CoverSave save;
  final ({String album, String artist})? online;
  final List<String>? libraryKeys;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_CoverPickerSheet> createState() => _CoverPickerSheetState();
}

class _CoverPickerSheetState extends ConsumerState<_CoverPickerSheet> {
  // A second tap while one pick is being saved would save twice and pop twice.
  bool _busy = false;

  /// Runs one pick; [read] gives the bytes and mime, or null when there is nothing to save.
  Future<void> _run(Future<(List<int>, String?)?> Function() read) async {
    if (_busy) return;
    _busy = true;
    final l = context.l10n;
    String? error;
    try {
      final picked = await read();
      if (picked == null) return;
      if (!await widget.save(ref.read(coverOpsProvider), picked.$1, picked.$2)) error = l.coverTooLarge;
    } on Object catch (e, st) {
      AppLog.w('cover pick failed', e, st);
      error = l.bgImageFailed;
    } finally {
      _busy = false;
    }
    if (mounted) Navigator.pop(context);
    if (error != null) showMsgOn(widget.messenger, error);
  }

  Future<(List<int>, String?)?> _readFile(File file) async {
    // Async read: the bytes never block the UI thread; a huge file is refused unread.
    // Over the limit is not a failure: empty bytes make the save answer «too large».
    if (await file.length() > CoverStore.maxBytes) return (const <int>[], null);
    return (await file.readAsBytes(), _mimeOf(file.path));
  }

  Future<void> _fromDevice() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    final path = res.isEmpty ? null : res.first.path;
    if (path == null || !mounted) return;
    await _run(() => _readFile(File(path)));
  }

  Future<void> _fromLibrary(String key) => _run(() async {
        final file = ref.read(coverStoreProvider).fileFor(key);
        if (file == null) throw FileSystemException('cover file missing', key);
        return _readFile(file);
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final albums = ref.watch(albumsProvider).value ?? const [];
    final titles = {
      for (final a in albums)
        if (a.coverKey != null) a.coverKey!: a.title ?? l.unknownAlbum,
    };
    final keys = widget.libraryKeys ?? titles.keys.toList();
    final q = widget.online;
    final proposals = q == null ? const <CoverProposal>[] : ref.watch(coverProposalsProvider(q)).value;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: Text(l.coverSourceDevice),
              onTap: () => _fromDevice(),
            ),
            if (keys.isNotEmpty) ...[
              SectionHeader(l.coverSourceLibrary),
              SizedBox(
                height: _thumb,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
                  itemExtent: _thumb + CcDims.gap8,
                  itemCount: keys.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: CcDims.gap8),
                    child: InkWell(
                      key: ValueKey('library-cover-${keys[i]}'),
                      onTap: () => _fromLibrary(keys[i]),
                      child: CoverImage(coverKey: keys[i], size: _thumb, semanticLabel: titles[keys[i]] ?? l.coverSourceLibrary),
                    ),
                  ),
                ),
              ),
            ],
            if (q != null && (proposals == null || proposals.isNotEmpty)) ...[
              SectionHeader(l.coverSourceOnline),
              if (proposals == null)
                Skeleton.list(rows: 2, label: l.coverSourceOnline)
              else
                SizedBox(
                  height: _thumb + 28,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
                    itemExtent: _thumb + CcDims.gap8,
                    itemCount: proposals.length,
                    itemBuilder: (_, i) {
                      final c = proposals[i];
                      final size = l.coverSizePx(c.width, c.height);
                      return Padding(
                        padding: const EdgeInsets.only(right: CcDims.gap8),
                        child: Semantics(
                          button: true,
                          label: '${c.label}, $size',
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: () => _run(() async => (c.bytes, c.bytes[1] == 0x50 ? 'image/png' : 'image/jpeg')),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.memory(c.bytes, width: _thumb, height: _thumb, fit: BoxFit.cover, cacheWidth: 192),
                                Text(size, style: Theme.of(context).textTheme.labelSmall, maxLines: 1),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
            const SizedBox(height: CcDims.gap8),
          ],
        ),
      ),
    );
  }
}

const double _thumb = 96;
