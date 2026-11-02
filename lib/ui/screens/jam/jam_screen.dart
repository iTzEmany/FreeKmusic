import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_providers.dart';
import '../../../services/jam/jam_guest.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ring_progress.dart';
import 'jam_parts.dart' show JamAvatar;
import 'jam_player.dart';
import '../../widgets/show_msg.dart';
import 'speaker_notices.dart';
import '../../widgets/cc_app_bar.dart';

/// The Jam: waiting for the answer, then the shared queue and controls.
class JamScreen extends ConsumerStatefulWidget {
  const JamScreen({super.key});

  @override
  ConsumerState<JamScreen> createState() => _JamScreenState();
}

class _JamScreenState extends ConsumerState<JamScreen> {
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    // An outcome set before this screen existed (e.g. «wait a moment»): ref.listen misses it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(jamProvider);
      if (s.phase == JamPhase.idle && s.outcome != null) {
        final t = _outcomeText(context.l10n, s);
        _leave(t.isEmpty ? null : t);
      }
    });
  }

  void _leave(String? message) {
    if (_popped || !mounted) return;
    _popped = true;
    final ctrl = ref.read(jamProvider.notifier);
    Navigator.of(context).pop();
    if (message != null) {
      showMsg(context, message);
    }
    Future<void>.microtask(ctrl.reset);
  }

  String _outcomeText(AppLocalizations l, JamUiState s) => switch (s.outcome) {
    JamJoinOutcome.declined => s.peerName.isEmpty ? l.jamDeclinedHost : l.jamDeclined(s.peerName),
    JamJoinOutcome.busy => s.peerName.isEmpty ? l.jamBusyHost : l.jamBusy(s.peerName),
    JamJoinOutcome.cancelled => '',
    JamJoinOutcome.tooSoon => l.jamTooSoon,
    JamJoinOutcome.expired => l.jamHostNoAnswer,
    JamJoinOutcome.codeInvalid => l.jamCodeInvalid,
    JamJoinOutcome.codeExpired => l.jamCodeExpired,
    JamJoinOutcome.customBroker => l.jamCustomBroker,
    _ => l.jamUnreachable,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(jamProvider);
    ref.listen(jamProvider, (prev, next) {
      final l = context.l10n;
      if (next.phase == JamPhase.idle && next.outcome != null) {
        final t = _outcomeText(l, next);
        _leave(t.isEmpty ? null : t);
      } else if (next.phase == JamPhase.ended) {
        _leave(next.lost ? l.jamLost : next.left ? l.jamLeft : l.jamEnded);
      }
    });
    final ctrl = ref.read(jamProvider.notifier);

    if (s.phase == JamPhase.requesting) {
      return _Requesting(peerName: s.peerName, onCancel: ctrl.cancelRequest);
    }

    final jam = s.jam;
    if (!s.active || jam == null) {
      return Scaffold(
        appBar: CcAppBar(title: l.jamTitle),
        body: EmptyState(
          icon: Icons.group_outlined,
          message: l.jamWaitingEmpty,
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SpeakerAwayNotice(),
            const JamLinkNotice(),
            Expanded(child: JamPlayerView(state: s)),
          ],
        ),
      ),
    );
  }
}

class _Requesting extends StatelessWidget {
  const _Requesting({required this.peerName, required this.onCancel});

  final String peerName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: CcAppBar(title: l.jamTitle),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(CcDims.gap24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingAvatars(names: [peerName]),
              const SizedBox(height: 24),
              Text(peerName.isEmpty ? l.jamWaitingHost : l.jamWaiting(peerName), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onCancel, child: Text(l.cancel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatars that pulse while the other device answers (still when the user
/// asked for fewer animations).
class _PulsingAvatars extends StatefulWidget {
  const _PulsingAvatars({required this.names});

  final List<String> names;

  @override
  State<_PulsingAvatars> createState() => _PulsingAvatarsState();
}

class _PulsingAvatarsState extends State<_PulsingAvatars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: CcTiming.avatarPulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final n in widget.names)
          Transform.scale(
            scale: 1 + 0.12 * _c.value,
            child: RingProgress(
              size: 96,
              stroke: 4,
              live: true,
              child: JamAvatar(
                name: n,
                size: RingProgress.innerSize(96, stroke: 4),
              ),
            ),
          ),
      ],
    ),
  );
}
