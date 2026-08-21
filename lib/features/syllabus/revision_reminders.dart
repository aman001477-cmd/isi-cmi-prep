import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../reminders/reminders_provider.dart';
import 'models.dart';

/// Schedules (and tracks) spaced-revision reminders for a syllabus item
/// the moment it is marked DONE: +3, +7 and +14 days at 18:00. Marking
/// the item DONE again re-creates the set; un-marking it cancels them.
class RevisionReminders {
  static const _prefsKey = 'revision_reminders_v1';
  static const _offsetsDays = [3, 7, 14];

  static Future<Map<String, List<String>>> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return {};
      return (jsonDecode(raw) as Map<String, Object?>)
          .map((k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(Map<String, List<String>> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (_) {
      // ignore — in-app state stays consistent
    }
  }

  static Future<void> scheduleFor(
      ExamNode node, RemindersNotifier reminders) async {
    final map = await _load();
    final ids = map.remove(node.id);
    if (ids != null) {
      for (final id in ids) {
        await reminders.remove(id);
      }
    }
    final created = <String>[];
    final now = DateTime.now();
    for (final offset in _offsetsDays) {
      final at = DateTime(now.year, now.month, now.day + offset, 18, 0);
      final r = await reminders.add('Revision: ${node.name}', at);
      created.add(r.id);
    }
    map[node.id] = created;
    await _save(map);
  }

  static Future<void> cancelFor(
      String nodeId, RemindersNotifier reminders) async {
    final map = await _load();
    final ids = map.remove(nodeId);
    if (ids == null) return;
    for (final id in ids) {
      await reminders.remove(id);
    }
    await _save(map);
  }
}
