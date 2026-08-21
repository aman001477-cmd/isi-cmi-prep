import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-exam countdown target (exam id → exam date). Kept separately
/// from the syllabus tree so setting a date never mutates progress.
class ExamCountdownNotifier extends StateNotifier<Map<String, DateTime>> {
  ExamCountdownNotifier() : super({}) {
    _load();
  }

  static const _prefsKey = 'exam_countdowns_v1';

  DateTime? targetOf(String examId) => state[examId];

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final e in decoded.entries)
          if (e.value is String) e.key: DateTime.parse(e.value as String),
      };
    } catch (_) {
      // keep empty — storage can be unavailable in privacy/incognito modes
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          for (final e in state.entries) e.key: e.value.toIso8601String(),
        }),
      );
    } catch (_) {
      // ignore — state is already committed in memory
    }
  }

  /// Sets (or clears with `null`) the exam date for [examId].
  Future<void> set(String examId, DateTime? target) async {
    final next = {...state};
    if (target == null) {
      next.remove(examId);
    } else {
      next[examId] = target;
    }
    state = next;
    await _save();
  }

  /// Clears every countdown (profile "Reset all data").
  Future<void> clear() async {
    state = {};
    await _save();
  }
}

final examCountdownProvider =
    StateNotifierProvider<ExamCountdownNotifier, Map<String, DateTime>>(
  (ref) => ExamCountdownNotifier(),
);

/// The hero countdown pinned at the top of the dashboard: an exam name
/// + date chosen by the user (independent of the syllabus tree).
class PinnedExam {
  const PinnedExam({required this.name, required this.date});

  final String name;
  final DateTime date;

  bool get passed => !date.isAfter(DateTime.now());

  Map<String, Object?> toJson() =>
      {'name': name, 'date': date.toIso8601String()};

  static PinnedExam? fromJson(Map<String, Object?> j) {
    try {
      final name = j['name'] as String;
      final date = DateTime.parse(j['date'] as String);
      if (name.trim().isEmpty) return null;
      return PinnedExam(name: name, date: date);
    } catch (_) {
      return null;
    }
  }
}

class PinnedExamNotifier extends StateNotifier<PinnedExam?> {
  PinnedExamNotifier() : super(null) {
    _load();
  }

  static const _prefsKey = 'pinned_exam_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      state = PinnedExam.fromJson(
          jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      // keep empty — storage can be unavailable in privacy/incognito modes
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state?.toJson()));
    } catch (_) {
      // ignore — state is already committed in memory
    }
  }

  Future<void> set(String name, DateTime date) async {
    state = PinnedExam(name: name.trim(), date: date);
    await _save();
  }

  Future<void> clear() async {
    state = null;
    await _save();
  }
}

final pinnedExamProvider =
    StateNotifierProvider<PinnedExamNotifier, PinnedExam?>(
  (ref) => PinnedExamNotifier(),
);
