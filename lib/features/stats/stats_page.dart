import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../../shared/widgets/data_card.dart';
import '../planner/planner_provider.dart';
import '../planner/mock_test_provider.dart';
import '../progress/mock_results_provider.dart';
import '../progress/streak_provider.dart';
import '../progress/study_log_provider.dart';

/// STATS â€” streak card (goal stepper + daily history), weekly bars and
/// mock-test trend/results. Everything derived from live providers.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final goal = ref.watch(streakGoalProvider);
    final tasks = ref.watch(plannerProvider);
    final mocks = ref.watch(mockResultsProvider);
    final mockDays = ref.watch(mockDaysProvider);
    final study = ref.watch(studyLogProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StreakCard(streak: streak, goal: goal),
          const SizedBox(height: AppSpacing.xl),
          _WeeklyCard(tasks: tasks),
          const SizedBox(height: AppSpacing.xl),
          _MockTrendCard(mocks: mocks, mockDays: mockDays),
          const SizedBox(height: AppSpacing.xl),
          if (study.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Study log', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...study.entries
                      .toList()
                      .reversed
                      .take(7)
                      .map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key, style: AppTypography.caption),
                                Text('${e.value} min',
                                    style: AppTypography.body.copyWith(
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------- streak */

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.goal});

  final StreakData streak;
  final int goal;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      title: 'Progress & goals',
      subtitle: streak.goalReachedToday
          ? 'Aaj ka target poora â€” streak chal rahi hai'
          : 'Aaj ke ${streak.goal - streak.todayDone} tasks baaki hain',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔥 ${streak.streak}-day streak',
                        key: const Key('streak-value-card'),
                        style: AppTypography.titleLarge.copyWith(
                            color: AppColors.accent, fontSize: 26)),
                    Text('best ${streak.best}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _GoalStepper(
                value: goal,
                upKey: 'streak-goal-up-card',
                downKey: 'streak-goal-down-card',
                valueKey: 'streak-goal-value-card',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: streak.goal == 0
                ? 0
                : (streak.todayDone / streak.goal).clamp(0.0, 1.0),
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Today: ${streak.todayDone}/$goal tasks',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          const _DailyHistory(),
        ],
      ),
    );
  }
}

class _GoalStepper extends ConsumerWidget {
  const _GoalStepper({
    required this.value,
    required this.upKey,
    required this.downKey,
    required this.valueKey,
  });

  final int value;
  final String upKey;
  final String downKey;
  final String valueKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(streakGoalProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: Key(downKey),
          onPressed: () => notifier.set(value - 1 < 1 ? 1 : value - 1),
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('$value',
              key: Key(valueKey), style: AppTypography.titleLarge),
        ),
        IconButton.filledTonal(
          key: Key(upKey),
          onPressed: () => notifier.set(value + 1 > 24 ? 24 : value + 1),
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }
}

class _DailyHistory extends ConsumerWidget {
  const _DailyHistory();

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(plannerProvider);
    final goal = ref.watch(streakGoalProvider);

    // group done-tasks per day for the last 7 days
    final byDay = <String, int>{};
    for (final t in tasks) {
      if (!t.done) continue;
      final k = _key(t.date);
      byDay[k] = (byDay[k] ?? 0) + 1;
    }

    final rows = <Widget>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final k = _key(d);
      final done = byDay[k] ?? 0;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 84,
                child: Text(i == 0 ? 'Today' : '${d.day}/${d.month}',
                    style: AppTypography.caption)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal == 0 ? 0 : (done / goal).clamp(0.0, 1.0),
                  backgroundColor: AppColors.surfaceFaint,
                  valueColor: AlwaysStoppedAnimation(done >= goal
                      ? AppColors.success
                      : AppColors.accent),
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
                width: 56,
                child: Text('$done/$goal tasks',
                    textAlign: TextAlign.right,
                    style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700))),
          ],
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Daily history', style: AppTypography.label),
      const SizedBox(height: 4),
      ...rows,
    ]);
  }
}

/* ------------------------------------------------------------- weekly */

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.tasks});

  final List<PlannerTask> tasks;

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final counts = List<int>.filled(7, 0); // Mon..Sun
    for (final t in tasks) {
      if (!t.done) continue;
      final diff = PlannerTask.day(now)
          .difference(PlannerTask.day(t.date))
          .inDays;
      if (diff >= 0 && diff < 7) {
        counts[6 - diff]++; // oldest â†’ today left-to-right
      }
    }
    final total = counts.fold<int>(0, (a, b) => a + b);
    final max = counts.fold<int>(1, (a, b) => a > b ? a : b);

    return DataCard(
      title: 'Weekly stats',
      subtitle: total == 0
          ? 'No completed tasks in the last 7 days'
          : '$total tasks this week — first week tracked',
      body: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${counts[i]}',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 10)),
                      const SizedBox(height: 4),
                      FractionallySizedBox(
                        widthFactor: 0.7,
                        child: Container(
                          height: 80 * (counts[i] / max).clamp(0.05, 1.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.accent.withValues(alpha: 0.55),
                              AppColors.accent,
                            ], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][
                              (now.weekday + i) % 7],
                          style: AppTypography.caption.copyWith(fontSize: 9)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------- mock trend */

class _MockTrendCard extends StatelessWidget {
  const _MockTrendCard({required this.mocks, required this.mockDays});

  final Map<String, MockResult> mocks;
  final Set<String> mockDays;

  @override
  Widget build(BuildContext context) {
    final entries = mocks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final avgPct = entries.isEmpty
        ? 0.0
        : entries.map((e) => e.value.percent).reduce((a, b) => a + b) /
            entries.length;

    return DataCard(
      title: 'Mock test trend',
      subtitle: entries.isEmpty
          ? 'Calendar pe kisi din ko Mock mark karke score daalo'
          : entries.length == 1
              ? 'Avg ${avgPct.round()}% across ${entries.length} attempt'
              : 'Avg ${avgPct.round()}% across ${entries.length} attempts',
      body: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text('Koi mock result nahi',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: avgPct / 100,
                          backgroundColor: AppColors.surfaceFaint,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.accent),
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('${avgPct.round()}%',
                        style: AppTypography.titleMedium.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Mock test results', style: AppTypography.label),
                const SizedBox(height: 4),
                ...entries.reversed.take(8).map((e) {
                  final day = DateTime.tryParse(e.key);
                  final label = day == null
                      ? e.key
                      : '${day.day}/${day.month}/${day.year}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(label, style: AppTypography.caption),
                        const Spacer(),
                        Text(
                            '${e.value.marks.round()}/${e.value.max.round()} · ${e.value.percent.round()}%',
                            style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}




