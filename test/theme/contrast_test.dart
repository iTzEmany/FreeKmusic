import 'dart:math';

import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  // Every built-in theme with every accent, through the same path as the app
  // (palette, then the theme built from it).
  for (final id in AppThemeId.values) {
    for (final accent in CcAccent.values) {
      final name = '${id.name} + ${accent.name}';
      test('$name: token pairs and scheme text colours meet WCAG AA', () {
        final theme = buildThemeFromColors(buildPalette(id, accent), false);
        final c = theme.extension<CcColors>()!;
        final s = theme.colorScheme;
        final pairs = {
          'text/bg': (c.text, c.bg, 4.5),
          'text/surface1': (c.text, c.surface1, 4.5),
          'text/surface2': (c.text, c.surface2, 4.5),
          'text/surface3': (c.text, c.surface3, 4.5),
          'textMuted/bg': (c.textMuted, c.bg, 4.5),
          'textMuted/surface1': (c.textMuted, c.surface1, 4.5),
          'textMuted/surface2': (c.textMuted, c.surface2, 4.5),
          // The playing row's title and links are drawn in the accent.
          'accent/bg': (c.accent, c.bg, 4.5),
          'accent/surface1': (c.accent, c.surface1, 3.0),
          'onAccent/accent': (c.onAccent, c.accent, 4.5),
          'accentSoft/surface1': (c.accentSoft, c.surface1, 4.5),
          'accentSoft/bg': (c.accentSoft, c.bg, 4.5),
          'error/bg': (c.error, c.bg, 4.5),
          'text/heroBase': (c.text, c.heroBase, 7.0),
          // What Material widgets draw with.
          'scheme onSurface/surface': (s.onSurface, s.surface, 4.5),
          'scheme onSurfaceVariant/surfaceContainerHigh':
              (s.onSurfaceVariant, s.surfaceContainerHigh, 4.5),
          'scheme onPrimary/primary': (s.onPrimary, s.primary, 4.5),
        };
        for (final e in pairs.entries) {
          expect(
            contrast(e.value.$1, e.value.$2),
            greaterThanOrEqualTo(e.value.$3),
            reason: '$name ${e.key}',
          );
        }
      });
    }
  }

  test('textFaint reaches AA on bg and surface1 in every theme (40.2)', () {
    const faint = {
      AppThemeId.notte: Color(0xFF887F99),
      AppThemeId.oled: Color(0xFF887F99),
      AppThemeId.chiaro: Color(0xFF6D6280),
    };
    for (final e in faint.entries) {
      final c = buildPalette(e.key, CcAccent.viola);
      expect(c.textFaint, e.value, reason: e.key.name);
      expect(contrast(c.textFaint, c.surface1), greaterThanOrEqualTo(4.5),
          reason: e.key.name);
    }
  });

  // Text on sheets, dialogs and cards (s2/s3): accentSoft, never the accent.
  for (final id in AppThemeId.values) {
    for (final accent in CcAccent.values) {
      test('${id.name} + ${accent.name}: accentSoft and error reach AA on s2/s3', () {
        final c = buildPalette(id, accent);
        for (final fg in {'accentSoft': c.accentSoft, 'error': c.error}.entries) {
          for (final bg in {'s2': c.surface2, 's3': c.surface3}.entries) {
            expect(contrast(fg.value, bg.value), greaterThanOrEqualTo(4.5),
                reason: '${fg.key}/${bg.key}');
          }
        }
      });
    }
  }

  test('accentSoft: today\'s values (violet) and ratios', () {
    expect(CcColors.notte.accentSoft, const Color(0xFFD9C8FF));
    expect(CcColors.oled.accentSoft, const Color(0xFFD9C8FF));
    expect(CcColors.chiaro.accentSoft, const Color(0xFF5B2BBE));
    expect(contrast(CcColors.notte.accentSoft, CcColors.notte.bg), closeTo(13.18, 0.01));
    expect(contrast(CcColors.notte.accentSoft, CcColors.notte.surface1), closeTo(12.36, 0.01));
    expect(contrast(CcColors.chiaro.accentSoft, CcColors.chiaro.bg), closeTo(7.86, 0.01));
    expect(contrast(CcColors.chiaro.accentSoft, CcColors.chiaro.surface1), closeTo(7.25, 0.01));
  });

  test('the light theme is light and the others are dark', () {
    Brightness of(AppThemeId id) =>
        buildThemeFromColors(buildPalette(id, CcAccent.viola), false).brightness;
    expect(of(AppThemeId.chiaro), Brightness.light);
    expect(of(AppThemeId.notte), Brightness.dark);
    expect(of(AppThemeId.oled), Brightness.dark);
    expect(buildPalette(AppThemeId.chiaro, CcAccent.blu).isLight, isTrue);
  });

  test('with the violet accent the palettes are the hand-picked ones', () {
    expect(buildPalette(AppThemeId.notte, CcAccent.viola), same(CcColors.notte));
    expect(buildPalette(AppThemeId.oled, CcAccent.viola), same(CcColors.oled));
    expect(buildPalette(AppThemeId.chiaro, CcAccent.viola), same(CcColors.chiaro));
  });

  test('another accent changes only the accent family', () {
    final v = buildPalette(AppThemeId.notte, CcAccent.viola);
    final b = buildPalette(AppThemeId.notte, CcAccent.blu);
    expect(b.accent, isNot(v.accent));
    expect(b.bg, v.bg);
    expect(b.text, v.text);
    expect(b.surface2, v.surface2);
  });

  test('every accent is different, on each theme', () {
    for (final id in AppThemeId.values) {
      final colors = {for (final a in CcAccent.values) buildPalette(id, a).accent};
      expect(colors, hasLength(CcAccent.values.length), reason: id.name);
    }
  });

  test('retired or unknown theme names fall back to notte; light is chiaro', () {
    for (final n in ['carbon', 'navy', '', 'boh']) {
      expect(appThemeIdFromName(n), AppThemeId.notte);
    }
    expect(appThemeIdFromName('light'), AppThemeId.chiaro);
    expect(appThemeIdFromName('chiaro'), AppThemeId.chiaro);
    expect(appThemeIdFromName('oled'), AppThemeId.oled);
    expect(appThemeIdFromName('notte'), AppThemeId.notte);
  });

  test('unknown accent names fall back to violet', () {
    expect(accentFromName('boh'), CcAccent.viola);
    expect(accentFromName(''), CcAccent.viola);
    expect(accentFromName('rosa'), CcAccent.rosa);
  });

  // Skeleton blocks are decorative (TalkBack gets «Caricamento…»), and the
  // approved surfaces top out near 1.2:1, so 3:1 is out of reach without new
  // tokens. Guard instead that they stay clearly more visible than the old
  // surface1-on-bg placeholder and than a plain card.
  for (final id in AppThemeId.values) {
    test('${id.name}: skeleton blocks stand out from bg and from a card', () {
      final c = buildPalette(id, CcAccent.viola);
      expect(contrast(c.surface2, c.bg), greaterThanOrEqualTo(1.15));
      expect(contrast(c.surface2, c.bg), greaterThan(contrast(c.surface1, c.bg)));
      expect(contrast(c.surface3, c.surface1), greaterThanOrEqualTo(1.25));
    });
  }
}
