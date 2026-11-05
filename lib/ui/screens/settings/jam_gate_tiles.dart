import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../services/jam/jam_gate.dart';
import 'settings_pages.dart';

/// Blocked and suspended senders of Jam requests, with the way back. Nothing
/// when both lists are empty. The gate notifies; the page rebuilds on it.
List<SettingsGroup> jamGateGroups(BuildContext context, JamGate gate) {
  final l = context.l10n;
  final blocked = gate.blocked, suspended = gate.suspended;
  String until(JamGateEntry e) => e.when == null
      ? l.jamUntilJamEnds
      : l.jamSuspendedUntil(MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(e.when!)));
  Widget tile(JamGateEntry e, String? sub, void Function(String) undo) => ListTile(
        title: Text(e.name),
        subtitle: sub == null ? null : Text(sub),
        trailing: Semantics(
          button: true,
          label: '${l.jamUnblock} ${e.name}',
          onTap: () => undo(e.id),
          excludeSemantics: true,
          child: TextButton(onPressed: () => undo(e.id), child: Text(l.jamUnblock)),
        ),
      );
  return [
    if (blocked.isNotEmpty)
      SettingsGroup(title: l.jamBlockedTitle, children: [for (final e in blocked) tile(e, null, gate.unblock)]),
    if (suspended.isNotEmpty)
      SettingsGroup(title: l.jamSuspendedTitle, children: [for (final e in suspended) tile(e, until(e), gate.unsuspend)]),
  ];
}
