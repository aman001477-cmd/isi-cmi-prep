import 'package:flutter/material.dart';

/// Futuristic, premium theme — years of R&D feel
/// Dark with neon accents, glassmorphism, smooth animations
class FuturisticTheme {
  FuturisticTheme._();

  // ============================================================
  // COLORS — Premium dark with electric accents
  // ============================================================
  static const Color bgDeep = Color(0xFF0A0A0F);
  static const Color bgSurface = Color(0xFF14141F);
  static const Color bgCard = Color(0xFF1C1C2E);
  static const Color bgElevated = Color(0xFF23233A);

  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonCyan = Color(0xFF06B6D4);
  static const Color neonPink = Color(0xFFEC4899);
  static const Color neonGreen = Color(0xFF10B981);
  static const Color neonOrange = Color(0xFFF59E0B);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);

  static const Color borderSubtle = Color(0x1AFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [neonPurple, neonCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1C1C2E), Color(0xFF23233A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [neonPink, neonOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glassmorphism
  static BoxDecoration get glassCard => BoxDecoration(
        color: bgCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: neonPurple.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 0),
          ),
        ],
      );

  static BoxDecoration get glassElevated => BoxDecoration(
        color: bgElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderStrong, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      );

  // Typography
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
    color: textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
    color: textSecondary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: textTertiary,
  );

  // ThemeData
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: neonPurple,
          secondary: neonCyan,
          tertiary: neonPink,
          surface: bgSurface,
          onSurface: textPrimary,
          error: Color(0xFFEF4444),
        ),
        textTheme: const TextTheme(
          displayLarge: displayLarge,
          headlineMedium: headlineMedium,
          titleLarge: titleLarge,
          bodyMedium: bodyMedium,
          labelMedium: labelMedium,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: headlineMedium,
        ),
        cardTheme: CardThemeData(
          color: bgCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: borderSubtle, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: neonPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: neonPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: neonPurple, width: 2),
          ),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textTertiary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}
