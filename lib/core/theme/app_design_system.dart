import 'package:flutter/material.dart';

import 'theme_palettes.dart';

/// ---------------------------------------------------------------------------
/// ISI CMI Prep — Global Visual System (Design Tokens)
/// Flat-first with neumorphic shadows ONLY on interactive controls.
/// Colours are mutable: [AppColors.apply] swaps the whole palette so a
/// theme change restyles the entire UI on the next rebuild.
/// ---------------------------------------------------------------------------

abstract final class AppColors {
  // Base canvas
  static Color canvas = Color(0xFFEBEFF3);

  // Surfaces & lines
  static Color surface = Color(0xFFFFFFFF);
  static Color surfaceFaint = Color(0xFFF5F7FA);
  static Color surfaceText = Color(0xFFF5F7FA);

  /// Always-dark block background (high-contrast card, full-screen
  /// timer) — stays dark in every theme, text on it is white.
  static Color surfaceDark = Color(0xFF1A1D20);

  // Text
  static Color textPrimary = Color(0xFF1A1D20);
  static Color textSecondary = Color(0xFF626971);

  // Accent / brand
  static Color accent = Color(0xFF8E94F2);
  static Color accentSoft = Color(0xFFE3E5FB);

  // Status
  static Color success = Color(0xFFA2E3C4);
  static Color danger = Color(0xFFF0A3A3);
  static Color warning = Color(0xFFF2D8A2);

  /// Deep status text — readable on both light and dark surfaces.
  static Color successDeep = Color(0xFF1F7A4D);
  static Color warningDeep = Color(0xFF9A6B14);
  static Color dangerDeep = Color(0xFFB42318);

  // Lines
  static Color border = Color(0xFFD6DDE4);
  static Color divider = Color(0xFFEBEFF3);

  // Neumorphic shadow pair
  static Color shadowLight = Color(0xFFFFFFFF);
  static Color shadowDark = Color(0xFFC2C9D2);
  static Color shadowSoft = Color(0x08000000); // rgba(0,0,0,0.03)

  /// Swaps every token to [palette]. Call before rebuilding the tree.
  static void apply(ThemePalette p) {
    canvas = p.canvas;
    surface = p.surface;
    surfaceFaint = p.surfaceFaint;
    surfaceText = p.surfaceText;
    surfaceDark = p.surfaceDark;
    textPrimary = p.textPrimary;
    textSecondary = p.textSecondary;
    accent = p.accent;
    accentSoft = p.accentSoft;
    success = p.success;
    danger = p.danger;
    warning = p.warning;
    successDeep = p.successDeep;
    warningDeep = p.warningDeep;
    dangerDeep = p.dangerDeep;
    border = p.border;
    divider = p.divider;
    shadowLight = p.shadowLight;
    shadowDark = p.shadowDark;
    shadowSoft = p.shadowSoft;
  }
}

abstract final class AppRadius {
  static const double large = 16;
  static const double standard = 12;
  static const double pill = 999;
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double gutter = 24;
}

abstract final class AppTypography {
  // Getters (not final statics!) so the palette swap on theme change
  // reaches every text: a static final would freeze the first theme's
  // colours and leave all text dark after switching to Midnight.
  static TextStyle get titleLarge => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
      );
  static TextStyle get titleMedium => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.25,
      );
  static TextStyle get body => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.45,
      );
  static TextStyle get bodyMedium => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );
  static TextStyle get small => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );
  static TextStyle get caption => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      );
  static TextStyle get label => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
}

abstract final class AppShadows {
  // Getters — see AppTypography: shadow colours follow the active palette.
  /// Raised (extruded) neumorphic shadow — interactive controls.
  /// Softened (tight blur, subtle offset) so the highlight reads as a
  /// chamfered edge, not a glowing halo.
  static List<BoxShadow> get raised => [
        BoxShadow(
          offset: Offset(-5, -5),
          blurRadius: 10,
          color: AppColors.shadowLight,
        ),
        BoxShadow(
          offset: Offset(5, 5),
          blurRadius: 10,
          color: AppColors.shadowDark,
        ),
      ];

  /// Crisp faint shadow — data display blocks only.
  static List<BoxShadow> get flatCard => [
        BoxShadow(
          offset: Offset(0, 2),
          blurRadius: 4,
          color: AppColors.shadowSoft,
        ),
      ];
}
