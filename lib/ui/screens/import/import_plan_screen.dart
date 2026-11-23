import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/import_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/import_providers.dart';
import '../../../providers/youtube_providers.dart';
import '../../../services/import/import_candidate.dart';
import '../../../services/online/youtube_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/cc_app_bar.dart';

/// «Rivedi prima di scaricare»: for each CSV row the video that would be
/// downloaded, with the other candidates to switch to, and one button to go.
class ImportPlanScreen extends ConsumerStatefulWidget {
  const ImportPlanScreen({super.key, required this.importId});

  final int importId;

  @override
  ConsumerState<ImportPlanScreen> createState() => _ImportPlanScreenState();
}

class _ImportPlanScreenState extends ConsumerState<ImportPlanScreen> {
  int get importId => widget.importId;

  /// Rows the user unticked; every planned row starts ticked.
  final _off = <int>{};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final items = ref.watch(importItemsProvider(importId)).value ?? const [];
    final planned = [
      for (final i in items)
        if (i.state == ImportItemStatus.planned) i,
    ];
    final svc = ref.read(playlistImportServiceProvider);
    final picked = planned.where((i) => !_off.contains(i.rowIndex)).length;

    return Scaffold(
      appBar: CcAppBar(title: l.csvImportPlanTitle),
      body: planned.isEmpty
          ? EmptyState(
              icon: Icons.check_circle_outline_rounded,
              message: l.csvImportPlanEmpty,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CcDims.gap8,
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            key: const ValueKey('plan-select-all'),
                            onPressed: picked == planned.length
                                ? null
                                : () => setState(_off.clear),
                            child: Text(l.selectAll),
                          ),
                          TextButton(
                            key: const ValueKey('plan-deselect-all'),
                            onPressed: picked == 0
                                ? null
                                : () => setState(
                                    () => _off.addAll([
                                      for (final i in planned) i.rowIndex,
                                    ]),
                                  ),
                            child: Text(l.deselectAll),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final it in planned)
                            _PlanTile(
                              importId,
                              it,
                              selected: !_off.contains(it.rowIndex),
                              onSelected: (v) => setState(
                                () => v
                                    ? _off.remove(it.rowIndex)
                                    : _off.add(it.rowIndex),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: planned.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(CcDims.margin),
                child: FilledButton(
                  onPressed: picked == 0
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          for (final i in planned) {
                            if (_off.contains(i.rowIndex)) {
                              await svc.skip(importId, i.rowIndex);
                            }
                          }
                          await svc.startPlanned(importId);
                          nav.pop();
                        },
                  child: Text(
                    l.csvImportPlanGo(picked),
                    style: theme.labelLarge,
                  ),
                ),
              ),
            ),
    );
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile(
    this.importId,
    this.it, {
    required this.selected,
    required this.onSelected,
  });

  final int importId;
  final PlaylistImportItem it;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final known = ref.watch(downloadIndexProvider).value;
    final svc = ref.read(playlistImportServiceProvider);
    final candidates = decodeCandidates(it.candidates);
    final chosen =
        candidates.where((c) => c.id == it.videoId).firstOrNull ??
        (candidates.isEmpty ? null : candidates.first);
    final want = it.durationMs;
    String diffOf(ImportCandidate c) {
      if (want == null || c.durationSec == null) return '';
      final d = c.durationSec! - (want / 1000).round();
      return ' (${d >= 0 ? '+' : ''}$d s)';
    }

    String line(ImportCandidate c) =>
        '${c.source == MediaSource.soundcloud ? '${l.searchSourceSoundcloud}, ' : ''}'
        '${c.channel}, ${formatDuration((c.durationSec ?? 0) * 1000)}'
        '${diffOf(c)}, ${(c.score * 100).round()}%';
    final alreadyHere =
        chosen != null &&
        known?.pathFor(chosen.id, source: chosen.source) != null;
    return ExpansionTile(
      leading: Semantics(
        label: '${it.title}, ${it.artistList.join(', ')}',
        child: Checkbox(
          key: ValueKey('plan-check-${it.rowIndex}'),
          value: selected,
          onChanged: (v) => onSelected(v ?? false),
        ),
      ),
      title: Text(
        '${it.title}, ${it.artistList.join(', ')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: chosen == null
          ? null
          : Text(
              '${line(chosen)}${alreadyHere ? ', ${l.csvImportPlanKnown}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    (want != null &&
                        chosen.durationSec != null &&
                        (chosen.durationSec! - want / 1000).abs() > 5)
                    ? cc.error
                    : cc.textMuted,
              ),
            ),
      children: [
        RadioGroup<String>(
          groupValue: chosen?.id,
          onChanged: (id) {
            final c = candidates.where((x) => x.id == id).firstOrNull;
            if (c != null) svc.choosePlanned(importId, it.rowIndex, c);
          },
          child: Column(
            children: [
              for (final c in candidates)
                RadioListTile<String>(
                  dense: true,
                  value: c.id,
                  title: Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${line(c)}${known?.pathFor(c.id, source: c.source) != null ? ', ${l.csvImportPlanKnown}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => svc.skip(importId, it.rowIndex),
            child: Text(l.csvImportSkip),
          ),
        ),
      ],
    );
  }
}
