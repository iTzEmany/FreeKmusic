import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/youtube_providers.dart' show downloadsProvider;
import '../../services/online/download_queue.dart';
import '../theme/tokens.dart';

/// The one widget that shows the download of a song (D-697).
///
///     DownloadBar(entryKey: result.indexKey, idle: <the button it replaces>, compact: false)
///
/// [entryKey] is the `source:id` key of `downloads.json` (`YtResult.indexKey`).
/// While the song is queued or downloading it shows the progress; when the
/// download ends it shows «Scaricato» for [doneFor], then goes back to [idle]
/// (the button that gives way to the bar). A [compact] bar is a 48 px round
/// indicator for list rows and shows no «Scaricato» (the row has its own tick).
/// The one widget that shows the progress of a song's download; the online rows and lists
/// (`online_song_row`, `online_results_sections`, `genre_screen`, `suggestions_screen`) also read `downloadsProvider`,
/// only to find the item (failed / done state of the row), never to draw a bar.
class DownloadBar extends ConsumerStatefulWidget {
  const DownloadBar({
    super.key,
    required this.entryKey,
    this.idle = const SizedBox.shrink(),
    this.compact = false,
    this.doneFor = const Duration(seconds: 4),
  });

  final String entryKey;
  final Widget idle;
  final bool compact;
  final Duration doneFor;

  @override
  ConsumerState<DownloadBar> createState() => _DownloadBarState();
}

class _DownloadBarState extends ConsumerState<DownloadBar> {
  Timer? _doneTimer;
  bool _showDone = false;

  static bool _active(DownloadStatus? s) =>
      s == DownloadStatus.queued ||
      s == DownloadStatus.downloading ||
      s == DownloadStatus.waitingRetry;

  DownloadItem? _latest(List<DownloadItem> all) =>
      all.where((x) => x.result.indexKey == widget.entryKey).lastOrNull;

  @override
  void didUpdateWidget(DownloadBar old) {
    super.didUpdateWidget(old);
    // Another song took the slot: its «Scaricato» is not the previous one's.
    if (old.entryKey != widget.entryKey) {
      _doneTimer?.cancel();
      _showDone = false;
    }
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    super.dispose();
  }

  void _onChange(DownloadItem? before, DownloadItem? now) {
    if (!_active(before?.status) || now?.status != DownloadStatus.done) return;
    if (widget.compact) return;
    _doneTimer?.cancel();
    setState(() => _showDone = true);
    _doneTimer = Timer(widget.doneFor, () {
      if (mounted) setState(() => _showDone = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DownloadItem?>(downloadsProvider.select(_latest), _onChange);
    final item = ref.watch(downloadsProvider.select(_latest));
    final l = context.l10n;
    final cc = context.cc;
    if (_active(item?.status)) {
      final value = item!.status == DownloadStatus.downloading
          ? item.progress
          : null;
      final label = value == null
          ? l.ytDownloading
          : l.downloadBarProgress((value * 100).round());
      if (widget.compact) {
        return Semantics(
          label: label,
          excludeSemantics: true,
          child: SizedBox(
            width: 48,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: value,
                ),
              ),
            ),
          ),
        );
      }
      return Semantics(
        label: label,
        excludeSemantics: true,
        child: _Block(
          color: cc.surface2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: value,
                borderRadius: BorderRadius.circular(CcDims.rList),
              ),
            ],
          ),
        ),
      );
    }
    if (_showDone) {
      return _Block(
        color: cc.surface2,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 18, color: cc.accentSoft),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l.downloadBarDone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      );
    }
    return widget.idle;
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(CcDims.rCard),
    ),
    alignment: Alignment.center,
    child: child,
  );
}
