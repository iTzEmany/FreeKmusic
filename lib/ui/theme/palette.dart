import 'package:flutter/material.dart';

import 'tokens.dart';

enum AppThemeId { notte, oled, chiaro }

/// Unknown or retired names (carbon, navy) fall back to `notte`; the old
/// `light` is the new `chiaro`.
AppThemeId appThemeIdFromName(String name) {
  if (name == 'light') return AppThemeId.chiaro;
  return AppThemeId.values.firstWhere(
    (e) => e.name == name,
    orElse: () => AppThemeId.notte,
  );
}

/// The eight accent colours on offer (a closed list: every combination with a
/// theme is checked for contrast, which a free colour picker could not be).
enum CcAccent { viola, blu, acqua, verde, ambra, arancio, rosa, rosso }

CcAccent accentFromName(String name) => CcAccent.values.firstWhere(
  (e) => e.name == name,
  orElse: () => CcAccent.viola,
);

/// Bright on the dark themes, deep on the light one (text and icons must
/// stand out against a white-ish background).
const _dark = {
  CcAccent.viola: Color(0xFFA06BFF),
  CcAccent.blu: Color(0xFF5B9BFF),
  CcAccent.acqua: Color(0xFF35D0BC),
  CcAccent.verde: Color(0xFF5FD07A),
  CcAccent.ambra: Color(0xFFFFC247),
  CcAccent.arancio: Color(0xFFFF9255),
  CcAccent.rosa: Color(0xFFFF70B4),
  CcAccent.rosso: Color(0xFFFF6468),
};

const _light = {
  CcAccent.viola: Color(0xFF6A35D8),
  CcAccent.blu: Color(0xFF1F5FD6),
  CcAccent.acqua: Color(0xFF0A7C72),
  CcAccent.verde: Color(0xFF1F7A3A),
  CcAccent.ambra: Color(0xFF9A5B00),
  CcAccent.arancio: Color(0xFFB8480A),
  CcAccent.rosa: Color(0xFFC0206F),
  CcAccent.rosso: Color(0xFFC0262D),
};

/// The colours of [theme] with [accent]. With the violet accent they are the
/// hand-picked constants of [CcColors].
CcColors buildPalette(AppThemeId theme, CcAccent accent) {
  final base = switch (theme) {
    AppThemeId.notte => CcColors.notte,
    AppThemeId.oled => CcColors.oled,
    AppThemeId.chiaro => CcColors.chiaro,
  };
  if (accent == CcAccent.viola) return base;
  final isLight = base.isLight;
  final color = (isLight ? _light : _dark)[accent]!;
  return CcColors(
    bg: base.bg,
    surface1: base.surface1,
    surface2: base.surface2,
    surface3: base.surface3,
    accent: color,
    accentSoft: accentSoftFor(color, isLight),
    onAccent: onAccentFor(color),
    text: base.text,
    textMuted: base.textMuted,
    textFaint: base.textFaint,
    heroBase: heroFor(color, isLight),
    error: base.error,
    isLight: isLight,
  );
}

/// Dark: a pale tint of the accent. Light: a touch deeper than the accent.
Color accentSoftFor(Color accent, bool isLight) => isLight
    ? Color.lerp(accent, Colors.black, 0.2)!
    : Color.lerp(accent, Colors.white, 0.56)!;

/// Text on the accent: white or near-black, whichever reads better.
Color onAccentFor(Color accent) {
  const ink = Color(0xFF12081F);
  return contrastRatio(Colors.white, accent) >= contrastRatio(ink, accent)
      ? Colors.white
      : ink;
}

/// The colour behind a cover with no tint: very dark or very light.
Color heroFor(Color accent, bool isLight) {
  final hsl = HSLColor.fromColor(accent);
  return isLight
      ? hsl.withSaturation(0.6).withLightness(0.88).toColor()
      : _darkHero(hsl);
}

Color _darkHero(HSLColor hsl) {
  var l = 0.26;
  var out = hsl.withSaturation(0.5).withLightness(l).toColor();
  while (out.computeLuminance() > 0.06 && l > 0.05) {
    l -= 0.01;
    out = hsl.withSaturation(0.5).withLightness(l).toColor();
  }
  return out;
}

/// WCAG contrast ratio, 1 (none) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance(), l2 = b.computeLuminance();
  return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) / (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
}

/// Search: Top 20 macro-genre tiles (D-591).
const chartGenreText = Color(0xFFFFFFFF);

/// Mid tones that keep white text above 4.5:1.
const chartGenreColors = <String, Color>{
  'pop': Color(0xFFC2185B),
  'rap': Color(0xFF6A1B9A),
  'rock': Color(0xFFB71C1C),
  'dance': Color(0xFF00695C),
  'rnb': Color(0xFF4527A0),
  'latin': Color(0xFFD84315),
  'italian': Color(0xFF1B5E20),
  'indie': Color(0xFF0D47A1),
  'jazz': Color(0xFF6D4C41),
  'classical': Color(0xFF455A64),
  'metal': Color(0xFF37474F),
  'country': Color(0xFF8D6E00),
};
