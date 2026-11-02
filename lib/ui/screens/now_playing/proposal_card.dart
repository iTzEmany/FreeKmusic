import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart' show Track;
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/activity_log_providers.dart';
import '../../../providers/online_providers.dart';
import '../../../providers/recognition_providers.dart';
import '../../widgets/show_msg.dart';
import 'now_playing_cards.dart';

/// «Title – Artist», or just the title when the artist is unknown.
String identLabel(AppLocalizations l, String title, String? artist) =>
    (artist ?? '').isEmpty ? title : l.recogIdent(title, artist!);

/// «Proposta: Titolo – Artista» with Accetta / Scarta; nothing when the track
/// has no open proposal or the user has edited it.
class ProposalCard extends ConsumerWidget {
  const ProposalCard({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(trackRecProvider(track.id)).value;
    final id = rec?.identity;
    if (rec == null || id == null || rec.prop != 'open' || track.userEdited) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final ident = identLabel(l, id.title, id.artist);
    final fixes = ref.read(trackCorrectionsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NpCard(
        title: l.recogProposal(ident),
        child: Wrap(
          spacing: 8,
          children: [
            ActionButton(
              label: l.recogAccept,
              semantics: l.recogAcceptSem(ident),
              failed: l.recogActionFailed,
              build: FilledButton.new,
              action: () async {
                await fixes.apply(track, rec, byUser: true);
                return true;
              },
            ),
            ActionButton(
              label: l.recogDiscard,
              semantics: l.recogDiscardSem(ident),
              failed: l.recogActionFailed,
              build: OutlinedButton.new,
              action: () async {
                await fixes.discard(track.id);
                return true;
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// «Cover di Titolo – Artista» (from `rec.original`), or just «Cover».
class CoverLine extends ConsumerWidget {
  /// Of a library track ([trackId]) or of an online item ([videoId], R-186; a
  /// null one asks nothing and draws nothing).
  const CoverLine({super.key, this.trackId, this.videoId});

  final int? trackId;
  final String? videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = switch ((trackId, videoId)) {
      (final int t, _) => ref.watch(trackRecProvider(t)).value,
      (_, final String v) => ref.watch(onlineRecognitionProvider(v)).value,
      _ => null,
    };
    if (rec == null || !rec.cover) return const SizedBox.shrink();
    final l = context.l10n;
    final o = rec.original;
    final text = o == null || (o['title'] ?? '').isEmpty
        ? l.recogCover
        : l.recogCoverOf(identLabel(l, o['title']!, o['artist']));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// A button that runs [action] one at a time (disabled meanwhile). It says so
/// when [action] throws or returns false (with [failed]), and then reloads the
/// Registro, which the correction services write to behind its back.
class ActionButton extends ConsumerStatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.semantics,
    required this.action,
    required this.failed,
    this.build = TextButton.new,
  });

  final String label, semantics, failed;
  final Future<bool> Function() action;
  final Widget Function({required VoidCallback? onPressed, required Widget child}) build;

  @override
  ConsumerState<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends ConsumerState<ActionButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    final log = ref.read(activityLogProvider.notifier); // the button may be gone when it ends
    var ok = false;
    try {
      ok = await widget.action();
    } on Object catch (e, st) {
      AppLog.w('${widget.semantics} failed', e, st);
    }
    unawaited(log.reload());
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) showMsg(context, widget.failed);
  }

  @override
  Widget build(BuildContext context) => widget.build(
    onPressed: _busy ? null : _run,
    // The label names the song; the visible text would be read twice.
    child: Semantics(label: widget.semantics, child: ExcludeSemantics(child: Text(widget.label))),
  );
}
