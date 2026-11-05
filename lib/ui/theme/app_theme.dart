import 'package:flutter/material.dart';
import '../../core/platform.dart';

import 'custom_theme.dart';
import 'palette.dart';
import 'tokens.dart';

export 'custom_theme.dart';
export 'theme_background.dart';
export 'palette.dart';

/// The same page transition on every platform (D-382): the new screen fades in
/// at full size (ease-in), no slide; none at all with «Riduci animazioni».
class CcPageTransitionsBuilder extends PageTransitionsBuilder {
  const CcPageTransitionsBuilder();

  @override
  Duration get transitionDuration => CcMotion.page;

  @override
  Duration get reverseTransitionDuration => CcMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: CurveTween(curve: Curves.easeIn).animate(animation),
      child: child,
    );
  }
}

/// The theme the `theme` setting names: a built-in one with its accent, or one
/// of the user's own (`custom:<id>`); one that no longer exists is Notte.
CcColors resolveColors(String theme, String accent, CustomThemes customs) {
  final id = customThemeIdOf(theme);
  final custom = id == null ? null : customs.byId(id);
  return custom?.resolve() ??
      buildPalette(appThemeIdFromName(theme), accentFromName(accent));
}

/// Text size is applied app-wide through MediaQuery's text scaler (see app.dart):
/// scaling the TextTheme directly asserts on styles without a font size.
///
/// [pageBackdrop]: pages and the app bar are see-through, so the gradient or
/// picture behind them shows (see `AppBackground`).
/// Icon buttons stay dense with a desktop mouse; a phone keeps the 48 dp default.
VisualDensity? get ccIconDensity => isDesktop ? VisualDensity.compact : null;

ThemeData buildThemeFromColors(CcColors c, bool compact, {bool pageBackdrop = false}) {
  final brightness = c.isLight ? Brightness.light : Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: c.surface3,
    onPrimaryContainer: c.accentSoft,
    secondary: c.accentSoft,
    onSecondary: c.onAccent,
    secondaryContainer: c.surface2,
    onSecondaryContainer: c.text,
    tertiary: c.accentSoft,
    onTertiary: c.onAccent,
    error: c.error,
    onError: c.bg,
    surface: c.bg,
    onSurface: c.text,
    onSurfaceVariant: c.textMuted,
    surfaceContainerLowest: c.bg,
    surfaceContainerLow: c.surface1,
    surfaceContainer: c.surface1,
    surfaceContainerHigh: c.surface2,
    surfaceContainerHighest: c.surface3,
    outline: c.textFaint,
    outlineVariant: c.surface3,
    inverseSurface: c.text,
    onInverseSurface: c.bg,
    inversePrimary: c.heroBase,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );
  final text = buildTextTheme(c);
  // A visible ring on the keyboard-focused main buttons (F-74).
  final focusRing = WidgetStateProperty.resolveWith<BorderSide?>(
    (s) => s.contains(WidgetState.focused)
        ? BorderSide(color: c.accent, width: 2)
        : null,
  );
  const pill = StadiumBorder();
  RoundedRectangleBorder top(double r) => RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(r)),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Figtree',
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: pageBackdrop ? Colors.transparent : c.bg,
    canvasColor: c.bg,
    dividerColor: c.surface3,
    focusColor: c.accent.withValues(alpha: 0.4),
    hoverColor: c.surface2.withValues(alpha: 0.5),
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values)
          p: const CcPageTransitionsBuilder(),
      },
    ),
    // Dense targets only for a desktop mouse; a phone keeps 48 dp (D-15).
    visualDensity: compact && isDesktop ? VisualDensity.compact : VisualDensity.standard,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: pageBackdrop ? Colors.transparent : c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface2,
      contentTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      actionTextColor: c.accentSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CcDims.rGrid),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface1,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surface1,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      dragHandleColor: c.surface3,
      shape: top(CcDims.rSheet),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CcDims.rSheet),
      ),
      titleTextStyle: text.titleMedium,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.text),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 480),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: CcDims.gap16, vertical: CcDims.gap12),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(999)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(999)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      hintStyle: text.bodyLarge?.copyWith(
        color: c.textMuted,
        fontWeight: FontWeight.w400,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: ButtonStyle(side: focusRing)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        textStyle: text.labelLarge,
      ).copyWith(side: focusRing),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: pill, textStyle: text.labelLarge),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        side: BorderSide(color: c.surface3),
        foregroundColor: c.text,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        foregroundColor: c.accentSoft,
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: BorderSide.none,
      backgroundColor: c.surface2,
      selectedColor: c.text,
      disabledColor: c.surface1,
      // Selected chips are filled with c.text, so the label flips to c.bg.
      labelStyle: text.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.bg : c.text,
        ),
      ),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: c.bg),
      checkmarkColor: c.bg,
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.text : c.surface2,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.bg : c.text,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: c.text,
      inactiveTrackColor: c.text.withValues(alpha: 0.24),
      thumbColor: c.text,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      overlayColor: c.text.withValues(alpha: 0.12),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: CcDims.gap16),
      iconColor: c.textMuted,
      textColor: c.text,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CcDims.rGrid),
      ),
      textStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.surface3,
      circularTrackColor: c.surface3,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : c.surface3,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onAccent : c.textMuted,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.textMuted.withValues(alpha: 0.4)),
      radius: const Radius.circular(999),
    ),
    iconTheme: IconThemeData(color: c.text),
    dividerTheme: DividerThemeData(color: c.surface3, space: 1, thickness: 1),
  );
}

/// Row height for track lists (fixed so lists can use `itemExtent`).
double trackRowExtent(bool compact) => compact ? 52 : 64;

/// Same, grown with the user's text size so two-line rows never overflow.
double trackRowExtentOf(BuildContext context, bool compact) {
  final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
  return trackRowExtent(compact) * (scale > 1 ? scale : 1);
}

/// Look of a row while it is being dragged to a new position: a soft
/// amethyst background and a little elevation, so it is clear it moves.
Widget ccDragProxy(BuildContext context, Widget child, Animation<double> anim) {
  final cc = context.cc;
  return AnimatedBuilder(
    animation: anim,
    builder: (_, _) {
      final t = CcMotion.curveIn.transform(anim.value);
      return Material(
        elevation: 6 * t,
        color: Color.lerp(cc.surface1, cc.accent.withValues(alpha: 0.28), t),
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(CcDims.rGrid),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    },
  );
}
