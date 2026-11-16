import '../settings/auto_backup_tile.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as pth;

import '../../../core/permissions.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/exportify_providers.dart';
import '../../../providers/folder_actions.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/memory_providers.dart';
import '../../../data/settings/settings_store.dart' show StorageMode;
import '../../widgets/format_utils.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/scanner/library_scanner.dart' show ScanProgress;
import '../../theme/tokens.dart';
import '../../../core/storage_volumes.dart' show sdRootOf;
import '../import/exportify_remind_choice.dart';
import '../../../providers/storage_providers.dart' show sdVolumesProvider;
import 'onboarding_screen.dart' show onboardingPageCount;

class _Page extends StatelessWidget {
  const _Page({
    required this.index,
    required this.icon,
    required this.title,
    required this.children,
  });

  /// Zero-based position in the guide: the ring fills one sixth per page.
  final int index;
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    const total = onboardingPageCount;
    final label = l.onboardingPageOf(index + 1, total);
    final step = l.onboardingStepOf(index + 1, total);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: CcDims.margin + CcDims.gap8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CcDims.margin),
          Semantics(
            label: label,
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: (index + 1) / total),
                    duration: ccDuration(context, CcMotion.enter),
                    curve: CcMotion.curveIn,
                    builder: (_, v, _) => CustomPaint(
                      size: const Size.square(140),
                      painter: _PageRing(v, cc.accent, cc.surface3, cc.surface2),
                    ),
                  ),
                  Icon(icon, size: 44, color: cc.accentSoft),
                ],
              ),
            ),
          ),
          const SizedBox(height: CcDims.gap8),
          Text(step, style: theme.bodySmall?.copyWith(color: cc.textMuted)),
          const SizedBox(height: CcDims.gap24),
          Text(title, style: theme.headlineSmall),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Ring of the page counter: a track, the arc from the top and a centre disc.
class _PageRing extends CustomPainter {
  const _PageRing(this.fraction, this.arc, this.rest, this.disc);

  final double fraction;
  final Color arc, rest, disc;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, line..color = rest);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * fraction, false, line..color = arc);
    canvas.drawCircle(c, r - stroke, Paint()..color = disc);
  }

  @override
  bool shouldRepaint(_PageRing o) =>
      o.fraction != fraction || o.arc != arc || o.rest != rest || o.disc != disc;
}

/// A list row with the 1 px separator under it (folders).
Widget _row(BuildContext context, Widget child) => Container(
  constraints: const BoxConstraints(minHeight: 48),
  alignment: Alignment.centerLeft,
  decoration: BoxDecoration(
    border: Border(bottom: BorderSide(color: context.cc.separator, width: CcDims.rHair)),
  ),
  child: child,
);

Widget _body(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: CcDims.gap12),
  child: Text(
    text,
    style: Theme.of(context).textTheme.bodyLarge
        ?.copyWith(color: context.cc.textMuted),
  ),
);

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Page(
      index: 0,
      icon: Icons.music_note_rounded,
      title: l.onboardingWelcomeTitle,
      children: [_body(context, l.onboardingWelcomeBody)],
    );
  }
}

/// Folders are added (and scanned) here.
class FoldersPage extends ConsumerStatefulWidget {
  const FoldersPage({super.key, required this.askAudioPermission});

  final bool askAudioPermission;

