import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/reminders/reminder_model.dart';
import '../../features/reminders/reminder_notifications.dart';
import '../../features/reminders/reminders_provider.dart';
import 'sound_player.dart';

/// Built-in sound options shown in the picker.
const List<SoundOption> soundCatalog = [
  SoundOption('none', 'No sound'),
  SoundOption('beep', 'Beep'),
  SoundOption('chime', 'Chime'),
  SoundOption('ding', 'Ding'),
  SoundOption('pulse', 'Pulse'),
  SoundOption('synth', 'Synth'),
];

/// How long a ringing alarm keeps playing before it stops on its own.
const List<(int, String)> ringDurationOptions = [
  (10, '10 s'),
  (30, '30 s'),
  (60, '1 min'),
  (120, '2 min'),
  (300, '5 min'),
];

class SoundOption {
  const SoundOption(this.id, this.label);

  final String id;
  final String label;
}

/// A scheduled task. [date] is day-precision:
///   date == today → Daily task
///   date < today  → falls into Backlog (if not done)
///   date > today  → Upcoming
/// [alarmAt] is the exact moment the reminder sound fires; the task's
/// alarm state is cleared automatically once it has played.
/// [ringSeconds] is how long the alarm sound keeps playing.
class PlannerTask {
  PlannerTask({
    required this.id,
    required this.title,
    required this.date,
    this.done = false,
    this.alarmAt,
    this.sound = 'none',
    this.ringSeconds = 30,
    this.notifyOnly = false,
    this.backlog = false,
    this.order = 0,
    this.repeatDaily = false,
    this.locked = false,
    this.lockedBy,
  });

  final String id;
  String title;
  DateTime date;
  bool done;
  DateTime? alarmAt;
  String sound;
  int ringSeconds;

  /// "Notification only" — the alarm fires as a silent notification +
  /// in-app popup, but never plays sound.
  bool notifyOnly;

  /// Explicitly parked in Backlog by the user ("Add to Backlog"). Such
  /// tasks are skipped by the daily rollover that moves overdue tasks
  /// into Today on launch.
  bool backlog;

  /// Manual priority order within today's list (drag to reorder).
  int order;

  /// Daily repeater — completing the task auto-creates an exact copy
  /// for tomorrow (same title, same alarm time), so daily habits like
  /// "10 hr padhna" or "maths ke 25 ques" never need re-adding.
  bool repeatDaily;

  /// Locked by admin — user cannot edit/delete this entry
  bool locked;
  String? lockedBy;

  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get isToday => day(DateTime.now()) == date;
  bool get isOverdue => !done && date.isBefore(day(DateTime.now()));
  bool get isUpcoming => date.isAfter(day(DateTime.now()));
  bool get hasAlarm => alarmAt != null;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'done': done,
        if (alarmAt != null) 'alarmAt': alarmAt!.toIso8601String(),
        'sound': sound,
        'ringSeconds': ringSeconds,
        'notifyOnly': notifyOnly,
        'backlog': backlog,
        'order': order,
        'repeatDaily': repeatDaily,
        'locked': locked,
        if (lockedBy != null) 'lockedBy': lockedBy,
      };

  static PlannerTask fromJson(Map<String, Object?> j) => PlannerTask(
        id: j['id'] as String,
        title: j['title'] as String,
        date: DateTime.parse(j['date'] as String),
        done: j['done'] as bool? ?? false,
        alarmAt: j['alarmAt'] == null
            ? null
            : DateTime.parse(j['alarmAt'] as String),
        sound: j['sound'] as String? ?? 'none',
        ringSeconds: j['ringSeconds'] as int? ?? 30,
        notifyOnly: j['notifyOnly'] as bool? ?? false,
        backlog: j['backlog'] as bool? ?? false,
        order: j['order'] as int? ?? 0,
        repeatDaily: j['repeatDaily'] as bool? ?? false,
        locked: j['locked'] as bool? ?? false,
        lockedBy: j['lockedBy'] as String?,
      );
}

/// What is ringing right now (or null when silent).
class Ringing {
  const Ringing({
    required this.id,
    required this.title,
    required this.sound,
    required this.seconds,
  });

  final String id;
  final String title;
  final String sound;
  final int seconds;
}

