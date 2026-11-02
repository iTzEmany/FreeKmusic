import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' show Handler;
import 'package:permission_handler/permission_handler.dart';

import '../core/app_log.dart';
import '../data/db/app_database.dart';
import '../data/repositories/playlist_sync_repository.dart';
import '../services/jam/jam_host.dart';
import 'jam_remote_providers.dart';
import '../services/share/device_identity.dart';
import '../services/share/discovery.dart';
import '../services/share/lan_client.dart';
import '../l10n/app_localizations.dart';
import '../services/share/offers.dart';
import '../services/share/received_meta.dart';
import '../services/share/pairing.dart';
import '../services/share/pairing_client.dart';
import '../services/share/sync_client.dart';
import '../services/share/sync_routes.dart';
import '../services/share/playlist_sync.dart';
import '../services/share/trusted_devices.dart';
import '../services/share/share_notifier.dart';
import '../core/paths.dart';
import '../core/platform.dart';
import 'database_providers.dart';
import 'online_providers.dart' show afterReceive, creditsRepositoryProvider;
import 'library_providers.dart';
import 'settings_providers.dart';
import 'share_providers.dart';
import 'youtube_providers.dart';
import 'startup_providers.dart';

class ShareHubState {
  const ShareHubState({
    this.active = false,
    this.peers = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.error,
  });

  final bool active;
  final List<Peer> peers;
  final List<IncomingOffer> incoming;
  final List<OutgoingOffer> outgoing;
  final LanError? error;

  ShareHubState copyWith({
    bool? active,
    List<Peer>? peers,
    List<IncomingOffer>? incoming,
    List<OutgoingOffer>? outgoing,
    LanError? error,
    bool clearError = false,
  }) => ShareHubState(
    active: active ?? this.active,
    peers: peers ?? this.peers,
    incoming: incoming ?? this.incoming,
    outgoing: outgoing ?? this.outgoing,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Owns the offer endpoint and the discovery beacon. It runs while someone
/// needs it (Share screen open, "receive from LAN" on) or an outgoing offer
/// is still open, so the sender can leave the screen.
class ShareHubNotifier extends Notifier<ShareHubState> {
  OfferService? _service;
  DeviceIdentity? _identity;
  PairingServer? _pairing;
  final _pairRequests = StreamController<PairRequest>.broadcast();
  OfferNode? _node;
  JamHost? _jam;
  LanDiscovery? _discovery;
  String? _speakerJamName;

  /// The name the beacon announces for the speaker's Jam; null = none.
  String? get speakerJamName => _speakerJamName;
  set speakerJamName(String? v) {
    _speakerJamName = v;
    _discovery?.speakerJamName = v;
  }

  StreamSubscription<List<Peer>>? _peerSub;
  StreamSubscription<void>? _changeSub;
  Timer? _sweep;
  int _users = 0;
  bool _starting = false;
  final _cancels = <String, CancelToken>{};
  final _newIncoming = StreamController<IncomingOffer>.broadcast();
  final _notified = <String>{}; // offers currently shown as notifications

  final _newJamRequests = StreamController<JamRequest>.broadcast();

  /// New pending offers (the shell turns them into a dialog).
  Stream<IncomingOffer> get newIncoming => _newIncoming.stream;

  /// Someone asked to pair: show the PIN and their fingerprint (see `acceptPairing`).
  Stream<PairRequest> get pairRequests => _pairRequests.stream;

  /// New Jam requests (dialog in the foreground, notification otherwise).
  Stream<JamRequest> get newJamRequests => _newJamRequests.stream;

  /// Jam protocol endpoint of this device; null while the hub is stopped.
  JamHost? get jamHost => _jam;

  /// Own device id, once the hub has been started.
  String? get deviceId => _service?.deviceId;

  /// Port of the HTTP endpoint (offers and Jam), while running.
  int? get port => _node?.port;

  /// Ensures the endpoint is up for a Jam and keeps it up until [releaseJam].
  /// [remote]: the notification says the Jam is a remote one (D-243). Holders
  /// are counted: the host's own and the bridge's can overlap.
  Future<void> holdJam({bool remote = false}) async {
    _jamHolds++;
    if (remote) _remoteHolds++;
    await enter();
    await _startJamService();
  }

  Future<void> releaseJam({bool remote = false}) async {
    if (_jamHolds > 0) _jamHolds--;
    if (remote && _remoteHolds > 0) _remoteHolds--;
    if (_jamHolds > 0) {
      await _startJamService(); // the text may change
    } else if (!ref.read(settingsProvider).receiveFromLan) {
      await _platform.stopService();
    }
    await leave();
  }

  /// Keeps the process alive with the screen off (Android foreground service).
  Future<void> _startJamService() {
    final l = _l10n;
    return _platform.startService(
      title: _remoteHolds > 0 ? l.jamRemoteActive : l.jamPlaying,
      text: _remoteHolds > 0 ? l.jamPlaying : l.jamIncomingBody,
      disable: _remoteHolds > 0 ? l.jamRemoteEnd : l.jamEnd,
    );
  }

  int _jamHolds = 0, _remoteHolds = 0;
  bool get _jamHeld => _jamHolds > 0;

  /// Set by the Jam controller: "End" pressed on the service notification.
  void Function()? onJamEnd;

  /// Set by the Jam controller: the user answered a request from a notification.
  void Function(JamRequest request, bool accept)? onJamAction;

  ShareNotifier get _platform => ref.read(shareNotifierProvider);

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Locale(ref.read(settingsProvider).language));

  @override
  ShareHubState build() {
    ref.onDispose(_teardown);
    final platform = ref.read(shareNotifierProvider);
    platform.onOfferAction = _onNotificationAction;
    platform.onDisableReceive = () {
      if (_jamHeld) {
        onJamEnd?.call();
        return;
      }
      ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(receiveFromLan: false));
    };
    platform.onAppResumed = _onResume;
    ref.listen(
      settingsProvider.select((s) => s.receiveFromLan),
      (_, on) => _applyReceiveSetting(on),
    );
    // Not at launch: the server, the discovery and the Android service start
    // once the app is on screen, if the setting is still on by then.
    if (ref.read(settingsProvider).receiveFromLan) {
      ref.read(startupSettledProvider.future).then((_) {
        if (ref.mounted && ref.read(settingsProvider).receiveFromLan) {
          unawaited(_applyReceiveSetting(true));
        }
      });
    }
    return const ShareHubState();
  }

