import 'package:flutter/material.dart';

abstract final class DayColors {
  static const blue = Color(0xFF2864DC);
  static const background = Color(0xFFF5F7FB);
  static const text = Color(0xFF18243A);
  static const muted = Color(0xFF5F7088);
  static const line = Color(0xFFE5EAF2);
  static const softBlue = Color(0xFFEAF1FF);
  static const darkBackground = Color(0xFF101827);
  static const darkSurface = Color(0xFF1B2638);
  static const darkLine = Color(0xFF344158);
  static const rose = Color(0xFFBC486F);
  static const green = Color(0xFF177B66);
  static const ink = Color(0xFF253449);
  static Color widgetColor(String theme) => switch (theme) {
    'rose' => rose,
    'green' => green,
    'ink' => ink,
    _ => blue,
  };
  static Color fromHex(String hex) =>
      Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
}

ThemeData dayTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final generatedScheme = ColorScheme.fromSeed(
    seedColor: DayColors.blue,
    brightness: brightness,
  );
  final scheme = dark
      ? generatedScheme.copyWith(
          primary: const Color(0xFFAAC6FF),
          surface: DayColors.darkSurface,
          onSurface: const Color(0xFFE7EDF7),
          onSurfaceVariant: const Color(0xFFA8B6CB),
          outlineVariant: DayColors.darkLine,
        )
      : generatedScheme.copyWith(
          primary: DayColors.blue,
          onPrimary: Colors.white,
          primaryContainer: DayColors.softBlue,
          onPrimaryContainer: DayColors.blue,
          secondaryContainer: DayColors.softBlue,
          onSecondaryContainer: DayColors.blue,
          surface: Colors.white,
          surfaceContainerHighest: DayColors.background,
          onSurface: DayColors.text,
          onSurfaceVariant: DayColors.muted,
          outline: const Color(0xFF8C9AB0),
          outlineVariant: DayColors.line,
        );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'sans-serif'],
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? DayColors.darkBackground
        : DayColors.background,
    textTheme: base.textTheme.apply(
      bodyColor: dark ? const Color(0xFFE7EDF7) : DayColors.text,
      displayColor: dark ? const Color(0xFFE7EDF7) : DayColors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? DayColors.darkBackground : DayColors.background,
      foregroundColor: dark ? const Color(0xFFE7EDF7) : DayColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 72,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    buttonTheme: base.buttonTheme.copyWith(alignedDropdown: true),
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      height: 74,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.primary,
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: DayColors.blue,
      foregroundColor: Colors.white,
      elevation: 3,
      hoverElevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      subtitleTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 13,
        height: 1.6,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.dragged)
            ? DayColors.blue
            : DayColors.muted.withValues(alpha: .45),
      ),
      trackColor: WidgetStatePropertyAll(
        dark ? const Color(0xFF1B2638) : DayColors.line,
      ),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
