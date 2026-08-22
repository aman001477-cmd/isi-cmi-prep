import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../planner/planner_provider.dart';
import '../syllabus/syllabus_provider.dart';
import '../reminders/reminders_provider.dart';
import 'marathon_provider.dart';
import 'timer_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(plannerProvider);
    final syllabus = ref.watch(syllabusProvider);
    final reminders = ref.watch(remindersProvider);
    final marathon = ref.watch(marathonProvider);
    final timer = ref.watch(timerProvider);

    final todayTasks = tasks.where((t) => t.isToday).toList();
    final doneToday = todayTasks.where((t) => t.done).length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 80,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Dashboard', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent.withValues(alpha: 0.12), AppColors.canvas],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList.list(
              children: [
                // Exam Hero
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
                      Text('Exam hero', style: AppTypography.titleMedium),
                      const SizedBox(height: 8),
                      Text('Set your exam name and date', style: AppTypography.caption),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Timers
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
                        child: Column(children: [
                          Text('Focus Timer', style: AppTypography.titleMedium),
                          const SizedBox(height: 8),
                          Text(timer.remaining != null ? '${timer.remaining}' : '25:00', style: AppTypography.titleLarge),
                        ]),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
                        child: Column(children: [
                          Text('Daily Fix Timer', style: AppTypography.titleMedium),
                          const SizedBox(height: 8),
                          Text('24:00:00', style: AppTypography.titleLarge),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Quick stats
                Row(
                  children: [
                    Expanded(child: _StatCard(title: 'Tasks', value: '$doneToday/${todayTasks.length}', subtitle: 'Today', icon: Icons.task_alt_rounded, color: AppColors.accent)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _StatCard(title: 'Syllabus', value: '${syllabus.length}', subtitle: 'Topics', icon: Icons.menu_book_rounded, color: AppColors.warning)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _StatCard(title: 'Reminders', value: '${reminders.length}', subtitle: 'Upcoming', icon: Icons.notifications_rounded, color: AppColors.success)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Mock test trend
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Mock test trend', style: AppTypography.titleMedium),
                    const SizedBox(height: 8),
                    Text('Avg 70% across 1 attempt', style: AppTypography.caption),
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Daily history
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Daily history', style: AppTypography.titleMedium),
                    const SizedBox(height: 8),
                    Text('2/2 tasks', style: AppTypography.body),
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Weekly stats
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Weekly stats', style: AppTypography.titleMedium),
                    const SizedBox(height: 8),
                    Text('2 tasks this week - first week tracked', style: AppTypography.caption),
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Today's tasks
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Today's Tasks", style: AppTypography.titleMedium),
                    const SizedBox(height: 8),
                    if (todayTasks.isEmpty)
                      Text('No tasks for today', style: AppTypography.caption)
                    else
                      ...todayTasks.take(5).map((t) => ListTile(
                            leading: Checkbox(value: t.done, onChanged: null),
                            title: Text(t.title),
                            trailing: t.locked ? const Icon(Icons.lock_rounded, size: 18, color: Colors.orange) : null,
                          )),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Text('60%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
        ]),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(title, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
        Text(subtitle, style: AppTypography.caption.copyWith(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }
}
