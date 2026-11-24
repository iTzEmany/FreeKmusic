import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/update_providers.dart';
import '../../../services/online/update_checker.dart';
import '../../../services/update/release_notes.dart';
import '../../../services/update/update_installer.dart' show UpdateFailure;
import '../../../services/update/update_target.dart';
import '../../theme/tokens.dart';
import '../../widgets/release_notes_view.dart';

/// «Aggiornamento disponibile»: a full-screen sheet on a phone, a two-column dialog from
/// [CcDims.wideBreakpoint]. With [info] (the start-up notice) nothing is asked again.
Future<void> showUpdate(BuildContext context, {UpdateInfo? info}) {
  final page = UpdatePage(info: info);
  return MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint
      ? showDialog<void>(context: context, builder: (_) => page)
      : Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => page));
}

class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key, this.info});

  final UpdateInfo? info;

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
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
    final wide = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    return FutureBuilder<UpdateResult>(
      future: _result,
      builder: (context, snap) {
        final r = snap.data;
        final info = r?.status == UpdateStatus.newer ? r!.info : null;
        if (info == null) {
          final body = r == null
              ? Row(
                  children: [
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 16),
                    Text(l.updateChecking),
                  ],
                )
              : Text(switch (r.status) {
                  UpdateStatus.upToDate => l.updateUpToDate(kAppVersion),
                  UpdateStatus.rateLimited => l.updateRateLimited,
                  _ => l.updateFailed,
                });
          return wide
              ? AlertDialog(
                  title: Text(l.updateCheck),
                  content: body,
                  actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.close))],
                )
              : Scaffold(
                  appBar: AppBar(title: Text(l.updateCheck)),
                  body: Padding(padding: const EdgeInsets.all(CcDims.margin), child: body),
                );
        }
        final notes = ReleaseNotesView(notes: parseReleaseNotes(info.notes), url: info.url);
        final head = _Head(info);
        final foot = _UpdateFooter(info);
        if (!wide) {
          return Scaffold(
            appBar: AppBar(),
            body: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
                    children: [head, notes],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(padding: const EdgeInsets.all(CcDims.margin), child: foot),
                ),
              ],
            ),
          );
        }
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880, maxHeight: 600),
            child: Row(
              children: [
                SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(CcDims.gap24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head, const Spacer(), foot]),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SingleChildScrollView(padding: const EdgeInsets.all(CcDims.gap24), child: notes),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.info);

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(l.updateArrived(info.version), style: t.textTheme.headlineSmall)),
        Text(l.updateFrom(kAppVersion), style: t.textTheme.bodyMedium),
      ],
    );
  }
}

int _mb(int bytes) => (bytes / 1048576).round();

/// What the update flow is doing and its one button, pinned at the bottom (D-656 asks before
/// a metered download; the download turns the button into the bar).
class _UpdateFooter extends ConsumerWidget {
  const _UpdateFooter(this.info);

  final UpdateInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(updateDownloadProvider);
    final n = ref.read(updateDownloadProvider.notifier);
    final target = ref.watch(updateTargetProvider).value;
    final asset = s.asset ?? (target == null ? null : pickUpdateAsset(info.assets, target));
    final self = target != null && selfInstalls(target.kind);
    final mb = _mb(asset?.size ?? 0);
    final err = Theme.of(context).colorScheme.error;
    Widget title(String t, {bool bad = false}) =>
        Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: bad ? err : null));
    Widget main(String label, VoidCallback onPressed) => FilledButton(onPressed: onPressed, child: Text(label));
    final children = switch (s.phase) {
      UpdatePhase.idle => [
        Text(self ? l.updateSelfHint : l.updateBrowserHint),
        const SizedBox(height: 12),
        main(self ? (mb > 0 ? l.updateWithSize(mb) : l.updateDo) : l.updateFromBrowser, () => n.start(info)),
      ],
      UpdatePhase.confirmSize => [
        Text(l.updateMeteredAsk(mb)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: n.cancel, child: Text(l.cancel)),
            ),
            const SizedBox(width: 8),
            Expanded(child: main(l.updateDownload, n.confirm)),
          ],
        ),
      ],
      UpdatePhase.downloading => [
        LinearProgressIndicator(
          value: asset == null || asset.size <= 0 ? null : s.received / asset.size,
          semanticsLabel: l.updateProgress(_mb(s.received), mb),
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: Text(
            l.updateProgress(_mb(s.received), mb),
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
        Text(l.updateKeepListening),
        TextButton(onPressed: n.cancel, child: Text(l.cancel)),
      ],
      UpdatePhase.ready => [Text(l.updateInstalling), main(l.updateDo, n.retry)],
      // Whoever cancels the system installer, or comes back with the page closed, can start again.
      UpdatePhase.needsPermission => [
        Text(l.updatePermissionBody),
        const SizedBox(height: 12),
        main(l.updateDo, n.retry),
      ],
      UpdatePhase.differentSigner => [
        title(l.updateDifferentSignerTitle, bad: true),
        Text(l.updateDifferentSignerBody),
      ],
      UpdatePhase.error => [
        switch (s.failure) {
          UpdateFailure.interrupted => title(l.updateInterruptedTitle),
          UpdateFailure.corrupt => title(l.updateCorruptTitle, bad: true),
          _ => const SizedBox.shrink(),
        },
        Text(switch (s.failure) {
          UpdateFailure.interrupted => l.updateInterruptedBody,
          UpdateFailure.corrupt => l.updateCorruptBody,
          _ => l.updateInstallFailed,
        }),
        const SizedBox(height: 12),
        main(l.retry, n.retry),
      ],
    };
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
