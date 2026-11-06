import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/import_providers.dart';
import '../../../providers/youtube_providers.dart';
import '../../../services/online/youtube_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/format_utils.dart';
import 'online_results.dart' show ytErrorText;
import '../../widgets/show_msg.dart';

/// A playlist (or channel) is long enough to warn about from here.
const longPlaylistVideos = 200;

/// Rough time per video (search is skipped, but download and conversion run
/// two at a time with pauses), used for the «it will take» estimate.
const secondsPerVideo = 15;

/// The sheet opened by pasting a YouTube playlist or channel address in Search:
/// its videos with a tick each (all ticked), a name, and one button that
/// downloads them into a new playlist in the listed order.
class PlaylistSourceSheet extends ConsumerStatefulWidget {
  const PlaylistSourceSheet({super.key, required this.url});

  /// The listing address (`listingUrl`), not what the user pasted.
  final String url;

  static Future<void> show(BuildContext context, String url) =>
      showCcSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.9,
          child: PlaylistSourceSheet(url: url),
        ),
      );

  @override
  ConsumerState<PlaylistSourceSheet> createState() =>
      _PlaylistSourceSheetState();
}

class _PlaylistSourceSheetState extends ConsumerState<PlaylistSourceSheet> {
  final _name = TextEditingController();
  Set<String>? _picked;
  bool _starting = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _init(PlaylistListing l) {
    if (_picked != null) return;
    _picked = {for (final e in l.entries) e.id};
    _name.text = l.title.isNotEmpty ? l.title : (l.owner ?? '');
  }

  Future<void> _go(PlaylistListing l) async {
    final l10n = context.l10n;
    final chosen = [
      for (final e in l.entries)
        if (_picked!.contains(e.id)) e,
    ];
    setState(() => _starting = true);
    final name = _name.text.trim();
    await ref
        .read(playlistImportServiceProvider)
        .startFromResults(name, chosen);
    if (!mounted) return;
    showMsg(
      context,
      l10n.playlistSourceStarted(name.isEmpty ? 'YouTube' : name),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final listing = ref.watch(playlistListingProvider(widget.url));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(l.playlistSourceTitle, style: theme.titleMedium),
          ),
        ),
        Expanded(
          child: listing.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12),
                  Text(l.playlistSourceLoading),
                ],
              ),
            ),
            error: (e, _) => ErrorState(
              message: e is YtException ? ytErrorText(context, e.kind) : '$e',
              onRetry: () =>
                  ref.invalidate(playlistListingProvider(widget.url)),
            ),
            data: (data) {
              _init(data);
              return _body(context, data);
            },
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, PlaylistListing data) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    if (data.entries.isEmpty) {
      return EmptyState(
        icon: Icons.queue_music_rounded,
        message: l.playlistSourceEmpty,
      );
    }
    final picked = _picked!;
    final all = picked.length == data.entries.length;
    final long = picked.length > longPlaylistVideos;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.margin,
            CcDims.gap8,
            CcDims.margin,
            0,
          ),
          child: TextField(
            key: const ValueKey('playlist-name'),
            controller: _name,
            decoration: InputDecoration(labelText: l.playlistSourceName),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.gap8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.playlistSourceCount(data.entries.length),
                  style: theme.labelLarge,
                ),
              ),
              TextButton(
                key: const ValueKey('toggle-all'),
                onPressed: () => setState(() {
                  if (all) {
                    picked.clear();
                  } else {
                    picked.addAll([for (final e in data.entries) e.id]);
                  }
                }),
                child: Text(all ? l.playlistSourceNone : l.selectAll),
              ),
            ],
          ),
        ),
        if (data.unavailable > 0)
          _note(l.playlistSourceUnavailable(data.unavailable), cc.textMuted),
        if (data.truncated)
          _note(l.playlistSourceTruncated(data.entries.length), cc.textMuted),
        if (long)
          _note(
            l.playlistSourceLong(
              picked.length,
              etaLabel(l, Duration(seconds: picked.length * secondsPerVideo)),
            ),
            cc.accentSoft,
          ),
        Expanded(
          child: ListView.builder(
            itemCount: data.entries.length,
            itemBuilder: (_, i) {
              final e = data.entries[i];
              return CheckboxListTile(
                key: ValueKey('video-${e.id}'),
                dense: true,
                value: picked.contains(e.id),
                onChanged: (v) => setState(() {
                  v == true ? picked.add(e.id) : picked.remove(e.id);
                }),
                title: Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (e.channel.isNotEmpty) e.channel,
                    if (e.duration != null)
                      formatDuration(e.duration!.inMilliseconds),
                  ].join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CcDims.margin),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('playlist-go'),
                onPressed: picked.isEmpty || _starting ? null : () => _go(data),
                icon: const Icon(Icons.download_rounded),
                label: Text(l.playlistSourceGo(picked.length)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _note(String text, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap4, CcDims.margin, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    ),
  );
}
