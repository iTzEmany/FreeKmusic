import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/track_ops.dart';
import '../../../providers/online_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/translation_providers.dart';
import '../../../services/lyrics/lyrics_shown.dart';
import '../../../services/online/http_client.dart';
import '../../../services/online/lrc_parser.dart';
import '../../../services/online/lrclib_client.dart';
import '../../theme/tokens.dart';
import '../../widgets/show_msg.dart';
import 'lyrics_editor.dart';

/// Synchronised lyrics that scroll by themselves (variable-height rows, the
/// current one near the upper third), or the plain text, or a search button.
/// Used by the Lyrics page and the desktop side panel.
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  List<LrcLine> _lines = const [];
  List<GlobalKey> _keys = const [];
  String? _parsedFor;
  final _index = ValueNotifier<int>(-1);
  final _scroll = ScrollController();
  bool _searching = false;

  void _ensureParsed(String? synced) {
    if (synced == _parsedFor) return;
    _parsedFor = synced;
    _lines = synced == null ? const [] : parseLrc(synced);
    _keys = [for (var i = 0; i < _lines.length; i++) GlobalKey()];
    _index.value = -1;
  }

  @override
  void dispose() {
    _index.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onPosition(Duration pos) {
    if (_lines.isEmpty) return;
    final i = currentLrcIndex(_lines, pos);
    if (i == _index.value) return;
    _index.value = i;
    if (i < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || i >= _keys.length) return;
      _reveal(i, 0);
    });
  }

  /// Centres line [i]. A row not built yet is reached by a scroll to an offset
  /// estimated from the rows built so far, then tried again next frame.
  void _reveal(int i, int attempt) {
    final ctx = _keys[i].currentContext;
    if (ctx != null) {
      if (!ctx.mounted) return;
      final reduce = MediaQuery.disableAnimationsOf(context);
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: reduce ? Duration.zero : CcMotion.sheet,
        curve: CcMotion.curveIn,
      );
      return;
    }
    if (attempt >= 3 || !_scroll.hasClients) return;
    final pos = _scroll.position;
    // The list's own extent estimate follows the average built row height.
    final total = pos.maxScrollExtent + pos.viewportDimension;
    // Aim half a viewport short so the row is inside the built range, not just past it.
    final target = (total * i / _lines.length - pos.viewportDimension / 2)
        .clamp(0.0, pos.maxScrollExtent);
    void retry() {
      if (mounted && i < _keys.length) _reveal(i, attempt + 1);
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      pos.jumpTo(target);
      WidgetsBinding.instance.addPostFrameCallback((_) => retry());
    } else {
      // Try again once the scroll has landed, so the row is built by then.
      pos
          .animateTo(target, duration: CcMotion.sheet, curve: CcMotion.curveIn)
          .then((_) => retry());
    }
  }

  Future<void> _search(Track t) async {
    final l = context.l10n;
    setState(() => _searching = true);
    LyricsResult? found;
    var unavailable = false;
    try {
      final r = await ref.read(lyricsChainProvider).find(t);
      found = r.lyrics;
      unavailable = r.failed;
    } on RateLimitedException {
      unavailable = true;
    } finally {
      if (mounted) setState(() => _searching = false);
    }
    if (!mounted) return;
    if (found == null) {
      showMsg(context, unavailable ? l.serviceUnavailable : l.lyricsNotFound);
      return;
    }
    final result = found;
    // The user asked for this text: the automatic searches never replace it.
    await ref
        .read(trackOpsProvider)
        .setLyrics(
          t.id,
          plain: result.plain,
          synced: result.synced,
          byUser: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final unsynced = ref.watch(unsyncedLyricsProvider);
    final track = lyricsAsShown(widget.track, unsynced);
    ref.listen(positionProvider, (_, next) {
      final p = next.value;
      if (p != null) _onPosition(p);
    });
    _ensureParsed(track.lyricsSynced);
    final tr = ref.watch(lyricsTranslationProvider);
    final translated = tr != null && tr.trackId == track.id ? tr : null;

    if (_lines.isNotEmpty) {
      final ctrl = ref.read(playerControllerProvider);
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          CcDims.margin,
          CcDims.gap24,
          CcDims.margin,
          200,
        ),
        itemCount: _lines.length,
        itemBuilder: (_, i) => _LyricRow(
          key: _keys[i],
          index: i,
          current: _index,
          onTap: () => ctrl.seek(_lines[i].time),
          text: _lines[i].text.isEmpty ? '♪' : _lines[i].text,
          translation:
              translated != null &&
                  translated.synced &&
                  i < translated.lines.length &&
                  translated.lines[i] != _lines[i].text
              ? translated.lines[i]
              : null,
        ),
      );
    }
    final plain = track.lyricsPlain;
    if (plain != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(CcDims.margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              plain,
              style: theme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
            if (unsynced.contains(track.id) &&
                widget.track.lyricsSynced != null) ...[
              const SizedBox(height: CcDims.gap16),
              Text(
                l.lyricsSyncedKept,
                style: theme.bodySmall?.copyWith(color: cc.textMuted),
              ),
            ],
            if (translated != null && !translated.synced) ...[
              const Divider(height: 32),
              SelectableText(
                translated.lines.join('\n'),
                key: const ValueKey('translated-plain'),
                style: theme.titleMedium?.copyWith(color: cc.textMuted),
              ),
            ],
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.noLyrics,
            style: theme.bodyLarge?.copyWith(color: cc.textMuted),
          ),
          const SizedBox(height: 12),
          _searching
              ? const SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : FilledButton(
                  onPressed: () => _search(track),
                  child: Text(l.searchLyrics),
                ),
          if (!_searching)
            Semantics(
              label: l.lyricsWriteA11y,
              excludeSemantics: true,
              child: TextButton(
                onPressed: () => openLyricsEditor(context, widget.track),
                child: Text(l.lyricsWrite),
              ),
            ),
        ],
      ),
    );
  }
}

/// One synced line: only the old and the new current row repaint on a change;
/// the colour fades instead of an Opacity layer.
class _LyricRow extends StatefulWidget {
  const _LyricRow({
    super.key,
    required this.index,
    required this.current,
    required this.onTap,
    required this.text,
    this.translation,
  });

  final int index;
  final ValueListenable<int> current;
  final VoidCallback onTap;
  final String text;
  final String? translation;

  @override
  State<_LyricRow> createState() => _LyricRowState();
}

class _LyricRowState extends State<_LyricRow> {
  late double _alpha = _alphaFor(widget.current.value);

  double _alphaFor(int cur) => cur < 0
      ? 0.55
      : (widget.index == cur ? 1.0 : (widget.index < cur ? 0.55 : 0.35));

  void _changed() {
    final a = _alphaFor(widget.current.value);
    if (a != _alpha) setState(() => _alpha = a);
  }

  @override
  void initState() {
    super.initState();
    widget.current.addListener(_changed);
  }

  @override
  void dispose() {
    widget.current.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final big = theme.titleLarge;
    final small = theme.titleMedium?.copyWith(color: context.cc.textMuted);
    Color? fade(TextStyle? s, double a) =>
        s?.color?.withValues(alpha: a * (s.color?.a ?? 1));
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(CcDims.rGrid),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CcDims.gap8),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _alpha),
          duration: ccDuration(context, CcMotion.enter),
          builder: (_, a, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.text, style: big?.copyWith(color: fade(big, a))),
              if (widget.translation != null)
                Text(
                  widget.translation!,
                  key: ValueKey('translated-${widget.index}'),
                  style: small?.copyWith(color: fade(small, a)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
