import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/radio_providers.dart' show searchPrefillProvider;
import '../../../providers/settings_providers.dart';
import '../../../providers/ui_providers.dart';
import '../../../providers/user_activity_provider.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_search_field.dart';
import '../../widgets/genre_grid.dart';
import '../../widgets/motion.dart' show RiseIn;
import '../../widgets/section_header.dart';
import '../youtube/online_results.dart';
import 'genre_screen.dart';

/// Search is online only (D-355): the library is searched from Library. Under
/// the bar: recent searches and the library's genres.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // Shared with the dock's field, which is where a phone types.
  late final _controller = ref.read(searchControllerProvider);
  Timer? _debounce;
  late String _lastText = _controller.text;
  late String _text = _controller.text.trim();
  int _submitted = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // A text sent here before this tab was ever opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyPrefill(ref.read(searchPrefillProvider));
    });
  }

  /// «Cerca questo brano» from the radio: runs the text.
  void _applyPrefill(String? text) {
    if (text == null || text.trim().isEmpty) return;
    ref.read(searchPrefillProvider.notifier).set(null);
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    setState(() {
      _text = text.trim();
      _submitted++;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // Also fires on cursor moves, hence the comparison.
  void _onTextChanged() {
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
    _remember(v);
    setState(() {
      _text = v.trim();
      _submitted++;
    });
  }

  void _useRecent(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _submit(q);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    ref.listen(searchPrefillProvider, (_, next) => _applyPrefill(next));
    ref.listen(searchSubmitProvider, (_, _) => _submit(_controller.text));
    // The phone types in the dock; only the desktop has a field on the page.
    final showField = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
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
                hint: l.ytHint,
                onSubmitted: _submit,
                onClear: () {
                  _controller.clear();
                  setState(() => _text = '');
                },
              ),
            ),
          Expanded(
            child: _text.isEmpty
                ? _EmptyQuery(onRecent: _useRecent)
                : OnlineResults(query: _text, submitted: _submitted),
          ),
        ],
      ),
    );
  }
}

/// Recent searches and the genres of the library, most tracks first (D-360).
class _EmptyQuery extends ConsumerWidget {
  const _EmptyQuery({required this.onRecent});

  final void Function(String) onRecent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final recents = ref.watch(settingsProvider.select((s) => s.recentSearches));
    final genres = ref.watch(genresProvider).value ?? const [];
    return CustomScrollView(
      slivers: [
        if (recents.isNotEmpty)
          SliverToBoxAdapter(
            // New key per open/close of the dock's field: they rise in with it.
            child: RiseIn(
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
                        tooltip: l.removeRecentSearch(q),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .update(
                              (s) => s.copyWith(
                                recentSearches: [...s.recentSearches]
                                  ..remove(q),
                              ),
                            ),
                      ),
                      onTap: () => onRecent(q),
                    ),
                ],
              ),
            ),
          ),
        if (genres.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader(l.genresTitle)),
          GenreGrid(
            columns: 3,
            wideColumns: 6,
            items: [
              for (final g in genres)
                GenreItem(
                  g.name,
                  g.name,
                  subtitle: l.tracksCount(g.trackCount),
                ),
            ],
            onSelect: (name) =>
                ShellNav.open<void>(context, GenreScreen(genre: name)),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
