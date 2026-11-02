import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/online_providers.dart';
import '../../../providers/recognition_providers.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../now_playing/proposal_card.dart' show ActionButton, identLabel;

/// «Da confermare (N)»: the open proposals, one by one or all at once.
class ProposalsScreen extends ConsumerWidget {
  const ProposalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final list = ref.watch(proposalsProvider).value ?? const [];
    final fixes = ref.read(trackCorrectionsProvider);
    return Scaffold(
      appBar: CcAppBar(
        title: l.recogToConfirm(list.length),
        actions: [
          if (list.isNotEmpty)
            ActionButton(
              label: l.recogAcceptAll,
              semantics: l.recogAcceptAll,
              failed: l.recogActionFailed,
              action: () async {
                await fixes.acceptAll();
                return true;
              },
            ), // D-331: no dialog
        ],
      ),
      body: list.isEmpty
          ? EmptyState(
              icon: Icons.task_alt_rounded,
              message: l.recogNoProposals,
            )
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final p = list[i];
                final id = p.rec.identity!;
                final now = identLabel(l, p.track.title, p.track.artist);
                final next = identLabel(l, id.title, id.artist);
                return ListTile(
                  key: ValueKey('proposal-${p.track.id}'),
                  title: Text(
                    l.recogFromTo(now, next),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [
                      ActionButton(
                        label: l.recogAccept,
                        semantics: l.recogAcceptSem(next),
                        failed: l.recogActionFailed,
                        action: () async {
                          await fixes.apply(p.track, p.rec, byUser: true);
                          return true;
                        },
                      ),
                      ActionButton(
                        label: l.recogDiscard,
                        semantics: l.recogDiscardSem(next),
                        failed: l.recogActionFailed,
                        action: () async {
                          await fixes.discard(p.track.id);
                          return true;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
