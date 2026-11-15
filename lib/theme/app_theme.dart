import 'package:flutter/material.dart';

/// Semantic color tokens and Material 3 theme for Lunch Ledger.
class AppTheme {
  const AppTheme._();

  static const Color primary = Color(0xFF0A7052);
  static const Color primaryAccent = Color(0xFF1B956C);
  static const Color primarySoft = Color(0xFFE5F4EE);
  static const Color surfaceBg = Color(0xFFF7FAF3);
  static const Color cardBorder = Color(0xFFD6E3DC);
  static const Color ink = Color(0xFF233242);
  static const Color mutedInk = Color(0xFF5A6B7B);

  static const Color fullColor = primaryAccent;
  static const Color fullSoft = Color(0xFFE6F6F0);

  static const Color halfColor = Color(0xFF0E7490);
  static const Color halfSoft = Color(0xFFE6F6FA);

  static const Color skipColor = Color(0xFF475569);
  static const Color skipSoft = Color(0xFFF1F5F9);

  static const Color pendingColor = Color(0xFFB45309);
  static const Color pendingSoft = Color(0xFFFEF3C7);

  static const Color warningBg = Color(0xFFFFF7ED);
  static const Color warningBorder = Color(0xFFFDBA74);
  static const Color warningFg = Color(0xFF9A3412);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: primaryAccent,
      tertiary: ink,
      surface: surfaceBg,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceBg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: cardBorder),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          selectedBackgroundColor: primarySoft,
          selectedForegroundColor: primary,
          side: const BorderSide(color: cardBorder),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primarySoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : mutedInk,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : mutedInk,
          );
        }),
      ),
    );
  }
}

