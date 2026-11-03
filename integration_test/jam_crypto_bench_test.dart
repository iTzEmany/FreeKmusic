import 'dart:async';
import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:math';
import 'dart:typed_data';

import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:codecore/services/jam/remote/jam_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// RNF-15 / K-JD-09: cost of sealing and opening a big STATE envelope on a
/// phone, compression included, exactly as the bridge does it
/// (`fitState` then `JamChannel.seal`; `JamChannel.open` on the other side).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seal/open of a ~64 KB state: mean and max over 50 rounds', (_) async {
    final host = JamProtocol(await SodiumJamCrypto.create());
    final guest = JamProtocol(await SodiumJamCrypto.create());
    final secrets = host.newHostSecrets();
    final req = guest.buildRequest(
      jamId: secrets.jamId,
      hpk: secrets.hpk,
      proof: host.token(secrets, 0),
      id: 'g',
      name: 'Anna',
    )!;
    final hostCh = host.openRequest(req.bytes, secrets, hostMs: 0)!.channel;
    final guestCh = req.channel;

    final rnd = Random(7);
    String words(int n) => List.generate(n, (_) {
          final len = 3 + rnd.nextInt(7);
          return String.fromCharCodes(
              List.generate(len, (_) => 97 + rnd.nextInt(26)));
        }).join(' ');
    final items = [
      for (var i = 0; i < 200; i++)
        JamItem(
          id: i + 1,
          ownerDeviceId: 'host-device-id',
          title: words(11 + rnd.nextInt(8)),
          artist: words(3 + rnd.nextInt(3)),
          album: words(3 + rnd.nextInt(5)),
          durationMs: 120000 + rnd.nextInt(240000),
          ext: 'mp3',
          sizeBytes: 3000000 + rnd.nextInt(8000000),
          videoId: List.generate(11, (_) => 'abcdefghijklmnopqrstuvwxyz'[rnd.nextInt(26)]).join(),
        ),
    ];
    final state = JamState(
      version: 3,
      items: items,
      currentIndex: 100,
      hostDeviceId: 'host',
      outputDeviceId: 'host',
    );
    final body = {'state': host.fitState(state)!};
    final rawJson = Uint8List.fromList(utf8.encode(jsonEncode(body)));
    final zipped = ZLibCodec().encode(rawJson).length;
    // Breakdown of the cost (diagnostic only): where the milliseconds go.
    final bd = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      host.fitState(state);
    }
    final fitMs = bd.elapsedMicroseconds / 20000;
    bd.reset();
    for (var i = 0; i < 20; i++) {
      jsonEncode(body);
    }
    final encMs = bd.elapsedMicroseconds / 20000;
    bd.reset();
    for (var i = 0; i < 20; i++) {
      ZLibCodec().encode(rawJson);
    }
    final zMs = bd.elapsedMicroseconds / 20000;
    final rawBytes = rawJson.length;

    // The old in-thread path, for the comparison: fitState + seal on the UI thread.
    Uint8List sealOld() => hostCh.seal(JamMsg.state, {'state': host.fitState(state)!})!;

    // Longest time the UI isolate's event loop was blocked meanwhile.
    var last = DateTime.now(), stall = 0;
    final ticker = Timer.periodic(const Duration(milliseconds: 1), (_) {
      final now = DateTime.now();
      stall = max(stall, now.difference(last).inMicroseconds);
      last = now;
    });

    final packUs = <int>[], sealUs = <int>[], openUs = <int>[], oldUs = <int>[];
    final sw = Stopwatch();
    Future<T> timed<T>(List<int> into, Future<T> Function() f) async {
      sw
        ..reset()
        ..start();
      final r = await f();
      sw.stop();
      into.add(sw.elapsedMicroseconds);
      return r;
    }

    for (var i = 0; i < 5; i++) {
      final b = (await packStateOffThread(state))!;
      guestCh.open(hostCh.sealPacked(JamMsg.state, b)!);
      guestCh.open(sealOld());
    }
    stall = 0;
    await Future<void>.delayed(const Duration(seconds: 2));
    final idleStall = stall;
    var wire = 0;
    stall = 0;
    for (var i = 0; i < 50; i++) {
      // As the bridge: one pack in the isolate, then a cheap AEAD per channel.
      final packed = (await timed(packUs, () => packStateOffThread(state)))!;
      final env = await timed(sealUs, () async => hostCh.sealPacked(JamMsg.state, packed)!);
      wire = env.length;
      final msg = await timed(openUs, () async => guestCh.open(env));
      expect(msg!.state!.items.length, 200);
    }
    final busyStall = stall;
    ticker.cancel();
    for (var i = 0; i < 50; i++) {
      final env = await timed(oldUs, () async => sealOld());
      expect(guestCh.open(env)!.state!.items.length, 200);
    }
    String stat(List<int> us) =>
        'mean ${(us.reduce((a, b) => a + b) / us.length / 1000).toStringAsFixed(2)} ms, '
        'max ${(us.reduce(max) / 1000).toStringAsFixed(2)} ms';
    // ignore: avoid_print
    print('jambench breakdown: fitState ${fitMs.toStringAsFixed(2)} ms, jsonEncode ${encMs.toStringAsFixed(2)} ms, zlib ${zMs.toStringAsFixed(2)} ms');
    // ignore: avoid_print
    print('jambench state json $rawBytes B, zlib $zipped B, envelope $wire B (padded, encrypted, compressed)');
    // ignore: avoid_print
    print('jambench before (all on the UI thread): seal ${stat(oldUs)}');
    // ignore: avoid_print
    print('jambench now: pack in isolate ${stat(packUs)} | seal per channel on the UI thread ${stat(sealUs)} | open ${stat(openUs)}');
    // ignore: avoid_print
    print('jambench longest UI event-loop block: idle ${(idleStall / 1000).toStringAsFixed(2)} ms, during the 50 rounds ${(busyStall / 1000).toStringAsFixed(2)} ms');
  });
}
