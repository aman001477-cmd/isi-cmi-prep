import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_design_system.dart';
import 'theme_palettes.dart';

/// Holds the active theme id, applies the palette to [AppColors] and
/// persists the choice so it survives reloads.
class ThemeNotifier extends StateNotifier<String> {
  ThemeNotifier() : super('indigo') {
    AppColors.apply(themeOptionFor('indigo')!.palette);
    _restore();
  }

  static const _themeKey = 'themeId';
  static const _lightKey = 'lightThemeId';

  /// Bumped on every palette application. main.dart keys the whole
  /// MaterialApp with it, forcing a full remount whenever the palette
  /// changes — so no widget (const or not) can keep stale light-theme
  /// colours after switching to Midnight.
  static int epoch = 0;

  /// Last light theme id, so the dark toggle can always bounce back
  /// to the user's favourite light theme instead of a hardcoded one.
  String _lastLightId = 'indigo';

  bool get isDark {
    final option = themeOptionFor(state);
    return option != null &&
        option.palette.canvas.computeLuminance() < 0.5;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _lastLightId = prefs.getString(_lightKey) ?? 'indigo';
    final saved = prefs.getString(_themeKey);
    if (saved != null && saved != state) {
      select(saved);
    }
  }

  void select(String id) {
    final option = themeOptionFor(id);
    if (option == null) return;
    if (option.palette.canvas.computeLuminance() >= 0.5) {
      _lastLightId = id;
    }
    AppColors.apply(option.palette);
    epoch++;
    state = id;
    final prefs = SharedPreferences.getInstance();
    prefs.then((p) async {
      await p.setString(_themeKey, id);
      await p.setString(_lightKey, _lastLightId);
    });
  }

  /// One-tap light ↔ dark switch (Midnight / last light theme).
  void toggleDark() => select(isDark ? _lastLightId : 'midnight');
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, String>((ref) => ThemeNotifier());
