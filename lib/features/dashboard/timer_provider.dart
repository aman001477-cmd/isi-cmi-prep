import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../planner/sound_player.dart';
import '../progress/study_log_provider.dart';
import 'timer_overlay.dart';

enum TimerPhase { idle, running, paused, done }

/// Full countdown status — lives in a provider so the timer keeps
/// ticking no matter which page is open (or in full-screen dialog).
class TimerStatus {
  const TimerStatus({
    required this.phase,
    required this.remaining,
    required this.total,
    required this.focus,
    this.sound = 'chime',
  });

  final TimerPhase phase;

  /// Seconds left on the clock.
  final int remaining;

  /// Seconds of the configured duration.
  final int total;

  /// Focus mode — mutes other alarm sounds while on.
  final bool focus;

  /// Completion sound id (see [soundCatalog] in planner).
  final String sound;

  bool get isActive => phase == TimerPhase.running;

  TimerStatus copyWith({
    TimerPhase? phase,
    int? remaining,
    int? total,
    bool? focus,
    String? sound,
  }) =>
      TimerStatus(
        phase: phase ?? this.phase,
        remaining: remaining ?? this.remaining,
        total: total ?? this.total,
        focus: focus ?? this.focus,
        sound: sound ?? this.sound,
      );
}

/// "HH:MM:SS" for a countdown clock.
String formatClockSeconds(int s) {
  final h = (s ~/ 3600).toString().padLeft(2, '0');
  final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$h:$m:$sec';
}

class TimerNotifier extends StateNotifier<TimerStatus> {
  TimerNotifier({
    void Function(int seconds)? onSessionComplete,
    void Function(Map<String, Object?> payload)? onOverlayState,
  })  : _onSessionComplete = onSessionComplete,
        _onOverlayState = onOverlayState,
        super(const TimerStatus(
          phase: TimerPhase.idle,
          remaining: 0,
          total: 0,
          focus: false,
        ));

  /// Called once per finished session with the seconds the timer
  /// actually ran — feeds the daily study-time log.
  final void Function(int seconds)? _onSessionComplete;

  /// Called whenever the on-screen state changes — feeds the floating
  /// overlay so it always mirrors the countdown.
  final void Function(Map<String, Object?> payload)? _onOverlayState;

  Timer? _tick;

  /// Accrued running seconds of the current session (pauses don't lose
  /// progress; committed to the study log on reset/dismiss/finish).
  int _sessionSeconds = 0;

  /// Epoch (ms) the current running block started — lets the overlay
  /// count down on its own between pushed updates.
  int? _startedAtEpoch;

  void _commitSession() {
    if (_sessionSeconds <= 0) return;
    _onSessionComplete?.call(_sessionSeconds);
    _sessionSeconds = 0;
  }

  void _publish() {
    _onOverlayState?.call({
      'phase': state.phase.name,
      'total': state.total,
      'remaining': state.remaining,
      'startedAtEpoch': _startedAtEpoch,
    });
  }

  void setDuration({int hours = 0, int minutes = 0, int seconds = 0}) {
    if (state.phase != TimerPhase.idle) return;
    final total = hours * 3600 + minutes * 60 + seconds;
    state = state.copyWith(remaining: total, total: total);
    _publish();
  }

  void start() {
    if (state.remaining <= 0 || state.phase == TimerPhase.running) return;
    _startedAtEpoch = DateTime.now().millisecondsSinceEpoch -
        (state.total - state.remaining) * 1000;
    state = state.copyWith(phase: TimerPhase.running);
    _publish();
    _tick?.cancel();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickDown(),
    );
  }

  void pause() {
    if (state.phase != TimerPhase.running) return;
    _tick?.cancel();
    _startedAtEpoch = null;
    state = state.copyWith(phase: TimerPhase.paused);
    _publish();
  }

  /// Toggle: running → paused, paused → running. A configured but idle
  /// timer starts; a finished one dismisses for a quick restart.
  void toggle() {
    if (state.phase == TimerPhase.running) {
      pause();
    } else if (state.phase == TimerPhase.paused) {
      start();
    } else if (state.phase == TimerPhase.idle && state.total > 0) {
      start();
    } else if (state.phase == TimerPhase.done) {
      dismiss();
    }
  }

  void reset() {
    _tick?.cancel();
    _commitSession();
    _startedAtEpoch = null;
    setFocusLock(false);
    state = state.copyWith(
      phase: TimerPhase.idle,
      remaining: 0,
      total: 0,
      focus: false,
    );
    _publish();
  }

  /// After "Time's up": stops the ring but keeps the duration so the
  /// timer can be restarted right away.
  void dismiss() {
    stopSound();
    _commitSession();
    _startedAtEpoch = null;
    state = state.copyWith(phase: TimerPhase.idle, remaining: state.total);
    _publish();
  }

  /// Focus mode on → the app behaves like Do-Not-Disturb: planner
  /// alarm rings are muted until the timer finishes or focus is off.
  void toggleFocus() {
    final on = !state.focus;
    setFocusLock(on);
    state = state.copyWith(focus: on);
  }

  /// Picks the completion sound and previews it right away.
  void selectSound(String id) {
    state = state.copyWith(sound: id);
    playSound(id);
  }

  void _tickDown() {
    if (state.remaining <= 1) {
      _tick?.cancel();
      _sessionSeconds += 1;
      _commitSession();
      _startedAtEpoch = null;
      state = state.copyWith(phase: TimerPhase.done, remaining: 0);
      _publish();
      playBounded(state.sound, 5);
    } else {
      _sessionSeconds += 1;
      _startedAtEpoch ??= DateTime.now().millisecondsSinceEpoch;
      state = state.copyWith(remaining: state.remaining - 1);
      _publish();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    // No commit here: the provider tree is being torn down, and the
    // study-log notifier may already be disposed too.
    setFocusLock(false);
    super.dispose();
  }
}

final timerProvider = StateNotifierProvider<TimerNotifier, TimerStatus>(
  (ref) => TimerNotifier(
    onSessionComplete: (seconds) =>
        ref.read(studyLogProvider.notifier).addSession(seconds),
    onOverlayState: (payload) =>
        ref.read(timerOverlayProvider.notifier).publish(payload),
  ),
);

final timerOverlayProvider =
    StateNotifierProvider<TimerOverlayController, bool>((ref) {
  final controller = TimerOverlayController();
  return controller;
});
