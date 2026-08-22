import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyPlanConfig {
  const DailyPlanConfig(
      {this.enabled = false, this.hour = 21, this.minute = 0});
  final bool enabled;
  final int hour;
  final int minute;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() =>
      {'enabled': enabled, 'hour': hour, 'minute': minute};

  static DailyPlanConfig fromJson(Map<String, Object?> j) => DailyPlanConfig(
        enabled: j['enabled'] as bool? ?? false,
        hour: j['hour'] as int? ?? 21,
        minute: j['minute'] as int? ?? 0,
      );
}

/// "Tomorrow's plan" nightly notification — persisted at `plan_notif_v1`
/// (legacy flat keys kept so old installs/tests stay compatible).
class DailyPlanNotifier extends StateNotifier<DailyPlanConfig> {
  DailyPlanNotifier() : super(const DailyPlanConfig()) {
    _load();
  }

  static const _prefsKey = 'daily_plan_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        state = DailyPlanConfig.fromJson(raw as Map<String, Object?>);
        return;
      }
      // legacy flat keys
      final enabled = prefs.getBool('plan_notif_v1');
      if (enabled != null) {
        state = DailyPlanConfig(enabled: enabled);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, '');
      await prefs.setString('daily_plan_v1', '');
      // legacy flat key mirrors the enabled flag
      await prefs.setBool('plan_notif_v1', state.enabled);
      await prefs.setInt('plan_notif_hour_v1', state.hour);
      await prefs.setInt('plan_notif_min_v1', state.minute);
    } catch (_) {}
  }

  void setEnabled(bool v) {
    state = DailyPlanConfig(enabled: v, hour: state.hour, minute: state.minute);
    _save();
  }

  void setTime(int h, int m) {
    state =
        DailyPlanConfig(enabled: state.enabled, hour: h % 24, minute: m % 60);
    _save();
  }
}

final dailyPlanProvider =
    StateNotifierProvider<DailyPlanNotifier, DailyPlanConfig>(
        (ref) => DailyPlanNotifier());
