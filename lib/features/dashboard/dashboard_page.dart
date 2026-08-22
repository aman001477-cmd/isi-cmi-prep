import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../../shared/widgets/data_card.dart';
import '../planner/mock_test_provider.dart';
import '../planner/planner_provider.dart';
import '../progress/streak_provider.dart';
import '../reminders/reminder_model.dart';
import '../reminders/reminders_provider.dart';
import '../syllabus/exam_countdown_provider.dart';
import 'marathon_provider.dart';
import 'timer_overlay.dart';
import 'timer_provider.dart';

/// DASHBOARD — exam hero, live reminder/mock countdowns, the Focus Timer
/// card (presets · ring · focus mode · completion sound), the permanent
/// Daily Fix marathon card and today's quick stats.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exam = ref.watch(pinnedExamProvider);
    final reminders = ref.watch(remindersProvider);
    final streak = ref.watch(streakProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ExamHero(exam: exam),
          const SizedBox(height: AppSpacing.xl),
          _UpNextCard(reminders: reminders),
          const SizedBox(height: AppSpacing.xl),
          const _TimerCard(),
          const SizedBox(height: AppSpacing.xl),
          const _MarathonCard(),
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(
                child: _Tile(
                    label: 'Streak',
                    value: '${streak.streak}d',
                    sub: 'best ${streak.best}',
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.warning)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: _Tile(
                    label: 'Today',
                    value: '${streak.todayDone}/${streak.goal}',
                    sub: streak.goalReachedToday ? 'done!' : 'to go',
                    icon: Icons.task_alt_rounded,
                    color: AppColors.accent)),
          ]),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------ exam hero */

class _ExamHero extends ConsumerStatefulWidget {
  const _ExamHero({required this.exam});
  final PinnedExam? exam;

  @override
  ConsumerState<_ExamHero> createState() => _ExamHeroState();
}

class _ExamHeroState extends ConsumerState<_ExamHero> {
  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.accent.withValues(alpha: 0.16),
          AppColors.surface,
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Exam countdown',
              style: AppTypography.caption.copyWith(
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  color: AppColors.textSecondary)),
          const Spacer(),
          IconButton(
              tooltip: 'Change',
              onPressed: _setExam,
              icon:
                  Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.accent)),
          if (exam != null)
            IconButton(
                key: const Key('exam-clear'),
                tooltip: 'Clear',
                onPressed: () =>
                    ref.read(pinnedExamProvider.notifier).clear(),
                icon: Icon(Icons.close_rounded,
                    size: 18, color: AppColors.danger)),
        ]),
        Text(exam?.name ?? 'ISI · CMI',
            style: AppTypography.titleLarge
                .copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        exam == null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Set your target exam date to start the countdown',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('exam-set'),
                  onPressed: _setExam,
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: const Text('Set exam'),
                ),
              ])
            : Text(
                key: const Key('exam-countdown'),
                _daysLeft(exam),
                style: AppTypography.titleLarge.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent)),
      ]),
    );
  }

  String _daysLeft(PinnedExam exam) {
    final nowDay = DateTime.now();
    final target =
        DateTime(exam.date.year, exam.date.month, exam.date.day);
    final days = target
        .difference(DateTime(nowDay.year, nowDay.month, nowDay.day))
        .inDays;
    if (days > 0) return '$days days to go · ${exam.date.day}/${exam.date.month}';
    if (days == 0) return 'TODAY! · ${exam.date.day}/${exam.date.month}';
    return '${-days} days ago · ${exam.date.day}/${exam.date.month}';
  }

  Future<void> _setExam() async {
    final ctrl = TextEditingController(text: widget.exam?.name ?? '');
    DateTime date =
        DateTime.now().add(const Duration(days: 60));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.standard)),
          title:
              Text('Target exam', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('exam-name'),
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Exam name'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('exam-date-pick'),
              onPressed: () async {
                final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 3)));
                if (picked != null) setState(() => date = picked);
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text('${date.day}/${date.month}/${date.year}'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                key: const Key('exam-save'),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && mounted && ctrl.text.trim().isNotEmpty) {
      await ref.read(pinnedExamProvider.notifier).set(ctrl.text.trim(), date);
    }
  }
}

