import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Day key "yyyy-mm-dd" used to mark a date as a mock test day.
String mockDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Optional alarm attached to a mock-test day (a reminder fires at the
/// picked time; [reminderId] links the created reminder for removal).
/// [notifyOnly] alarms notify without sound.
class MockAlarm {
  const MockAlarm({
    required this.hour,
    required this.minute,
    this.reminderId,
    this.notifyOnly = false,
  });

  final int hour;
  final int minute;
  final String? reminderId;
  final bool notifyOnly;

  DateTime atOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  MockAlarm copyWith({
    int? hour,
    int? minute,
    String? reminderId,
    bool? notifyOnly,
  }) =>
      MockAlarm(
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        reminderId: reminderId ?? this.reminderId,
        notifyOnly: notifyOnly ?? this.notifyOnly,
      );

  factory MockAlarm.fromJson(Map<String, Object?> json) => MockAlarm(
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        reminderId: json['reminderId'] as String?,
        notifyOnly: json['notifyOnly'] as bool? ?? false,
      );

  Map<String, Object?> toJson() => {
        'hour': hour,
        'minute': minute,
        'reminderId': reminderId,
        'notifyOnly': notifyOnly,
      };
}

/// Marks which days hold mock tests. Kept separately from tasks so a
/// day can be flagged without adding a to-do; the calendar highlights
/// marked days with an "M" badge. Days can also carry an alarm time
/// (optionally linked to a reminder so it rings).
class MockTestNotifier extends StateNotifier<Set<String>> {
  MockTestNotifier() : super({}) {
    _load();
  }

  static const _prefsKey = 'mock_days_v1';
  static const _alarmsPrefsKey = 'mock_alarms_v1';

  Map<String, MockAlarm> _alarms = {};

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey);
      if (raw != null) state = raw.toSet();
      final rawAlarms = prefs.getString(_alarmsPrefsKey);
      if (rawAlarms != null && rawAlarms.isNotEmpty) {
        _alarms = (jsonDecode(rawAlarms) as Map<String, Object?>)
            .map((k, v) => MapEntry(
                k, MockAlarm.fromJson(v as Map<String, Object?>)));
      }
    } catch (_) {
      // keep empty — storage can be unavailable in privacy/incognito modes
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, state.toList());
      await prefs.setString(
        _alarmsPrefsKey,
        jsonEncode(_alarms.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (_) {
      // ignore — state is already committed in memory
    }
  }

  bool has(DateTime d) => state.contains(mockDayKey(d));

  /// Alarm (if any) set for [d].
  MockAlarm? alarmFor(DateTime d) => _alarms[mockDayKey(d)];

  bool hasAlarm(DateTime d) => _alarms.containsKey(mockDayKey(d));

  /// How many mock test days fall inside [month] (used in the header).
  int countInMonth(DateTime month) {
    final prefix =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}-';
    return state.where((k) => k.startsWith(prefix)).length;
  }

  Future<void> toggle(DateTime d) async {
    final key = mockDayKey(d);
    if (state.contains(key)) {
      state = {...state}..remove(key);
    } else {
      state = {...state, key};
    }
    await _save();
  }

  /// Attaches an alarm to an already-marked day.
  Future<void> setAlarm(DateTime d, MockAlarm alarm) async {
    _alarms[mockDayKey(d)] = alarm;
    await _save();
  }

  /// Removes the alarm from [d] (reminder cleanup is the caller's job).
  Future<void> clearAlarm(DateTime d) async {
    _alarms.remove(mockDayKey(d));
    await _save();
  }

  /// Unmarks every day and drops all alarm data (profile "Reset all").
  Future<void> clear() async {
    state = {};
    _alarms = {};
    await _save();
  }
}

final mockDaysProvider =
    StateNotifierProvider<MockTestNotifier, Set<String>>(
  (ref) => MockTestNotifier(),
);