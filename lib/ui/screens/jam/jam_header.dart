import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../services/jam/jam_models.dart';
import '../../theme/tokens.dart';
import '../../widgets/artist_avatar.dart';

/// Participants shown by name and avatar; the rest is «+N».
const jamHeaderMaxShown = 4;

/// Top of the Jam screen, the only part that differs from the player: back,
/// «Jam» centred, then the participants and «Termina Jam» (host, after a
/// confirmation) or «Esci dalla Jam» (guest). At large text the avatars and
/// the action go to two rows and the title wraps, nothing is clipped.
class JamHeader extends StatelessWidget {
  const JamHeader({
    super.key,
    required this.jam,
    required this.isHost,
    required this.onEnd,
    this.unreachable = const [],
  });

  /// Remote guests the host has not heard from for a while.
  final List<String> unreachable;
  final JamState jam;
  final bool isHost;
  final VoidCallback onEnd;

  Future<void> _confirmEnd(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = ctx.l10n;
        final cc = ctx.cc;
        final guests = (jam.participants.length - 1).clamp(0, 99);
        const min = Size(64, 48);
        return AlertDialog(
          title: Text(l.jamEndConfirmTitle),
          content: Text(l.jamEndConfirmBody(guests)),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: cc.accentSoft,
                minimumSize: min,
              ),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: cc.error,
                minimumSize: min,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.jamEndConfirmAction),
            ),
          ],
        );
      },
    );
    if (ok == true) onEnd();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final ps = [
      ...jam.participants.where((p) => p.id == jam.hostDeviceId),
      ...jam.participants.where((p) => p.id != jam.hostDeviceId),
    ];
    String label(JamParticipant p) => p.id == jam.hostDeviceId
        ? '${p.name} (${l.jamHostTag})'
        : unreachable.contains(p.id)
            ? '${p.name} (${l.jamMemberUnreachable})'
            : p.name;
    final shown = ps.take(jamHeaderMaxShown).toList();
    final extra = ps.length - shown.length;
    final all = ps.map(label).join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.gap4,
        CcDims.gap8,
        CcDims.gap4,
        CcDims.gap4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l.back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  l.jamTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleLarge,
                ),
              ),
              // Same width as the back button: «Jam» stays centred.
              const SizedBox(width: 48),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.gap12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: CcDims.gap4,
              children: [
                if (ps.isNotEmpty)
                  Semantics(
                    container: true,
                    excludeSemantics: true,
                    label: l.jamParticipantsLabel(ps.length, all),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Avatars(people: shown, extra: extra),
                        const SizedBox(width: CcDims.gap12),
                        // Never wider than the screen.
                        Flexible(
                          child: _Names(
                            shown: shown.map(label).toList(),
                            hostFirst: shown.first.id == jam.hostDeviceId,
                            extra: extra,
                          ),
                        ),
                      ],
                    ),
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: isHost ? cc.error : cc.text,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: isHost ? () => _confirmEnd(context) : onEnd,
                  child: Text(isHost ? l.jamEnd : l.jamLeave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The first names; the host's one in bold, then «+N».
class _Names extends StatelessWidget {
  const _Names({
    required this.shown,
    required this.hostFirst,
    required this.extra,
  });

  final List<String> shown;
  final bool hostFirst;
  final int extra;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: context.cc.textMuted,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, n) in shown.indexed) ...[
            if (i > 0) const TextSpan(text: ', '),
            TextSpan(
              text: n,
              style: i == 0 && hostFirst
                  ? TextStyle(
                      color: context.cc.text,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
          ],
          if (extra > 0) TextSpan(text: ' +$extra'),
        ],
      ),
      style: style,
    );
  }
}

/// 32 dp initials overlapping by 10, ringed with 2 dp of the background; the
/// colours are accent tokens, in order. «+N» closes the row.
class _Avatars extends StatelessWidget {
  const _Avatars({required this.people, required this.extra});

  final List<JamParticipant> people;
  final int extra;

  static const _size = 32.0, _step = 22.0;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final fills = [
      (cc.accent, cc.onAccent),
      (cc.accentSoft, cc.onAccent),
      (Color.alphaBlend(cc.accent.withValues(alpha: 0.45), cc.surface2), cc.text),
      (cc.surface3, cc.accentSoft),
    ];
    final n = people.length + (extra > 0 ? 1 : 0);
    Widget disc(String text, Color bg, Color fg) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cc.bg, width: 2),
      ),
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return SizedBox(
      width: n == 0 ? 0 : _size + 4 + _step * (n - 1),
      height: _size + 4,
      child: Stack(
        children: [
          for (final (i, p) in people.indexed)
            Positioned(
              left: i * _step,
              child: disc(
                artistMonogram(p.name),
                fills[i % fills.length].$1,
                fills[i % fills.length].$2,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: people.length * _step,
              child: disc('+$extra', cc.surface2, cc.textMuted),
            ),
        ],
      ),
    );
  }
}