  /// "Receive from the local network" on/off: endpoint, discovery and (on
  /// Android) the foreground service with its notification.
  Future<void> _applyReceiveSetting(bool on) async {
    if (!ref.mounted) return;
    if (on) {
      if (isAndroid) {
        try {
          await Permission.notification.request();
        } on Object catch (e) {
          AppLog.d('notification permission not asked', e); // no activity yet
        }
      }
      await _ensureRunning();
      final l = _l10n;
      await _platform.startService(
        title: l.receiveServiceTitle,
        text: l.receiveServiceText,
        disable: l.receiveServiceDisable,
      );
    } else {
      await _platform.stopService();
      _maybeStop();
    }
  }

  void _onNotificationAction(String offerId, bool accept) {
    final req = _jam?.requests[offerId];
    if (req != null) {
      _notified.remove(offerId);
      onJamAction?.call(req, accept);
      return;
    }
    final o = _service?.incoming[offerId];
    if (o == null || o.status != OfferStatus.pending) return;
    _notified.remove(offerId);
    accept ? this.accept(o) : decline(o);
  }

  void _onResume() {
    // Offers that arrived while in the background become a normal dialog.
    for (final id in _notified.toList()) {
      final o = _service?.incoming[id];
      _platform.clearOffer(id);
      if (o != null && o.status == OfferStatus.pending) _newIncoming.add(o);
      final r = _jam?.requests[id];
      if (r != null && r.status == JamRequestStatus.pending) {
        _newJamRequests.add(r);
      }
    }
    _notified.clear();
  }

