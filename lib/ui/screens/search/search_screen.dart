import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../core/constants.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/library_queries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/user_activity_provider.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/radio_providers.dart' show searchPrefillProvider;
import '../../../providers/settings_providers.dart';
import '../../../providers/ui_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart' show PressScale, RiseIn;
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import '../youtube/online_results.dart';
import '../library/library_search.dart';
import 'genre_screen.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_search_field.dart';

/// Search: one pill, [In libreria] and [Online] chips. Online only runs when
/// the user submits.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // Shared with the dock's field, which is where a phone types.
  late final _controller = ref.read(searchControllerProvider);
  late final _focus = ref.read(searchFocusProvider);
  Timer? _debounce;
  late String _lastText = _controller.text;
  late String _text = _controller.text.trim();
  int _onlineSubmitted = 0;
  // Not remembered across launches: they start off every time.
  bool _favorites = false;
  bool _recent = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focus.addListener(_warmIndex);
    // A text sent here before this tab was ever opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyPrefill(ref.read(searchPrefillProvider));
    });
  }

  /// «Cerca questo brano» from the radio: runs the text in «Online».
  void _applyPrefill(String? text) {
    if (text == null || text.trim().isEmpty) return;
    ref.read(searchPrefillProvider.notifier).set(null);
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    ref.read(searchOnlineProvider.notifier).set(true);
    setState(() {
      _text = text.trim();
      _onlineSubmitted++;
    });
  }

  /// The first focus loads the library and normalises it into the search
  /// index (tens of ms on a phone, all in one go); doing it here, before the
  /// first key, keeps that frame out of the typing.
  void _warmIndex() {
    if (!_focus.hasFocus) return;
    _focus.removeListener(_warmIndex);
    // Kept (closed with this State): a plain read would pause it at once.
    ref.listenManual(searchIndexProvider, (_, _) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _focus.removeListener(_warmIndex);
    super.dispose();
  }

  // Also fires on cursor moves, hence the comparison.
  void _onTextChanged() {
    // Cursor moves also land here: only a changed text is the user typing.
    if (_controller.text != _lastText) {
      _lastText = _controller.text;
      ref.read(userActivityProvider).touch();
    }
    _debounce?.cancel();
    final v = _controller.text.trim();
    if (v == _text) return;
    _debounce = Timer(CcTiming.debounce, () {
      if (mounted) setState(() => _text = v);
    });
  }

  void _remember(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            recentSearches: [
              t,
              ...s.recentSearches.where(
                (e) => e.toLowerCase() != t.toLowerCase(),
              ),
            ].take(10).toList(),
          ),
        );
  }

  void _submit(String v) {
    _debounce?.cancel();
    setState(() => _text = v.trim());
    if (ref.read(searchOnlineProvider)) {
      setState(() => _onlineSubmitted++);
    } else {
      _remember(v);
      if (kEnableYoutube && _text.isNotEmpty) _goOnlineIfNoLocal();
    }
  }

  /// Waits for every local source, then goes online if the text is unchanged
  /// and nothing matched locally.
  Future<void> _goOnlineIfNoLocal() async {
    final text = _text;
    final q = SearchQuery(text, favorites: _favorites, recent: _recent);
    await Future.wait([
      _loaded(searchTracksProvider(q)),
      _loaded(artistsProvider),
      _loaded(albumsProvider),
      _loaded(playlistsProvider),
    ]);
    if (mounted && _text == text && localResults(ref.read, q).isEmpty) {
      _toOnline();
    }
  }

  /// Completes once [p] is no longer loading (data or error).
  Future<void> _loaded(ProviderListenable<AsyncValue<Object?>> p) {
    final done = Completer<void>();
    final sub = ref.listenManual(p, (_, v) {
      if (!v.isLoading && !done.isCompleted) done.complete();
    }, fireImmediately: true);
    return done.future.whenComplete(sub.close);
  }

  void _useRecent(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _text = q);
  }

  void _toOnline() {
    _remember(_text);
    ref.read(searchOnlineProvider.notifier).set(true);
    setState(() => _onlineSubmitted++);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    ref.listen(searchPrefillProvider, (_, next) => _applyPrefill(next));
    ref.listen(searchSubmitProvider, (_, _) => _submit(_controller.text));
    final online = ref.watch(searchOnlineProvider);
    // The phone types in the dock; only the desktop has a field on the page.
    final showField = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    final Widget body;
    if (online) {
      body = OnlineResults(query: _text, submitted: _onlineSubmitted);
    } else if (_text.isEmpty && !_favorites && !_recent) {
      body = _EmptyQuery(onRecent: _useRecent);
    } else {
      body = LibraryResults(
        query: SearchQuery(_text, favorites: _favorites, recent: _recent),
        onOnline: _toOnline,
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CcDims.margin,
              CcDims.gap12,
              CcDims.margin,
              CcDims.gap8,
            ),
            child: Row(
              children: [
                Expanded(child: Text(l.navSearch, style: theme.headlineSmall)),
              ],
            ),
          ),
          if (showField)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
              child: CcSearchField(
                controller: _controller,
                focusNode: ref.watch(searchFocusProvider),
                hint: online ? l.ytHint : l.searchHint,
                onSubmitted: _submit,
                onClear: () {
                  _controller.clear();
                  setState(() => _text = '');
                },
              ),
            ),
          if (!online)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CcDims.margin,
                vertical: 6,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      avatar: Icon(
                        Icons.favorite_rounded,
                        color: _favorites ? context.cc.bg : context.cc.text,
                      ),
                      label: Text(l.navFavorites),
                      selected: _favorites,
                      onSelected: (v) => setState(() => _favorites = v),
                    ),
                    FilterChip(
                      avatar: Icon(
                        Icons.schedule_rounded,
                        color: _recent ? context.cc.bg : context.cc.text,
                      ),
                      label: Text(l.sortRecent),
                      selected: _recent,
                      onSelected: (v) => setState(() => _recent = v),
                    ),
                  ],
                ),
              ),
            ),
          if (kEnableYoutube)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CcDims.margin,
                vertical: CcDims.gap8,
              ),
              child: SegmentedBlocks<bool>(
                selected: online,
                onChanged: ref.read(searchOnlineProvider.notifier).set,
                items: [
                  BlockItem(
                    value: false,
                    icon: Icons.library_music_rounded,
                    label: l.searchModeLibrary,
                  ),
                  BlockItem(
                    value: true,
                    icon: Icons.public_rounded,
                    label: l.searchModeOnline,
                  ),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Recent searches and the genre tiles.
class _EmptyQuery extends ConsumerWidget {
  const _EmptyQuery({required this.onRecent});

  final void Function(String) onRecent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final recents = ref.watch(settingsProvider.select((s) => s.recentSearches));
    final genresAsync = ref.watch(genresProvider);
    final genres = genresAsync.value ?? const <GenreSummary>[];
    // Nothing to suggest (no recents, genres loaded and empty): say what to do.
    if (recents.isEmpty && genresAsync.hasValue && genres.isEmpty) {
      return EmptyState(
        icon: Icons.search_rounded,
        message: l.searchEmptyPrompt,
      );
    }
    return ListView(
      children: [
        if (recents.isNotEmpty)
          // New key per open/close of the dock's field: they rise in with it.
          RiseIn(
            key: ValueKey(ref.watch(searchBarProvider)),
            child: Column(
              children: [
                SectionHeader(l.recentSearches),
                for (final q in recents)
                  ListTile(
                    leading: Icon(Icons.search_rounded, color: cc.textMuted),
                    title: Text(
                      q,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: l.removeRecentSearch,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .update(
                            (s) => s.copyWith(
                              recentSearches: [...s.recentSearches]..remove(q),
                            ),
                          ),
                    ),
                    onTap: () => onRecent(q),
                  ),
              ],
            ),
          ),
        if (genres.isNotEmpty) ...[
          SectionHeader(l.genresTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in genres)
                  _GenrePill(
                    name: g.name,
                    onTap: () => ShellNav.open<void>(
                      context,
                      GenreScreen(genre: g.name),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _GenrePill extends StatelessWidget {
  const _GenrePill({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CcDims.rCard);
    return PressScale(
      child: Material(
        color: context.cc.surface1,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CcDims.gap16,
              vertical: 10,
            ),
            child: Text(name, style: Theme.of(context).textTheme.labelLarge),
          ),
        ),
      ),
    );
  }
}

/// «Mostra tutti»: every track matching the text.
class SearchTracksScreen extends ConsumerWidget {
  const SearchTracksScreen({super.key, required this.query});

  final SearchQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tracks =
        ref.watch(searchTracksProvider(query)).value ?? const <Track>[];
    final ctrl = ref.read(playerControllerProvider);
    final compact = ref.watch(settingsProvider.select((s) => s.compactMode));
    final key = SelectionKey.searchAll.key;
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in tracks) t.id],
    );
    return SelectionScope(
      listKey: key,
      visibleIds: selection.visibleIds,
      child: Scaffold(
        appBar: SelectableAppBar(
          listKey: key,
          tracks: tracks,
          normal: CcAppBar(title: l.tracks),
        ),
        body: ListView.builder(
          itemExtent: trackRowExtentOf(context, compact),
          itemCount: tracks.length,
          itemBuilder: (_, i) => LiveTrackRow(
            track: tracks[i],
            compact: compact,
            selection: selection,
            onTap: () => ctrl.playFromList(
              tracks,
              i,
              context: const PlayContext(PlayContextKind.search),
            ),
          ),
        ),
      ),
    );
  }
}
