import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_providers.dart';
import '../../../providers/jam_gate_providers.dart';
import '../../../services/jam/jam_host.dart';
import '../../widgets/duration_choice_sheet.dart';
import 'jam_screen.dart';

/// Asks whether to start a Jam requested by a nearby device.
class JamRequestDialog extends ConsumerStatefulWidget {
  const JamRequestDialog({super.key, required this.request});

  final JamRequest request;

  @override
  ConsumerState<JamRequestDialog> createState() => _JamRequestDialogState();
}

class _JamRequestDialogState extends ConsumerState<JamRequestDialog> {
  Timer? _watch;

  JamRequest get request => widget.request;

  @override
  void initState() {
    super.initState();
    // The requester may cancel (or the request expire) while the dialog is up.
    _watch = Timer.periodic(const Duration(seconds: 1), (_) {
      if (request.status == JamRequestStatus.pending || !mounted) return;
      // Only when the dialog itself is the top route: a pop() issued while it
      // is already closing would take away the screen below.
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        _watch?.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  /// Rejects the request and mutes its sender: [minutes] null = until the Jam ends.
  void _mute({required bool block, int? minutes}) {
    _watch?.cancel();
    final gate = ref.read(jamGateProvider);
    if (block) {
      gate.block(request.fromId, request.fromName);
    } else {
      gate.suspend(request.fromId, request.fromName, minutes == null ? null : Duration(minutes: minutes));
    }
    ref.read(jamProvider.notifier).decline(request);
    Navigator.of(context).pop();
  }

  Future<void> _suspend() async {
    final l = context.l10n;
    final v = await showDurationChoiceSheet(context,
        title: l.jamSuspendTitle,
        // «Until the Jam ends» means nothing with no Jam running.
        endLabel: ref.read(jamProvider).active ? l.jamUntilJamEnds : null);
    if (v == null || !mounted) return;
    _mute(block: false, minutes: v == -1 ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ctrl = ref.read(jamProvider.notifier);
    return AlertDialog(
      title: Text(l.jamIncomingTitle(request.fromName)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (request.friend) Chip(avatar: const Icon(Icons.person_outline, size: 18), label: Text(l.jamFriendBadge)),
        Text(l.jamIncomingDialog),
      ]),
      actions: [
        TextButton(onPressed: _suspend, child: Text(l.jamSuspend)),
        TextButton(onPressed: () => _mute(block: true), child: Text(l.jamBlock)),
        TextButton(
          onPressed: () {
            _watch?.cancel();
            ctrl.decline(request);
            Navigator.of(context).pop();
          },
          child: Text(l.decline),
        ),
        FilledButton(
          onPressed: () async {
            // The dialog is gone after pop(): keep what is needed beforehand.
            _watch?.cancel();
            final nav = Navigator.of(context);
            final container = ProviderScope.containerOf(context);
            nav.pop();
            await ctrl.acceptRequest(request);
            if (container.read(jamProvider).active && nav.mounted) {
              nav.push(
                MaterialPageRoute<void>(builder: (_) => const JamScreen()),
              );
            }
          },
          child: Text(l.accept),
        ),
      ],
    );
  }
}
