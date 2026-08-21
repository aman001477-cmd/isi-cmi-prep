import 'package:flutter/material.dart';

/// One complete colour scheme. Every colour the app draws comes from
/// here, so swapping the palette restyles the entire UI.
class ThemePalette {
  const ThemePalette({
    required this.canvas,
    required this.surface,
    required this.surfaceFaint,
    required this.surfaceText,
    required this.surfaceDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.danger,
    required this.warning,
    required this.border,
    required this.divider,
    required this.shadowLight,
    required this.shadowDark,
    required this.shadowSoft,
    required this.successDeep,
    required this.warningDeep,
    required this.dangerDeep,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceFaint;
  final Color surfaceText;
  final Color surfaceDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color danger;
  final Color warning;
  final Color border;
  final Color divider;
  final Color shadowLight;
  final Color shadowDark;
  final Color shadowSoft;

  /// Deep status text colours — dark enough on light surfaces, light enough
  /// on dark surfaces (midnight), so status words never vanish.
  final Color successDeep;
  final Color warningDeep;
  final Color dangerDeep;
}

/// A selectable theme: an id (persisted), a label and its palette.
class ThemeOption {
  const ThemeOption({
    required this.id,
    required this.label,
    required this.palette,
    required this.swatch,
  });

  final String id;
  final String label;
  final ThemePalette palette;

  /// Accent colour used as the picker's dot.
  final Color swatch;
}

/// Built-in themes.
const List<ThemeOption> themeCatalog = [
  ThemeOption(
    id: 'indigo',
    label: 'Indigo',
    swatch: Color(0xFF8E94F2),
    palette: ThemePalette(
      canvas: Color(0xFFEBEFF3),
      surface: Color(0xFFFFFFFF),
      surfaceFaint: Color(0xFFF5F7FA),
      surfaceText: Color(0xFFF5F7FA),
      surfaceDark: Color(0xFF1A1D20),
      textPrimary: Color(0xFF1A1D20),
      textSecondary: Color(0xFF626971),
      accent: Color(0xFF8E94F2),
      accentSoft: Color(0xFFE3E5FB),
      success: Color(0xFFA2E3C4),
      danger: Color(0xFFF0A3A3),
      warning: Color(0xFFF2D8A2),
      border: Color(0xFFD6DDE4),
      divider: Color(0xFFEBEFF3),
      shadowLight: Color(0xFFFFFFFF),
      shadowDark: Color(0xFFC2C9D2),
      shadowSoft: Color(0x08000000),
      successDeep: Color(0xFF1F7A4D),
      warningDeep: Color(0xFF9A6B14),
      dangerDeep: Color(0xFFB42318),
    ),
  ),
  ThemeOption(
    id: 'ocean',
    label: 'Ocean',
    swatch: Color(0xFF3D8FD4),
    palette: ThemePalette(
      canvas: Color(0xFFEAF1F6),
      surface: Color(0xFFFFFFFF),
      surfaceFaint: Color(0xFFF3F7FA),
      surfaceText: Color(0xFFF3F7FA),
      surfaceDark: Color(0xFF14232E),
      textPrimary: Color(0xFF14232E),
      textSecondary: Color(0xFF5C6F7E),
      accent: Color(0xFF3D8FD4),
      accentSoft: Color(0xFFD9EAF7),
      success: Color(0xFF8FD9B6),
      danger: Color(0xFFEF9E9E),
      warning: Color(0xFFF4D98A),
      border: Color(0xFFC9D8E2),
      divider: Color(0xFFE0EAF1),
      shadowLight: Color(0xFFF5FAFD),
      shadowDark: Color(0xFFB4C3CE),
      shadowSoft: Color(0x08000000),
      successDeep: Color(0xFF1D6B49),
      warningDeep: Color(0xFF8F6510),
      dangerDeep: Color(0xFFB02A2A),
    ),
  ),
  ThemeOption(
    id: 'forest',
    label: 'Forest',
    swatch: Color(0xFF4C9E5F),
    palette: ThemePalette(
      canvas: Color(0xFFEDF3EA),
      surface: Color(0xFFFFFFFF),
      surfaceFaint: Color(0xFFF5F8F3),
      surfaceText: Color(0xFFF5F8F3),
      surfaceDark: Color(0xFF1C2A1F),
      textPrimary: Color(0xFF1C2A1F),
      textSecondary: Color(0xFF5F7063),
      accent: Color(0xFF4C9E5F),
      accentSoft: Color(0xFFDCEAD9),
      success: Color(0xFF8FCE9F),
      danger: Color(0xFFE8A0A0),
      warning: Color(0xFFEBD48C),
      border: Color(0xFFCBD9C6),
      divider: Color(0xFFE1EBDE),
      shadowLight: Color(0xFFF6FAF3),
      shadowDark: Color(0xFFB9C6B4),
      shadowSoft: Color(0x08000000),
      successDeep: Color(0xFF206B36),
      warningDeep: Color(0xFF8C6710),
      dangerDeep: Color(0xFFAD2D2D),
    ),
  ),
  ThemeOption(
    id: 'sunset',
    label: 'Sunset',
    swatch: Color(0xFFE8864C),
    palette: ThemePalette(
      canvas: Color(0xFFF6EFE7),
      surface: Color(0xFFFFFDFB),
      surfaceFaint: Color(0xFFFBF4EC),
      surfaceText: Color(0xFFFBF4EC),
      surfaceDark: Color(0xFF2E2318),
      textPrimary: Color(0xFF2E2318),
      textSecondary: Color(0xFF7A6A58),
      accent: Color(0xFFE8864C),
      accentSoft: Color(0xFFFBE6D3),
      success: Color(0xFF9FD6A8),
      danger: Color(0xFFE89A8F),
      warning: Color(0xFFF0CE7E),
      border: Color(0xFFE2D4C4),
      divider: Color(0xFFEFE5D9),
      shadowLight: Color(0xFFFFF3E6),
      shadowDark: Color(0xFFCBBBA7),
      shadowSoft: Color(0x08000000),
      successDeep: Color(0xFF2E6B3F),
      warningDeep: Color(0xFF94660D),
      dangerDeep: Color(0xFFB23B2B),
    ),
  ),
  ThemeOption(
    id: 'rose',
    label: 'Rose',
    swatch: Color(0xFFD66C9E),
    palette: ThemePalette(
      canvas: Color(0xFFF4EDF1),
      surface: Color(0xFFFFFFFF),
      surfaceFaint: Color(0xFFFBF6F8),
      surfaceText: Color(0xFFFBF6F8),
      surfaceDark: Color(0xFF2B1F26),
      textPrimary: Color(0xFF2B1F26),
      textSecondary: Color(0xFF77606B),
      accent: Color(0xFFD66C9E),
      accentSoft: Color(0xFFF7DFEB),
      success: Color(0xFF9CD6B4),
      danger: Color(0xFFE89AA6),
      warning: Color(0xFFEFD084),
      border: Color(0xFFE2CFDA),
      divider: Color(0xFFEFE1E9),
      shadowLight: Color(0xFFFFF2F8),
      shadowDark: Color(0xFFC9B5C1),
      shadowSoft: Color(0x08000000),
      successDeep: Color(0xFF2E6B4C),
      warningDeep: Color(0xFF8C6412),
      dangerDeep: Color(0xFFB02F50),
    ),
  ),
  ThemeOption(
    id: 'midnight',
    label: 'Midnight',
    swatch: Color(0xFF8A9CF2),
    palette: ThemePalette(
      canvas: Color(0xFF14171C),
      surface: Color(0xFF1D2129),
      surfaceFaint: Color(0xFF252A33),
      surfaceText: Color(0xFFFFFFFF),
      surfaceDark: Color(0xFF262B33),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFFFFFFF),
      accent: Color(0xFF8A9CF2),
      accentSoft: Color(0xFF2A2F45),
      success: Color(0xFF7CC9A0),
      danger: Color(0xFFE08A8A),
      warning: Color(0xFFE2C07E),
      border: Color(0xFF39404A),
      divider: Color(0xFF2A2F37),
      shadowLight: Color(0xFF232831),
      shadowDark: Color(0xFF0C0E12),
      shadowSoft: Color(0x14000000),
      successDeep: Color(0xFF7CC9A0),
      warningDeep: Color(0xFFE2C07E),
      dangerDeep: Color(0xFFE08A8A),
    ),
  ),
];

ThemeOption? themeOptionFor(String id) {
  for (final option in themeCatalog) {
    if (option.id == id) return option;
  }
  return null;
}