  @override
  ConsumerState<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends ConsumerState<FoldersPage> {
  bool? _granted;

  Future<void> _allow() async {
    final ok = await ensureAudioPermission();
    if (mounted) setState(() => _granted = ok);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final folders = ref.watch(foldersProvider).value ?? const [];
    final scan = ref.watch(scanStateProvider);
    return _Page(
      index: 1,
      icon: Icons.folder_rounded,
      title: l.onboardingFoldersTitle,
      children: [
        _body(context, l.onboardingFoldersBody),
        if (widget.askAudioPermission) ...[
          // Said before Android asks, so the system prompt is not a surprise.
          _body(context, l.permissionExplain),
          Align(
            alignment: Alignment.centerLeft,
            child: _granted == true
                ? Chip(
                    avatar: Icon(
                      Icons.check_circle_rounded,
                      color: context.cc.accent,
                    ),
                    label: Text(l.onboardingAccessGranted),
                  )
                : OutlinedButton.icon(
                    onPressed: _allow,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(l.onboardingAllowAccess),
                  ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: () => addFolderAndScan(ref),
          icon: const Icon(Icons.create_new_folder_rounded),
          label: Text(l.addFolder),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => addDefaultFolderAndScan(ref), child: Text(l.useDefaultFolder)),
        if (scan.running) _ScanProgress(scan.progress),
        if (folders.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l.onboardingFoldersAdded(folders.length),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          for (final f in folders)
            _row(
              context,
              Row(
                children: [
                  Icon(Icons.folder_outlined, color: context.cc.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.cc.textMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Under this much free space the guide suggests streaming (D-575).
const _lowSpaceBytes = 4 * 1024 * 1024 * 1024;

/// «Dove tieni la musica?»: files on the device or saved tracks in streaming.
class StoragePage extends ConsumerStatefulWidget {
  const StoragePage({super.key});

  @override
  ConsumerState<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends ConsumerState<StoragePage> {
  bool _preselected = false;

  void _set(StorageMode m) =>
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(storageMode: m));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final free = ref.watch(musicDiskSpaceProvider).value?.freeBytes;
    if (free != null && !_preselected) {
      _preselected = true;
      final m = free < _lowSpaceBytes ? StorageMode.stream : StorageMode.device;
      // After the frame: a provider cannot change while the tree is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _set(m);
      });
    }
    final mode = ref.watch(settingsProvider.select((s) => s.storageMode));
    final sds = ref.watch(sdVolumesProvider).value ?? const <String>[];
    final sdChosen = sds.contains(ref.watch(settingsProvider.select((s) => s.downloadLocation)));
    return _Page(
      index: 2,
      icon: Icons.storage_rounded,
      title: l.onboardingStorageTitle,
      children: [
        _body(context, l.onboardingStorageBody),
        if (free != null) _body(context, l.onboardingStorageFree(formatBytes(free, l.localeName))),
        RadioGroup<StorageMode>(
          groupValue: mode,
          onChanged: (m) {
            if (m != null) _set(m);
          },
          child: Column(
            children: [
              RadioListTile<StorageMode>(
                contentPadding: EdgeInsets.zero,
                value: StorageMode.device,
                title: Text(l.storageModeDevice),
                subtitle: Text(l.onboardingStorageDeviceHint),
              ),
              RadioListTile<StorageMode>(
                contentPadding: EdgeInsets.zero,
                value: StorageMode.stream,
                title: Text(l.storageModeStream),
                subtitle: Text(l.onboardingStorageStreamHint),
              ),
            ],
          ),
        ),
        // D-579: only with a card in the device and files kept on it.
        if (mode == StorageMode.device && sds.isNotEmpty)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.downloadMemorySd(pth.basename(sdRootOf(sds.first) ?? sds.first))),
            subtitle: Text(l.onboardingStorageSdHint),
            value: sdChosen,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .update((s) => s.copyWith(downloadLocation: v ? sds.first : '')),
          ),
        const AutoBackupTile(onboarding: true),
      ],
    );
  }
}

/// Scan in progress after a folder is added (the scan itself is shared).
class _ScanProgress extends StatelessWidget {
  const _ScanProgress(this.progress);

  final ScanProgress? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final known = p != null && p.total > 0;
    return Padding(
      padding: const EdgeInsets.only(top: CcDims.gap12),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              known ? '${context.l10n.scanning} ${p.done} / ${p.total}' : context.l10n.scanning,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: CcDims.gap8),
            LinearProgressIndicator(value: known ? p.done / p.total : null),
          ],
        ),
      ),
    );
  }
}

/// The two online features, off until the user turns them on.
class OnlinePage extends ConsumerWidget {
  const OnlinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return _Page(
      index: 3,
      icon: Icons.cloud_outlined,
      title: l.onboardingOnlineTitle,
      children: [
        _body(context, l.onboardingOnlineBody),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.autoEnrich),
          subtitle: Text(l.autoEnrichHint),
          value: s.autoEnrich,
          onChanged: (v) => notifier.update((c) => c.copyWith(autoEnrich: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.autoLyrics),
          subtitle: Text(l.autoLyricsHint),
          value: s.autoLyrics,
          onChanged: (v) => notifier.update((c) => c.copyWith(autoLyrics: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.autoCuriosities),
          subtitle: Text(l.autoCuriositiesHint),
          value: s.autoCuriosities,
          onChanged: (v) =>
              notifier.update((c) => c.copyWith(autoCuriosities: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.deezerMeta),
          subtitle: Text(l.deezerMetaHint),
          value: s.deezerMeta,
          onChanged: (v) => notifier.update((c) => c.copyWith(deezerMeta: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.creditsDetails),
          subtitle: Text('${l.creditsDetailsHint}\n${l.creditsDetailsNote}'),
          value: s.creditsDetails,
          onChanged: (v) => notifier.update((c) => c.copyWith(creditsDetails: v)),
        ),
      ],
    );
  }
}

/// Optional: how to bring Spotify playlists in, and the reminder (off).
class SpotifyPage extends ConsumerWidget {
  const SpotifyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lines = l.onboardingSpotifyBody.split('\n');
    return _Page(
      index: 4,
      icon: Icons.playlist_add_rounded,
      title: l.onboardingSpotifyTitle,
      children: [
        for (final line in lines) _body(context, line),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => openExportify(ref),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l.csvImportOpenExportify),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.exportifyRemindTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const ExportifyRemindChoice(),
      ],
    );
  }
}

class SharePage extends StatelessWidget {
  const SharePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    return _Page(
      index: 5,
      icon: Icons.devices_rounded,
      title: l.onboardingShareTitle,
      children: [
        _body(context, l.onboardingYoutubeBody),
        Container(
          padding: const EdgeInsets.all(CcDims.gap12),
          margin: const EdgeInsets.only(bottom: CcDims.gap12),
          decoration: BoxDecoration(
            color: cc.surface1,
            borderRadius: BorderRadius.circular(CcDims.rCard),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: cc.accentSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.ytLegal,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        _body(context, l.onboardingJamBody),
        _body(context, l.onboardingSendBody),
      ],
    );
  }
}
