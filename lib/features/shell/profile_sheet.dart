import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/backup/backup_files.dart';
import '../../core/backup/backup_service.dart';
import '../../core/auth/session_provider.dart';
import '../../core/cloud/cloud_sync.dart';
import '../../core/mailto/mailto_opener.dart';
import '../../core/theme/app_design_system.dart';
import '../../core/theme/app_logo.dart';
import '../../core/theme/theme_palettes.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/time_format.dart';
import '../../features/planner/marker_provider.dart';
import '../../features/planner/mock_test_provider.dart';
import '../../features/planner/planner_provider.dart';
import '../../features/progress/daily_plan.dart';
import '../../features/progress/mock_results_provider.dart';
import '../../features/progress/streak_provider.dart';
import '../../features/progress/study_log_provider.dart';
import '../../features/reminders/reminder_widgets.dart';
import '../../features/schedule/schedule_provider.dart';
import '../../features/syllabus/exam_countdown_provider.dart';
import '../../features/syllabus/syllabus_provider.dart';
import '../../shared/widgets/clock_input.dart';
import '../../shared/widgets/data_card.dart';import '../../shared/widgets/neu_toggle.dart';

/// The developer's contact inbox for errors, feedback and ideas.
const String developerEmail = 'zen201247007@gmail.com';

/// Opens the profile sheet from the top-right avatar chip.
void showProfileSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
    ),
    builder: (_) => const ProfileSheet(),
  );
}

/// Profile sheet — greeting, a message from the developer, and the
/// usual profile actions (contact, about, reset).
class ProfileSheet extends ConsumerWidget {
  const ProfileSheet({super.key});

