import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Short + full names indexed by `DateTime.weekday` (Monday = 1).
const weekdayShort = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayFull = [
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Renders minutes-since-midnight as "HH:MM".
String formatClock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// One weekly time slot: a recurring activity on [weekday] running from
/// [startMin] to [endMin] (minutes since 00:00).
class ScheduleSlot {
  ScheduleSlot({
    required this.id,
    required this.weekday,
    required this.title,
    required this.startMin,
    required this.endMin,
    this.locked = false,
    this.lockedBy,
  });

  final String id;
  final int weekday;
  String title;
  int startMin;
  int endMin;
  bool locked;
  String? lockedBy;

  bool contains(DateTime moment) {
    final min = moment.hour * 60 + moment.minute;
    return startMin <= min && min < endMin;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'weekday': weekday,
        'title': title,
        'startMin': startMin,
        'endMin': endMin,
        'locked': locked,
        if (lockedBy != null) 'lockedBy': lockedBy,
      };

  static ScheduleSlot fromJson(Map<String, Object?> j) => ScheduleSlot(
        id: j['id'] as String,
        weekday: j['weekday'] as int,
        title: j['title'] as String,
        startMin: j['startMin'] as int,
        endMin: j['endMin'] as int,
        locked: j['locked'] as bool? ?? false,
        lockedBy: j['lockedBy'] as String?,
      );
}

class ScheduleNotifier extends StateNotifier<List<ScheduleSlot>> {
  ScheduleNotifier() : super([]) {
    _load();
  }

  static const _prefsKey = 'schedule_v1';
  static int _seq = 0;

  String _id() => 's${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      state = (jsonDecode(raw) as List<dynamic>)
          .map((e) => ScheduleSlot.fromJson(e as Map<String, Object?>))
          .toList();
    } catch (_) {
      // keep empty — storage can be unavailable in privacy/incognito modes
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.map((s) => s.toJson()).toList()),
      );
    } catch (_) {
      // ignore — state is already committed in memory
    }
  }

  /// Slots for [weekday] (1 = Monday … 7 = Sunday), sorted by start time.
  List<ScheduleSlot> slotsOn(int weekday) =>
      state.where((s) => s.weekday == weekday).toList()
        ..sort((a, b) => a.startMin.compareTo(b.startMin));

  int get total => state.length;

  Future<void> add(
    int weekday,
    String title,
    int startMin,
    int endMin,
  ) async {
    if (title.trim().isEmpty) return;
    state = [
      ...state,
      ScheduleSlot(
        id: _id(),
        weekday: weekday,
        title: title.trim(),
        startMin: startMin,
        endMin: endMin,
      ),
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _save();
  }

  /// Empties the whole weekly schedule (profile "Reset all data").
  Future<void> clear() async {
    state = [];
    await _save();
  }

  Future<void> rename(String id, String title) async {
    if (title.trim().isEmpty) return;
    state = [
      for (final s in state)
        if (s.id == id)
          ScheduleSlot(
            id: s.id,
            weekday: s.weekday,
            title: title.trim(),
            startMin: s.startMin,
            endMin: s.endMin,
          )
        else
          s,
    ];
    await _save();
  }

  Future<void> updateTime(String id, int startMin, int endMin) async {
    state = [
      for (final s in state)
        if (s.id == id)
          ScheduleSlot(
            id: s.id,
            weekday: s.weekday,
            title: s.title,
            startMin: startMin,
            endMin: endMin,
          )
        else
          s,
    ];
    await _save();
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, List<ScheduleSlot>>(
  (ref) => ScheduleNotifier(),
);
