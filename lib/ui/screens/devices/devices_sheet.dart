import '../../../providers/track_ops.dart';
import '../../widgets/cc_sheet.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/share_hub.dart';
import '../../../providers/speaker_providers.dart';
import '../../../services/share/discovery.dart';
import '../../theme/tokens.dart';
import '../jam/jam_remote_sheets.dart';
import '../jam/jam_screen.dart';
import '../share/share_screen.dart';
import '../share/track_picker_screen.dart';
import 'peer_card.dart';
import '../../widgets/show_msg.dart';

/// «Dispositivi»: the active Jam and the nearby devices, with [Jam] / [Invia].
class DevicesSheet extends ConsumerStatefulWidget {
  const DevicesSheet({super.key, this.trackIds});

  /// Tracks preselected by the caller (track or album menu); null = ask.
  final List<int>? trackIds;

  static Future<void> show(BuildContext context, {List<int>? trackIds}) =>
      showCcSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        builder: (_) => DevicesSheet(trackIds: trackIds),
      );

  @override
  ConsumerState<DevicesSheet> createState() => _DevicesSheetState();
}

class _DevicesSheetState extends ConsumerState<DevicesSheet> {
  late final ShareHubNotifier _hub;

  @override
  void initState() {
    super.initState();
    // Captured now: `ref` must not be used from dispose().
    _hub = ref.read(shareHubProvider.notifier);
    unawaited(_hub.enter());
  }

  @override
  void dispose() {
    _hub.leave();
    super.dispose();
  }

  Future<void> _send(Peer peer) async {
    final l = context.l10n;
    final nav = Navigator.of(context, rootNavigator: true);
    var ids = widget.trackIds;
    if (ids == null) {
      final picked = await nav.push<Set<int>>(
        MaterialPageRoute(builder: (_) => const TrackPickerScreen(initial: {})),
      );
      if (picked == null || picked.isEmpty) return;
      ids = picked.toList();
    }
    final List<Track> tracks = await ref.read(trackOpsProvider).byIds(ids);
    if (tracks.isEmpty) return;
    final ok = await _hub.sendOffer(peer, tracks);
    if (!mounted) return;
    showMsg(context, ok ? l.offerSent(peer.name) : l.shareErrUnreachable);
    nav.maybePop();
  }

  void _startJam(Peer peer) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (!ref.read(jamProvider).active) {
      unawaited(ref.read(jamProvider.notifier).request(peer));
    }
    nav.pop();
    nav.push(MaterialPageRoute<void>(builder: (_) => const JamScreen()));
  }

  void _openJam() {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    nav.push(MaterialPageRoute<void>(builder: (_) => const JamScreen()));
  }

  /// Closes this sheet, then opens the remote-Jam [sheet] on the root navigator.
  void _remote(Future<void> Function(BuildContext) sheet) {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    unawaited(sheet(nav.context));
  }

  void _manual() {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ShareScreen(initialTrackIds: widget.trackIds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final hub = ref.watch(shareHubProvider);
    final jam = ref.watch(jamProvider);
    final announced = ref.watch(announcedJamProvider);
    final visible = ref.watch(settingsProvider.select((s) => s.receiveFromLan));
    final ownId = _hub.deviceId ?? '';
    final others = <String>[
      for (final p in jam.jam?.participants ?? const [])
        if (p.id != ownId) p.name,
    ];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          CcDims.margin,
          0,
          CcDims.margin,
          CcDims.gap16,
        ),
        children: [
          Text(l.devicesTitle, style: theme.titleMedium),
          const SizedBox(height: 12),
          if (jam.active) ...[
            _JamActive(
              jam: jam,
              others: others,
              onOpen: _openJam,
              onEnd: () {
                unawaited(ref.read(jamProvider.notifier).end());
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 16),
          ],
          if (announced != null && !jam.active) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.queue_music_rounded, color: cc.accent),
              title: Text(l.jamInviteBanner(announced.jamName!)),
              onTap: () => _startJam(announced),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            l.nearbyDevices,
            style: theme.labelLarge?.copyWith(color: cc.textMuted),
          ),
          const SizedBox(height: 4),
          for (final peer in hub.peers)
            PeerCard(
              peer: peer,
              onJam: () => _startJam(peer),
              onSend: () => _send(peer),
            ),
          if (hub.peers.isEmpty)
            _NoPeers(visible: visible, hubActive: hub.active),
          const SizedBox(height: 8),
          // Remote Jam: invite (host, or no Jam yet) and join with a code (no Jam yet).
          if (!jam.active || jam.isHost)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.qr_code_2_rounded),
              title: Text(l.jamInviteNearby),
              onTap: () => _remote(JamInviteSheet.show),
            ),
          if (!jam.active)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.keyboard_rounded),
              title: Text(l.jamEnterCode),
              onTap: () => _remote(JamJoinSheet.show),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link_rounded),
            title: Text(l.manualConnection),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _manual,
          ),
        ],
      ),
    );
  }
}

class _JamActive extends StatelessWidget {
  const _JamActive({
    required this.jam,
    required this.others,
    required this.onOpen,
    required this.onEnd,
  });

  final JamUiState jam;
  final List<String> others;
  final VoidCallback onOpen, onEnd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.devicesJamActive,
          style: theme.labelLarge?.copyWith(color: cc.textMuted),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CcDims.gap4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cc.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.queue_music_rounded, color: cc.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      others.isEmpty ? jam.peerName : others.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyLarge,
                    ),
                    Text(
                      l.jamParticipantsCount(others.length + 1),
                      style: theme.labelSmall?.copyWith(color: cc.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: Text(l.jamOpen),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: onEnd,
                child: Text(jam.isHost ? l.jamEnd : l.jamLeave),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown when no device is around: the visibility switch or the searching hint.
class _NoPeers extends ConsumerWidget {
  const _NoPeers({required this.visible, required this.hubActive});

  final bool visible, hubActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    if (!visible) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CcDims.gap8),
            child: Text(l.devicesVisibleHint, style: theme.bodyMedium),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.devicesVisibleTitle),
            value: visible,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .update((s) => s.copyWith(receiveFromLan: v)),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CcDims.gap12),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hubActive ? l.noDevicesHint : l.searchingDevices,
              style: theme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
