import 'package:flutter/material.dart';

class WayTheme {
  WayTheme._();

  static const _seedLight = Color(0xFF2E7D53);
  static const _seedDark = Color(0xFF9BDDB4);

  static ThemeData light([ColorScheme? dynamicScheme]) =>
      _build(dynamicScheme ?? ColorScheme.fromSeed(seedColor: _seedLight));

  static ThemeData dark([ColorScheme? dynamicScheme]) => _build(
      dynamicScheme ??
          ColorScheme.fromSeed(seedColor: _seedDark, brightness: Brightness.dark));

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
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
      headlineSmall:
          t.headlineSmall?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.25),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    final fieldShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    final fieldShapeFocused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.primary, width: 2),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: t.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: fieldShape,
        enabledBorder: fieldShape,
        focusedBorder: fieldShapeFocused,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
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
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24),
          ),
          textStyle: WidgetStatePropertyAll(
            t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6.0),
        radius: const Radius.circular(999),
      ),
    );
  }
}
