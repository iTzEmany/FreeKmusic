import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable, mapEquals;
import 'package:flutter/painting.dart';

import 'palette.dart';
import 'tokens.dart';

/// The twelve colours a theme is made of (the fields of [CcColors]).
enum CcToken {
  bg,
  surface1,
  surface2,
  surface3,
  accent,
  accentSoft,
  onAccent,
  text,
  textMuted,
  textFaint,
  heroBase,
  error,
}

enum ThemeBackgroundKind { solid, gradient, image }

/// What sits behind the pages: the theme's background colour alone, a
/// gradient from it to [gradientEnd], or a picture from a file.
@immutable
class ThemeBackground {
  const ThemeBackground({
    this.kind = ThemeBackgroundKind.solid,
    this.gradientEnd,
    this.angle = 180,
    this.imagePath,
    this.dim = 0.35,
    this.blur = 0,
    this.coverBackdrop = true,
  });

  final ThemeBackgroundKind kind;

  /// The colour the gradient ends in (it starts in the theme's `bg`).
  final Color? gradientEnd;

  /// Degrees, 0 = towards the top, 90 = towards the right, 180 = towards the bottom.
  final double angle;

  /// A file in the app's own folder (copied there when picked).
  final String? imagePath;

  /// 0..1: how much black is laid over the picture so text stays readable.
  final double dim;

  /// 0..20: blur radius of the picture.
  final double blur;

  /// Now playing keeps the tint of the cover (true) or shows this background.
  final bool coverBackdrop;

  /// A background that needs more than the plain colour.
  bool get isCustom => switch (kind) {
    ThemeBackgroundKind.solid => false,
    ThemeBackgroundKind.gradient => gradientEnd != null,
    ThemeBackgroundKind.image => imagePath != null,
  };

  ThemeBackground copyWith({
    ThemeBackgroundKind? kind,
    Color? gradientEnd,
    bool clearGradientEnd = false,
    double? angle,
    String? imagePath,
    bool clearImage = false,
    double? dim,
    double? blur,
    bool? coverBackdrop,
  }) => ThemeBackground(
    kind: kind ?? this.kind,
    gradientEnd: clearGradientEnd ? null : gradientEnd ?? this.gradientEnd,
    angle: angle ?? this.angle,
    imagePath: clearImage ? null : imagePath ?? this.imagePath,
    dim: dim ?? this.dim,
    blur: blur ?? this.blur,
    coverBackdrop: coverBackdrop ?? this.coverBackdrop,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (gradientEnd != null) 'gradientEnd': gradientEnd!.toARGB32(),
    'angle': angle,
    if (imagePath != null) 'imagePath': imagePath,
    'dim': dim,
    'blur': blur,
    'coverBackdrop': coverBackdrop,
  };

  static ThemeBackground fromJson(Object? j) {
    if (j is! Map) return const ThemeBackground();
    double num01(Object? v, double min, double max, double fallback) =>
        v is num && v.isFinite ? v.toDouble().clamp(min, max) : fallback;
    final end = j['gradientEnd'];
    final path = j['imagePath'];
    return ThemeBackground(
      kind: ThemeBackgroundKind.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => ThemeBackgroundKind.solid,
      ),
      gradientEnd: end is int ? _opaque(Color(end)) : null,
      angle: num01(j['angle'], 0, 360, 180),
      imagePath: path is String && path.isNotEmpty ? path : null,
      dim: num01(j['dim'], 0, 0.8, 0.35),
      blur: num01(j['blur'], 0, 20, 0),
      coverBackdrop: j['coverBackdrop'] is bool
          ? j['coverBackdrop'] as bool
          : true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeBackground &&
      other.kind == kind &&
      other.gradientEnd == gradientEnd &&
      other.angle == angle &&
      other.imagePath == imagePath &&
      other.dim == dim &&
      other.blur == blur &&
      other.coverBackdrop == coverBackdrop;

  @override
  int get hashCode => Object.hash(
    kind,
    gradientEnd,
    angle,
    imagePath,
    dim,
    blur,
    coverBackdrop,
  );
}

/// Only the three surfaces may be see-through (D-551), never under 20 % opaque.
bool hasAlphaToken(CcToken t) =>
    t == CcToken.surface1 || t == CcToken.surface2 || t == CcToken.surface3;

const _minSurfaceAlpha = 0x33;

/// A colour is fully opaque in a theme: a see-through text would change with
/// what is behind it. A surface keeps its alpha, clamped to >= 20 %.
Color _fit(CcToken t, Color c) => c.withAlpha(
  hasAlphaToken(t) ? (c.a * 255).round().clamp(_minSurfaceAlpha, 0xFF) : 0xFF,
);
Color _opaque(Color c) => c.withAlpha(0xFF);

/// A theme the user made: a built-in theme as the starting point, the colours
/// they changed (`overrides`), and a background. Colours that were not changed
/// by hand follow the ones that were (the surfaces follow the background, the
/// muted texts follow the text…), so a theme can be made from three colours.
@immutable
class CustomTheme {
  const CustomTheme({
    required this.id,
    required this.name,
    this.base = AppThemeId.notte,
    this.overrides = const {},
    this.background = const ThemeBackground(),
  });

