import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/smart_search_providers.dart';
import '../../../services/online/merge_results.dart';
import '../../../services/online/query_intent.dart';
import '../../../services/online/query_match.dart' show MediaKind;
import '../../../services/online/smart_search.dart';
import '../../../services/online/youtube_service.dart';
import '../../../services/online/youtube_urls.dart';
import '../../../services/online/ytm_artist.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/motion.dart';
import '../../widgets/section_header.dart';
import '../../widgets/yt_dlp_outdated_banner.dart';
import '../online/album_card.dart';
import '../online/artist_card.dart';
import '../online/artist_page_screen.dart';
import '../online/online_album_screen.dart';
import '../online/online_selection_scope.dart';
import '../online/online_song_row.dart';
import 'online_results_sections.dart';
import 'playlist_source_sheet.dart';

String ytErrorText(BuildContext context, YtErrorKind k) {
  final l = context.l10n;
  return switch (k) {
    YtErrorKind.unavailable => l.ytErrUnavailable,
    YtErrorKind.network => l.ytErrNetwork,
    YtErrorKind.changed => l.ytErrChanged,
    YtErrorKind.toolMissing => l.ytErrToolMissing,
    YtErrorKind.rateLimited => l.ytErrRateLimited,
    YtErrorKind.toolOutdated => l.ytErrToolOutdated,
  };
}

/// Online results for [query]: YouTube Music and YouTube together, the same
/// song once, the sure ones first. The search runs only when [submitted]
/// changes (Enter / the arrow / «Cerca online»), never while typing.
class OnlineResults extends ConsumerStatefulWidget {
  const OnlineResults({
    super.key,
    required this.query,
    required this.submitted,
  });

  final String query;
  final int submitted;

  @override
  ConsumerState<OnlineResults> createState() => _OnlineResultsState();
}

class _OnlineResultsState extends ConsumerState<OnlineResults> {
  /// Results are picked by their place in best + others (before any filter).
  static final _selectionKey = SelectionKey.online.key;
  SmartSearchRequest? _request;
  int _serial = 0;

