import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../../features/syllabus/syllabus_provider.dart';
import 'main_shell.dart';

/// LEFT SIDEBAR (20%) — flat white anchor with nav links
/// and a soft utility card at the bottom.
class LeftRail extends StatelessWidget {
  const LeftRail({
    super.key,
    required this.destinations,
    required this.index,
    required this.onSelected,
  });

  final List<ShellDestination> destinations;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          ...List.generate(destinations.length, (i) {
            final d = destinations[i];
            return _NavLink(
              icon: d.icon,
              label: d.label,
              active: i == index,
              onTap: () => onSelected(i),
            );
          }),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _UtilityCard(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 3,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: active
                ? Border.all(color: AppColors.accent, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 19,
                  color: active ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: active ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft Utility Card — flat block hosting real completion data.
class _UtilityCard extends ConsumerWidget {
  const _UtilityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(appStatsProvider);
    final percent = stats.coverage * 100;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.standard),
        boxShadow: AppShadows.flatCard,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 15, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text('Completion', style: AppTypography.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('${stats.done} of ${stats.nodes} items done',
              style: AppTypography.small),
          const SizedBox(height: AppSpacing.sm),
          _GoalBar(progress: stats.coverage),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('${percent.round()}% complete',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      )),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('${stats.pending} to go',
                  style: AppTypography.caption.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('${(progress * 100).round()}% complete',
            style: AppTypography.caption),
      ],
    );
  }
}
