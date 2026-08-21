import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One closed study segment of the daily timer — every Pause closes the
/// current stretch as a lap: [start] → [end] is the study time between
/// (re)start and pause, break time between Pause→Resume is never counted.
class MarathonLap {
  const MarathonLap({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  int get durationSeconds => end.difference(start).inSeconds;

  Map<String, Object?> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  static MarathonLap fromJson(Map<String, Object?> j) => MarathonLap(
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
      );
}

/// Immutable snapshot of the permanent daily countdown ("Daily Fix Timer").
class MarathonState {
  const MarathonState({
    required this.targetMinutes,
    required this.periodStart,
    this.pausedAccum = Duration.zero,
    this.pausedAt,
    this.runningSince,
    this.laps = const [],
  });

  /// User-set daily target in minutes (1–24 h).
  final int targetMinutes;

  /// Moment the current daily period began (local midnight normally,
  /// "now" after a manual reset).
  final DateTime periodStart;

  /// Time already frozen by previous pauses (excluded from consumption).
  final Duration pausedAccum;

  /// Set while paused — the countdown is frozen at this moment.
  final DateTime? pausedAt;

  /// Moment the current RUNNING stretch began (start of the segment that
  /// becomes a lap when Pause is pressed).
  final DateTime? runningSince;

  /// Closed study segments of today, oldest first.
  final List<MarathonLap> laps;

  bool get isPaused => pausedAt != null;

  MarathonState copyWith({
    int? targetMinutes,
    DateTime? periodStart,
    Duration? pausedAccum,
    DateTime? pausedAt,
    DateTime? runningSince,
    List<MarathonLap>? laps,
    bool clearPause = false,
    bool clearRunningSince = false,
  }) =>
      MarathonState(
        targetMinutes: targetMinutes ?? this.targetMinutes,
        periodStart: periodStart ?? this.periodStart,
        pausedAccum: pausedAccum ?? this.pausedAccum,
        pausedAt: clearPause ? null : (pausedAt ?? this.pausedAt),
        runningSince:
            clearRunningSince ? null : (runningSince ?? this.runningSince),
        laps: laps ?? this.laps,
      );

  Map<String, Object?> toJson() => {
        'targetMinutes': targetMinutes,
        'periodStart': periodStart.toIso8601String(),
        'pausedAccumMs': pausedAccum.inMilliseconds,
        if (pausedAt != null) 'pausedAt': pausedAt!.toIso8601String(),
        if (runningSince != null)
          'runningSince': runningSince!.toIso8601String(),
        'laps': [for (final l in laps) l.toJson()],
      };

  static MarathonState fromJson(Map<String, Object?> j) => MarathonState(
        targetMinutes: j['targetMinutes'] as int? ??
            MarathonNotifier.defaultTargetMinutes,
        periodStart: DateTime.parse(j['periodStart'] as String),
        pausedAccum:
            Duration(milliseconds: (j['pausedAccumMs'] as num?)?.toInt() ?? 0),
        pausedAt: j['pausedAt'] == null
            ? null
            : DateTime.parse(j['pausedAt'] as String),
        runningSince: j['runningSince'] == null
            ? null
            : DateTime.parse(j['runningSince'] as String),
        laps: [
          for (final l in (j['laps'] as List? ?? const []))
            if (l is Map<String, Object?>)
              MarathonLap.fromJson(l)
            else if (l is Map)
              MarathonLap.fromJson(
                  Map<String, Object?>.from(l.cast<String, dynamic>())),
        ],
      );
}

/// Permanent daily countdown ("Daily Fix Timer").
///
/// Unlike the focus timer this one never stops on its own: it counts
/// against the wall clock, so closing the app, locking the phone or
/// resetting the focus timer has no effect. It supports explicit
/// **Pause** (freeze where it is), **Reset** (fresh full target from
/// now), an automatic refill every midnight, and keeps counting past
/// the target — that extra time still counts towards the day.
class MarathonNotifier extends StateNotifier<MarathonState> {
  MarathonNotifier()
      : super(MarathonState(
          targetMinutes: defaultTargetMinutes,
          periodStart: dayStart(DateTime.now()),
        )) {
    _load();
  }

  static const String prefsKey = 'marathon_v2';
  static const int defaultTargetMinutes = 600; // 10 h
  static const int minTargetMinutes = 60; // 1 h
  static const int maxTargetMinutes = 1440; // 24 h

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final loaded = MarathonState.fromJson(j);
        state = refillIfStale(
          loaded.copyWith(
            targetMinutes: loaded.targetMinutes
                .clamp(minTargetMinutes, maxTargetMinutes),
          ),
          DateTime.now(),
        );
      }
    } catch (_) {
      // corrupt/first run — keep the fresh default
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(state.toJson()));
    } catch (_) {
      // session-only — fine offline
    }
  }

  /// Local midnight of the given moment (the daily refill instant).
  static DateTime dayStart(DateTime now) =>
      DateTime(now.year, now.month, now.day);

  /// The clock the countdown currently sees: frozen at [MarathonState.pausedAt]
  /// while paused, real time otherwise.
  static DateTime runningClock(MarathonState s, DateTime now) =>
      s.isPaused ? s.pausedAt! : now;

  /// Seconds already consumed today — uncapped, so it keeps growing past
  /// the target. Pure — testable.
  static int consumedSeconds(MarathonState s, DateTime now) {
    final t = runningClock(s, now).difference(s.periodStart).inSeconds;
    final frozen = s.pausedAccum.inSeconds;
    final c = t - frozen;
    return c < 0 ? 0 : c;
  }

  /// Seconds still left today (0 once the target is consumed).
  static int remainingSeconds(MarathonState s, DateTime now) {
    final r = s.targetMinutes * 60 - consumedSeconds(s, now);
    return r < 0 ? 0 : r;
  }

  /// Seconds counted beyond the target today (0 until the target is hit).
  static int overSeconds(MarathonState s, DateTime now) {
    final c = consumedSeconds(s, now);
    final t = s.targetMinutes * 60;
    return c > t ? c - t : 0;
  }

  /// Target fully consumed (or exceeded) for today.
  static bool achieved(MarathonState s, DateTime now) =>
      overSeconds(s, now) > 0 || remainingSeconds(s, now) == 0;

  /// Enforce the midnight refill — a period that started before today's
  /// midnight restarts fresh at midnight ("agle din wapas full target").
  /// Laps belong to the day, so a fresh day starts with no laps.
  static MarathonState refillIfStale(MarathonState s, DateTime now) {
    final midnight = dayStart(now);
    if (s.periodStart.isBefore(midnight)) {
      return MarathonState(
        targetMinutes: s.targetMinutes,
        periodStart: midnight,
        runningSince: midnight,
      );
    }
    return s;
  }

  Future<void> setTargetMinutes(int minutes) async {
    final clamped = minutes.clamp(minTargetMinutes, maxTargetMinutes);
    state = refillIfStale(
      state.copyWith(targetMinutes: clamped),
      DateTime.now(),
    );
    await _save();
  }

  /// Freeze the countdown where it is — the current running stretch is
  /// closed as a lap ([start] → this moment).
  Future<void> pause() async {
    if (state.isPaused) return;
    final now = DateTime.now();
    final s = refillIfStale(state, now);
    final lap = MarathonLap(
      start: s.runningSince ?? s.periodStart,
      end: now,
    );
    state = s.copyWith(
      pausedAt: now,
      clearRunningSince: true,
      laps: [...s.laps, lap],
    );
    await _save();
  }

  /// Continue from the frozen point — a new running stretch starts now,
  /// so the next Pause closes its own lap.
  Future<void> resume() async {
    if (!state.isPaused) return;
    final now = DateTime.now();
    state = refillIfStale(
      state.copyWith(
        pausedAccum: state.pausedAccum + now.difference(state.pausedAt!),
        clearPause: true,
        runningSince: now,
      ),
      now,
    );
    await _save();
  }

  /// Start a fresh full target right now (running) — old lanes+laps are
  /// gone, the next Pause opens the first lap of the new session.
  Future<void> reset() async {
    state = MarathonState(
      targetMinutes: state.targetMinutes,
      periodStart: DateTime.now(),
      runningSince: DateTime.now(),
    );
    await _save();
  }
}

final marathonProvider =
    StateNotifierProvider<MarathonNotifier, MarathonState>((ref) =>
        MarathonNotifier());