  /// The source filter and the «Altri risultati» list: both start over with
  /// each search.
  MediaKind? _filter;
  bool _othersOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.submitted > 0) _search();
  }

  @override
  void didUpdateWidget(OnlineResults old) {
    super.didUpdateWidget(old);
    if (widget.submitted != old.submitted) _search();
  }

  void _search({bool refresh = false}) {
    final q = widget.query.trim();
    if (q.isEmpty) return;
    // A playlist or channel address is not a search: it opens its video list.
    final listing = listingUrl(q);
    if (listing != null) {
      // After the frame: a sheet cannot be opened while the page is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) PlaylistSourceSheet.show(context, listing);
      });
      return;
    }
    final first = _request == null;
    setState(() {
      _request = (query: q, refresh: refresh, serial: ++_serial);
      _filter = null;
      _othersOpen = false;
    });
    // Picks refer to rows of the old results (not while the tree is building).
    if (!first) {
      scheduleMicrotask(() {
        if (mounted) {
          ref.read(selectionProvider(_selectionKey).notifier).clear();
        }
      });
    }
  }

  Future<void> _pullToRefresh() async {
    _search(refresh: true);
    await Future<void>.delayed(CcTiming.afterRefresh);
  }

  void _openArtist(YtmArtistRef artist) =>
      ShellNav.open<void>(context, ArtistPageScreen(artist: artist));

  void _openAlbum(YtmRelease r) => ShellNav.open<void>(
    context,
    OnlineAlbumScreen(browseId: r.browseId, release: r),
  );

  void _pickFilter(MediaKind? k) {
    if (k == _filter) return;
    ref.read(selectionProvider(_selectionKey).notifier).clear();
    setState(() => _filter = k);
  }

  /// Starts a download for each picked row that is not already in the library
  /// or on its way.
  void _downloadSelection(List<SmartResult> all) {
    final picked = ref.read(selectionProvider(_selectionKey));
    startOnlineDownloads(context, ref, [
      for (final i in picked.orderedIds)
        if (i < all.length) all[i].primary,
    ]);
    ref.read(selectionProvider(_selectionKey).notifier).clear();
  }

  bool _shows(SmartResult r) => _filter == null || r.sources.contains(_filter);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final seen = ref.watch(settingsProvider.select((s) => s.ytNoticeSeen));
    final picked = ref.watch(selectionProvider(_selectionKey));
    final request = _request;
    final async = request == null
        ? null
        : ref.watch(smartSearchProvider(request));
    final s = async?.value;
    final all = s == null ? const <SmartResult>[] : [...s.best, ...s.others];
    final bestEnd = s?.best.length ?? 0;
    // (place in `all`, row) of what is shown under the filter.
    final shownBest = [
      for (var i = 0; i < bestEnd; i++)
        if (_shows(all[i])) (i, all[i]),
    ];
    final shownOthers = [
      for (var i = bestEnd; i < all.length; i++)
        if (_shows(all[i])) (i, all[i]),
    ];
    final shownIds = [
      for (final (i, _) in shownBest) i,
      if (_othersOpen)
        for (final (i, _) in shownOthers) i,
    ];
    final error = s?.error ?? async?.error;
    final retry = TextButton(
      key: const ValueKey('online-retry'),
      onPressed: () => _search(refresh: true),
      child: Text(l.retry),
    );
    return OnlineSelectionScope(
      selectionKey: _selectionKey,
      ids: shownIds,
      actions: (_) => [
        IconButton(
          tooltip: l.ytDownload,
          icon: const Icon(Icons.download_rounded),
          onPressed: () => _downloadSelection(all),
        ),
      ],
      child: Column(
        children: [
          const YtDlpOutdatedBanner(),
          if (!seen) const _LegalNotice(),
          if (request == null)
            Expanded(
              child: EmptyState(
                icon: Icons.smart_display,
                message: l.ytSearchPrompt,
              ),
            )
          else if (s == null && error == null)
            const LinearProgressIndicator(minHeight: 2)
          else ...[
            // Its place is always there: the list below never jumps when it goes.
            SizedBox(
              height: 2,
              child: s != null && s.loading
                  ? const LinearProgressIndicator(minHeight: 2)
                  : null,
            ),
            if (s != null) SearchNotices(notices: s.notices),
            if (all.isNotEmpty)
              SourceFilterChips(filter: _filter, onPick: _pickFilter),
            Expanded(
              child: error != null && all.isEmpty
                  ? _ErrorView(error: error, retry: retry)
                  : s != null && all.isEmpty && s.card == null && !s.loading
                  ? EmptyState(
                      icon: Icons.smart_display,
                      message: l.ytNoResults,
                    )
                  : RefreshIndicator(
                      onRefresh: _pullToRefresh,
                      child: _list(s!, shownBest, shownOthers, picked.active),
                    ),
            ),
          ],
          if (request != null && s == null && error == null) const Spacer(),
        ],
      ),
    );
  }

  Widget _list(
    SmartSearchState s,
    List<(int, SmartResult)> best,
    List<(int, SmartResult)> others,
    bool selecting,
  ) {
    final l = context.l10n;
    var n = 0;
    Widget enter(Widget child) => EnterOnce(index: n++, child: child);
    Widget row((int, SmartResult) e) {
      final (i, r) = e;
      return enter(
        SmartRow(
          key: ValueKey('row-${r.primary.id}'),
          row: r,
          index: i,
          selectionKey: _selectionKey,
          onArtistTap: _openArtist,
          onListenVideo: () => tapOnline(context, ref, r.alternatives.first),
        ),
      );
    }

    final card = s.card;
    final children = <Widget>[];
    switch (card) {
      case TopArtist(:final artist):
        children.add(
          enter(
            ArtistCard(
              artist: artist,
              large: s.intent == SearchIntent.artistPage,
              onTap: () => _openArtist(artist),
            ),
          ),
        );
      case TopAlbum(:final release, :final artist):
        children.add(
          enter(
            AlbumCard(
              release: release,
              artist: artist,
              onTap: () => _openAlbum(release),
            ),
          ),
        );
      default:
    }
    var rest = best;
    if (s.intent == SearchIntent.artistPage && card is TopArtist) {
      final mine = [
        for (final e in best)
          if (e.$2.primary.artistIds.contains(card.artist.id)) e,
      ];
      if (mine.isNotEmpty) {
        children.add(SectionHeader(l.onlineArtistSongs(card.artist.name)));
        children.addAll(mine.map(row));
        rest = [
          for (final e in best)
            if (!mine.contains(e)) e,
        ];
      }
    }
    if (rest.isNotEmpty) {
      children.add(
        SectionHeader(s.noneSure ? l.onlineNoneSure : l.onlineBestResults),
      );
      children.addAll(rest.map(row));
    }
    if (others.isNotEmpty) {
      children.add(
        OthersChip(
          count: others.length,
          open: _othersOpen,
          onTap: () => setState(() => _othersOpen = !_othersOpen),
        ),
      );
      if (_othersOpen) children.addAll(others.map(row));
    }
    return EntranceScope(
      // A new search is a new list: its rows come in again.
      key: ValueKey(_serial),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.retry});

  final Object error;
  final Widget retry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    final text = e is YtException
        ? ytErrorText(context, e.kind)
        : context.l10n.ytErrUnavailable;
    return Padding(
      padding: const EdgeInsets.all(CcDims.gap12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(color: context.cc.error)),
          retry,
        ],
      ),
    );
  }
}

class _LegalNotice extends ConsumerWidget {
  const _LegalNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap4,
        CcDims.margin,
        CcDims.gap8,
      ),
      child: Container(
        padding: const EdgeInsets.all(CcDims.gap12),
        decoration: BoxDecoration(
          color: context.cc.surface1,
          borderRadius: BorderRadius.circular(CcDims.rCard),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l.ytLegal,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(ytNoticeSeen: true)),
              child: Text(l.gotIt),
            ),
          ],
        ),
      ),
    );
  }
}

/// The explanation of personal use, opened by the info icon next to «Cerca».
Future<void> showLegalInfo(BuildContext context) {
  final l = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l.ytLegal),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l.close),
        ),
      ],
    ),
  );
}
