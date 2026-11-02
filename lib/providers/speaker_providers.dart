import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform.dart';
import '../services/audio/speaker_monitor.dart';
import '../services/jam/speaker_jam.dart';
import '../services/share/discovery.dart' show Peer;
import 'jam_providers.dart';
import 'share_hub.dart';

/// The monitor; started once the shell asks for it. Inert off Android.
final speakerMonitorProvider = Provider<SpeakerMonitor>((ref) {
  final m = SpeakerMonitor();
  ref.onDispose(m.dispose);
  if (isAndroid) {
    unawaited(m.start());
    // Every opening reads the connected outputs again (K-JC-03).
    final life = AppLifecycleListener(onResume: () => unawaited(m.refresh()));
    ref.onDispose(life.dispose);
  }
  return m;
});

/// Ticks whenever what the settings show may have changed. A counter, not
/// `void`: equal values would not notify the listeners.
final speakerChangesProvider = StreamProvider<int>((ref) {
  var n = 0;
  return ref.watch(speakerMonitorProvider).changes.map((_) => ++n);
});

/// A speaker is connected now (answer «yes», or guessed from its class).
final speakerConnectedProvider = StreamProvider<bool>(
  (ref) => ref.watch(speakerMonitorProvider).speakerConnected,
);

/// The permission sheet and «È una cassa?», one at a time (the shell opens them).
final speakerPromptsProvider = StreamProvider<SpeakerPrompt>(
  (ref) => ref.watch(speakerMonitorProvider).prompts,
);

/// Follows the speaker for the Jam; the shell keeps it alive. Off Android it
/// is inert: the monitor never reports a speaker.
final speakerJamProvider = Provider<SpeakerJam>((ref) {
  final monitor = ref.watch(speakerMonitorProvider);
  final jam = SpeakerJam(
    speakerConnected: monitor.speakerConnected,
    connected: () => monitor.connected,
    enabled: () => monitor.enabled,
    port: ref.read(jamProvider.notifier).speakerPort,
  );
  // The switch (and the answers) change what «connected» and «enabled» say.
  ref.listen(speakerChangesProvider, (_, _) => jam.refresh());
  ref.onDispose(jam.dispose);
  return jam;
});

/// The guest's offer «play the Jam on your speaker» is pending.
final speakerOfferProvider = StreamProvider<bool>((ref) {
  final v = ref.watch(speakerJamProvider).offerPending;
  final c = StreamController<bool>();
  void push() => c.add(v.value);
  v.addListener(push);
  ref.onDispose(() {
    v.removeListener(push);
    c.close();
  });
  push();
  return c.stream;
});

/// The first nearby device announcing a Jam, while this one is in none.
final announcedJamProvider = Provider<Peer?>((ref) {
  if (ref.watch(jamProvider.select((j) => j.phase != JamPhase.idle))) {
    return null;
  }
  final peers = ref.watch(shareHubProvider.select((h) => h.peers));
  final hidden = ref.watch(jamInviteDismissedProvider);
  return peers
      .where((p) => p.jamName != null && !hidden.contains(jamInviteKey(p)))
      .firstOrNull;
});

String jamInviteKey(Peer p) => '${p.id}|${p.jamName}';

/// Invitations the user closed (kept in memory: a Jam is announced once).
class JamInviteDismissed extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // A device that stops announcing is forgotten, so its next Jam shows again.
    ref.listen(shareHubProvider.select((h) => h.peers), (_, p) => keepOnly(p));
    return const {};
  }

  void hide(Peer p) => state = {...state, jamInviteKey(p)};

  /// Keeps only the keys of Jams still announced: a new Jam from the same
  /// device invites again.
  void keepOnly(Iterable<Peer> peers) {
    final live = {for (final p in peers) if (p.jamName != null) jamInviteKey(p)};
    final kept = state.where(live.contains).toSet();
    if (kept.length != state.length) state = kept;
  }
}

final jamInviteDismissedProvider =
    NotifierProvider<JamInviteDismissed, Set<String>>(JamInviteDismissed.new);
