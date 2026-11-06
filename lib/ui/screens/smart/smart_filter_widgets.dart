import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/filter_counts_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/filter_counts_providers.dart';
import '../../../services/library/rules/rule_ast.dart';
import '../../../services/radio/country_names.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_search_field.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/segmented_blocks.dart';
import 'smart_filter_model.dart';

String filterFieldLabel(AppLocalizations l, RuleField f) => switch (f) {
      RuleField.artist => l.fieldArtist,
      RuleField.album => l.fieldAlbum,
      RuleField.albumArtist => l.smartFieldAlbumArtist,
      RuleField.genre => l.fieldGenre,
      RuleField.year => l.fieldYear,
      RuleField.country => l.smartFieldCountry,
      RuleField.recordLabel => l.creditsLabel,
      RuleField.bpm => l.creditsBpm,
      RuleField.plays => l.smartFieldPlays,
      RuleField.lastPlayed => l.smartFieldLastPlayed,
      RuleField.duration => l.detailDuration,
      RuleField.added => l.smartFieldAdded,
      RuleField.bitrate => l.smartFieldBitrate,
      RuleField.format => l.detailFormat,
      RuleField.folder => l.smartFieldFolder,
      RuleField.tag => l.smartFieldTag,
    };

String filterSpecLabel(AppLocalizations l, FilterSpec s) => s.field != null
    ? filterFieldLabel(l, s.field!)
    : switch (s.flag!) {
        RuleFlagKind.favorites => l.navFavorites,
        RuleFlagKind.neverPlayed => l.smartTplNever,
        RuleFlagKind.hasLyrics => l.smartFlagLyrics,
      };

String _groupLabel(AppLocalizations l, FilterGroup g) => switch (g) {
      FilterGroup.music => l.smartGroupMusic,
      FilterGroup.listening => l.smartGroupListening,
      FilterGroup.file => l.smartGroupFile,
      FilterGroup.tags => l.smartFieldTag,
    };

/// What a stored value looks like: a country code gets its name.
String valueLabel(BuildContext context, RuleField field, String v) {
  if (field != RuleField.country) return v;
  return countryNameIn(v, Localizations.localeOf(context).languageCode, v);
}

FilterList? _listOf(RuleField f) => switch (f) {
      RuleField.artist || RuleField.albumArtist => FilterList.artists,
      RuleField.genre => FilterList.genres,
      RuleField.country => FilterList.countries,
      RuleField.recordLabel => FilterList.labels,
      _ => null,
    };

/// The «Aggiungi filtro» sheet: fields in groups.
Future<FilterSpec?> showAddFilterSheet(BuildContext context) {
  final l = context.l10n;
  return showCcSheet<FilterSpec>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    barrierLabel: l.close,
    builder: (sheet) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in FilterGroup.values) ...[
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap12, CcDims.margin, CcDims.gap4),
                  child: Text(
                    _groupLabel(l, g),
                    style: Theme.of(sheet).textTheme.labelLarge?.copyWith(color: sheet.cc.textMuted),
                  ),
                ),
              ),
              for (final s in filterGroups[g]!)
                ListTile(
                  title: Text(filterSpecLabel(l, s)),
                  subtitle: s.enrichedOnly ? Text(l.smartEnrichedOnly) : null,
                  onTap: () => Navigator.of(sheet).pop(s),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Picks the values of a list field; returns the new selection on «Fatto».
Future<List<String>?> showValuePicker(BuildContext context, RuleField field, List<String> current) =>
    showCcSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      barrierLabel: context.l10n.close,
      builder: (sheet) => _ValueSheet(field: field, initial: current),
    );

class _ValueSheet extends ConsumerStatefulWidget {
  const _ValueSheet({required this.field, required this.initial});
  final RuleField field;
  final List<String> initial;

  @override
  ConsumerState<_ValueSheet> createState() => _ValueSheetState();
}

