import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../planner/mock_test_provider.dart';

/// Score logged for one mock-test day.
class MockResult {
  const MockResult({required this.marks, required this.max});

  final double marks;
  final double max;

  double get percent => max <= 0 ? 0 : (marks / max * 100).clamp(0, 100);

  Map<String, Object?> toJson() => {'marks': marks, 'max': max};

  static MockResult? fromJson(Map<String, Object?> j) {
    try {
      final marks = (j['marks'] as num).toDouble();
      final max = (j['max'] as num).toDouble();
      if (max <= 0 || marks < 0) return null;
      return MockResult(marks: marks, max: max);
    } catch (_) {
      return null;
    }
  }
}

/// Logged results per mock-test day: "how many marks did I score".
class MockResultsNotifier extends StateNotifier<Map<String, MockResult>> {
  MockResultsNotifier() : super({}) {
    _load();
  }

  static const _prefsKey = 'mock_results_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final map = <String, MockResult>{};
      (jsonDecode(raw) as Map<String, Object?>).forEach((k, v) {
        final r = MockResult.fromJson(v as Map<String, Object?>);
        if (r != null) map[k] = r;
      });
      state = map;
    } catch (_) {
      // keep empty — storage can be unavailable in privacy/incognito modes
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (_) {
      // ignore — state is already committed in memory
    }
  }

  MockResult? resultFor(DateTime day) => state[mockDayKey(day)];

  /// Latest results, newest first.
  List<(DateTime, MockResult)> get latest {
    final list = state.entries
        .map((e) => (DateTime.parse(e.key), e.value))
        .toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));
    return list;
  }

  double? get averagePercent {
    if (state.isEmpty) return null;
    final total = state.values.map((r) => r.percent).reduce((a, b) => a + b);
    return total / state.length;
  }

  Future<void> set(DateTime day, double marks, double max) async {
    if (max <= 0 || marks < 0) return;
    state = {...state, mockDayKey(day): MockResult(marks: marks, max: max)};
    await _save();
  }

  Future<void> remove(DateTime day) async {
    state = {...state}..remove(mockDayKey(day));
    await _save();
  }

  /// Empties every result (profile "Reset all data").
  Future<void> clear() async {
    state = {};
    await _save();
  }
}

final mockResultsProvider =
    StateNotifierProvider<MockResultsNotifier, Map<String, MockResult>>(
  (ref) => MockResultsNotifier(),
);
