import 'dart:convert';
import 'dart:io';

import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/app_harness.dart';
import 'seed.dart';

/// Phone and desktop sizes used by every shot (logical size, pixel ratio).
enum ShotSize {
  phone(Size(360, 800), 2),
  desktop(Size(1280, 800), 1);

  const ShotSize(this.size, this.dpr);
  final Size size;
  final double dpr;
}

bool _fontsLoaded = false;

/// Loads every family of the asset manifest so shots show real glyphs.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json'))
      as List<dynamic>;
  var hasIcons = false;
  var hasFigtree = false;
  for (final family in manifest) {
    final name = family['family'] as String;
    if (name == 'MaterialIcons') hasIcons = true;
    if (name == 'Figtree') hasFigtree = true;
    final loader = FontLoader(name);
    for (final font in family['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  if (!hasFigtree) {
    // Before the app ships its own fonts the theme asks for Roboto: stand in
    // with a system font so shots are readable.
    const dir = '/usr/share/fonts/truetype/liberation';
    final loader = FontLoader('Roboto');
    for (final f in ['LiberationSans-Regular.ttf', 'LiberationSans-Bold.ttf']) {
      final file = File('$dir/$f');
      if (file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }
  if (!hasIcons) {
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    final f = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await loader.load();
    }
  }
}

class Shot {
  Shot(this.tester, this.h, this.coversDir, this.seed, this.size);

  final WidgetTester tester;
  final Harness h;
  final Directory coversDir;
  final SeedResult seed;
  final ShotSize size;

  List<Override> get overrides => h.overrides;

  /// Pumps [home] inside the real theme; [extra] adds provider overrides.
  Future<void> show(Widget home,
      {List<Override> extra = const [],
      double textScale = 1,
      AppThemeId theme = AppThemeId.notte,
      CcAccent accent = CcAccent.viola}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [...overrides, ...extra],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildThemeFromColors(buildPalette(theme, accent), false),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    ));
    await settle();
  }

  /// Fixed-time pumps (no pumpAndSettle: some screens animate forever) and a
  /// decode of every cover so the shot never shows placeholders by accident.
  Future<void> settle() async {
    await tester.pump(const Duration(milliseconds: 100));
    for (var round = 0; round < 1; round++) {
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(MaterialApp));
        for (final e in find.byType(Image).evaluate().toList()) {
          await precacheImage((e.widget as Image).image, ctx)
              .timeout(const Duration(milliseconds: 200), onTimeout: () {});
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> expectShot(String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/${size.name}_$name.png'));

  /// A golden under `test/goldens/` (path relative to the test file).
  Future<void> expectGolden(String path) =>
      expectLater(find.byType(MaterialApp), matchesGoldenFile(path));

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    await h.dispose(tester);
  }
}

/// One shot test body: sets the view, builds data, runs [body], cleans up.
Future<void> withShot(
  WidgetTester tester,
  ShotSize size,
  Future<void> Function(Shot s) body, {
  bool radio = false,
}) async {
  debugDisableShadows = false;
  await loadFonts();
  tester.view.physicalSize = size.size * size.dpr;
  tester.view.devicePixelRatio = size.dpr;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, radio: radio, onlineOff: false);
  final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('shots')))!;
  h.coversDir = dir;
  final seed = (await tester.runAsync(() => seedLibrary(h.db, dir)))!;
  final s = Shot(tester, h, dir, seed, size);
  try {
    await body(s);
  } finally {
    // The binding checks painting flags before tear-downs run.
    debugDisableShadows = true;
  }
  await s.dispose();
  await tester.runAsync(() => dir.delete(recursive: true));
}
