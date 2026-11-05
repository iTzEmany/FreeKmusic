import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_nearby_providers.dart';
import '../../../providers/jam_providers.dart';
import '../../../providers/speaker_providers.dart';
import '../../../services/jam/jam_guest_link.dart' show JamLinkState;
import '../../../services/jam/jam_models.dart';
import '../../../services/share/discovery.dart';
import '../../theme/tokens.dart';
import '../../widgets/show_msg.dart';
import 'jam_screen.dart';

/// Asks to join [peer]'s Jam and opens the Jam screen (same as the «Jam» button).
void joinAnnouncedJam(BuildContext context, WidgetRef ref, Peer peer) {
  final nav = Navigator.of(context, rootNavigator: true);
  unawaited(ref.read(jamProvider.notifier).request(peer));
  nav.push(MaterialPageRoute<void>(builder: (_) => const JamScreen()));
}

/// Asks to enter a Jam heard over Bluetooth and opens the Jam screen; like the
/// QR, with the newest token heard. A custom-broker Jam answers «inquadra il QR».
void joinNearbyJam(BuildContext context, WidgetRef ref, JamNearbyJam jam) {
  // The token may have run out since the list was drawn.
  ref.read(jamNearbyProvider.notifier).expire();
  if (!ref.read(jamNearbyProvider).any((e) => e.key == jam.key)) return;
  final nav = Navigator.of(context, rootNavigator: true);
  unawaited(ref.read(jamProvider.notifier).requestRemote(jam.invite));
  nav.push(MaterialPageRoute<void>(builder: (_) => const JamScreen()));
}

/// «Unisciti alla Jam di X» for a friend, «…una Jam qui vicino» for a stranger.
String nearbyJamText(BuildContext context, JamNearbyJam jam) {
  final l = context.l10n;
  final name = jam.friendName;
  return name == null ? l.jamNearbyJoin : l.jamInviteBanner(name);
}

/// Sends a Jam command; a refusal for the missing speaker says so.
Future<void> sendJamCommand(
  BuildContext context,
  JamController ctrl,
  JamCommand cmd,
) async {
  final msg = context.l10n.speakerAwayNotice;
  final err = await ctrl.send(cmd);
  if (err == JamError.noSpeaker && context.mounted) showMsg(context, msg);
}

/// «Unisciti alla Jam di X» above the player; ✕ hides it for that Jam.
class JamInviteBanner extends ConsumerWidget {
  const JamInviteBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peer = ref.watch(announcedJamProvider);
    // The LAN Jam comes first; else the one heard over Bluetooth.
    final near = peer == null ? ref.watch(jamNearbyBannerProvider) : null;
    if (peer == null && near == null) return const SizedBox.shrink();
    final l = context.l10n;
    final cc = context.cc;
    final text = peer != null ? l.jamInviteBanner(peer.jamName!) : nearbyJamText(context, near!);
    void join() => peer != null ? joinAnnouncedJam(context, ref, peer) : joinNearbyJam(context, ref, near!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, 4, CcDims.margin, 0),
      child: Material(
        color: cc.surface2,
        borderRadius: BorderRadius.circular(CcDims.dockRadius),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: text,
                onTap: join,
                excludeSemantics: true,
                child: InkWell(
                  onTap: join,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CcDims.gap12,
                      vertical: CcDims.gap12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.queue_music_rounded, color: cc.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l.jamInviteDismiss,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => peer != null
                  ? ref.read(jamInviteDismissedProvider.notifier).hide(peer)
                  : ref.read(jamNearbyProvider.notifier).dismiss(near!.key),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Collega una cassa» while the speaker's Jam waits for its speaker.
class SpeakerAwayNotice extends ConsumerWidget {
  const SpeakerAwayNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final away = ref.watch(
      jamProvider.select((j) => j.jam?.speakerAwaySince != null),
    );
    if (!away) return const SizedBox.shrink();
    final isHost = ref.watch(jamProvider.select((j) => j.isHost));
    void continueOnPhone() => unawaited(ref.read(jamProvider.notifier).continueOnPhone());
    final cc = context.cc;
    final l = context.l10n;
    final text = l.speakerAwayNotice;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, 4, CcDims.margin, 0),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: cc.surface2,
          borderRadius: BorderRadius.circular(CcDims.dockRadius),
          child: Padding(
            padding: const EdgeInsets.all(CcDims.gap12),
            child: Row(
              children: [
                Icon(Icons.speaker_rounded, color: cc.accent),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
                if (isHost)
                  Semantics(
                    button: true,
                    label: l.speakerContinueOnPhoneLabel,
                    onTap: continueOnPhone,
                    excludeSemantics: true,
                    child: TextButton(
                      onPressed: continueOnPhone,
                      child: Text(l.speakerContinueOnPhone),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Connessione persa, riprovo…» for a remote guest whose link to the host is down.
class JamLinkNotice extends ConsumerWidget {
  const JamLinkNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(jamProvider.select((j) => j.remote ? j.link : JamLinkState.ok));
    if (link == JamLinkState.ok) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, 4, CcDims.margin, 0),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: context.cc.surface2,
          borderRadius: BorderRadius.circular(CcDims.dockRadius),
          child: Padding(
            padding: const EdgeInsets.all(CcDims.gap12),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: context.cc.accent),
                const SizedBox(width: 12),
                Expanded(child: Text(link == JamLinkState.hostSilent ? l.jamHostSilent : l.jamLinkReconnecting)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
