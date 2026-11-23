// Golden of the theme preview with a picture behind it (phase 138.6). Linux only.
//   flutter test --update-goldens test/goldens/theme_preview_golden_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/screens/settings/theme_editor_screen.dart';
import 'package:codecore/ui/theme/custom_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tolerant_comparator.dart';

void main() {
  if (!Platform.isLinux) return;
  setUpAll(TolerantComparator.install);

  testWidgets('theme preview with a picture', (tester) async {
    final dir = Directory.systemTemp.createTempSync('prevgolden');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/bg.png');
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(
        const Rect.fromLTWH(0, 0, 64, 64),
        ui.Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(64, 64), [
            const Color(0xFFCC3300),
            const Color(0xFF0033CC),
          ]),
      );
      final img = await rec.endRecording().toImage(64, 64);
      file.writeAsBytesSync(
        (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
      );
    });
    // Decode it on the real clock, into the image cache, before drawing.
    await tester.runAsync(() async {
      final done = Completer<void>();
      FileImage(file)
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (_, _) => done.complete(),
              onError: (e, _) => done.completeError(e),
            ),
          );
      await done.future;
    });
    tester.view.physicalSize = const Size(500, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('shot'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ThemePreview(
                colors: CcColors.notte,
                background: ThemeBackground(
                  kind: ThemeBackgroundKind.image,
                  imagePath: file.path,
                  dim: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }
    await expectLater(
      find.byKey(const ValueKey('shot')),
      matchesGoldenFile('theme_preview_image.png'),
    );
  });
}
