import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_test_provider.dart' show mockDayKey;

/// Fixed palette offered when creating a custom calendar marker.
const List<int> appMarkerColors = [
  0xFF3B5BDB, // blue
  0xFF5E5CE6, // indigo
  0xFF7048E8, // violet
  0xFFC2255C, // pink
  0xFFE8590C, // orange
  0xFFF59F00, // amber
  0xFF2F9E44, // green
  0xFF0CA678, // teal
];

/// A user-created day marker: name + highlight colour.
class CalendarMarker {
  const CalendarMarker({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  final String id;
  final String name;
  final int colorValue;

  Color get color => Color(colorValue);

  factory CalendarMarker.fromJson(Map<String, Object?> json) =>
      CalendarMarker(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: json['color'] as int,
      );

  Map<String, Object?> toJson() =>
      {'id': id, 'name': name, 'color': colorValue};
}

/// A marker placed on one day, with an optional alarm (linked reminder).
/// [notifyOnly] alarms notify without sound.
class MarkerAssignment {
  const MarkerAssignment({
    required this.markerId,
    this.alarmHour,
    this.alarmMinute,
    this.reminderId,
    this.notifyOnly = false,
  });

  final String markerId;
  final int? alarmHour;
  final int? alarmMinute;
  final String? reminderId;
  final bool notifyOnly;

  bool get hasAlarm => alarmHour != null && alarmMinute != null;

  DateTime? atOn(DateTime day) => hasAlarm
      ? DateTime(day.year, day.month, day.day, alarmHour!, alarmMinute!)
      : null;

  factory MarkerAssignment.fromJson(Map<String, Object?> json) =>
      MarkerAssignment(
        markerId: json['markerId'] as String,
        alarmHour: json['hour'] as int?,
        alarmMinute: json['minute'] as int?,
        reminderId: json['reminderId'] as String?,
        notifyOnly: json['notifyOnly'] as bool? ?? false,
      );

  Map<String, Object?> toJson() => {
        'markerId': markerId,
        'hour': alarmHour,
        'minute': alarmMinute,
        'reminderId': reminderId,
        'notifyOnly': notifyOnly,
      };
}

class MarkersState {
  const MarkersState({this.markers = const [], this.assignments = const {}});

  final List<CalendarMarker> markers;
  final Map<String, MarkerAssignment> assignments; // dayKey -> assignment

  MarkersState copyWith({
    List<CalendarMarker>? markers,
    Map<String, MarkerAssignment>? assignments,
  }) =>
      MarkersState(
        markers: markers ?? this.markers,
        assignments: assignments ?? this.assignments,
      );
}

/// Custom calendar markers: named, coloured highlights users stamp onto
/// days. Assignments may carry an alarm (a reminder rings on that day).
class MarkersNotifier extends StateNotifier<MarkersState> {
  MarkersNotifier() : super(const MarkersState()) {
    _load();
  }

  static const _prefsKey = 'calendar_markers_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, Object?>;
      final markers = (json['markers'] as List<dynamic>? ?? [])
          .map((e) => CalendarMarker.fromJson(e as Map<String, Object?>))
          .toList();
      final assignments = (json['assignments'] as Map<String, Object?>? ?? {})
          .map((k, v) => MapEntry(
              k, MarkerAssignment.fromJson(v as Map<String, Object?>)));
      state = MarkersState(markers: markers, assignments: assignments);
    } catch (_) {
      // keep empty — storage can be unavailable in incognito modes
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'markers': state.markers.map((m) => m.toJson()).toList(),
          'assignments':
              state.assignments.map((k, v) => MapEntry(k, v.toJson())),
        }),
      );
    } catch (_) {
      // ignore — state is already committed in memory
    }
  }

  CalendarMarker? markerById(String id) {
    for (final m in state.markers) {
      if (m.id == id) return m;
    }
    return null;
  }

  CalendarMarker? markerAt(DateTime d) {
    final assignment = state.assignments[mockDayKey(d)];
    return assignment == null ? null : markerById(assignment.markerId);
  }

  MarkerAssignment? assignmentAt(DateTime d) =>
      state.assignments[mockDayKey(d)];

  String addMarker(String name, int colorValue) {
    final marker = CalendarMarker(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      colorValue: colorValue,
    );
    state = state.copyWith(markers: [...state.markers, marker]);
    _save();
    return marker.id;
  }

  /// Removes a marker definition and every day it was stamped on.
  List<MarkerAssignment> removeMarker(String id) {
    final removed = <MarkerAssignment>[];
    final assignments = Map<String, MarkerAssignment>.from(state.assignments);
    assignments.removeWhere((_, a) {
      if (a.markerId == id) {
        removed.add(a);
        return true;
      }
      return false;
    });
    state = state.copyWith(
      markers: state.markers.where((m) => m.id != id).toList(),
      assignments: assignments,
    );
    _save();
    return removed;
  }

  Future<void> assign(DateTime d, MarkerAssignment assignment) async {
    state = state.copyWith(
      assignments: {...state.assignments, mockDayKey(d): assignment},
    );
    await _save();
  }

  Future<void> unassign(DateTime d) async {
    final assignments = Map<String, MarkerAssignment>.from(state.assignments)
      ..remove(mockDayKey(d));
    state = state.copyWith(assignments: assignments);
    await _save();
  }

  /// Wipes everything (profile "Reset all").
  Future<void> clear() async {
    state = const MarkersState();
    await _save();
  }
}

final markersProvider =
    StateNotifierProvider<MarkersNotifier, MarkersState>(
  (ref) => MarkersNotifier(),
);