import 'package:flutter/material.dart';

/// Accent presets, Chumpy-style: every preset is a hue seed for the stock
/// Material 3 tonal palettes. `adaptive` follows the OS (dynamic_color),
/// `mono` desaturates everything.
abstract final class WayAccents {
  static const presets = <String, double>{
    'green': 145,
    'sky': 211,
    'blue': 217,
    'indigo': 248,
    'violet': 285,
    'red': 4,
    'orange': 30,
    'yellow': 52,
  };

  static const order = [
    'adaptive',
    'wall1',
    'wall2',
    'wall3',
    'green',
    'sky',
    'blue',
    'indigo',
    'violet',
    'red',
    'orange',
    'yellow',
    'mono',
    'custom',
  ];

  static Color swatch(String id) {
    final hue = presets[id] ?? 145;
    return HSLColor.fromAHSL(1, hue, 0.62, 0.52).toColor();
  }

  static Color _seedFor(
    String accent,
    Brightness brightness, [
    Color? customColor,
  ]) {
    if (accent == 'mono') {
      return brightness == Brightness.light
          ? const Color(0xFF5B5B5B)
          : const Color(0xFFC4C4C4);
    }
    if ((accent == 'custom' || accent.startsWith('wall')) &&
        customColor != null) {
      return customColor;
    }
    final hue = presets[accent] ?? presets['green']!;
    return brightness == Brightness.light
        ? HSLColor.fromAHSL(1, hue, 0.62, 0.45).toColor()
        : HSLColor.fromAHSL(1, hue, 0.55, 0.72).toColor();
  }

  static ColorScheme schemeFor(
    String accent,
    Brightness brightness, [
    ColorScheme? dynamicScheme,
    Color? customColor,
  ]) {
    if (dynamicScheme != null && accent == 'adaptive') return dynamicScheme;
    return ColorScheme.fromSeed(
      seedColor: _seedFor(accent, brightness, customColor),
      brightness: brightness,
    );
  }

  static ColorScheme amolized(ColorScheme scheme) {
    const black = Color(0xFF000000);
    const lift = Color(0xFF0C0C0D);
    const lift2 = Color(0xFF141416);
    return scheme.copyWith(
      surface: black,
      surfaceDim: black,
      surfaceContainerLowest: black,
      surfaceContainerLow: lift,
      surfaceContainer: lift,
      surfaceContainerHigh: lift2,
      surfaceContainerHighest: lift2,
      onSurface: scheme.onSurface,
    );
  }
}

class WayTheme {
  WayTheme._();

  static ThemeData light([ColorScheme? scheme]) =>
      _build(scheme ?? WayAccents.schemeFor('green', Brightness.light));

  static ThemeData dark([ColorScheme? scheme, bool amoled = false]) => _build(
      _applyAmoled(
          scheme ?? WayAccents.schemeFor('green', Brightness.dark), amoled));

  static ColorScheme _applyAmoled(ColorScheme scheme, bool amoled) =>
      amoled ? WayAccents.amolized(scheme) : scheme;

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      }),
    );

    final t = base.textTheme;
    final text = t.copyWith(
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      titleLarge: t.titleLarge
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
      bodySmall: t.bodySmall?.copyWith(height: 1.4),
      labelLarge: t.labelLarge
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
    );

    const fieldRadius = BorderRadius.all(Radius.circular(16));
    final fieldShape = OutlineInputBorder(
      borderRadius: fieldRadius,
      borderSide: BorderSide.none,
    );
    final fieldShapeFocused = OutlineInputBorder(
      borderRadius: fieldRadius,
      borderSide: BorderSide(color: scheme.primary, width: 2),
    );

    final segStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      side: WidgetStatePropertyAll(
        BorderSide(color: scheme.outlineVariant),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.secondaryContainer
              : Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant),
      textStyle: WidgetStatePropertyAll(
        t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: t.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          t.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        iconColor: scheme.onSurfaceVariant,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: fieldShape,
        enabledBorder: fieldShape,
        focusedBorder: fieldShapeFocused,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24),
          ),
          textStyle: WidgetStatePropertyAll(
            t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24),
          ),
          textStyle: WidgetStatePropertyAll(
            t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: WidgetStatePropertyAll(
            t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: segStyle,
        selectedIcon: const Icon(Icons.check_rounded, size: 18),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLow,
        labelStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6.0),
        radius: const Radius.circular(999),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: t.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}