  final String id;
  final String name;
  final AppThemeId base;

  /// Only the tokens the user set; the others are derived in [resolve].
  final Map<CcToken, Color> overrides;
  final ThemeBackground background;

  CustomTheme copyWith({
    String? name,
    AppThemeId? base,
    Map<CcToken, Color>? overrides,
    ThemeBackground? background,
  }) => CustomTheme(
    id: id,
    name: name ?? this.name,
    base: base ?? this.base,
    overrides: overrides ?? this.overrides,
    background: background ?? this.background,
  );

  /// The same theme under another id (a copy, or an import).
  CustomTheme withId(String newId) => CustomTheme(
    id: newId,
    name: name,
    base: base,
    overrides: overrides,
    background: background,
  );

  /// What goes into a file for another device: a picture lives in this
  /// device's own folder, so it is left out.
  CustomTheme forExport() =>
      copyWith(background: background.copyWith(clearImage: true));

  @override
  bool operator ==(Object other) =>
      other is CustomTheme &&
      other.id == id &&
      other.name == name &&
      other.base == base &&
      mapEquals(other.overrides, overrides) &&
      other.background == background;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    base,
    Object.hashAllUnordered(
      overrides.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    background,
  );

  CustomTheme withColor(CcToken t, Color c) =>
      copyWith(overrides: {...overrides, t: _fit(t, c)});

  /// Back to the derived value for [t].
  CustomTheme withoutColor(CcToken t) =>
      copyWith(overrides: {...overrides}..remove(t));

  /// The colours this theme shows, every one of the twelve filled in.
  CcColors resolve() {
    final b = buildPalette(base, CcAccent.viola);
    Color? o(CcToken t) => overrides[t];
    final bgSet = overrides.containsKey(CcToken.bg);
    final textSet = overrides.containsKey(CcToken.text);
    final accentSet = overrides.containsKey(CcToken.accent);

    final bg = o(CcToken.bg) ?? b.bg;
    // Light when dark text reads better on the background than light text.
    final light = bgSet ? bg.computeLuminance() > 0.18 : b.isLight;
    final text = o(CcToken.text) ?? (bgSet ? _textFor(bg, light) : b.text);

    // Surfaces step away from the background towards the text colour.
    Color surface(CcToken t, Color baseValue, double step) =>
        o(t) ??
        (bgSet ? Color.lerp(bg, text, light ? step * 0.85 : step)! : baseValue);

    final muted = bgSet || textSet;
    final accent = o(CcToken.accent) ?? b.accent;
    return CcColors(
      bg: bg,
      surface1: surface(CcToken.surface1, b.surface1, 0.05),
      surface2: surface(CcToken.surface2, b.surface2, 0.10),
      surface3: surface(CcToken.surface3, b.surface3, 0.17),
      accent: accent,
      accentSoft:
          o(CcToken.accentSoft) ??
          (accentSet || bgSet ? accentSoftFor(accent, light) : b.accentSoft),
      onAccent:
          o(CcToken.onAccent) ?? (accentSet ? onAccentFor(accent) : b.onAccent),
      text: text,
      textMuted:
          o(CcToken.textMuted) ??
          (muted ? Color.lerp(text, bg, 0.35)! : b.textMuted),
      textFaint:
          o(CcToken.textFaint) ??
          (muted ? Color.lerp(text, bg, 0.6)! : b.textFaint),
      heroBase:
          o(CcToken.heroBase) ??
          (accentSet || bgSet ? heroFor(accent, light) : b.heroBase),
      error: o(CcToken.error) ?? b.error,
      isLight: light,
    );
  }

