import 'package:flutter_riverpod/flutter_riverpod.dart';

class DailyPlanConfig {
  const DailyPlanConfig({this.enabled = false, this.hour = 21, this.minute = 0});
  final bool enabled;
  final int hour;
  final int minute;
  String get timeLabel => '${hour.toString().padLeft(2,'0')}:${minute.toString().padLeft(2,'0')}';
}

class DailyPlanNotifier extends StateNotifier<DailyPlanConfig> {
  DailyPlanNotifier() : super(const DailyPlanConfig());
  void setEnabled(bool v) => state = DailyPlanConfig(enabled: v, hour: state.hour, minute: state.minute);
  void setTime(int h, int m) => state = DailyPlanConfig(enabled: state.enabled, hour: h, minute: m);
}

final dailyPlanProvider = StateNotifierProvider<DailyPlanNotifier, DailyPlanConfig>((ref) => DailyPlanNotifier());