  Future<void> _surfaceIncoming(IncomingOffer o) async {
    if (await _platform.isForeground()) {
      _newIncoming.add(o);
      return;
    }
    final l = _l10n;
    final mb = (o.totalBytes / 1048576).toStringAsFixed(1);
    _notified.add(o.offerId);
    _platform.showOffer(
      offerId: o.offerId,
      title: o.trusted ? l.incomingTrustedTitle(o.fromName) : l.incomingTitle(o.fromName),
      body: l.incomingBody(o.items.length, mb),
      accept: l.accept,
      decline: l.decline,
    );
  }

  Future<void> _surfaceJamRequest(JamRequest r) async {
    if (await _platform.isForeground()) {
      _newJamRequests.add(r);
      return;
    }
    final l = _l10n;
    _notified.add(r.id);
    _platform.showOffer(
      offerId: r.id,
      title: l.jamIncomingTitle(r.fromName),
      body: l.jamIncomingBody,
      accept: l.accept,
      decline: l.decline,
    );
  }

  void _clearStaleNotifications() {
    final s = _service;
    if (s == null) return;
    for (final id in _notified.toList()) {
      final r = _jam?.requests[id];
      if (r != null) {
        if (r.status != JamRequestStatus.pending) {
          _notified.remove(id);
          _platform.clearOffer(id);
        }
        continue;
      }
      final o = s.incoming[id];
      if (o == null || o.status != OfferStatus.pending) {
        _notified.remove(id);
        _platform.clearOffer(id);
      }
    }
  }

  Future<void> enter() async {
    _users++;
    await _ensureRunning();
  }

  Future<void> leave() async {
    if (_users > 0) _users--;
    _maybeStop();
  }

  Future<void> _ensureRunning() async {
    if (_node?.running == true || _starting) return;
    _starting = true;
    try {
      final store = ref.read(settingsStoreProvider);
      final service =
          OfferService(
              deviceId: await store.deviceId(),
              deviceName: ref.read(deviceNameProvider),
            )
            ..onIncoming = (o) {
              final fp = o.callerFingerprint;
              final trusted = ref.read(trustedDevicesProvider);
              o.trusted = fp != null && trusted.matches(o.fromId, fp);
              _publish();
              // A trusted device with «accept automatically» needs no question.
              if (o.trusted && trusted.byId(o.fromId)!.autoAccept) {
                unawaited(accept(o));
                return;
              }
              _surfaceIncoming(o);
            };
      final gate = ref.read(jamGateProvider);
      await gate.ready;
      final jam = JamHost(
        deviceId: service.deviceId,
        deviceName: service.deviceName,
        gate: gate,
      )..onRequest = _surfaceJamRequest;
      // HTTPS needs the device identity; without it (it could not be made) the
      // hub runs plain HTTP as before (R59).
      DeviceIdentity? identity;
      try {
        identity = await DeviceIdentity.loadOrCreate(Directory(await appSupportDir()));
        if (identity.regenerated) {
          AppLog.w('device identity was remade: paired devices must pair again');
        }
      } on Object catch (e, st) {
        AppLog.w('no device identity: plain HTTP only', e, st);
      }
      ref.read(lanClientProvider).identity = identity;
      _identity = identity;
      final node = OfferNode(
        service,
        extraRoutes: {'/jam': jam.buildRouter().call},
        identity: identity,
        secureRoutes: identity == null ? const {} : _secureRoutes(identity, service),
      );
      final port = await node.start();
      final discovery = LanDiscovery(
        deviceId: service.deviceId,
        deviceName: service.deviceName,
      );
      discovery.speakerJamName = _speakerJamName;
      await discovery.start(port, tlsPort: node.tlsPort);
      if (!ref.mounted) {
        await discovery.dispose();
        await node.stop();
        service.dispose();
        jam.dispose();
        return;
      }
      _jam = jam;
      _service = service;
      _node = node;
      _discovery = discovery;
      _peerSub = discovery.peers.listen((_) => _publish());
      _changeSub = service.changes.listen((_) {
        _clearStaleNotifications();
        _publish();
        _maybeStop();
      });
      _sweep = Timer.periodic(const Duration(seconds: 5), (_) {
        service.expire();
        _publish();
        _maybeStop();
      });
      state = state.copyWith(active: true, clearError: true);
      _publish();
    } on Object catch (e, st) {
      AppLog.e('share hub start failed', e, st);
      await _shutdown();
    } finally {
      _starting = false;
    }
  }

