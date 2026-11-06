import '../../../providers/playlist_ops.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/smart_playlist_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/smart_playlist_providers.dart';
import '../../../services/library/rules/rule_parser.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';

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

/// Creates a smart playlist, or edits [existing]: name, rules with a live
/// count and the parser's remarks, order and limit.
class SmartPlaylistEditor extends ConsumerStatefulWidget {
  const SmartPlaylistEditor({super.key, this.existing});

  final SmartPlaylist? existing;

  @override
  ConsumerState<SmartPlaylistEditor> createState() =>
      _SmartPlaylistEditorState();
}

class _SmartPlaylistEditorState extends ConsumerState<SmartPlaylistEditor> {
  late final TextEditingController _name;
  late final TextEditingController _rules;
  late final TextEditingController _limit;
  late SmartSort _sort;
  Timer? _debounce;
  String _previewRules = '';
  bool _triedSave = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _rules = TextEditingController(text: p?.rules ?? '');
    _limit = TextEditingController(text: p?.limitCount?.toString() ?? '');
    _sort = SmartSort.fromName(p?.sort);
    _previewRules = _rules.text;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _rules.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _onRulesChanged(String text) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(CcTiming.debounce, () {
      if (mounted) setState(() => _previewRules = text);
    });
  }

  void _apply(_Template t) {
    final l = context.l10n;
    setState(() {
      if (_name.text.trim().isEmpty) _name.text = t.label(l);
      _rules.text = t.rules;
      _previewRules = t.rules;
      _sort = t.sort;
      _limit.text = t.limit?.toString() ?? '';
    });
  }

  int? get _limitValue {
    final n = int.tryParse(_limit.text.trim());
    return n == null || n <= 0 ? null : n;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _triedSave = true);
      return;
    }
    await ref.read(playlistOpsProvider).saveSmart(
      existingId: widget.existing?.id,
      name: _name.text,
      rules: _rules.text,
      sort: _sort,
      limit: _limitValue,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final warnings = parseRules(_rules.text).warnings.where(
      (w) =>
          w.kind != RuleWarningKind.emptyValue &&
          w.kind != RuleWarningKind.danglingOr,
    );
    final count = ref.watch(ruleCountProvider(_previewRules)).value;
    final shown = count == null
        ? null
        : (_limitValue == null ? count : count.clamp(0, _limitValue!));
    return Scaffold(
      appBar: CcAppBar(
        title: widget.existing == null ? l.smartPlaylistNew : l.smartPlaylistEdit,
        actions: [TextButton(onPressed: _save, child: Text(l.save))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(CcDims.margin).withDock(context),
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
              const SizedBox(height: 8),
              Text(l.smartTemplates, style: theme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in _templates)
                    ActionChip(
                      label: Text(t.label(l)),
                      onPressed: () => _apply(t),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _rules,
                minLines: 1,
                maxLines: 3,
                onChanged: _onRulesChanged,
                decoration: InputDecoration(
                  labelText: l.smartRules,
                  hintText: l.smartRulesHint,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(CcDims.gap4, CcDims.gap8, CcDims.gap4, 0),
                child: Text(
                  shown == null ? '' : l.tracksCount(shown),
                  style: theme.titleMedium?.copyWith(color: cc.accent),
                ),
              ),
              if (_rules.text.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(CcDims.gap4, CcDims.gap4, CcDims.gap4, 0),
                  child: Text(l.smartNoRules, style: theme.bodyMedium),
                ),
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.fromLTRB(CcDims.gap4, CcDims.gap4, CcDims.gap4, 0),
                  child: Text(
                    l.ruleWarning(w.term),
                    style: theme.bodyMedium?.copyWith(color: cc.textMuted),
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<SmartSort>(
                initialValue: _sort,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.smartSortBy),
                items: [
                  for (final s in SmartSort.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(smartSortLabel(l, s)),
                    ),
                ],
                onChanged: (s) => setState(() => _sort = s ?? _sort),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _limit,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l.smartLimit),
              ),
              const SizedBox(height: 16),
              Text(l.smartAutoNote, style: theme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
