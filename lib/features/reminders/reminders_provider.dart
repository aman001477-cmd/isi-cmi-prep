import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_model.dart';
import 'reminder_notifications.dart';

/// The reminder whose time has arrived — non-null while its popup should
/// be shown. Cleared by the popup (close / snooze / dismiss).
final dueReminderProvider = StateProvider<Reminder?>((_) => null);

class RemindersNotifier extends StateNotifier<List<Reminder>> {
  RemindersNotifier(this._onDue) : super([]) {
    _load();
    _checker = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkDue(DateTime.now());
    });
  }

  static const _prefsKey = 'reminders_v1';
  static const _shownPrefsKey = 'reminders_shown_v1';

  /// Fired with the first due reminder so the shell can pop it up.
  final void Function(Reminder) _onDue;

  Timer? _checker;

  /// Ids already popped this session — they don't re-fire until restart.
  final Set<String> _shown = {};

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        state = (jsonDecode(raw) as List<dynamic>)
            .map((e) => Reminder.fromJson(e as Map<String, Object?>))
            .whereType<Reminder>()
            .toList();
      }
      final shown = prefs.getStringList(_shownPrefsKey);
      if (shown != null) _shown.addAll(shown);
    } catch (_) {
      // keep empty — storage can be unavailable in incognito modes
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.map((r) => r.toJson()).toList()),
      );
      await prefs.setStringList(_shownPrefsKey, _shown.toList());
    } catch (_) {
      // ignore — state is already committed in memory
    }
  }

  /// [silent] reminders notify without sound ("notification only").
  Future<Reminder> add(String title, DateTime at, {bool silent = false}) async {
    final reminder = Reminder(
      id: 'r${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      at: at,
      silent: silent,
    );
    state = [...state, reminder];
    // Only suppress popups for times already past at creation — future
    // alarms (mock tests, marker alarms, reminders) must fire when their
    // time arrives.
    if (!reminder.at.isAfter(DateTime.now())) _shown.add(reminder.id);
    await _save();
    await scheduleReminderNotification(reminder);
    return reminder;
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _save();
    await cancelReminderNotification(id);
  }

  /// Moves the reminder [by] into the future and re-arms its alarm.
  Future<void> snooze(String id, Duration by) async {
    final index = state.indexWhere((r) => r.id == id);
    if (index < 0) return;
    final updated = state[index].copyWith(at: DateTime.now().add(by));
    state = [...state]..[index] = updated;
    await _save();
    await scheduleReminderNotification(updated);
  }

  List<Reminder> get upcoming {
    final now = DateTime.now();
    return state.where((r) => r.at.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  /// Fires the first reminder whose time passed (once per session).
  void _checkDue(DateTime now) {
    for (final r in state) {
      if (!r.at.isAfter(now) && !_shown.contains(r.id)) {
        _shown.add(r.id);
        _save();
        _onDue(r);
        return;
      }
    }
  }

  @override
  void dispose() {
    _checker?.cancel();
    super.dispose();
  }
}

final remindersProvider =
    StateNotifierProvider<RemindersNotifier, List<Reminder>>(
  (ref) => RemindersNotifier(
    (r) => ref.read(dueReminderProvider.notifier).state = r,
  ),
);
