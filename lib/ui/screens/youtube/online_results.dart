import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../core/app_log.dart';
import '../../../providers/online_collection_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/smart_search_providers.dart';
import '../../../services/online/merge_results.dart';
import '../../../services/online/external_collection.dart';
import '../../../services/online/external_links.dart';
import '../../../services/online/query_intent.dart' show ClassifiedQuery, QueryKind, SearchIntent, classifyQuery;
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
import '../now_playing/now_playing_screen.dart' show playFromSearchAndOpen, playFromSearchNotice;
import '../online/online_album_screen.dart';
import '../online/online_selection_scope.dart';
import '../online/online_song_row.dart';
import 'online_results_rows.dart';
import 'online_results_sections.dart';
import '../online/online_playlist_screen.dart';

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
  /// Picks are keyed by a number given to each result the first time it is seen
  /// (any of its video ids finds it again), not by its place in the list: hiding
  /// a row above (the library index changes) must not move the picks.
  static final _selectionKey = SelectionKey.online.key;
  final _slots = <String, int>{};
  SmartSearchRequest? _request;
  int _serial = 0;

  /// The source filter and the «Altri risultati» list: both start over with
  /// each search.
  MediaKind? _filter;
  bool _othersOpen = false;

  /// A pasted video link plays its video once, when the result with that id
  /// arrives (it stays listed).
  String? _autoPlayId;

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
    _linkSerial++; // a newer search drops a link still being resolved
    final q = widget.query.trim();
    if (q.isEmpty) return;
    final external = classifyQuery(q);
    if (external.kind == QueryKind.external) {
      unawaited(_openExternal(external));
      return;
    }
    // A playlist or channel address is not a search: it opens its video list.
    final listing = listingUrl(q);
    if (listing != null) {
      // After the frame: a page cannot be pushed while this one is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ShellNav.open<void>(context, OnlinePlaylistScreen(OnlineCollectionRef.youtubeListing(listing)));
        }
      });
      return;
    }
    final album = ytmAlbumBrowseId(q);
    if (album != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ShellNav.open<void>(context, OnlineAlbumScreen(browseId: album));
      });
      return;
    }
    // The same text sent again while its search is still coming (a double
    // Enter) is that search, not a second one.
    final current = _request;
    final running = current == null ? null : ref.read(smartSearchProvider(current));
    if (!refresh &&
        current != null &&
        current.query == q &&
        running != null &&
        (running.isLoading || (running.value?.loading ?? false))) {
      return;
    }
    final first = current == null;
    if (!refresh) _autoPlayId = youtubeVideoId(q);
    setState(() {
      _slots.clear();
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

  int _linkSerial = 0;

  void _openPage(OnlineCollectionRef page) {
    if (mounted) ShellNav.open<void>(context, OnlinePlaylistScreen(page));
  }

  /// A Deezer or Spotify link: a list opens its page; a single song is matched
  /// and played once, with its similar ones (R-199); no match shows a page with
  /// that one row (R-196). Any failure opens the page, which says what went wrong.
  Future<void> _openExternal(ClassifiedQuery q) async {
    final serial = ++_linkSerial;
    var link = q.link;
    OnlineCollectionRef page = link != null
        ? OnlineCollectionRef.external(link)
        : OnlineCollectionRef.shortLink(q.url!);
    try {
      if (link == null) {
        final resolved = await ref.read(shortLinkResolverProvider).resolve(q.url!);
        if (!mounted) return;
        link = parseExternalLink(resolved);
        if (link != null) page = OnlineCollectionRef.external(link);
      }
      if (link != null && link.kind == ExternalLinkKind.track) {
        final c = await ref.read(externalReaderProvider(link.service)).read(link);
        if (!mounted) return;
        final key = Object();
        final sub = ref.listenManual(collectionMatcherProvider(key), (_, _) {});
        TrackMatch? m;
        try {
          await for (final (_, one)
              in ref.read(collectionMatcherProvider(key)).match(c.tracks.take(1).toList())) {
            m = one;
            break;
          }
        } finally {
          sub.close();
        }
        if (!mounted || serial != _linkSerial) return;
        switch (m) {
          case TrackReadyOnline(:final result):
            unawaited(playFromSearchAndOpen(context, ref, result));
            return;
          case TrackReadyLibrary(:final track):
            unawaited(playFromSearchNotice(context, ref, track: track));
            return;
          case _:
            // The page shows this one row as not found without matching it again.
            if (m != null) ref.read(resolvedMatchesProvider(page))[c.tracks.first.fingerprint] = m;
        }
      }
    } on Object catch (e, st) {
      AppLog.w('external link: $e', e, st);
    }
    if (mounted && serial == _linkSerial) _openPage(page);
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
  void _downloadSelection(Map<int, SmartResult> bySlot) {
    final picked = ref.read(selectionProvider(_selectionKey));
    startOnlineDownloads(context, ref, [
      for (final i in picked.orderedIds)
        if (bySlot[i] case final r?) r.primary,
    ]);
    ref.read(selectionProvider(_selectionKey).notifier).clear();
  }

  bool _shows(SmartResult r) => _filter == null || r.sources.contains(_filter);

  int _slotOf(SmartResult r) {
    final slot = r.ids.map((id) => _slots[id]).nonNulls.firstOrNull ?? _slots.length;
    for (final id in r.ids) {
      _slots[id] = slot;
    }
    return slot;
  }

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
    // D-399: songs the library already has leave the online rows (the split is
    // worked out once per result; until the index is ready nothing is hidden).
    final inLibrary = s != null && s.showsLibrary;
    final owned = s == null ? null : ref.watch(ownedSplitProvider(s));
    final bestRows = owned?.best ?? s?.best ?? const <SmartResult>[];
    final othersRows = owned?.others ?? s?.others ?? const <SmartResult>[];
    final hidden = owned?.hidden ?? 0;
    final all = [...bestRows, ...othersRows];
    final autoId = _autoPlayId;
    if (autoId != null && s != null) {
      for (final r in [...s.best, ...s.others]) {
        final hit = [r.primary, ...r.alternatives].where((y) => y.id == autoId).firstOrNull;
        if (hit == null) continue;
        _autoPlayId = null;
        // After the frame: playing changes providers that this build reads.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(playFromSearchAndOpen(context, ref, hit));
        });
        break;
      }
    }
    final bestEnd = bestRows.length;
    final slots = [for (final r in all) _slotOf(r)];
    // (slot, row) of what is shown under the filter.
    final shownBest = [
      for (var i = 0; i < bestEnd; i++)
        if (_shows(all[i])) (slots[i], all[i]),
    ];
    final shownOthers = [
      for (var i = bestEnd; i < all.length; i++)
        if (_shows(all[i])) (slots[i], all[i]),
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
          onPressed: () => _downloadSelection({
            for (var i = 0; i < all.length; i++) slots[i]: all[i],
          }),
        ),
      ],
      child: Column(
        children: [
          const YtDlpOutdatedBanner(),
          // Scrolls within a third of the screen: at a large text scale it is taller than the page.
          if (!seen)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 3),
              child: const SingleChildScrollView(child: _LegalNotice()),
            ),
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
                  ? _withLibrary(s, owned, _ErrorView(error: error, retry: retry))
                  : s != null && all.isEmpty && hidden == 0 && s.card == null && !s.loading
                  ? _withLibrary(
                      s,
                      owned,
                      EmptyState(icon: Icons.smart_display, message: l.ytNoResults),
                    )
                  : RefreshIndicator(
                      onRefresh: _pullToRefresh,
                      child: _list(
                          s!,
                          shownBest,
                          shownOthers,
                          picked.active,
                          showLibrary: inLibrary,
                          owned: owned,
                        ),
                    ),
            ),
          ],
          if (request != null && s == null && error == null) const Spacer(),
        ],
      ),
    );
  }

  /// A song search shows what the library has even with nothing (or an error)
  /// from online.
  Widget _withLibrary(SmartSearchState? s, OwnedSplit? owned, Widget child) =>
      s == null || !s.showsLibrary
          ? child
          : ListView(children: [LibraryTracksSection(query: s.query, owned: owned), child]);

  Widget _list(
    SmartSearchState s,
    List<(int, SmartResult)> best,
    List<(int, SmartResult)> others,
    bool selecting, {
    required bool showLibrary,
    required OwnedSplit? owned,
  }) {
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
    // Above every online row, the cards and the Artists and Albums rows too (D-399).
    final children = <Widget>[if (showLibrary) LibraryTracksSection(query: s.query, owned: owned)];
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
    final albums = AlbumsRow(albums: s.albums, onOpen: _openAlbum);
    final artists = ArtistsRow(
      // The main card already shows its artist.
      artists: [
        for (final a in s.artists)
          if (card is! TopArtist || a.id != card.artist.id) a,
      ],
      onOpen: _openArtist,
    );
    children.addAll(card is TopAlbum ? [albums, artists] : [artists, albums]);
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
    }
    children.addAll(rest.map(row));
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
    // At the end, where the total of the page makes sense; under a source
    // filter only the hidden rows of that source count.
    final hiddenShown = owned?.hiddenRows.where(_shows).length ?? 0;
    if (hiddenShown > 0) children.add(OwnedHiddenNote(count: hiddenShown));
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
