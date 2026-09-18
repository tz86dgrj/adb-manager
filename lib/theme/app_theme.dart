import 'package:flutter/material.dart';

class AppTheme {
  // Surfaces & Backgrounds (Pure Light Mode)
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);    // Pure White
  static const Color surfaceMuted = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceSubtle = Color(0xFFE2E8F0); // Slate 200

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);      // Slate 200
  static const Color borderSubtle = Color(0xFFCBD5E1); // Slate 300

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8);     // Slate 400

  // Brand & Accent Colors
  static const Color primary = Color(0xFF2563EB);       // Blue 600
  static const Color primaryHover = Color(0xFF1D4ED8);  // Blue 700
  static const Color primarySubtle = Color(0xFFEFF6FF); // Blue 50

  // Status & Action Colors
  static const Color success = Color(0xFF16A34A);       // Green 600
  static const Color successSubtle = Color(0xFFF0FDF4); // Green 50
  static const Color warning = Color(0xFFD97706);       // Amber 600
  static const Color warningSubtle = Color(0xFFFFFBEB); // Amber 50
  static const Color error = Color(0xFFDC2626);         // Red 600
  static const Color errorSubtle = Color(0xFFFEF2F2);   // Red 50

  // Console Specific (Light Monokai-esque / GitHub Light)
  static const Color consoleBackground = Color(0xFFF8FAFC);
  static const Color consoleBorder = Color(0xFFE2E8F0);
  static const Color consoleText = Color(0xFF1E293B);
  static const Color consoleSuccess = Color(0xFF15803D);
  static const Color consoleWarning = Color(0xFFB45309);
  static const Color consoleError = Color(0xFFB91C1C);
  static const Color consoleSystem = Color(0xFF1D4ED8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: textPrimary,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