/// Owns the active ring: plays the looping sound, auto-stops it after
/// [Ringing.seconds], and clears when the user picks one of the options.
class RingingNotifier extends StateNotifier<Ringing?> {
  RingingNotifier() : super(null);

  Timer? _autoStop;

  void ring(Ringing ring) {
    _autoStop?.cancel();
    state = ring;
    playLoop(ring.sound);
    _autoStop = Timer(
      Duration(seconds: ring.seconds),
      stop,
    );
  }

  /// Stops the sound immediately (called by any of the ring options).
  void stop() {
    _autoStop?.cancel();
    _autoStop = null;
    stopSound();
    state = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class PlannerNotifier extends StateNotifier<List<PlannerTask>> {
  PlannerNotifier(this._ringer, {void Function(Reminder)? onSilentDue})
      : _onSilentDue = onSilentDue,
        super([]) {
    _load();
    _alarmClock = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkAlarms(DateTime.now()),
    );
  }

  final RingingNotifier _ringer;

  /// Fired with a due notification-only task so the shell can pop it
  /// up silently (no sound).
  final void Function(Reminder)? _onSilentDue;

  static const _prefsKey = 'planner_v1';
  static int _seq = 0;

  late final Timer _alarmClock;

  @override
  void dispose() {
    _alarmClock.cancel();
    super.dispose();
  }

  String _id() => 't${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      var tasks = (jsonDecode(raw) as List<dynamic>)
          .map((e) => PlannerTask.fromJson(e as Map<String, Object?>))
          .toList();
      // Daily rollover: every overdue task that hasn't been parked in
      // Backlog on purpose moves to Today on launch, so "yesterday's"
      // tasks (mock tests, events, study items) stay in front of the
      // user instead of rotting in a past bucket.
      final today = PlannerTask.day(DateTime.now());
      final rolled = tasks.any(
          (t) => !t.done && !t.backlog && t.date.isBefore(today));
      if (rolled) {
        tasks = [
          for (final t in tasks)
            if (!t.done && !t.backlog && t.date.isBefore(today))
              _copy(t, date: today)
            else
              t,
        ];
      }
      state = tasks;
      if (rolled) await _save();
    } catch (_) {
      // keep empty — storage can be unavailable in privacy/incognito modes
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.map((t) => t.toJson()).toList()),
      );
    } catch (_) {
      // ignore — state is already committed in memory
    }
  }

  List<PlannerTask> get today =>
      state.where((t) => t.isToday).toList()
        ..sort((a, b) {
          if (a.done != b.done) return a.done ? 1 : -1;
          return a.order - b.order;
        });

  List<PlannerTask> get upcoming =>
      state.where((t) => t.isUpcoming && !t.done).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  /// All tasks scheduled for [day] (done ones last), used by the calendar.
  List<PlannerTask> tasksOn(DateTime day) =>
      state.where((t) => PlannerTask.day(t.date) == PlannerTask.day(day)).toList()
        ..sort((a, b) => a.done ? 1 : b.done ? -1 : 0);

  /// How many undone tasks are scheduled for [day] (calendar badge).
  int pendingOn(DateTime day) =>
      tasksOn(day).where((t) => !t.done).length;

  /// Tasks explicitly parked in Backlog ("Add to Backlog"), newest first.
  List<PlannerTask> get backlog =>
      state.where((t) => !t.done && t.backlog).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  int get done => state.where((t) => t.done).length;

  Future<void> add(
    String title,
    DateTime date, {
    DateTime? alarmAt,
    String sound = 'none',
    int ringSeconds = 30,
    bool notifyOnly = false,
    bool backlog = false,
    bool repeatDaily = false,
  }) async {
    if (title.trim().isEmpty) return;
    final task = PlannerTask(
      id: _id(),
      title: title.trim(),
      date: date,
      alarmAt: alarmAt,
      sound: sound,
      ringSeconds: ringSeconds,
      notifyOnly: notifyOnly,
      backlog: backlog,
      repeatDaily: repeatDaily,
      order: today.length,
    );
    state = [...state, task];
    await _save();
    if (alarmAt != null) {
      await scheduleReminderNotification(
        Reminder(
          id: task.id,
          title: task.title,
          at: alarmAt,
          silent: notifyOnly,
        ),
      );
    }
  }

  /// Parks an undone task into Backlog: silent notification cancelled,
  /// date set to yesterday so it sorts oldest-first, skipped by rollover.
  /// Drag-reorder of today's list. [orderedIds] is the new top-to-bottom
  /// sequence of (undone) today tasks; their [PlannerTask.order] is
  /// rewritten to match so the sort stays stable across reloads.
  Future<void> reorderToday(List<String> orderedIds) async {
    final rank = {for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i};
    state = [
      for (final t in state)
        if (rank.containsKey(t.id) && t.isToday)
          _copy(t, order: rank[t.id]!)
        else
          t,
    ];
    await _save();
  }

  Future<void> addToBacklog(String id) async {
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task == null || task.done) return;
    if (task.alarmAt != null) await cancelReminderNotification(id);
    state = [
      for (final t in state)
        if (t.id == id)
          _copy(
            t,
            backlog: true,
            alarmAt: null,
            date: PlannerTask.day(DateTime.now())
                .subtract(const Duration(days: 1)),
          )
        else
          t,
    ];
    await _save();
  }

  /// Pulls a backlog task back into Today (with a clean reminder state).
  Future<void> bringToToday(String id) async {
    state = [
      for (final t in state)
        if (t.id == id)
            _copy(t, backlog: false, date: PlannerTask.day(DateTime.now()))
        else
          t,
    ];
    await _save();
  }

  Future<void> toggle(String id) async {
    final prev = state.where((t) => t.id == id).firstOrNull;
    if (prev == null) return;
    final nowDone = !prev.done;
    state = [
      for (final t in state)
        if (t.id == id) _copy(t, done: nowDone) else t,
    ];
    await _save();
    if (nowDone) await _maybeRepeat(prev);
  }

  Future<void> markDone(String id, bool value) async {
    final prev = state.where((t) => t.id == id).firstOrNull;
    if (prev == null || prev.done == value) return;
    state = [
      for (final t in state)
        if (t.id == id) _copy(t, done: value) else t,
    ];
    await _save();
    if (value) await _maybeRepeat(prev);
  }

  /// A completed daily-repeater spawns its exact copy for tomorrow —
  /// same title, same alarm time-of-day. If tomorrow's copy already
  /// exists (e.g. the user toggled done twice), nothing is duplicated.
  Future<void> _maybeRepeat(PlannerTask task) async {
    if (!task.repeatDaily) return;
    final tomorrow = PlannerTask.day(DateTime.now())
        .add(const Duration(days: 1));
    final exists = state.any((t) =>
        !t.done &&
        t.repeatDaily &&
        t.title == task.title &&
        PlannerTask.day(t.date) == tomorrow);
    if (exists) return;
    final DateTime? alarmAt = task.alarmAt == null
        ? null
        : DateTime(tomorrow.year, tomorrow.month, tomorrow.day,
            task.alarmAt!.hour, task.alarmAt!.minute);
    final copy = PlannerTask(
      id: _id(),
      title: task.title,
      date: tomorrow,
      alarmAt: alarmAt,
      sound: task.sound,
      ringSeconds: task.ringSeconds,
      notifyOnly: task.notifyOnly,
      repeatDaily: true,
    );
    state = [...state, copy];
    await _save();
    if (alarmAt != null) {
      await scheduleReminderNotification(Reminder(
        id: copy.id,
        title: copy.title,
        at: alarmAt,
        silent: copy.notifyOnly,
      ));
    }
  }

  /// Turns daily repetition on/off for a task (⋮ menu → Repeat daily).
  Future<void> setRepeatDaily(String id, bool value) async {
    state = [
      for (final t in state)
        if (t.id == id) _copy(t, repeatDaily: value) else t,
    ];
    await _save();
  }

  Future<void> reschedule(String id, DateTime date) async {
    state = [
      for (final t in state)
        if (t.id == id) _copy(t, date: date) else t,
    ];
    await _save();
  }

  Future<void> rename(String id, String title) async {
    if (title.trim().isEmpty) return;
    state = [
      for (final t in state)
        if (t.id == id) _copy(t, title: title.trim()) else t,
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    final removed = state.where((t) => t.id == id).toList();
    state = state.where((t) => t.id != id).toList();
    await _save();
    for (final t in removed) {
      if (t.alarmAt != null) await cancelReminderNotification(t.id);
    }
  }

  /// Empties the whole task list (used by the profile "Reset all data").
  Future<void> clear() async {
    for (final t in state) {
      if (t.alarmAt != null) await cancelReminderNotification(t.id);
    }
    state = [];
    await _save();
  }

  /// Sets the reminder time (or clears it with `null`). The chosen
  /// [SoundOption] id and ring duration are stored alongside so the
  /// alarm knows what to play and for how long. A system notification
  /// is scheduled too, so the alarm also rings when the app is closed.
  /// [notifyOnly] tasks fire a silent notification instead of a sound.
  Future<void> setReminder(
    String id,
    DateTime? alarmAt, {
    String? sound,
    int? ringSeconds,
    bool? notifyOnly,
  }) async {
    final prev = state.where((t) => t.id == id).firstOrNull;
    state = [
      for (final t in state)
        if (t.id == id)
          PlannerTask(
            id: t.id,
            title: t.title,
            date: t.date,
            done: t.done,
            alarmAt: alarmAt,
            sound: sound ?? t.sound,
            ringSeconds: ringSeconds ?? t.ringSeconds,
            notifyOnly: notifyOnly ?? t.notifyOnly,
            backlog: t.backlog,
            repeatDaily: t.repeatDaily,
            order: t.order,
          )
        else
          t,
    ];
    await _save();
    if (prev != null && prev.alarmAt != null) {
      await cancelReminderNotification(id);
    }
    if (alarmAt != null) {
      await scheduleReminderNotification(Reminder(
        id: id,
        title: prev?.title ?? '',
        at: alarmAt,
        silent: notifyOnly ?? prev?.notifyOnly ?? false,
      ));
    }
  }

  /// One-second heartbeat: rings every due alarm exactly once (looping
  /// sound + on-screen options), disarms the task's alarm, and clears
  /// it so a same-day task doesn't ring again on reload.
  /// Notification-only tasks never ring — they fire a silent in-app
  /// popup instead (the system notification is scheduled separately).
  void _checkAlarms(DateTime now) {
    final due = <PlannerTask>[];
    final silentDue = <PlannerTask>[];
    for (final t in state) {
      if (t.alarmAt != null && !now.isBefore(t.alarmAt!)) {
        (t.notifyOnly ? silentDue : due).add(t);
      }
    }
    if (due.isEmpty && silentDue.isEmpty) return;
    state = [
      for (final t in state)
        if (t.alarmAt != null && !now.isBefore(t.alarmAt!))
          PlannerTask(
            id: t.id,
            title: t.title,
            date: t.date,
            done: t.done,
            alarmAt: null,
            sound: t.sound,
            ringSeconds: t.ringSeconds,
            notifyOnly: t.notifyOnly,
            backlog: t.backlog,
            repeatDaily: t.repeatDaily,
            order: t.order,
          )
        else
          t,
    ];
    _save();
    for (final t in due) {
      _ringer.ring(Ringing(
        id: t.id,
        title: t.title,
        sound: t.sound,
        seconds: t.ringSeconds,
      ));
    }
    for (final t in silentDue) {
      _onSilentDue?.call(Reminder(
        id: t.id,
        title: t.title,
        at: t.alarmAt ?? now,
        silent: true,
      ));
    }
  }

  PlannerTask _copy(
    PlannerTask t, {
    String? title,
    DateTime? date,
    bool? done,
    DateTime? alarmAt,
    String? sound,
    int? ringSeconds,
    bool? notifyOnly,
    bool? backlog,
    int? order,
    bool? repeatDaily,
  }) =>
      PlannerTask(
        id: t.id,
        title: title ?? t.title,
        date: date ?? t.date,
        done: done ?? t.done,
        alarmAt: alarmAt ?? t.alarmAt,
        sound: sound ?? t.sound,
        ringSeconds: ringSeconds ?? t.ringSeconds,
        notifyOnly: notifyOnly ?? t.notifyOnly,
        backlog: backlog ?? t.backlog,
        repeatDaily: repeatDaily ?? t.repeatDaily,
        order: order ?? t.order,
      );
}

final ringingProvider =
    StateNotifierProvider<RingingNotifier, Ringing?>(
  (ref) => RingingNotifier(),
);

final plannerProvider =
    StateNotifierProvider<PlannerNotifier, List<PlannerTask>>(
  (ref) => PlannerNotifier(
    ref.read(ringingProvider.notifier),
    onSilentDue: (r) => ref.read(dueReminderProvider.notifier).state = r,
  ),
);