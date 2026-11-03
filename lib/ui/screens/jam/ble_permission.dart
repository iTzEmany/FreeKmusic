import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_nearby_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/show_msg.dart';

/// The explanation shown before Android asks for the Bluetooth permission (R-138).
/// Pops `true` for «Consenti», `false` for «Non ora».
class JamBlePermissionSheet extends StatelessWidget {
  const JamBlePermissionSheet({super.key, required this.legacy});

  /// Android <= 11: the permission is the location one.
  final bool legacy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.jamBleTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(legacy ? l.jamBleBody11 : l.jamBleBody12),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.jamBleNotNow)),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.jamBleAllow)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Makes sure the Bluetooth permission is there, asking once with the sheet
/// (again when [force], from the «Cerca Jam vicine» switch). A refusal turns
/// the scan off: only code and QR remain. With the location off (Android <= 11)
/// it says so with a snackbar ([notifyLocationOff] false: the caller shows it itself). True when the permission is granted.
Future<bool> askBlePermission(BuildContext context, WidgetRef ref, {bool force = false, bool notifyLocationOff = true}) async {
  final beacon = ref.read(jamBeaconProvider);
  final store = ref.read(settingsStoreProvider);
  final scan = ref.read(jamNearbyScanProvider.notifier);
  // Read before the awaits: the widget (and its ref) may be gone by then; the notifiers live in the container.
  final nearby = ref.read(jamNearbyProvider.notifier);
  final container = ProviderScope.containerOf(context);
  final caps = await beacon.capabilities();
  if (!caps.scan && !caps.advertise) return false; // no Bluetooth LE here
  var p = await beacon.permissions();
  var granted = p.scan && p.advertise;
  if (!granted) {
    if (!force && store.readJamBlePermAsked()) return false;
    if (!context.mounted) return false;
    final go = await showCcSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => JamBlePermissionSheet(legacy: caps.needsLocation),
    );
    await store.writeJamBlePermAsked(true);
    if (go == true) p = await beacon.requestPermissions();
    granted = p.scan && p.advertise;
    scan.set(granted);
  } else if (force) {
    scan.set(true);
  }
  if (!granted) return false;
  nearby.refresh();
  // Only worth saying when the search is wanted.
  if (container.read(jamNearbyScanProvider) && notifyLocationOff && (await beacon.capabilities()).locationOff && context.mounted) {
    showMsg(context, context.l10n.jamBleLocationOff);
  }
  return true;
}
