import 'package:flutter/material.dart';

class EcoColors {
  static const forest = Color(0xFF103F35);
  static const green = Color(0xFF1A8460);
  static const mint = Color(0xFFD9EFDD);
  static const lime = Color(0xFFD6F18B);
  static const pale = Color(0xFFF4F7F3);
  static const text = Color(0xFF203B32);
  static const muted = Color(0xFF71827B);
  static const line = Color(0xFFE0E9E3);
  static const orange = Color(0xFFDC8D44);
}

ThemeData ecoTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: EcoColors.green, brightness: Brightness.light,
    surface: Colors.white,
  );
  return ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    scaffoldBackgroundColor: EcoColors.pale,
    appBarTheme: const AppBarTheme(
      backgroundColor: EcoColors.pale, foregroundColor: EcoColors.forest,
      scrolledUnderElevation: 0, centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: EcoColors.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: EcoColors.green, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        side: const BorderSide(color: EcoColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: EcoColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: EcoColors.line)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white, indicatorColor: EcoColors.mint,
      height: 74,
    ),
    dividerColor: EcoColors.line,
  );
}
