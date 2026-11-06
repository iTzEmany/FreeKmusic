import '../../../providers/playlist_ops.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/smart_playlist_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/filter_counts_providers.dart';
import '../../../services/library/rules/rule_parser.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/segmented_blocks.dart';
import 'smart_filter_model.dart';
import 'smart_filter_widgets.dart';

String smartSortLabel(AppLocalizations l, SmartSort s) => switch (s) {
  SmartSort.defaultOrder => l.sortDefault,
  SmartSort.title => l.sortTitle,
  SmartSort.artist => l.sortArtist,
  SmartSort.album => l.sortAlbum,
  SmartSort.year => l.sortYear,
  SmartSort.addedAt => l.sortAdded,
  SmartSort.duration => l.sortDuration,
  SmartSort.mostPlayed => l.smartSortMostPlayed,
  SmartSort.random => l.smartSortRandom,
};

class _Template {
  const _Template(this.label, this.rules, this.sort, this.limit);

  final String Function(AppLocalizations) label;
  final String rules;
  final SmartSort sort;
  final int? limit;
}

final _templates = [
  _Template(
    (l) => l.smartTplNever,
    'mai-ascoltati',
    SmartSort.defaultOrder,
    null,
  ),
  _Template((l) => l.smartTplRecent, 'aggiunto<30g', SmartSort.addedAt, null),
  _Template((l) => l.smartTplTop, 'ascolti>0', SmartSort.mostPlayed, 50),
  _Template(
    (l) => l.smartTpl90s,
    'anno:1990..1999',
    SmartSort.defaultOrder,
    null,
  ),
];

/// Creates a smart playlist, or edits [existing]: name, filters as cards with
/// a live count, order and limit. The rule is written in the same canonical
/// string as ever; one that cards cannot show is kept as it is.
class SmartPlaylistEditor extends ConsumerStatefulWidget {
  const SmartPlaylistEditor({super.key, this.existing});

  final SmartPlaylist? existing;

  @override
  ConsumerState<SmartPlaylistEditor> createState() =>
      _SmartPlaylistEditorState();
}

class _SmartPlaylistEditorState extends ConsumerState<SmartPlaylistEditor> {
  late final TextEditingController _name;
  late final TextEditingController _limit;
  late SmartSort _sort;
  var _model = FilterModel();

  /// The saved rule when the cards cannot show it; null otherwise.
  String? _raw;
  bool _showAdvanced = false;
  bool _triedSave = false;
  int? _count;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _limit = TextEditingController(text: p?.limitCount?.toString() ?? '');
    _sort = SmartSort.fromName(p?.sort);
    _load(p?.rules ?? '');
    _showAdvanced = _raw != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _load(String rules) {
    final m = FilterModel.fromExpr(parseRules(rules).expr);
    _model = m ?? FilterModel();
    _raw = m == null ? rules : null;
  }

  String get _rules => _raw ?? _model.rules;

  bool get _canSave => _raw != null || _model.hasComplete;

  void _apply(_Template t) {
    final l = context.l10n;
    setState(() {
      if (_name.text.trim().isEmpty) _name.text = t.label(l);
      _load(t.rules);
      _sort = t.sort;
      _limit.text = t.limit?.toString() ?? '';
    });
  }

  int? get _limitValue {
    final n = int.tryParse(_limit.text.trim());
    return n == null || n <= 0 ? null : n;
  }

  Future<void> _add() async {
    final spec = await showAddFilterSheet(context);
    if (spec != null && mounted) {
      setState(() => _model.cards.add(FilterCard.fromSpec(spec)));
    }
  }

  Future<void> _pickSort() async {
    final l = context.l10n;
    final s = await showCcActionSheet<SmartSort>(
      context: context,
      title: l.smartSortBy,
      groups: [
        [
          for (final o in SmartSort.values)
            CcAction(
              icon: Icons.sort_rounded,
              label: smartSortLabel(l, o),
              value: o,
              selected: o == _sort,
            ),
        ],
      ],
    );
    if (s != null && mounted) setState(() => _sort = s);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _triedSave = true);
      return;
    }
    await ref.read(playlistOpsProvider).saveSmart(
      existingId: widget.existing?.id,
      name: _name.text,
      rules: _rules,
      sort: _sort,
      limit: _limitValue,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _bottomBar(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Material(
      color: cc.surface1,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.all(CcDims.margin),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.sort_rounded),
                          label: Text(
                            '${l.smartSortBy}: ${smartSortLabel(l, _sort)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: _pickSort,
                        ),
                      ),
                      const SizedBox(width: CcDims.gap12),
                      SizedBox(
                        width: 112,
                        child: TextField(
                          controller: _limit,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: l.smartLimitShort,
                            constraints: const BoxConstraints(minHeight: 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CcDims.gap12),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _count == null ? '' : l.tracksCount(_count!),
                            style: theme.titleMedium?.copyWith(color: cc.accent),
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _canSave ? _save : null,
                        child: Text(l.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    // The provider answers null while a newer request supersedes it: keep the last number.
    final live = ref.watch(liveRuleCountProvider((rules: _rules, limit: _limitValue))).value;
    if (live != null) _count = live;
    return Scaffold(
      appBar: CcAppBar(
        title: widget.existing == null ? l.smartPlaylistNew : l.smartPlaylistEdit,
      ),
      bottomNavigationBar: _bottomBar(context),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(CcDims.margin),
            children: [
              TextField(
                controller: _name,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.smartName,
                  errorText: _triedSave && _name.text.trim().isEmpty
                      ? l.smartNameRequired
                      : null,
                ),
              ),
              const SizedBox(height: CcDims.gap8),
              Text(l.smartTemplates, style: theme.labelLarge),
              const SizedBox(height: CcDims.gap8),
              Wrap(
                spacing: CcDims.gap8,
                runSpacing: CcDims.gap4,
                children: [
                  for (final t in _templates)
                    ActionChip(
                      label: Text(t.label(l)),
                      onPressed: () => _apply(t),
                    ),
                ],
              ),
              const SizedBox(height: CcDims.gap16),
              if (_raw != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: CcDims.gap12),
                  child: Text(l.smartNotVisual, style: theme.bodyMedium),
                )
              else ...[
                SegmentedBlocks<bool>(
                  items: [
                    BlockItem(value: false, label: l.smartAll),
                    BlockItem(value: true, label: l.smartAny),
                  ],
                  selected: _model.any,
                  onChanged: (v) => setState(() => _model.any = v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(CcDims.gap4, CcDims.gap8, CcDims.gap4, CcDims.gap12),
                  child: Text(
                    _model.any ? l.smartAnyNote : l.smartAllNote,
                    style: theme.bodySmall?.copyWith(color: cc.textMuted),
                  ),
                ),
                for (final c in _model.cards)
                  FilterCardView(
                    key: ObjectKey(c),
                    card: c,
                    onChanged: () => setState(() {}),
                    onRemove: () => setState(() => _model.cards.remove(c)),
                  ),
                if (_model.cards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CcDims.gap12),
                    child: Text(l.smartNoFilters, style: theme.bodyMedium),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.smartAddFilter),
                  onPressed: _add,
                ),
              ],
              const SizedBox(height: CcDims.gap16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsAdvanced),
                trailing: Icon(_showAdvanced ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              ),
              if (_showAdvanced) ...[
                Text(l.smartAdvancedNote, style: theme.bodySmall?.copyWith(color: cc.textMuted)),
                const SizedBox(height: CcDims.gap8),
                SelectableText(_rules, style: theme.bodyMedium),
              ],
              const SizedBox(height: CcDims.gap16),
              Text(l.smartAutoNote, style: theme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
