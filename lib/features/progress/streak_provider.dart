import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../planner/planner_provider.dart';

/// Daily task goal used by the streak (default 3, user-adjustable 1..20).
class StreakGoalNotifier extends StateNotifier<int> {
  StreakGoalNotifier() : super(3) {
    _load();
  }

  static const _prefsKey = 'streak_goal_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(_prefsKey);
      if (v != null && v > 0) state = v;
    } catch (_) {
      // keep default — storage unavailable
    }
  }

  Future<void> set(int value) async {
    state = value.clamp(1, 20);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, state);
    } catch (_) {
      // ignore — state is already committed in memory
    }
  }
}

final streakGoalProvider =
    StateNotifierProvider<StreakGoalNotifier, int>((ref) => StreakGoalNotifier());

class StreakData {
  const StreakData({
    required this.streak,
    required this.best,
    required this.todayDone,
    required this.goal,
  });

  /// Consecutive days (up to and including today) that reached the goal.
  final int streak;
  /// Longest streak over the last ~400 days.
  final int best;
  /// Tasks completed today.
  final int todayDone;
  final int goal;

  bool get goalReachedToday => todayDone >= goal;
}

/// Current streak, derived purely from planner history: a day counts
/// when its completed tasks reached the daily goal. Today is included
/// once its goal is reached; until then the streak stays alive (it only
/// breaks at midnight).
final streakProvider = Provider<StreakData>((ref) {
  final tasks = ref.watch(plannerProvider);
  final goal = ref.watch(streakGoalProvider);
  final today = PlannerTask.day(DateTime.now());

  int doneOn(DateTime d) =>
      tasks.where((t) => PlannerTask.day(t.date) == d && t.done).length;
  final todayDone = doneOn(today);

  var streak = 0;
  var d = today;
  if (doneOn(d) < goal) d = d.subtract(const Duration(days: 1));
  while (doneOn(d) >= goal) {
    streak++;
    d = d.subtract(const Duration(days: 1));
  }

  var best = 0;
  var run = 0;
  for (var i = 0; i < 400; i++) {
    if (doneOn(today.subtract(Duration(days: i))) >= goal) {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }

  return StreakData(
    streak: streak,
    best: best,
    todayDone: todayDone,
    goal: goal,
  );
});
