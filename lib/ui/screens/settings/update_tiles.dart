
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/update_providers.dart';
import '../../../services/online/update_checker.dart';
import '../../../services/update/update_installer.dart' show UpdateFailure;
import '../../../services/update/update_target.dart';
import '../../widgets/show_msg.dart' show CcSnackContent;

/// «Controlla aggiornamenti» and «Controlla all'avvio». Nothing while no
/// release repository is configured.
List<Widget> updateTiles(BuildContext context, WidgetRef ref) {
  if (ref.watch(releaseRepoProvider).isEmpty) return const [];
  final l = context.l10n;
  return [
    ListTile(
      leading: const Icon(Icons.system_update_alt_rounded),
      title: Text(l.updateCheck),
      subtitle: Text(l.updateCheckHint),
      onTap: () => showDialog<void>(context: context, builder: (_) => const UpdateDialog()),
    ),
    SwitchListTile(
      title: Text(l.updateOnStart),
      subtitle: Text(l.updateOnStartHint),
      value: ref.watch(checkUpdatesOnStartProvider),
      onChanged: ref.read(checkUpdatesOnStartProvider.notifier).set,
    ),
  ];
}

/// The start-up notice: «Aggiorna» opens the dialog on the release found.
SnackBar updateSnackBar(BuildContext context, UpdateInfo info, Duration duration) {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  void open() {
    messenger.hideCurrentSnackBar();
    showDialog<void>(context: context, builder: (_) => UpdateDialog(info: info));
  }

  return SnackBar(
    duration: duration,
    persist: false, // D-541: every snackbar times out
    content: Semantics(
      button: true,
      child: InkWell(onTap: open, child: CcSnackContent(l.updateAvailable(info.version), duration)),
    ),
    action: SnackBarAction(label: l.updateDo, onPressed: open),
  );
}

/// With [info] (from the start-up notice) nothing is asked again.
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, this.info});

  final UpdateInfo? info;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  late final Future<UpdateResult> _result = widget.info != null
      ? Future.value(UpdateResult(UpdateStatus.newer, widget.info))
      : ref.read(updateCheckerProvider)?.check() ?? Future.value(const UpdateResult(UpdateStatus.failed));

  // Back from Android's unknown-sources setting: go on with the file already downloaded.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(updateDownloadProvider.notifier).resumeInstall());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.updateCheck),
      content: FutureBuilder<UpdateResult>(
        future: _result,
        builder: (context, snap) {
          final r = snap.data;
          if (r == null) {
            return Row(children: [
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 16),
              Text(l.updateChecking),
            ]);
          }
          final info = r.info;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (r.status) {
                  UpdateStatus.newer => l.updateAvailable(info!.version),
                  UpdateStatus.upToDate => l.updateUpToDate(kAppVersion),
                  UpdateStatus.rateLimited => l.updateRateLimited,
                  UpdateStatus.failed => l.updateFailed,
                }),
                if (r.status == UpdateStatus.newer && info != null) ...[
                  if (info.notes.isNotEmpty) ...[const SizedBox(height: 12), Text(info.notes)],
                  const SizedBox(height: 12),
                  _UpdateProgress(info),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        FutureBuilder<UpdateResult>(
          future: _result,
          builder: (context, snap) {
            final info = snap.data?.status == UpdateStatus.newer ? snap.data!.info : null;
            if (info == null) return const SizedBox.shrink();
            return _UpdateActions(info);
          },
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.close)),
      ],
    );
  }
}

int _mb(int bytes) => (bytes / 1048576).round();

/// The file, then what the update flow is doing (D-656 asks before a metered download).
class _UpdateProgress extends ConsumerWidget {
  const _UpdateProgress(this.info);

  final UpdateInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(updateDownloadProvider);
    final target = ref.watch(updateTargetProvider).value;
    final asset = s.asset ?? (target == null ? null : pickUpdateAsset(info.assets, target));
    final err = Theme.of(context).colorScheme.error;
    Widget title(String t, {bool bad = false}) =>
        Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: bad ? err : null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (asset != null) Text(l.updateFile(asset.name, _mb(asset.size))),
        const SizedBox(height: 8),
        switch (s.phase) {
          UpdatePhase.idle => const SizedBox.shrink(),
          UpdatePhase.confirmSize => Text(l.updateMeteredAsk(_mb(asset?.size ?? 0))),
          UpdatePhase.downloading => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: asset == null || asset.size <= 0 ? null : s.received / asset.size,
                semanticsLabel: l.updateProgress(_mb(s.received), _mb(asset?.size ?? 0)),
              ),
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: Text(
                  l.updateProgress(_mb(s.received), _mb(asset?.size ?? 0)),
                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
          UpdatePhase.ready => Text(l.updateInstalling),
          UpdatePhase.needsPermission => Text(l.updatePermissionBody),
          UpdatePhase.differentSigner => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title(l.updateDifferentSignerTitle, bad: true), Text(l.updateDifferentSignerBody)],
          ),
          UpdatePhase.error => switch (s.failure) {
            UpdateFailure.interrupted => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title(l.updateInterruptedTitle), Text(l.updateInterruptedBody)],
            ),
            UpdateFailure.corrupt => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title(l.updateCorruptTitle, bad: true), Text(l.updateCorruptBody)],
            ),
            _ => Text(l.updateInstallFailed),
          },
        },
      ],
    );
  }
}

class _UpdateActions extends ConsumerWidget {
  const _UpdateActions(this.info);

  final UpdateInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final n = ref.read(updateDownloadProvider.notifier);
    final target = ref.watch(updateTargetProvider).value;
    return switch (ref.watch(updateDownloadProvider).phase) {
      UpdatePhase.idle => TextButton(
        onPressed: () => n.start(info),
        child: Text(target != null && selfInstalls(target.kind) ? l.updateDo : l.updateFromBrowser),
      ),
      UpdatePhase.confirmSize => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: n.cancel, child: Text(l.cancel)),
          TextButton(onPressed: n.confirm, child: Text(l.updateDownload)),
        ],
      ),
      UpdatePhase.downloading => TextButton(onPressed: n.cancel, child: Text(l.cancel)),
      UpdatePhase.error => TextButton(onPressed: n.retry, child: Text(l.retry)),
      // Whoever cancels the system installer, or comes back with the dialog closed, can start again.
      UpdatePhase.ready || UpdatePhase.needsPermission => TextButton(onPressed: n.retry, child: Text(l.updateDo)),
      UpdatePhase.differentSigner => const SizedBox.shrink(),
    };
  }
}