  void _publish() {
    final s = _service;
    if (s == null || !ref.mounted) return;
    state = state.copyWith(
      peers: _discovery?.current ?? const [],
      incoming: s.incoming.values.toList()
        ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt)),
      outgoing: s.outgoing.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  bool get _busy {
    final s = _service;
    if (s == null) return false;
    return s.hasOpenOutgoing || _cancels.isNotEmpty || (_jam?.hosting ?? false);
  }

  void _maybeStop() {
    if (!ref.mounted) return;
    final wantsOn =
        _users > 0 || ref.read(settingsProvider).receiveFromLan || _busy;
    if (!wantsOn && _node != null) unawaited(_shutdown());
  }

  Future<void> _shutdown() async {
    await _teardown();
    if (ref.mounted) state = const ShareHubState();
  }

  /// Stops sockets and timers; safe to call from `onDispose` (touches no state).
  Future<void> _teardown() async {
    _sweep?.cancel();
    _sweep = null;
    await _peerSub?.cancel();
    await _changeSub?.cancel();
    _peerSub = _changeSub = null;
    await _discovery?.dispose();
    await _node?.stop();
    _service?.dispose();
    _jam?.dispose();
    _jam = null;
    _discovery = null;
    _node = null;
    _service = null;
  }

  /// The fingerprint saved for a paired device, null if [id] is not paired.
  String? _pinOf(String id) => ref.read(trustedDevicesProvider).byId(id)?.fingerprint;

  // ---- sending -------------------------------------------------------------

  /// Sends an offer (metadata only) to [peer]. Returns false if delivery fails.
  Future<bool> sendOffer(Peer peer, List<Track> tracks) async {
    await _ensureRunning();
    final service = _service;
    final node = _node;
    if (service == null || node == null || node.port == null) return false;
    final entries = await buildShareEntries(ref, tracks);
    if (entries.isEmpty) return false;
    final offer = service.createOutgoing(
      toId: peer.id,
      toName: peer.name,
      entries: entries,
    );
    try {
      await ref
          .read(lanClientProvider)
          .sendOffer(
            peer.host,
            peer.port,
            service.offerPayload(offer, node.port!, tlsPort: node.tlsPort),
            tlsPort: peer.tlsPort,
            pin: _pinOf(peer.id),
          );
      _publish();
      return true;
    } on LanException catch (e) {
      offer.status = OfferStatus.failed;
      state = state.copyWith(error: e.error);
      service.notify();
      return false;
    }
  }

  Future<void> cancelOutgoing(OutgoingOffer offer, Peer? peer) async {
    if (!offer.open) return;
    offer.status = OfferStatus.cancelled;
    _service?.notify();
    if (peer != null) {
      try {
        await ref
            .read(lanClientProvider)
            .offerAction(
              peer.host,
              peer.port,
              offer.offerId,
              'cancel',
              offer.token,
              tlsPort: peer.tlsPort,
              pin: _pinOf(peer.id),
            );
      } on LanException {
        // The receiver may be gone; the offer is closed on our side anyway.
      }
    }
  }

  // ---- receiving -----------------------------------------------------------

  Future<void> decline(IncomingOffer o) async {
    o.status = OfferStatus.declined;
    _service?.notify();
    try {
      await ref
          .read(lanClientProvider)
          .offerAction(o.fromHost, o.fromPort, o.offerId, 'decline', o.token,
              tlsPort: o.fromTlsPort, pin: _pinOf(o.fromId));
    } on LanException catch (e) {
      AppLog.w('decline not delivered: $e');
    }
  }

