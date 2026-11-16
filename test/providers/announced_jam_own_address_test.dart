import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/providers/speaker_providers.dart';
import 'package:codecore/services/share/discovery.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Peer _peer(String id, String host) =>
    Peer(id: id, name: 'Mi A3', host: host, port: 1, platform: 'android', jamName: 'Jam');

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() =>
      ShareHubState(peers: [_peer('old', '192.168.1.5'), _peer('other', '192.168.1.9')]);
}

void main() {
  test('a Jam announced from this device own address is ignored', () async {
    final c = ProviderContainer(overrides: [
      shareHubProvider.overrideWith(_Hub.new),
      ownAddressesProvider.overrideWith((ref) async => {'192.168.1.5'}),
    ]);
    addTearDown(c.dispose);
    await c.read(ownAddressesProvider.future);
    expect(c.read(announcedJamProvider)?.id, 'other');
  });
}
