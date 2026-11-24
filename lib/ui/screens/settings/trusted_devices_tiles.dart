import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/share_providers.dart';
import '../../../services/share/trusted_devices.dart';
import '../share/sync_flow.dart';

/// One expandable entry per paired device: its fingerprint, «accept
/// automatically» and «revoke». Empty while nothing is paired, so the
/// «Rete locale» group does not show a section that leads nowhere.
List<Widget> trustedDevicesTiles(BuildContext context, WidgetRef ref) {
  final devices = ref.watch(trustedDevicesProvider).all;
  return [for (final d in devices) _DeviceTile(device: d)];
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});

  final TrustedDevice device;

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.trustedRevokeTitle(device.name)),
        content: Text(l.trustedRevokeBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.trustedRevoke)),
        ],
      ),
    );
    if (ok == true) ref.read(trustedDevicesProvider.notifier).revoke(device.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final paired = DateFormat.yMMMd(locale)
        .format(DateTime.fromMillisecondsSinceEpoch(device.pairedAt));
    return ExpansionTile(
      leading: const Icon(Icons.verified_user_outlined),
      title: Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(l.trustedFingerprint(formatFingerprint(device.fingerprint))),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        ListTile(
          dense: true,
          title: Text(l.trustedPairedOn(paired)),
        ),
        SwitchListTile(
          title: Text(l.trustedAutoAccept),
          subtitle: Text(l.trustedAutoAcceptHint),
          value: device.autoAccept,
          onChanged: (v) =>
              ref.read(trustedDevicesProvider.notifier).setAutoAccept(device.id, v),
        ),
        SwitchListTile(
          title: Text(l.trustedMine),
          subtitle: Text(l.trustedMineHint),
          value: device.mine,
          onChanged: (v) => ref.read(trustedDevicesProvider.notifier).setMine(device.id, v),
        ),
        ListTile(
          leading: const Icon(Icons.sync_rounded),
          title: Text(l.syncDevice),
          onTap: () => syncFlow(context, ref, device),
        ),
        ListTile(
          leading: const Icon(Icons.link_off),
          title: Text(l.trustedRevoke),
          onTap: () => _revoke(context, ref),
        ),
      ],
    );
  }
}

/// «Impronta di questo dispositivo»: what to compare when pairing.
Widget ownFingerprintTile(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  final fp = ref.watch(ownIdentityProvider).value?.fingerprint;
  return ListTile(
    leading: const Icon(Icons.fingerprint_rounded),
    title: Text(l.ownFingerprint),
    subtitle: Text(fp == null ? l.ownFingerprintHint : '${formatFingerprint(fp, groups: 8)}\n${l.ownFingerprintHint}'),
    isThreeLine: fp != null,
  );
}