  /// Near-white or near-black, tinted a little with the background's hue.
  static Color _textFor(Color bg, bool light) {
    final hsl = HSLColor.fromColor(bg);
    return hsl
        .withSaturation((hsl.saturation * 0.3).clamp(0.0, 0.2))
        .withLightness(light ? 0.09 : 0.95)
        .toColor();
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'id': id,
    'name': name,
    'base': base.name,
    'colors': {
      for (final e in overrides.entries) e.key.name: e.value.toARGB32(),
    },
    'background': background.toJson(),
  };

  /// Null when [j] is not a theme (no id). Unknown tokens and colours that are
  /// not integers are dropped; a missing name becomes «Tema».
  static CustomTheme? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    if (id is! String || id.isEmpty) return null;
    final colors = <CcToken, Color>{};
    final raw = j['colors'];
    if (raw is Map) {
      for (final t in CcToken.values) {
        final v = raw[t.name];
        if (v is int) colors[t] = _fit(t, Color(v));
      }
    }
    final name = j['name'];
    return CustomTheme(
      id: id,
      name: name is String && name.trim().isNotEmpty ? name.trim() : 'Tema',
      base: appThemeIdFromName('${j['base']}'),
      overrides: colors,
      background: ThemeBackground.fromJson(j['background']),
    );
  }

  /// One theme as a file for «Esporta tema».
  String encode() => jsonEncode(toJson());

  static CustomTheme? decode(String raw) {
    try {
      return fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }
}

/// How many themes the user can keep.
const kMaxCustomThemes = 20;

/// The user's themes, in the order they made them. Immutable.
@immutable
class CustomThemes {
  const CustomThemes([this.items = const []]);

  final List<CustomTheme> items;

  CustomTheme? byId(String id) {
    for (final t in items) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Adds [t], or replaces the one with the same id. Over [kMaxCustomThemes]
  /// a new one is refused (the list comes back unchanged).
  CustomThemes put(CustomTheme t) {
    final i = items.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      return CustomThemes([...items]..[i] = t);
    }
    if (items.length >= kMaxCustomThemes) return this;
    return CustomThemes([...items, t]);
  }

  CustomThemes remove(String id) => CustomThemes([
    for (final t in items)
      if (t.id != id) t,
  ]);

  String encode() => jsonEncode([for (final t in items) t.toJson()]);

  /// A damaged list gives an empty one; damaged entries are skipped.
  static CustomThemes decode(String? raw) {
    if (raw == null || raw.isEmpty) return const CustomThemes();
    try {
      final j = jsonDecode(raw);
      if (j is! List) return const CustomThemes();
      final seen = <String>{};
      final out = <CustomTheme>[];
      for (final e in j) {
        final t = CustomTheme.fromJson(e);
        if (t != null && seen.add(t.id) && out.length < kMaxCustomThemes) {
          out.add(t);
        }
      }
      return CustomThemes(out);
    } on FormatException {
      return const CustomThemes();
    }
  }
}

/// `theme` setting value of the custom theme [id].
String customThemeSettingValue(String id) => 'custom:$id';

/// The id in a `theme` setting like `custom:abc`, or null for a built-in one.
String? customThemeIdOf(String setting) =>
    setting.startsWith('custom:') ? setting.substring(7) : null;

/// [fg] moved lighter or darker (keeping its hue) until it reads against [bg]
/// with at least [min] contrast; [fg] itself when it already does. Gives the
/// best of black and white if nothing in between is enough.
Color ensureContrast(Color fg, Color bg, {double min = 4.5}) {
  if (contrastRatio(fg, bg) >= min) return fg;
  final hsl = HSLColor.fromColor(fg);
  final lighter = bg.computeLuminance() < 0.18;
  var l = hsl.lightness;
  for (var i = 0; i < 100; i++) {
    l = (l + (lighter ? 0.01 : -0.01)).clamp(0.0, 1.0);
    final c = hsl.withLightness(l).toColor();
    if (contrastRatio(c, bg) >= min) return c;
    if (l == 0 || l == 1) break;
  }
  return contrastRatio(const Color(0xFFFFFFFF), bg) >=
          contrastRatio(const Color(0xFF000000), bg)
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF000000);
}

/// True when any pair of the editor's contrast list (text, muted text, on-accent,
/// accent) is under its minimum. Only a warning: colours are never changed (D-07, D-13).
bool hasLowContrastText(CcColors c) =>
    contrastRatio(c.text, c.bg) < 4.5 ||
    contrastRatio(c.textMuted, Color.alphaBlend(c.surface1, c.bg)) < 4.5 ||
    contrastRatio(c.onAccent, c.accent) < 4.5 ||
    contrastRatio(c.accent, c.bg) < 3;