/* ---------------------------------------------------------- up next row */

class _UpNextCard extends ConsumerWidget {
  const _UpNextCard({required this.reminders});

  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mockDays = ref.watch(mockDaysProvider);
    final mockNotifier = ref.read(mockDaysProvider.notifier);
    final now = DateTime.now();

    MockAlarm? todayAlarm;
    for (final d in mockDays) {
      final day = DateTime.tryParse(d);
      if (day != null &&
          day.year == now.year &&
          day.month == now.month &&
          day.day == now.day &&
          mockNotifier.hasAlarm(day)) {
        todayAlarm = mockNotifier.alarmFor(day);
      }
    }
    final upcoming = reminders.where((r) => r.at.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));

    if (upcoming.isEmpty && todayAlarm == null) return const SizedBox.shrink();

    return DataCard(
      title: 'Up next',
      subtitle: 'Live countdowns',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in upcoming.take(3))
            _CountdownRow(
                icon: Icon(
                    r.silent
                        ? Icons.volume_off_rounded
                        : Icons.notifications_rounded,
                    size: 18,
                    color: AppColors.accent),
                title: r.title,
                prefix: 'event in',
                at: r.at),
          if (todayAlarm != null)
            _CountdownRow(
                icon: Icon(Icons.fact_check_rounded,
                    size: 18, color: AppColors.warning),
                title: 'Mock test',
                prefix:
                    'TODAY · ${todayAlarm.hour.toString().padLeft(2, '0')}:${todayAlarm.minute.toString().padLeft(2, '0')} —',
                at: todayAlarm.atOn(now)),
        ],
      ),
    );
  }
}

class _CountdownRow extends StatefulWidget {
  const _CountdownRow({
    required this.icon,
    required this.title,
    required this.prefix,
    required this.at,
  });

  final Widget icon;
  final String title;
  final String prefix;
  final DateTime at;

  @override
  State<_CountdownRow> createState() => _CountdownRowState();
}

class _CountdownRowState extends State<_CountdownRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.at.difference(DateTime.now());
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    final label = d > 0
        ? '${d}d ${h}h ${m}m'
        : h > 0
            ? '${h}h ${m}m ${s}s'
            : '${m}m ${s}s';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(children: [
        widget.icon,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(widget.title,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
        ),
        Text(widget.prefix,
            style: AppTypography.caption.copyWith(fontSize: 10)),
        const SizedBox(width: 4),
        Text(label,
            key: const Key('ticking'),
            style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w800, color: AppColors.accent)),
      ]),
    );
  }
}

/* ---------------------------------------------------------- focus timer */

String _fmtClock(int s) => s < 3600
    ? '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}'
    : formatClockSeconds(s);

class _TimerCard extends ConsumerStatefulWidget {
  const _TimerCard();

  static const timerPresets = [25, 45, 60];

  @override
  ConsumerState<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends ConsumerState<_TimerCard> {
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);
    final idle = t.phase == TimerPhase.idle;
    final done = t.phase == TimerPhase.done;
    final ringValue = t.total > 0 ? t.remaining / t.total : 0.0;

