import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isi_cmi_prep/features/dashboard/marathon_provider.dart';

void main() {
  final dayStart = DateTime(2026, 8, 20);

  MarathonState st(int target, DateTime start) =>
      MarathonState(targetMinutes: target, periodStart: start);

  group('MarathonNotifier pure math', () {
    test('counts down across the day', () {
      final s = st(600, dayStart);
      final t = dayStart.add(const Duration(hours: 3));
      expect(MarathonNotifier.consumedSeconds(s, t), 3 * 3600);
      expect(MarathonNotifier.remainingSeconds(s, t), 7 * 3600);
      expect(MarathonNotifier.overSeconds(s, t), 0);
      expect(MarathonNotifier.achieved(s, t), isFalse);
    });

    test('keeps counting past the target — over time counts too', () {
      final s = st(600, dayStart);
      final t = dayStart.add(const Duration(hours: 11));
      expect(MarathonNotifier.achieved(s, t), isTrue);
      expect(MarathonNotifier.overSeconds(s, t), 3600);
      expect(MarathonNotifier.remainingSeconds(s, t), 0);
      expect(MarathonNotifier.consumedSeconds(s, t), 11 * 3600);
    });

    test('pause freezes where it is, resume continues from the frozen point',
        () {
      final s = st(600, dayStart);
      final t1 = dayStart.add(const Duration(hours: 1));
      final paused = s.copyWith(pausedAt: t1);

      // hours pass while paused — nothing consumed
      final t2 = t1.add(const Duration(hours: 4));
      expect(MarathonNotifier.runningClock(paused, t2), t1);
      expect(MarathonNotifier.consumedSeconds(paused, t2), 3600);
      expect(MarathonNotifier.remainingSeconds(paused, t2), 9 * 3600);

      // resume — frozen time is banked, counting continues
      final resumed = paused.copyWith(
        pausedAccum: paused.pausedAccum + t2.difference(paused.pausedAt!),
        clearPause: true,
      );
      expect(MarathonNotifier.consumedSeconds(resumed, t2), 3600);
      final t3 = t2.add(const Duration(hours: 1));
      expect(MarathonNotifier.consumedSeconds(resumed, t3), 2 * 3600);
    });

    test('reset starts a fresh full target from now', () {
      final s = st(600, dayStart);
      final t1 = dayStart.add(const Duration(hours: 5));
      final fresh = s.copyWith(periodStart: t1);
      expect(MarathonNotifier.consumedSeconds(fresh, t1), 0);
      expect(MarathonNotifier.remainingSeconds(fresh, t1), 10 * 3600);
      expect(MarathonNotifier.achieved(fresh, t1), isFalse);
    });

    test('midnight refill restarts the day fresh automatically', () {
      final s = st(600, dayStart.subtract(const Duration(days: 1)));
      final now = dayStart.add(const Duration(hours: 2));
      final refilled = MarathonNotifier.refillIfStale(s, now);
      expect(refilled.periodStart, dayStart);
      expect(refilled.isPaused, isFalse);
      expect(MarathonNotifier.consumedSeconds(refilled, now), 2 * 3600);
      expect(MarathonNotifier.remainingSeconds(refilled, now), 8 * 3600);
    });

    test('paused across midnight is also refilled', () {
      final s = st(600, dayStart)
          .copyWith(pausedAt: dayStart.add(const Duration(hours: 23)));
      final now = dayStart.add(const Duration(days: 1, hours: 1));
      final refilled = MarathonNotifier.refillIfStale(s, now);
      expect(refilled.isPaused, isFalse);
      expect(refilled.periodStart, MarathonNotifier.dayStart(now));
      expect(MarathonNotifier.consumedSeconds(refilled, now), 3600);
    });
  });

  group('MarathonNotifier persistence', () {
    test('pause state survives a provider restart', () async {
      SharedPreferences.setMockInitialValues({});
      final n1 = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await n1.pause();

      final n2 = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(n2.state.isPaused, isTrue);

      await n2.resume();
      final n3 = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(n3.state.isPaused, isFalse);
    });

    test('target selection persists', () async {
      SharedPreferences.setMockInitialValues({});
      final n1 = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await n1.setTargetMinutes(8 * 60);

      final n2 = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(n2.state.targetMinutes, 8 * 60);
    });
  });

  group('MarathonNotifier laps', () {
    test('every Pause closes the running stretch as a lap', () async {
      SharedPreferences.setMockInitialValues({});
      final n = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      await n.pause();
      expect(n.state.laps.length, 1);
      expect(n.state.laps.first.end.isAfter(n.state.laps.first.start), isTrue);
      expect(n.state.laps.first.durationSeconds,
          greaterThanOrEqualTo(0));
      expect(n.state.runningSince, isNull);

      await n.resume();
      expect(n.state.laps.length, 1);
      expect(n.state.runningSince, isNotNull);

      // let real time pass so the second lap is strictly longer than nothing
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await n.pause();
      expect(n.state.laps.length, 2);
      expect(n.state.laps[1].start.isAfter(n.state.laps[0].end), isTrue);
      expect(n.state.laps[1].start.isBefore(n.state.laps[1].end), isTrue);
    });

    test('pause while paused adds no lap', () async {
      SharedPreferences.setMockInitialValues({});
      final n = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await n.pause();
      await n.pause();
      expect(n.state.laps.length, 1);
    });

    test('laps persist across a provider restart', () async {
      SharedPreferences.setMockInitialValues({});
      final n1 = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await n1.pause();
      await n1.resume();
      await n1.pause();
      expect(n1.state.laps.length, 2);

      final n2 = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(n2.state.laps.length, 2);
      expect(n2.state.runningSince, isNull);
    });

    test('reset clears every lap and opens a fresh stretch', () async {
      SharedPreferences.setMockInitialValues({});
      final n = MarathonNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await n.pause();
      await n.resume();
      await n.pause();
      await n.reset();
      expect(n.state.laps, isEmpty);
      expect(n.state.isPaused, isFalse);
      expect(n.state.runningSince, isNotNull);
    });

    test('midnight refill starts the day without laps', () {
      final yesterday = dayStart.subtract(const Duration(hours: 3));
      final s = MarathonState(
        targetMinutes: 600,
        periodStart: yesterday,
        runningSince: yesterday,
        laps: [
          MarathonLap(start: dayStart, end: dayStart),
        ],
      );
      final now = dayStart.add(const Duration(hours: 1));
      final refilled = MarathonNotifier.refillIfStale(s, now);
      expect(refilled.laps, isEmpty);
      expect(refilled.runningSince, dayStart);
    });
  });
}