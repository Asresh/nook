import 'package:flutter/material.dart';

abstract final class NookColors {
  static const background = Color(0xFF09090F);
  static const surface = Color(0xFF15151F);
  static const surfaceHigh = Color(0xFF1F1F2E);
  static const accent = Color(0xFFB9A6FF);
  static const accentSoft = Color(0xFF2A2440);
  static const text = Color(0xFFF2F0FF);
  static const muted = Color(0xFF9C98B4);
  static const live = Color(0xFF7BE3B0);
  static const danger = Color(0xFFFF7A8B);
  static const onAccent = Color(0xFF161022);
}

ThemeData buildNookTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: NookColors.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: NookColors.accent,
        onPrimary: NookColors.onAccent,
        surface: NookColors.surface,
        onSurface: NookColors.text,
        secondary: NookColors.live,
      );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: NookColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: NookColors.text,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: NookColors.text,
      displayColor: NookColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NookColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: NookColors.accent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: NookColors.muted),
      labelStyle: const TextStyle(color: NookColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NookColors.accent,
        foregroundColor: NookColors.onAccent,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: NookColors.surfaceHigh,
      contentTextStyle: TextStyle(color: NookColors.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NookColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: NookColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
