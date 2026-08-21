import 'package:flutter/material.dart';

import 'app_design_system.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: ColorScheme.light(
          primary: AppColors.accent,
          onPrimary: AppColors.surfaceDark,
          secondary: AppColors.accent,
          surface: AppColors.canvas,
          onSurface: AppColors.textPrimary,
          error: AppColors.danger,
        ),
        textTheme: TextTheme(
          titleLarge: AppTypography.titleLarge,
          titleMedium: AppTypography.titleMedium,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.small,
          labelMedium: AppTypography.label,
        ),
        dividerColor: AppColors.divider,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      );

  /// Dark mode is deliberately minimal — patterns/results stay identical.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          onPrimary: Colors.white,
          surface: AppColors.canvas,
          onSurface: AppColors.textPrimary,
          error: AppColors.danger,
        ),
        textTheme: TextTheme(
          titleLarge: AppTypography.titleLarge,
          titleMedium: AppTypography.titleMedium,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.small,
          labelMedium: AppTypography.label,
        ),
        dividerColor: AppColors.divider,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      );
}