import 'package:codecore/core/platform.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/storage_providers.dart' show sdVolumesProvider;
import 'package:codecore/ui/screens/settings/download_location_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  const sd = '/storage/1234-5678/Android/data/x/files';

  testWidgets('Android with an SD card: no dropdown in the tile (narrow phones broke the title); a dialog picks the volume', (tester) async {
    debugIsAndroidOverride = true;
    addTearDown(() => debugIsAndroidOverride = null);
    final h = await Harness.create(tester);
    await h.pump(tester, const Scaffold(body: DownloadLocationTile()),
        extraOverrides: [sdVolumesProvider.overrideWith((_) async => [sd])]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.text('Memoria dei download'), findsOneWidget);
    await tester.tap(find.text('Memoria dei download'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Scheda SD'));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    expect(c.read(settingsProvider).downloadLocation, sd);
    await h.dispose(tester);
  });
}