  Future<void> accept(IncomingOffer o) async {
    if (o.status != OfferStatus.pending) return;
    final client = ref.read(lanClientProvider);
    try {
      await client.offerAction(
        o.fromHost,
        o.fromPort,
        o.offerId,
        'accept',
        o.token,
        tlsPort: o.fromTlsPort,
        pin: _pinOf(o.fromId),
      );
    } on LanException catch (e) {
      AppLog.w('offer accept failed: $e');
      o.status = OfferStatus.failed;
      state = state.copyWith(error: e.error);
      _service?.notify();
      return;
    }
    o.status = OfferStatus.accepted;
    _service?.notify();
    final cancel = _cancels[o.offerId] = CancelToken();
    final saved = <String>[];
    final savedItems = <String, OfferItem>{};
    try {
      final base = await resolveDownloadFolder(
        ref.read(folderRepositoryProvider),
      );
      if (base == null) {
        AppLog.w('offer: no destination folder');
        throw const LanException(LanError.failed);
      }
      final out = Directory(p.join(base.$1.path, 'Ricevuti'));
      for (final item in o.items) {
        if (cancel.isCancelled) break;
        await for (final e in client.downloadOfferItem(
          o.fromHost,
          o.fromPort,
          o.offerId,
          o.token,
          item,
          out,
          cancel: cancel,
        )) {
          if (e.path != null) {
            saved.add(e.path!);
            savedItems[e.path!] = item;
          }
        }
        o.received++;
        _service?.notify();
      }
      if (saved.isNotEmpty) {
        await ref
            .read(libraryScannerProvider)
            .scanFiles(base.$2, saved)
            .drain<void>();
        for (final entry in savedItems.entries) {
          final item = entry.value;
          await applyReceivedPackage(
            ref.read(trackRepositoryProvider),
            ref.read(coverStoreProvider),
            entry.key,
            item.meta,
            credits: ref.read(creditsRepositoryProvider),
            fetchCover: item.hasCover
                ? () => client.downloadOfferCover(
                      o.fromHost, o.fromPort, o.offerId, o.token, item.id)
                : null,
          );
          final row =
              await ref.read(trackRepositoryProvider).byPath(entry.key);
          if (row != null) afterReceive(ref.read, row.id);
        }
      }
      o.status = o.received == o.items.length
          ? OfferStatus.done
          : OfferStatus.failed;
      try {
        await client.offerAction(
          o.fromHost,
          o.fromPort,
          o.offerId,
          'done',
          o.token,
          tlsPort: o.fromTlsPort,
          pin: _pinOf(o.fromId),
        );
      } on LanException {
        // Informational only.
      }
    } on LanException catch (e) {
      AppLog.w('offer download failed: $e');
      o.status = OfferStatus.failed;
      state = state.copyWith(error: e.error);
    } finally {
      _cancels.remove(o.offerId);
      _service?.notify();
    }
  }

  void clearFinished() {
    final s = _service;
    if (s == null) return;
    s.incoming.removeWhere(
      (_, o) =>
          o.status != OfferStatus.pending && o.status != OfferStatus.accepted,
    );
    s.outgoing.removeWhere((_, o) => !o.open);
    _publish();
  }

  // ---- pairing and playlist sync (HTTPS only) ------------------------------
  Map<String, Handler> _secureRoutes(DeviceIdentity identity, OfferService service) {
    final pairing = PairingServer(
      ownFingerprint: identity.fingerprint,
      ownId: service.deviceId,
      ownName: service.deviceName,
    )
      ..onRequest = _pairRequests.add
      ..onPaired = (r) => ref.read(trustedDevicesProvider.notifier).add(TrustedDevice(
            id: r.deviceId,
            name: r.name,
            fingerprint: r.fingerprint,
            pairedAt: DateTime.now().millisecondsSinceEpoch,
          ));
    _pairing = pairing;
    final sync = PlaylistSyncRepository(ref.read(databaseProvider));
    return {
      '/pair': pairing.buildRouter().call,
      '/sync': buildSyncRouter(
        export: sync.export,
        isTrusted: (fp) => ref.read(trustedDevicesProvider).byFingerprint(fp) != null,
        onWant: _offerWanted,
      ).call,
    };
  }

  /// The person here accepted (or refused) a pairing whose PIN was proven.
  bool acceptPairing(PairRequest r) => _pairing?.accept(r.id) ?? false;

  void rejectPairing(PairRequest r) => _pairing?.reject(r.id);

  /// Our own fingerprint, for the pairing screens.
  String? get ownFingerprint => _identity?.fingerprint;

  Peer? _peerOf(String deviceId) {
    for (final p in state.peers) {
      if (p.id == deviceId) return p;
    }
    return null;
  }

