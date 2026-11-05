import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/radio_ops.dart';
import '../../../providers/radio_providers.dart';
import '../../../providers/ui_providers.dart' show searchPrefillProvider;
import '../../../providers/settings_providers.dart';
import '../../../providers/shuffle_plus_providers.dart' show networkProbeProvider;
import '../../../services/radio/radio_station.dart';
import '../../shell/shell_nav.dart';
import '../../widgets/show_msg.dart';

/// Plays [stations] from [index]: next and previous move between them. The
/// first time on mobile data a notice says what the radio costs.
Future<void> playRadioList(
  BuildContext context,
  WidgetRef ref,
  List<RadioStation> stations,
  int index,
  String listName,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final text = context.l10n.radioMobileNotice;
  await ref.read(playerControllerProvider).playStations(
        stations,
        index,
        context: PlayContext(PlayContextKind.radio, listName),
      );
  unawaited(_mobileDataNotice(ref, messenger, text));
}

Future<void> _mobileDataNotice(WidgetRef ref, ScaffoldMessengerState? messenger, String text) async {
  final prefs = ref.read(radioPrefsProvider);
  if (messenger == null || await prefs.dataNoticeSeen()) return;
  final kind = await ref.read(networkProbeProvider).current();
  if (!kind.metered) return;
  await prefs.setDataNoticeSeen();
  showMsgOn(messenger, text);
}

/// The star: saves the station in «Le mie radio» or takes it out.
Future<void> toggleSavedRadio(BuildContext context, WidgetRef ref, RadioStation s) async {
  final saved = ref.read(savedRadioIdsProvider).contains(s.id);
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final undo = await ref.read(radioOpsProvider).toggleSaved(s);
  if (messenger == null || !ref.read(settingsProvider).showUndoSnackbar) return;
  showMsgOn(
    messenger,
    saved ? l.radioRemovedDone : l.radioSavedDone,
    action: SnackBarAction(
      label: l.undo,
      onPressed: undo,
    ),
  );
}

/// «Cerca questo brano»: opens Search → Online with the title on air.
void searchOnAir(BuildContext context, WidgetRef ref, String text) {
  ref.read(searchPrefillProvider.notifier).set(text);
  ShellNav.showSearch(context, ref);
}