class _ValueSheetState extends ConsumerState<_ValueSheet> {
  late final List<String> _sel = List.of(widget.initial);
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String v) => setState(() => _sel.contains(v) ? _sel.remove(v) : _sel.add(v));

  void _addTyped() {
    final v = _search.text.trim();
    if (v.isEmpty) return;
    if (!_sel.contains(v)) setState(() => _sel.add(v));
    _search.clear();
    setState(() => _q = '');
  }

  Widget _row(String value, int? count) => CheckboxListTile(
        key: ValueKey('value:$value'),
        value: _sel.contains(value),
        onChanged: (_) => _toggle(value),
        title: Text(valueLabel(context, widget.field, value), maxLines: 2, overflow: TextOverflow.ellipsis),
        secondary: count == null ? null : Text(context.l10n.tracksCount(count)),
        controlAffinity: ListTileControlAffinity.leading,
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = _listOf(widget.field);
    final countries = widget.field == RuleField.country;
    final counts = list == null
        ? null
        : ref.watch(filterValueCountsProvider((list: list, query: countries ? '' : _q)));
    final qn = _q.toLowerCase();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: SafeArea(
          child: Column(
            children: [
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(filterFieldLabel(l, widget.field), style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(CcDims.margin),
                child: Row(
                  children: [
                    Expanded(
                      child: CcSearchField(
                        controller: _search,
                        hint: list == null ? l.smartValueHint : l.searchHint,
                        onQuery: (q) => setState(() => _q = q),
                        onSubmitted: list == null ? (_) => _addTyped() : null,
                      ),
                    ),
                    if (list == null)
                      TextButton(onPressed: _addTyped, child: Text(l.smartAddValue)),
                  ],
                ),
              ),
              Expanded(
                child: counts == null
                    ? ListView(children: [for (final v in _sel) _row(v, null)])
                    : counts.when(
                        data: (all) {
                          final shown = [
                            for (final c in all)
                              if (!countries ||
                                  qn.isEmpty ||
                                  c.value.toLowerCase().contains(qn) ||
                                  valueLabel(context, widget.field, c.value).toLowerCase().contains(qn))
                                c,
                          ];
                          return ListView.builder(
                            itemCount: shown.length,
                            itemBuilder: (_, i) => _row(shown[i].value, shown[i].count),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(CcDims.margin),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_sel),
                    child: Text(l.smartDone),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One filter as a card. [onChanged] runs after every edit (the editor
/// rebuilds); [onRemove] drops the card.
class FilterCardView extends StatelessWidget {
  const FilterCardView({super.key, required this.card, required this.onChanged, required this.onRemove});

  final FilterCard card;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final title = card.field != null
        ? filterFieldLabel(l, card.field!)
        : filterSpecLabel(l, FilterSpec.flag(card.flag!));
    return Card(
      margin: const EdgeInsets.only(bottom: CcDims.gap12),
      color: cc.surface1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap4, CcDims.gap4, CcDims.gap12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Semantics(header: true, child: Text(title, style: theme.titleSmall))),
                IconButton(
                  tooltip: l.smartRemoveFilter,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onRemove,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: CcDims.gap12),
              child: SegmentedBlocks<bool>(
                items: [
                  BlockItem(value: false, label: l.smartInclude),
                  BlockItem(value: true, label: l.smartExclude),
                ],
                selected: card.exclude,
                onChanged: (v) {
                  card.exclude = v;
                  onChanged();
                },
              ),
            ),
            if (card.kind != FilterKind.flag) const SizedBox(height: CcDims.gap8),
            Padding(
              padding: const EdgeInsets.only(right: CcDims.gap12),
              child: switch (card.kind) {
                FilterKind.list => _values(context),
                FilterKind.text => _textField(l.smartContains, card.text, (v) => card.text = v),
                FilterKind.number => _numbers(context),
                FilterKind.age => _age(context),
                FilterKind.flag => const SizedBox.shrink(),
              },
            ),
            if (card.toExpr() == null)
              Padding(
                padding: const EdgeInsets.only(top: CcDims.gap8, right: CcDims.gap12),
                child: Text(l.smartIncomplete, style: theme.bodySmall?.copyWith(color: cc.textMuted)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _textField(String label, String initial, ValueChanged<String> set, {String? suffix, bool number = false}) =>
      TextFormField(
        key: ObjectKey(card),
        initialValue: initial,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(labelText: label, suffixText: suffix, constraints: const BoxConstraints(minHeight: 48)),
        onChanged: (v) {
          set(v);
          onChanged();
        },
      );

  Widget _values(BuildContext context) {
    final l = context.l10n;
    final field = card.field!;
    return Wrap(
      spacing: CcDims.gap8,
      children: [
        for (final v in card.values)
          Semantics(
            button: true,
            label: l.smartRemoveValue(valueLabel(context, field, v)),
            excludeSemantics: true,
            onTap: () {
              card.values.remove(v);
              onChanged();
            },
            child: InkWell(
              borderRadius: BorderRadius.circular(CcDims.rPill),
              onTap: () {
                card.values.remove(v);
                onChanged();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        valueLabel(context, field, v),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: CcDims.gap4),
                    const Icon(Icons.close_rounded, size: 16),
                    const SizedBox(width: CcDims.gap8),
                  ],
                ),
              ),
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.checklist_rounded),
          label: Text(l.smartPickValues),
          onPressed: () async {
            final picked = await showValuePicker(context, field, card.values);
            if (picked != null) {
              card.values = picked;
              onChanged();
            }
          },
        ),
      ],
    );
  }

  Widget _numbers(BuildContext context) {
    final l = context.l10n;
    final suffix = card.isDuration ? l.smartMinutes : null;
    final fromLabel = switch (card.op) {
      NumOp.gt => l.smartMoreThan,
      NumOp.eq => l.smartEqualTo,
      _ => l.smartFrom,
    };
    final toLabel = card.op == NumOp.lt ? l.smartLessThan : l.smartTo;
    return Row(
      children: [
        Expanded(child: _textField(fromLabel, card.from, (v) => card.from = v, suffix: suffix, number: true)),
        const SizedBox(width: CcDims.gap12),
        Expanded(child: _textField(toLabel, card.to, (v) => card.to = v, suffix: suffix, number: true)),
      ],
    );
  }

  Widget _age(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedBlocks<bool>(
          items: [
            BlockItem(value: true, label: l.smartAgeRecent),
            BlockItem(value: false, label: l.smartAgeOlder),
          ],
          selected: card.recent,
          onChanged: (recent) {
            card.op = recent ? NumOp.lt : NumOp.gt;
            onChanged();
          },
        ),
        const SizedBox(height: CcDims.gap8),
        _textField(l.smartDays, card.from, (v) => card.from = v, number: true),
      ],
    );
  }
}
