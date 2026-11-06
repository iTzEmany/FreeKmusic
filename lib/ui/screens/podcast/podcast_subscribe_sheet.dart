import '../../widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/podcast_providers.dart';
import '../../../services/podcast/podcast_models.dart';
import '../../theme/tokens.dart';
import 'podcast_texts.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/show_msg.dart';
import '../../../core/app_log.dart';

/// «Aggiungi podcast»: paste a feed address, or search the public directory by
/// name and pick a result. Nothing is fetched until the user asks.
class PodcastSubscribeSheet extends ConsumerStatefulWidget {
  const PodcastSubscribeSheet({super.key});

  static Future<void> show(BuildContext context) => showCcSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: const PodcastSubscribeSheet(),
    ),
  );

  @override
  ConsumerState<PodcastSubscribeSheet> createState() =>
      _PodcastSubscribeSheetState();
}

class _PodcastSubscribeSheetState extends ConsumerState<PodcastSubscribeSheet> {
  final _url = TextEditingController();
  final _term = TextEditingController();
  List<PodcastSearchHit>? _hits;
  bool _busy = false;
  PodcastErrorKind? _error;

  @override
  void dispose() {
    _url.dispose();
    _term.dispose();
    super.dispose();
  }

  Future<void> _subscribe(String url, {String? name}) async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(podcastServiceProvider).subscribeFromUrl(url);
      if (!mounted) return;
      showMsg(context, l.podcastSubscribed(name ?? url.trim()));
      Navigator.of(context).pop();
    } on PodcastException catch (e) {
      AppLog.w('podcast subscribe failed', e);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.kind;
        });
      }
    }
  }

  Future<void> _search() async {
    final term = _term.text.trim();
    if (term.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final hits = await ref.read(podcastServiceProvider).search(term);
      if (mounted) {
        setState(() {
          _hits = hits;
          _busy = false;
        });
      }
    } on PodcastException catch (e) {
      AppLog.w('podcast subscribe failed', e);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.kind;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
        children: [
          Text(l.podcastAdd, style: theme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l.podcastsNotice,
            style: theme.bodySmall?.copyWith(color: cc.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('feed-url'),
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: l.podcastFeedUrl),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (v) => _busy || v.trim().isEmpty ? null : _subscribe(v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('feed-go'),
                onPressed: _busy || _url.text.trim().isEmpty
                    ? null
                    : () => _subscribe(_url.text),
                child: Text(l.podcastSubscribe),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('podcast-search'),
            controller: _term,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l.podcastSearchHint,
            ),
            onSubmitted: (_) => _busy ? null : _search(),
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: CcDims.gap12),
            child: LinearProgressIndicator(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: CcDims.gap12),
              child: Text(
                podcastErrorText(l, _error!),
                key: const ValueKey('subscribe-error'),
                style: TextStyle(color: cc.error),
              ),
            ),
          if (_hits != null && _hits!.isEmpty && !_busy)
            Padding(
              padding: const EdgeInsets.only(top: CcDims.gap16),
              child: Text(l.podcastSearchNone),
            ),
          for (final h in _hits ?? const <PodcastSearchHit>[])
            ListTile(
              key: ValueKey('hit-${h.feedUrl}'),
              contentPadding: EdgeInsets.zero,
              leading: NetThumbnail(
                url: h.artworkUrl,
                width: 48,
                height: 48,
                icon: Icons.podcasts_rounded,
              ),
              title: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  if (h.author != null) h.author!,
                  if (h.episodeCount != null) l.podcastEpisodesCount(h.episodeCount!),
                ].join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.add_rounded),
              onTap: _busy ? null : () => _subscribe(h.feedUrl, name: h.name),
            ),
        ],
      ),
    );
  }
}
