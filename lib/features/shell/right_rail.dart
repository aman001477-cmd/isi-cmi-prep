import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../../features/syllabus/syllabus_provider.dart';
import '../../shared/widgets/neu_button.dart';
import '../../shared/widgets/neu_container.dart';
import '../../shared/widgets/neu_input.dart';
import '../../shared/widgets/neu_toggle.dart';

/// RIGHT SIDEBAR (25%) — dedicated tactile neumorphic control zone:
/// status grid block · quick memo pad · action control.
class RightRail extends ConsumerStatefulWidget {
  const RightRail({super.key, required this.onOpenPlanner});

  final VoidCallback onOpenPlanner;

  @override
  ConsumerState<RightRail> createState() => _RightRailState();
}

class _RightRailState extends ConsumerState<RightRail> {
  final _memo = TextEditingController();
  bool _focusMode = false;
  int _pomodoro = 5;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(appStatsProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceFaint, AppColors.canvas],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusGrid(stats: stats),
            const SizedBox(height: AppSpacing.lg),
            _MemoPad(controller: _memo),
            const SizedBox(height: AppSpacing.lg),
            _FocusControl(
              focusMode: _focusMode,
              pomodoro: _pomodoro,
              onToggleFocus: (v) => setState(() => _focusMode = v),
              onPomodoroIncrease: () =>
                  setState(() => _pomodoro = _pomodoro >= 25 ? 5 : _pomodoro + 5),
            ),
            const SizedBox(height: AppSpacing.lg),
            NeuButton(
              label: 'Open To Do List',
              icon: Icons.event_outlined,
              filled: true,
              onPressed: widget.onOpenPlanner,
            ),
          ],
        ),
      ),
    );
  }
}

/// Status grid block — 2×2 metric tiles fed by real app data.
class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.stats});

  final AppStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Items', '${stats.nodes}', AppColors.accent),
      ('Done', '${stats.done}', AppColors.success),
      ('Attempts', '${stats.attempts}', AppColors.accent),
      ('Revisions', '${stats.scheduled}', AppColors.success),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STATUS', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.35,
          children: tiles
              .map((t) => NeuContainer.flat(
                    radius: AppRadius.standard,
                    color: AppColors.surface,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.$2,
                            style: AppTypography.titleMedium.copyWith(
                              color: t.$3,
                              fontSize: 20,
                            )),
                        const SizedBox(height: 2),
                        Text(t.$1, style: AppTypography.caption),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

/// Quick memo pad — flat card, engraved well for scratch notes.
class _MemoPad extends StatelessWidget {
  const _MemoPad({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.standard),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.flatCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 15, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Quick Memo', style: AppTypography.label),
              ),
              Text('auto-saved',
                  style: AppTypography.caption.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          NeuInput(
            controller: controller,
            hint: 'jot the idea…',
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

/// Tactile control widget — focus-mode toggle + pomodoro stepper.
class _FocusControl extends StatelessWidget {
  const _FocusControl({
    required this.focusMode,
    required this.pomodoro,
    required this.onToggleFocus,
    required this.onPomodoroIncrease,
  });

  final bool focusMode;
  final int pomodoro;
  final ValueChanged<bool> onToggleFocus;
  final VoidCallback onPomodoroIncrease;

  @override
  Widget build(BuildContext context) {
    return NeuContainer.raised(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FOCUS', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Deep focus', style: AppTypography.label),
              NeuToggle(
                value: focusMode,
                onChanged: onToggleFocus,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Session', style: AppTypography.label),
              _PomodoroPill(
                minutes: pomodoro,
                onTap: onPomodoroIncrease,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PomodoroPill extends StatelessWidget {
  const _PomodoroPill({required this.minutes, required this.onTap});

  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.raised,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$minutes min', style: AppTypography.label),
            const SizedBox(width: 6),
            Icon(Icons.add, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
