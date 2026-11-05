import 'package:codecore/providers/jam_media.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/services/jam/jam_guest_link.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:flutter_test/flutter_test.dart';

JamItem _item(String owner) => JamItem(id: 7, ownerDeviceId: owner, title: 't', ext: 'mp3');

void main() {
  final jam = JamState(
    hostDeviceId: 'h',
    outputDeviceId: 'h',
    participants: const [
      JamParticipant(id: 'h', name: 'host'),
      JamParticipant(id: 'g2', name: 'other', host: '10.0.0.5', port: 4000),
    ],
  );
  JamMedia media({JamHostFiles? files}) => JamMedia(
    () => throw UnimplementedError(),
    () => 'me',
    () => JamUiState(phase: JamPhase.active, role: JamRole.guest, jam: jam),
    () => null,
    () => files,
  );
  const files = JamHostFiles(sessionId: 's1', hostBase: 'http://10.0.0.1:3000/jam', fileToken: 'k');

  test('a guest reaches the host at hostBase and another guest at its own address', () {
    final m = media(files: files);
    expect(m.remoteUri(_item('h')).toString(), 'http://10.0.0.1:3000/jam/s1/file/7');
    expect(m.remoteUri(_item('g2')).toString(), 'http://10.0.0.5:4000/jam/s1/file/7');
  });

  test('no session, no address', () {
    expect(media().remoteUri(_item('h')), isNull);
  });
}
