import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/online_collection_providers.dart' show OnlineCollectionRef;
import '../../../services/online/chart_genres.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/ui_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/palette.dart' show chartGenreColors;
import '../../theme/tokens.dart';
import '../../widgets/activity_button.dart';
import '../../widgets/cc_search_field.dart';
import '../../widgets/genre_grid.dart';
import '../../widgets/motion.dart' show RiseIn;
import '../../widgets/section_header.dart';
import '../youtube/online_results.dart';
import '../online/online_playlist_screen.dart';
import 'chart_genre_labels.dart';

/// Search is online only (D-355): the library is searched from Library. Under
/// the always-visible bar: recent searches and the Top 20 genre grid.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // Shared with the shell, which clears it when Search is left.
  late final _controller = ref.read(searchControllerProvider);
  Timer? _debounce;
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
                Flexible(child: Text(l.navSearch, style: theme.headlineSmall)),
                IconButton(
                  tooltip: l.ytInfoTooltip,
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => showLegalInfo(context),
                ),
                const Spacer(),
                const ActivityButton(),
              ],
            ),
          ),
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

/// Recent searches, then the 12 macro-genres that open a Top 20 (D-591).
class _EmptyQuery extends ConsumerWidget {
  const _EmptyQuery({required this.onRecent});

  final void Function(String) onRecent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final recents = ref.watch(settingsProvider.select((s) => s.recentSearches));
    return CustomScrollView(
      slivers: [
        if (recents.isNotEmpty)
          SliverToBoxAdapter(
            child: RiseIn(
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
        SliverToBoxAdapter(child: SectionHeader(l.chartGridTitle)),
        GenreGrid(
          columns: 3,
          wideColumns: 6,
          items: [
            for (final g in chartGenres)
              GenreItem(g.id, chartGenreLabel(l, g.id), color: chartGenreColors[g.id]),
          ],
          onSelect: (id) => ShellNav.open<void>(
            context,
            OnlinePlaylistScreen(
              OnlineCollectionRef.chart(chartGenres.firstWhere((g) => g.id == id)),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: 24 + context.dockInset),
        ),
      ],
    );
  }
}
