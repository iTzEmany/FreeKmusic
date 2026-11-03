import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_broker_providers.dart';
import '../../../providers/jam_gate_providers.dart';
import '../../../providers/jam_nearby_providers.dart';
import '../../../services/jam/remote/broker_entry.dart';
import '../../../services/jam/remote/jam_friends.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/show_msg.dart';
import '../jam/ble_permission.dart';
import 'settings_pages.dart';

/// «Jam a distanza»: the list of brokers (add, remove, reorder, restore, test), R-122.
class JamRemoteSettings extends ConsumerStatefulWidget {
  const JamRemoteSettings({super.key});

  @override
  ConsumerState<JamRemoteSettings> createState() => _JamRemoteSettingsState();
}

class _JamRemoteSettingsState extends ConsumerState<JamRemoteSettings> {
  BrokerEntry? _testing;

  Future<void> _test(BrokerEntry b) async {
    setState(() => _testing = b);
    final link = ref.read(mqttLinkFactoryProvider)();
    final ok = await testBroker(link, b);
    if (!mounted) return;
    setState(() => _testing = null);
    final l = context.l10n;
    showMsg(context, ok ? l.jamBrokerTestOk('$b') : l.jamBrokerTestFail('$b'));
  }

  Future<void> _add() => showCcSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _AddBrokerSheet(),
      );

  Future<void> _removeFriend(JamFriend f) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.jamFriendRemoveTitle(f.name)),
        content: Text(l.jamFriendRemoveBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.jamFriendRemove)),
        ],
      ),
    );
    if (ok == true) await ref.read(jamFriendsProvider).remove(f.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final friends = ref.watch(jamFriendsProvider);
    final brokers = ref.watch(jamBrokersProvider);
    final notifier = ref.read(jamBrokersProvider.notifier);
    return Scaffold(
      appBar: CcAppBar(
        title: l.jamRemoteTitle,
        actions: [TextButton(onPressed: notifier.restore, child: Text(l.jamBrokerRestore))],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: CcDims.gap24),
        children: [
          SettingsGroup(children: [
            ListTile(dense: true, title: Text(l.jamRemoteHint)),
            for (var i = 0; i < brokers.length; i++)
              ListTile(
                title: Text('${brokers[i]}'),
                subtitle: brokers[i].tls
                    ? null
                    : Text(l.jamBrokerNoTls, style: TextStyle(color: context.cc.error)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  _testing == brokers[i]
                      ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          tooltip: l.jamBrokerTest,
                          icon: const Icon(Icons.network_check),
                          onPressed: _testing == null ? () => _test(brokers[i]) : null,
                        ),
                  if (i > 0)
                    IconButton(
                      tooltip: l.jamBrokerMoveUp,
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: () => notifier.move(i, i - 1),
                    ),
                  if (brokers.length > 1)
                    IconButton(
                    tooltip: l.jamBrokerRemove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => notifier.remove(brokers[i]),
                  ),
                ]),
              ),
            ListTile(leading: const Icon(Icons.add), title: Text(l.jamBrokerAdd), onTap: _add),
          ]),
          if (ref.watch(jamBleAvailableProvider))
            SettingsGroup(children: [
            SwitchListTile(
              title: Text(l.jamNearbyScanTitle),
              subtitle: Text(l.jamNearbyScanHint),
              value: ref.watch(jamNearbyScanProvider),
              // On: the permission sheet again if it is missing (a refusal turned it off).
              onChanged: (v) => v
                  ? askBlePermission(context, ref, force: true)
                  : ref.read(jamNearbyScanProvider.notifier).set(false),
            ),
          ]),
          SettingsGroup(title: l.jamFriendsTitle, children: [
            SwitchListTile(
              title: Text(l.jamAutoAcceptFriends),
              subtitle: Text(l.jamAutoAcceptFriendsHint),
              value: ref.watch(jamAutoAcceptFriendsProvider),
              onChanged: ref.read(jamAutoAcceptFriendsProvider.notifier).set,
            ),
            // The list lives in a ChangeNotifier: rebuild on it.
            ListenableBuilder(
              listenable: friends,
              builder: (context, _) {
                final all = friends.all;
                if (all.isEmpty) return ListTile(dense: true, title: Text(l.jamFriendsEmpty));
                return Column(children: [
                  for (final f in all)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(f.name),
                      trailing: IconButton(
                        tooltip: '${l.jamFriendRemove} ${f.name}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeFriend(f),
                      ),
                    ),
                ]);
              },
            ),
          ]),
        ],
      ),
    );
  }
}

class _AddBrokerSheet extends ConsumerStatefulWidget {
  const _AddBrokerSheet();

  @override
  ConsumerState<_AddBrokerSheet> createState() => _AddBrokerSheetState();
}

class _AddBrokerSheetState extends ConsumerState<_AddBrokerSheet> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '8883');
  bool _tls = true;
  bool _invalid = false;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  void _save() {
    final b = BrokerEntry(host: _host.text.trim(), port: int.tryParse(_port.text.trim()) ?? 0, tls: _tls);
    if (!ref.read(jamBrokersProvider.notifier).add(b)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, MediaQuery.viewInsetsOf(context).bottom + CcDims.gap16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _host, decoration: InputDecoration(labelText: l.jamBrokerHost), autofocus: true),
        TextField(
          controller: _port,
          decoration: InputDecoration(labelText: l.jamBrokerPort),
          keyboardType: TextInputType.number,
        ),
        SwitchListTile(title: Text(l.jamBrokerTls), value: _tls, onChanged: (v) => setState(() => _tls = v)),
        if (!_tls) Text(l.jamBrokerNoTls, style: TextStyle(color: context.cc.error)),
        if (_invalid) Text(l.jamBrokerInvalid, style: TextStyle(color: context.cc.error)),
        Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, child: Text(l.save))),
      ]),
    );
  }
}
