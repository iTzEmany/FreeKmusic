import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart' show Track;
import '../../../l10n/l10n_ext.dart';
import '../../../providers/online_providers.dart';
import '../../../providers/recognition_providers.dart';
import '../../../services/library/track_corrections.dart';
import '../../../services/recognition/track_identity.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_tile.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/track_art.dart';
import '../../widgets/action_button.dart';
import '../now_playing/proposal_card.dart' show identLabel, recogSourceLabel;

typedef _Build = Widget Function({
  required VoidCallback? onPressed,
  required Widget child,
});

// 48 dp high, as every target of the app.
_Build _filled({bool tonal = false}) => ({required onPressed, required child}) {
  final style = FilledButton.styleFrom(minimumSize: const Size(0, 48));
  return tonal
      ? FilledButton.tonal(style: style, onPressed: onPressed, child: child)
      : FilledButton(style: style, onPressed: onPressed, child: child);
};

/// «Da confermare»: the open proposals, one by one or all at once.
class ProposalsScreen extends ConsumerWidget {
  const ProposalsScreen({super.key});

  /// «Annulla» after «Accetta tutte»: puts every correction back (like «Ripristina») and the proposals among the open ones.
  Future<void> _undo(BuildContext context, TrackCorrections fixes, AcceptedAll done) async {
    final back = await fixes.revertAll(done);
    if (back.count < done.count && context.mounted) {
      showMsg(context, context.l10n.logRevertFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final list = ref.watch(proposalsProvider).value ?? const [];
    final fixes = ref.read(trackCorrectionsProvider);
    return Scaffold(
      appBar: CcAppBar(title: l.recogTitle),
      body: list.isEmpty
          ? EmptyState(
              icon: Icons.task_alt_rounded,
              message: l.recogNoProposals,
              help: l.recogNoProposalsHint,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: CcDims.gap16),
                  itemCount: list.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          CcDims.margin,
                          0,
                          CcDims.margin,
                          CcDims.gap12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.recogSuggested(list.length),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: CcDims.gap12),
                            ActionButton(
                              label: l.recogAcceptAllCount(list.length),
                              semantics: l.recogAcceptAllCount(list.length),
                              failed: l.recogActionFailed,
                              build: _filled(),
                              action: () async {
                                // The «Annulla» of a previous round must not undo this one.
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                final done = await fixes
                                    .acceptAll(); // D-331: no dialog
                                if (done.count > 0 && context.mounted) {
                                  showUndoSnack(
                                    context,
                                    l.recogAcceptedAll(done.count),
                                    () => unawaited(_undo(context, fixes, done)),
                                  );
                                }
                                return true;
                              },
                            ),
                          ],
                        ),
                      );
                    }
                    final p = list[i - 1];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CcDims.margin,
                        0,
                        CcDims.margin,
                        CcDims.gap8,
                      ),
                      child: _ProposalTile(
                        key: ValueKey('proposal-${p.track.id}'),
                        track: p.track,
                        rec: p.rec,
                        fixes: fixes,
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}

/// One proposal: cover, the old values struck out and dimmed, the new ones
/// highlighted where they differ, the source, and Scarta / Accetta.
class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    super.key,
    required this.track,
    required this.rec,
    required this.fixes,
  });

  final Track track;
  final Recognition rec;
  final TrackCorrections fixes;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final id = rec.identity!;
    final now = identLabel(l, track.title, track.artist);
    final next = identLabel(l, id.title, id.artist);
    final src = rec.src == null ? null : recogSourceLabel(l, rec.src!);
    final dimmed = theme.bodySmall?.copyWith(
      color: cc.textMuted.withValues(alpha: .85),
      decoration: TextDecoration.lineThrough,
    );

    // A changed value sits on a soft accent patch; an unchanged one stays quiet.
    Widget value(String text, bool changed, TextStyle? style) => changed
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: cc.accent.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(CcDims.rList),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              child: Text(
                text,
                style: style,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        : Text(
            text,
            style: style?.copyWith(color: cc.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );

    final artist = id.artistOver(track.artist) ?? '';
    return CcTile(
      child: Padding(
        padding: const EdgeInsets.all(CcDims.gap12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrackArt(track: track, size: 56),
                const SizedBox(width: CcDims.gap12),
                Expanded(
                  // One line for screen readers; the buttons below keep their own.
                  child: Semantics(
                    container: true,
                    label: [l.recogFromTo(now, next), ?src].join(', '),
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            now,
                            style: dimmed,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: CcDims.gap4),
                          value(
                            id.title,
                            id.title != track.title,
                            theme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (artist.isNotEmpty || src != null) ...[
                            const SizedBox(height: CcDims.gap4),
                            Wrap(
                              spacing: CcDims.gap8,
                              runSpacing: CcDims.gap4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (artist.isNotEmpty)
                                  value(
                                    artist,
                                    artist != (track.artist ?? ''),
                                    theme.bodyMedium,
                                  ),
                                if (src != null)
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: cc.surface2,
                                      borderRadius: BorderRadius.circular(
                                        CcDims.rCard,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      child: Text(
                                        src,
                                        style: theme.bodySmall?.copyWith(
                                          color: cc.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CcDims.gap12),
            Row(
              children: [
                Expanded(
                  child: ActionButton(
                    label: l.recogDiscard,
                    semantics: l.recogDiscardSem(next),
                    failed: l.recogActionFailed,
                    build: _filled(tonal: true),
                    action: () async {
                      await fixes.discard(track.id);
                      return true;
                    },
                  ),
                ),
                const SizedBox(width: CcDims.gap8),
                Expanded(
                  child: ActionButton(
                    label: l.recogAccept,
                    semantics: l.recogAcceptSem(next),
                    failed: l.recogActionFailed,
                    build: _filled(),
                    action: () async {
                      await fixes.apply(track, rec, byUser: true);
                      return true;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