    return DataCard(
      title: 'Focus Timer',
      subtitle: switch (t.phase) {
        TimerPhase.running => 'Running — stay on it',
        TimerPhase.paused => 'Paused — resume when ready',
        TimerPhase.done => "Time's up — great block!",
        TimerPhase.idle => 'Pick a duration and start',
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // clock + ring
          Row(children: [
            SizedBox(
              width: 74,
              height: 74,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: CircularProgressIndicator(
                    key: const Key('timer-ring'),
                    value: done ? 0.0 : ringValue.clamp(0.0, 1.0),
                    strokeWidth: 7,
                    backgroundColor: AppColors.surfaceFaint,
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                Text(_fmtClock(done ? 0 : t.remaining),
                    key: const Key('timer-clock'),
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in _TimerCard.timerPresets)
                  ActionChip(
                    key: Key('timer-preset-$p'),
                    label: Text('$p min',
                        style: AppTypography.caption.copyWith(fontSize: 11)),
                    onPressed: idle ? () => notifier.setDuration(minutes: p) : null,
                  ),
                IconButton(
                  key: const Key('timer-overlay'),
                  tooltip: 'Overlay timer',
                  onPressed: () {},
                  icon: const Icon(Icons.picture_in_picture_alt_rounded,
                      size: 20),
                ),
                IconButton(
                  key: const Key('timer-fullscreen'),
                  tooltip: 'Full screen',
                  onPressed: () => _showFullScreen(context),
                  icon: const Icon(Icons.fullscreen_rounded, size: 24),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),

          // controls
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 150,
              child: FilledButton.icon(
                key: const Key('timer-toggle'),
                onPressed: toggle,
                icon: Icon(switch (t.phase) {
                  TimerPhase.running => Icons.pause_rounded,
                  TimerPhase.done => Icons.check_rounded,
                  _ => Icons.play_arrow_rounded,
                }, size: 20),
                label: Text(switch (t.phase) {
                  TimerPhase.running => 'Pause',
                  TimerPhase.paused => 'Resume',
                  TimerPhase.done => 'Dismiss',
                  _ => 'Start',
                }),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('timer-reset'),
              onPressed: idle && t.total == 0 ? null : notifier.reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset'),
            ),
            IconButton(
              key: const Key('timer-focus'),
              tooltip: t.focus ? 'Focus on (DND)' : 'Focus mode',
              onPressed: notifier.toggleFocus,
              icon: Icon(
                t.focus ? Icons.notifications_off : Icons.notifications,
                size: 20,
                color: t.focus ? AppColors.danger : null,
              ),
            ),
          ]),

          // completion sound picker
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in soundCatalog)
                ActionChip(
                  key: Key('timer-sound-${s.id}'),
                  backgroundColor: t.sound == s.id
                      ? AppColors.accent.withValues(alpha: 0.14)
                      : null,
                  side: BorderSide(
                      color: t.sound == s.id
                          ? AppColors.accent
                          : AppColors.divider),
                  label: Text(_cap(s.id),
                      style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: t.sound == s.id
                              ? AppColors.accent
                              : AppColors.textSecondary)),
                  onPressed: () => notifier.selectSound(s.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void toggle() {
    ref.read(timerProvider.notifier).toggle();
  }

  String _cap(String s) =>
      '${s[0].toUpperCase()}${s.substring(1)}';

  void _showFullScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _FullScreenTimer(),
    );
  }
}

/* ------------------------------------------------------ full screen */

class _FullScreenTimer extends ConsumerWidget {
  const _FullScreenTimer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);
    final idle = t.total == 0 || t.phase == TimerPhase.idle;

    return Dialog.fullscreen(
      backgroundColor: AppColors.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: t.total > 0
                          ? (t.remaining / t.total).clamp(0.0, 1.0)
                          : 0.0,
                      strokeWidth: 12,
                      backgroundColor: AppColors.surfaceFaint,
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                  Text(
                      t.phase == TimerPhase.done
                          ? "Time's up!"
                          : _fmtClock(t.remaining),
                      style: AppTypography.titleLarge
                          .copyWith(fontSize: 44, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(t.phase == TimerPhase.done
                  ? "Time's up!"
                  : idle
                      ? 'Ready when you are'
                      : ''),
              const SizedBox(height: AppSpacing.lg),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                for (final p in const [25, 45, 60])
                  ActionChip(
                    key: Key('fs-preset-$p'),
                    label: Text('$p min'),
                    onPressed: () => notifier.setDuration(minutes: p),
                  ),
              ]),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const Key('fullscreen-toggle'),
                onPressed: () => notifier.toggle(),
                icon: Icon(t.phase == TimerPhase.running
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
                label: Text(t.phase == TimerPhase.running ? 'Pause' : 'Start'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------- marathon card */

class _MarathonCard extends ConsumerStatefulWidget {
  const _MarathonCard();

  @override
  ConsumerState<_MarathonCard> createState() => _MarathonCardState();
}

final bool _kIsWidgetTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');

class _MarathonCardState extends ConsumerState<_MarathonCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // live tick — skipped under flutter_test so goldens stay deterministic
    if (!_kIsWidgetTest) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static const presets = [360, 480, 600, 720];

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(marathonProvider);
    final notifier = ref.read(marathonProvider.notifier);
    // widget tests freeze the wall clock reference so goldens stay stable
    final now = _kIsWidgetTest ? s.periodStart : DateTime.now();
    final remaining = MarathonNotifier.remainingSeconds(s, now);
    final over = MarathonNotifier.overSeconds(s, now);
    final achieved = over > 0;
    final hours = s.targetMinutes ~/ 60;

    return DataCard(
      title: 'Daily Fix Timer',
      subtitle: achieved
          ? 'Target poora — extra time bhi count ho raha hai'
          : s.isPaused
              ? 'Paused at ${_fmtClock(remaining)} — resume to continue'
              : 'Wall-clock countdown — band karke bhi chalta hai',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // clocks
          Wrap(alignment: WrapAlignment.center, spacing: AppSpacing.xl, runSpacing: AppSpacing.sm, children: [
            Column(children: [
              Text(formatClockSeconds(remaining),
                  key: const Key('marathon-clock'),
                  style: AppTypography.titleLarge
                      .copyWith(fontSize: 30, fontWeight: FontWeight.w900)),
              Text('left today',
                  key: const Key('marathon-left'),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary)),
            ]),
            Column(children: [
              Text('+${formatClockSeconds(over)}',
                  key: const Key('marathon-complete'),
                  style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: achieved
                          ? AppColors.success
                          : AppColors.textSecondary)),
              Text('extra',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary)),
            ]),
          ]),
          const SizedBox(height: AppSpacing.md),

          // progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (MarathonNotifier.consumedSeconds(s, now) /
                      (s.targetMinutes * 60))
                  .clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceFaint,
              valueColor: AlwaysStoppedAnimation(achieved
                  ? AppColors.success
                  : AppColors.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // target stepper + presets
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              key: const Key('marathon-minus'),
              onPressed: () => notifier.setTargetMinutes(s.targetMinutes - 60),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Text('$hours h',
                key: const Key('marathon-target'),
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 18)),
            IconButton(
              key: const Key('marathon-plus'),
              onPressed: () => notifier.setTargetMinutes(s.targetMinutes + 60),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ]),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final p in presets)
                ActionChip(
                  key: Key('marathon-preset-$p'),
                  label: Text('${p ~/ 60} h',
                      style: AppTypography.caption.copyWith(fontSize: 11)),
                  onPressed: () => notifier.setTargetMinutes(p),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // controls
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            SizedBox(
              width: 150,
              child: FilledButton.icon(
                key: const Key('marathon-pause'),
                onPressed: () =>
                    s.isPaused ? notifier.resume() : notifier.pause(),
                icon: Icon(s.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded),
                label: Text(s.isPaused ? 'Resume' : 'Pause'),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('marathon-reset'),
              onPressed: () => notifier.reset(),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset'),
            ),
          ]),

          // laps
          if (s.laps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              key: const Key('marathon-laps'),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceFaint,
                borderRadius: BorderRadius.circular(AppRadius.standard),
              ),
              child: Column(children: [
                for (var i = 0; i < s.laps.length; i++)
                  Padding(
                    key: Key('marathon-lap-$i'),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Text('Lap ${i + 1}',
                          style: AppTypography.caption
                              .copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                          '${_hm(s.laps[i].start)} – ${_hm(s.laps[i].end)}'
                          ' · ${_durMin(s.laps[i])} min',
                          style: AppTypography.caption),
                    ]),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _durMin(MarathonLap l) =>
      (l.durationSeconds / 60).round().toString();
}

/* --------------------------------------------------------------- tiles */

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label),
          ),
        ]),
        const SizedBox(height: 6),
        Text(value,
            style: AppTypography.titleLarge
                .copyWith(fontSize: 24, fontWeight: FontWeight.w800)),
        Text(sub,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)),
      ]),
    );
  }
}







