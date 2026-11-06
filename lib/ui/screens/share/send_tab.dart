import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/track_ops.dart';
import '../../../providers/share_hub.dart';
import '../../../providers/share_providers.dart';
import '../../../services/share/discovery.dart';
import '../../../services/share/lan_server.dart';
import '../../theme/tokens.dart';
import '../../widgets/segmented_blocks.dart';
import '../jam/jam_screen.dart';
import '../../../providers/jam_providers.dart';
import '../devices/peer_card.dart';
import 'offer_status_label.dart';
import 'pairing_dialogs.dart';
import 'track_picker_screen.dart';
import '../../widgets/show_msg.dart';

class SendTab extends ConsumerStatefulWidget {
  const SendTab({super.key, this.initialTrackIds});

  final List<int>? initialTrackIds;

  @override
  ConsumerState<SendTab> createState() => _SendTabState();
}

class _SendTabState extends ConsumerState<SendTab> {
  /// null = whole library. Opened without tracks, the selection starts empty
  /// («Scegli brani»): sharing everything must be a deliberate choice.
  late Set<int>? _ids = {...?widget.initialTrackIds};
  ShareInfo? _info;
  bool _starting = false;
  bool _noNetwork = false;
  late final ShareController _controller;

  @override
  void initState() {
    super.initState();
    // Captured now: `ref` must not be used from dispose().
    _controller = ref.read(shareControllerProvider);
  }

  @override
  void dispose() {
    // The PIN server only lives while this screen is open.
    _controller.stopSharing();
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await Navigator.of(context).push<Set<int>>(
      MaterialPageRoute(
        builder: (_) => TrackPickerScreen(initial: _ids ?? const {}),
      ),
    );
    if (res != null && mounted) setState(() => _ids = res);
  }

  Future<void> _sendTo(Peer peer) async {
    final l = context.l10n;
    final repo = ref.read(trackOpsProvider);
    final List<Track> tracks = _ids == null
        ? await repo.all()
        : await repo.byIds(_ids!.toList());
    if (tracks.isEmpty) {
      if (!mounted) return;
      showMsg(context, l.offerChooseFirst);
      return;
    }
    final ok = await ref
        .read(shareHubProvider.notifier)
        .sendOffer(peer, tracks);
    if (!mounted) return;
    showMsg(context, ok ? l.offerSent(peer.name) : l.shareErrUnreachable);
  }

  void _startJam(Peer peer) {
    final ctrl = ref.read(jamProvider.notifier);
    final jam = ref.read(jamProvider);
    if (!jam.active) unawaited(ctrl.request(peer));
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const JamScreen()));
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _noNetwork = false;
    });
    final info = await _controller.startSharing(_ids?.toList());
    if (!mounted) return;
    setState(() {
      _starting = false;
      _info = info;
      _noNetwork = info == null;
    });
  }

  Future<void> _stop() async {
    await _controller.stopSharing();
    if (mounted) setState(() => _info = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hub = ref.watch(shareHubProvider);
    final all = _ids == null;
    return ListView(
      padding: const EdgeInsets.all(CcDims.margin).withDock(context),
      children: [
        SegmentedBlocks<bool>(
          selected: all,
          onChanged: (v) => setState(() => _ids = v ? null : (_ids ?? {})),
          items: [
            BlockItem(
              value: true,
              icon: Icons.library_music_rounded,
              label: l.shareAll,
            ),
            BlockItem(
              value: false,
              icon: Icons.checklist_rounded,
              label: l.shareSelection(_ids?.length ?? 0),
            ),
          ],
        ),
        if (!all)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: _pick, child: Text(l.sharePick)),
          ),
        const SizedBox(height: 16),
        if (ref.watch(jamProvider).active) const _JamBanner(),
        Text(l.nearbyDevices, style: Theme.of(context).textTheme.titleMedium),
        if (hub.peers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CcDims.gap12),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l.searchingDevices)),
              ],
            ),
          ),
        for (final peer in hub.peers)
          PeerCard(
            peer: peer,
            onSend: () => _sendTo(peer),
            onJam: () => _startJam(peer),
            trusted: ref.watch(trustedDevicesProvider).byId(peer.id) != null,
            onPair:
                peer.tlsPort != null &&
                    ref.watch(trustedDevicesProvider).byId(peer.id) == null
                ? () => pairFlow(context, ref, peer)
                : null,
          ),
        if (hub.peers.isEmpty && hub.active)
          Text(l.noDevicesHint, style: Theme.of(context).textTheme.bodySmall),
        if (hub.outgoing.isNotEmpty) _SentRequests(hub: hub),
        const SizedBox(height: 8),
        ExpansionTile(
          title: Text(l.manualConnection),
          tilePadding: EdgeInsets.zero,
          children: [
            if (_info != null)
              _Active(info: _info!, onStop: _stop)
            else ...[
              Text(l.shareHint),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _starting || (!all && _ids!.isEmpty) ? null : _start,
                icon: const Icon(Icons.wifi_tethering),
                label: Text(l.shareStart),
              ),
              if (_noNetwork)
                Padding(
                  padding: const EdgeInsets.only(top: CcDims.gap12),
                  child: Text(
                    l.shareNoNetwork,
                    style: TextStyle(color: context.cc.error),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Active extends StatelessWidget {
  const _Active({required this.info, required this.onStop});

  final ShareInfo info;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final url = 'http://${info.host}:${info.port}/?pin=${info.pin}';
    return Column(
      children: [
        Text(l.shareActive, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          // A QR needs a light quiet zone in every theme.
          color: Colors.white,
          padding: const EdgeInsets.all(CcDims.gap8),
          child: QrImageView(data: url, size: 180),
        ),
        ListTile(
          title: Text(l.shareAddress),
          subtitle: SelectableText(
            '${info.host}:${info.port}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          title: Text(l.sharePin),
          subtitle: SelectableText(
            info.pin,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(letterSpacing: 4),
          ),
        ),
        FilledButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          label: Text(l.shareStop),
        ),
      ],
    );
  }
}

class _JamBanner extends StatelessWidget {
  const _JamBanner();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: CcDims.gap16),
      child: Material(
        color: context.cc.surface1,
        borderRadius: BorderRadius.circular(CcDims.rCard),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(Icons.queue_music),
          title: Text(l.jamPlaying),
          trailing: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const JamScreen())),
            child: Text(l.jamOpen),
          ),
        ),
      ),
    );
  }
}

class _SentRequests extends ConsumerWidget {
  const _SentRequests({required this.hub});

  final ShareHubState hub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(l.sentRequests, style: Theme.of(context).textTheme.titleMedium),
        for (final o in hub.outgoing)
          ListTile(
            leading: const Icon(Icons.north_east),
            title: Text(o.toName),
            subtitle: Text(
              '${l.tracksCount(o.entries.length)}, ${offerStatusLabel(l, o.status)}',
            ),
            trailing: o.open
                ? IconButton(
                    tooltip: l.cancel,
                    icon: const Icon(Icons.close),
                    onPressed: () => ref
                        .read(shareHubProvider.notifier)
                        .cancelOutgoing(
                          o,
                          hub.peers.where((p) => p.id == o.toId).firstOrNull,
                        ),
                  )
                : null,
          ),
      ],
    );
  }
}
