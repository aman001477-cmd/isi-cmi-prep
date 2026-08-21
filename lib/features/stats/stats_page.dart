import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_design_system.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Stats', style: AppTypography.titleLarge)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mock test trend', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              Text('Avg 70% across 1 attempt', style: AppTypography.caption),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: 0.7, backgroundColor: AppColors.accent.withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(AppColors.accent), minHeight: 8, borderRadius: BorderRadius.circular(4)),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Weekly stats', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              Text('2 tasks this week - first week tracked', style: AppTypography.caption),
              const SizedBox(height: 8),
              Text('Daily history', style: AppTypography.titleMedium),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Streak', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              Text('?? 2-day streak', style: AppTypography.body),
              Text('Today: 2/2 tasks', style: AppTypography.caption),
            ]),
          ),
        ],
      ),
    );
  }
}
