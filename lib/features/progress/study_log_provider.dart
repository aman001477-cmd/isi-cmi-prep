import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Day key "yyyy-mm-dd" used for study-time totals.
String studyDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Total focused study minutes per day, persisted locally. Every focus
/// timer session (start → reset / dismiss / finish) adds its accrued
/// running seconds here, so the day's real padhai time survives resets.
class StudyLogNotifier extends StateNotifier<Map<String, int>> {
  StudyLogNotifier() : super({}) {
    _load();
  }

  static const _prefsKey = 'study_log_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final map = <String, int>{};
      (jsonDecode(raw) as Map<String, Object?>).forEach((k, v) {
        final minutes = (v as num?)?.toInt();
        if (minutes != null && minutes > 0) map[k] = minutes;
      });
      state = map;
    } catch (_) {
      // keep empty — storage can be unavailable
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state));
    } catch (_) {
      // ignore
    }
  }

  int get todayMinutes {
    final key = studyDayKey(DateTime.now());
    return state[key] ?? 0;
  }

  int minutesOn(DateTime day) => state[studyDayKey(day)] ?? 0;

  /// Day-by-day totals for [days] latest days, oldest first.
  List<(DateTime, int)> lastDays(int days) {
    final today = DateTime.now();
    final out = <(DateTime, int)>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      out.add((d, state[studyDayKey(d)] ?? 0));
    }
    return out;
  }

  /// Adds seconds accrued by a finished timer session (rounded up to
  /// the nearest minute — a 25-minute pomodoro is a full minute credit).
  Future<void> addSession(int seconds) async {
    if (seconds <= 0) return;
    final now = DateTime.now();
    final key = studyDayKey(now);
    final minutes = (seconds + 59) ~/ 60;
    state = {...state, key: (state[key] ?? 0) + minutes};
    await _save();
  }

  /// Empties every session total (profile "Reset all data").
  Future<void> clear() async {
    state = {};
    await _save();
  }
}

final studyLogProvider =
    StateNotifierProvider<StudyLogNotifier, Map<String, int>>(
  (ref) => StudyLogNotifier(),
);