  /// Pairs with [peer] (PIN typed here, shown there). Saves it as trusted.
  Future<PairedPeer> pairWith(
    Peer peer,
    Future<String?> Function(String peerFingerprint, int? attemptsLeft) askPin,
  ) async {
    await _ensureRunning();
    final identity = _identity, tls = peer.tlsPort, service = _service;
    if (identity == null || tls == null || service == null) throw const PairingException(PairingError.failed);
    final paired = await PairingClient(ref.read(lanClientProvider), identity).pair(
      peer.host,
      tls,
      ownId: service.deviceId,
      ownName: service.deviceName,
      askPin: askPin,
    );
    ref.read(trustedDevicesProvider.notifier).add(TrustedDevice(
          id: paired.id,
          name: paired.name,
          fingerprint: paired.fingerprint,
          pairedAt: DateTime.now().millisecondsSinceEpoch,
        ));
    return paired;
  }

  /// Reads the playlists of the trusted [device] and plans what a sync does.
  Future<SyncPlan> planPlaylistSync(TrustedDevice device) async {
    await _ensureRunning();
    final peer = _peerOf(device.id);
    if (peer?.tlsPort == null) throw const SyncException(SyncError.unreachable);
    final db = ref.read(databaseProvider);
    final repo = PlaylistSyncRepository(db);
    final remote = await SyncClient(ref.read(lanClientProvider))
        .playlists(peer!.host, peer.tlsPort!, pin: device.fingerprint);
    final resolver = await repo.resolver(caseInsensitive: Platform.isWindows);
    return planSync(await repo.local(), remote, resolver.resolve);
  }

  Future<void> applyPlaylistSync(SyncPlan plan) => PlaylistSyncRepository(ref.read(databaseProvider)).apply(plan);

  /// «Chiedi i brani mancanti»: the other device offers us the tracks of [plan]
  /// that it has. Returns how many it found.
  Future<int> askMissingTracks(TrustedDevice device, SyncPlan plan) async {
    final peer = _peerOf(device.id);
    final node = _node;
    if (peer?.tlsPort == null || node?.port == null) throw const SyncException(SyncError.unreachable);
    final refs = plan.missing.take(kMaxWantedTracks).toList();
    if (refs.isEmpty) return 0;
    return SyncClient(ref.read(lanClientProvider)).want(
      peer!.host,
      peer.tlsPort!,
      refs,
      pin: device.fingerprint,
      port: node!.port!,
      tlsPortHere: node.tlsPort,
    );
  }

  /// A trusted device asked for these tracks: find them here and offer them back.
  Future<int> _offerWanted(String host, String fingerprint, TrackRequest request) async {
    final device = ref.read(trustedDevicesProvider).byFingerprint(fingerprint);
    if (device == null) return 0;
    final resolver = await PlaylistSyncRepository(ref.read(databaseProvider)).resolver();
    final ids = <int>{
      for (final t in request.refs) ?resolver.resolve(t),
    }.toList();
    if (ids.isEmpty) return 0;
    final tracks = await ref.read(trackRepositoryProvider).getByIds(ids);
    final to = Peer(
      id: device.id,
      name: device.name,
      host: host,
      port: request.port,
      tlsPort: request.tlsPort,
      platform: 'other',
    );
    final ok = await sendOffer(to, tracks);
    return ok ? tracks.length : 0;
  }
}

final shareHubProvider = NotifierProvider<ShareHubNotifier, ShareHubState>(
  ShareHubNotifier.new,
);

/// New pending offers, for the app-wide accept/decline dialog.
final pairRequestsProvider = StreamProvider<PairRequest>(
  (ref) => ref.watch(shareHubProvider.notifier).pairRequests,
);

final shareOffersProvider = StreamProvider<IncomingOffer>(
  (ref) => ref.watch(shareHubProvider.notifier).newIncoming,
);

/// Starts listening at launch when "receive from the local network" is on.
final shareAutoStartProvider = Provider<void>((ref) {
  // Creating the hub is enough: it applies the saved setting by itself.
  ref.read(shareHubProvider);
});

final shareNotifierProvider = Provider<ShareNotifier>(
  (ref) => createShareNotifier(),
);
