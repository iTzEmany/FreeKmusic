import 'package:codecore/providers/permission_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/ui/screens/home/audio_permission_banner.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _Perm extends AudioPermission {
  _Perm(this.has);
  final bool has;
  int grants = 0;

  @override
  bool build() => has;

  @override
  Future<void> grant() async => grants++;
}

void main() {
  testWidgets('banner shows only without permission and «Concedi» grants', (tester) async {
    final h = await Harness.create(tester);
    final missing = _Perm(false);
    await h.pump(tester, const Scaffold(body: AudioPermissionBanner()),
        extraOverrides: [audioPermissionProvider.overrideWith(() => missing)]);
    await tester.tap(find.text('Concedi'));
    expect(missing.grants, 1);
    await h.dispose(tester);

    await h.pump(tester, const Scaffold(body: AudioPermissionBanner()),
        extraOverrides: [audioPermissionProvider.overrideWith(() => _Perm(true))]);
    expect(find.text('Concedi'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('three errors in a row make one message with the count', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const AppShell(), extraOverrides: [
      playerFailuresProvider.overrideWith((ref) => Stream.fromIterable([
            const PlaybackFailure('A', PlaybackFailureReason.fileMissing, 1),
            const PlaybackFailure('B', PlaybackFailureReason.fileMissing, 2),
            const PlaybackFailure('C', PlaybackFailureReason.fileMissing, 3),
          ])),
    ]);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('3 brani non riproducibili'), findsOneWidget);
    expect(find.textContaining('Impossibile riprodurre'), findsNothing);
    await h.dispose(tester);
  });
}