  Future<void> _resetAll(WidgetRef ref) async {
    await Future.wait([
      ref.read(plannerProvider.notifier).clear(),
      ref.read(scheduleProvider.notifier).clear(),
      ref.read(mockDaysProvider.notifier).clear(),
      ref.read(markersProvider.notifier).clear(),
      ref.read(examCountdownProvider.notifier).clear(),
      ref.read(pinnedExamProvider.notifier).clear(),
      ref.read(syllabusProvider.notifier).clear(),
      ref.read(mockResultsProvider.notifier).clear(),
      ref.read(studyLogProvider.notifier).clear(),
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Re-create every persisted provider so in-memory state matches the
    // wiped storage (each notifier re-reads prefs in its constructor).
    ref.invalidate(streakGoalProvider);
    ref.invalidate(mockResultsProvider);
    ref.invalidate(dailyPlanProvider);
    ref.invalidate(pinnedExamProvider);
    ref.invalidate(studyLogProvider);
  }

  Future<void> _exportData(BuildContext context) async {
    final doc = await collectBackup();
    final saved = await saveBackupFile(
      encodeBackup(doc),
      defaultBackupFileName(doc.savedAt),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Backup downloaded — keep the file safe!'
              : 'Export cancelled',
        ),
      ),
    );
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final raw = await pickBackupFile();
    if (raw == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import cancelled — no file selected')),
      );
      return;
    }
    final doc = decodeBackup(raw);
    if (doc == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not a valid backup file')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.standard),
        ),
        title: Text('Restore from backup?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This replaces all current data with the backup '
          '(${doc.data.length} entries, saved '
          '${doc.savedAt.toLocal().toString().substring(0, 16)}).',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            key: const Key('import-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Restore',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final written = await applyBackup(doc);
    // Re-create every persisted provider so in-memory state matches the
    // restored storage (each notifier re-reads prefs in its constructor).
    ref.invalidate(plannerProvider);
    ref.invalidate(scheduleProvider);
    ref.invalidate(mockDaysProvider);
    ref.invalidate(markersProvider);
    ref.invalidate(examCountdownProvider);
    ref.invalidate(syllabusProvider);
    ref.invalidate(streakGoalProvider);
    ref.invalidate(mockResultsProvider);
    ref.invalidate(dailyPlanProvider);
    ref.invalidate(pinnedExamProvider);
    ref.invalidate(themeProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup restored — $written entries loaded')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.raised,
                  ),
                  child: const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: AppLogo(size: 44),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prep', style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text('Your prep desk',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Hello! Welcome to your Prep Desk.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Consistency beats intensity — plan your day, mark your '
              'mock tests, and keep the streak alive. All the best for '
              'ISI · CMI!',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SessionCard(),
            const SizedBox(height: AppSpacing.lg),
            DataCard(
              title: 'Message from Developer',
              body: Text(
                'Hi! This app is built to make your prep a daily habit — '
                'planner, weekly schedule, mock-test marks and exam '
                'countdowns in one place. Koi error aaye ya koi '
                'recommendation ho, toh email karo — I read every '
                'single one.',
                style: AppTypography.small,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SheetOption(
              key: const Key('profile-email'),
              icon: Icons.mail_outline,
              title: 'Email the developer',
              subtitle: developerEmail,
              onTap: () {
                Navigator.of(context).pop();
                openMailto(developerEmail,
                    subject: 'Prep — feedback');
              },
            ),
            _SheetOption(
              key: const Key('profile-about'),
              icon: Icons.info_outline,
              title: 'About this app',
              subtitle: 'Version 1.0.0',
              onTap: () => _showAbout(context),
            ),
            const SizedBox(height: 4),
            _ThemePicker(),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceFaint,
                borderRadius: BorderRadius.circular(AppRadius.standard),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.audiotrack_outlined,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Alarm sound'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const RingtoneRow(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceFaint,
                borderRadius: BorderRadius.circular(AppRadius.standard),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_outlined,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text('Progress & goals',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _DailyGoalRow(),
                  const SizedBox(height: AppSpacing.sm),
                  const _PlanNotifRow(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceFaint,
                borderRadius: BorderRadius.circular(AppRadius.standard),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup_outlined,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Backup & Restore', style: AppTypography.label),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _BackupRow(
                    key: const Key('profile-export'),
                    icon: Icons.download_outlined,
                    title: 'Export data',
                    subtitle: 'Save all progress to a backup file',
                    onTap: () => _exportData(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _BackupRow(
                    key: const Key('profile-import'),
                    icon: Icons.upload_file_outlined,
                    title: 'Import data',
                    subtitle: 'Restore progress from a backup file',
                    onTap: () => _importData(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SheetOption(
              key: const Key('profile-reset'),
              icon: Icons.delete_forever_outlined,
              title: 'Reset all data',
              subtitle: 'Clears tasks, schedule, mock marks & countdowns',
              danger: true,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.standard),
                    ),
                    title: Text('Reset all data?',
                        style: TextStyle(color: AppColors.textPrimary)),
                    content: Text(
                      'This clears planner tasks, schedule slots, '
                      'mock-test marks and exam countdowns. The syllabus '
                      'seed comes back fresh.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        key: const Key('reset-confirm'),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('Reset',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await _resetAll(ref);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('All data cleared — fresh start!')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.standard),
        ),
        title: Text('About Prep',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Version 1.0.0\n\nYour daily prep desk: syllabus tracker, '
          'planner with alarm sounds, weekly schedule, mock-test '
          'calendar and exam countdowns. All data lives only in your '
          'browser.\n\nTip: after every update, hard-refresh '
          '(Ctrl + Shift + R) to load the newest build.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

/// Daily-goal stepper — how many tasks make a streak day (1..20).
class _DailyGoalRow extends ConsumerWidget {
  const _DailyGoalRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(streakGoalProvider);
    final notifier = ref.read(streakGoalProvider.notifier);

    Widget stepButton(IconData icon, Key key, VoidCallback onTap) =>
        GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Icon(icon, size: 15, color: AppColors.accent),
          ),
        );

    return Row(
      children: [
        Expanded(child: Text('Daily goal', style: AppTypography.label)),
        stepButton(Icons.remove,
            const Key('streak-goal-down'), () => notifier.set(goal - 1)),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 32,
          child: Text(
            '$goal',
            key: const Key('streak-goal-value'),
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(color: AppColors.accent),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        stepButton(Icons.add,
            const Key('streak-goal-up'), () => notifier.set(goal + 1)),
      ],
    );
  }
}

/// Toggle + time for the daily "tomorrow's plan" notification — ring
/// time is fully user-picked (morning start, evening review, whatever
/// suits the routine).
class _PlanNotifRow extends ConsumerWidget {
  const _PlanNotifRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(dailyPlanProvider);
    final notifier = ref.read(dailyPlanProvider.notifier);
    final use24h = ref.watch(timeFormatProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily plan notification', style: AppTypography.label),
                  const SizedBox(height: 2),
                  Text(
                    config.timeLabel == '21:00'
                        ? 'Rings at 9 PM with tomorrow’s plan'
                        : 'Rings at '
                            '${fmtClockTime(config.hour, config.minute, use24h: use24h)}',
                    style: AppTypography.caption.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            NeuToggle(
              key: const Key('plan-notif-toggle'),
              value: config.enabled,
              onChanged: (v) => notifier.setEnabled(v),
            ),
          ],
        ),
        if (config.enabled) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClockInput(
                keyPrefix: 'plan-notif-hour',
                isHour: true,
                value: config.hour,
                onChanged: (v) => notifier.setTime(v % 24, config.minute),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(':',
                    style: AppTypography.titleMedium.copyWith(fontSize: 18)),
              ),
              ClockInput(
                keyPrefix: 'plan-notif-min',
                isHour: false,
                value: config.minute,
                onChanged: (v) => notifier.setTime(config.hour, v % 60),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Theme picker — one swatch per palette, applies instantly app-wide.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceFaint,
        borderRadius: BorderRadius.circular(AppRadius.standard),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text('Theme', style: AppTypography.label),
              const Spacer(),
              Text(
                themeOptionFor(current)?.label ?? current,
                style: AppTypography.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in themeCatalog)
                GestureDetector(
                  key: Key('theme-${option.id}'),
                  onTap: () => ref.read(themeProvider.notifier).select(option.id),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: option.swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: current == option.id
                              ? AppColors.textPrimary
                              : AppColors.border,
                          width: current == option.id ? 2.5 : 1,
                        ),
                        boxShadow: AppShadows.raised,
                      ),
                    child: current == option.id
                        ? const Icon(Icons.check,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One backup action row (export / import) inside the backup card.
class _BackupRow extends StatelessWidget {
  const _BackupRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.standard),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.label),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// The active account: name, role and a Logout row (back to the login
/// screen — data stays safe in the user's slot).
class _SessionCard extends ConsumerWidget {
  const _SessionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final account = session.account;
    if (account == null) return const SizedBox.shrink();
    return DataCard(
      key: const Key('profile-session'),
      title: 'Signed in as',
      subtitle: account.isAdmin ? 'admin · full access' : 'user',
      body: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accent.withValues(alpha: 0.14),
            child: Text(
              account.name.characters.first.toUpperCase(),
              style: TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${account.name} (${account.id})',
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(CloudSync.cloudReady
                    ? 'Cloud sync ON'
                    : 'Local-only mode',
                    style: AppTypography.caption.copyWith(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('profile-logout'),
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: danger
                ? AppColors.danger.withValues(alpha: 0.06)
                : AppColors.surfaceFaint,
            borderRadius: BorderRadius.circular(AppRadius.standard),
            border: Border.all(
              color: danger ? AppColors.danger : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.label.copyWith(
                          color: danger
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
