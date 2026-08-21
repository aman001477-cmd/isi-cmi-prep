import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../../core/theme/app_logo.dart';
import '../../core/theme/theme_provider.dart';
import '../../features/syllabus/syllabus_provider.dart';
import 'profile_sheet.dart';

/// Top bar: [logo/title] ......... [streak pill] [theme toggle] [user chip]
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(appStatsProvider);
    final onTrack = stats.done > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Very narrow screens (phones in portrait) drop the streak pill
        // and the "PREP" suffix so the title + profile chip always fit.
        final compact = constraints.maxWidth < 560;
        // Small phones drop the "done" counter too — logo + title +
        // profile chip are the guaranteed-fits core.
        final mini = constraints.maxWidth < 430;

        return Container(
          color: AppColors.canvas,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const _LogoMark(),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text('PREP',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium),
                ),
                const Spacer(),
                if (!mini) _DoneBadge(done: stats.done),
                if (!compact) ...[
                  const SizedBox(width: AppSpacing.md),
                  _TrackBadge(onTrack: onTrack, pending: stats.pending),
                ],
                const SizedBox(width: AppSpacing.sm),
                const _ThemeToggle(),
                const SizedBox(width: AppSpacing.sm),
                const _ProfileChip(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        boxShadow: AppShadows.raised,
      ),
      child: const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(9)),
        child: AppLogo(size: 34),
      ),
    );
  }
}

class _DoneBadge extends StatelessWidget {
  const _DoneBadge({required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 15, color: AppColors.success),
          const SizedBox(width: 6),
          Text('$done', style: AppTypography.bodyMedium),
          const SizedBox(width: 4),
          Text('done', style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _TrackBadge extends StatelessWidget {
  const _TrackBadge({required this.onTrack, required this.pending});

  final bool onTrack;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final color = onTrack ? AppColors.success : AppColors.surfaceFaint;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: onTrack ? AppColors.success : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: onTrack ? AppColors.successDeep : AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            onTrack ? 'ON TRACK' : '$pending left',
            style: AppTypography.caption.copyWith(
              color: onTrack ? AppColors.successDeep : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final dark = ref.read(themeProvider.notifier).isDark;
    return GestureDetector(
      key: const Key('theme-toggle'),
      onTap: ref.read(themeProvider.notifier).toggleDark,
      child: Tooltip(
        message: dark ? 'Switch to light theme' : 'Switch to dark theme',
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surfaceFaint,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Icon(
            dark ? Icons.light_mode : Icons.dark_mode,
            size: 18,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('profile-chip'),
      onTap: () => showProfileSheet(context),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          boxShadow: AppShadows.raised,
        ),
        child: const Icon(Icons.person, size: 18, color: Colors.white),
      ),
    );
  }
}
