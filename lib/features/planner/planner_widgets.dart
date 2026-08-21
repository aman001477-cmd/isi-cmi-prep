import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../../core/utils/time_format.dart';
import '../../shared/widgets/clock_input.dart';
import '../../shared/widgets/data_card.dart';
import '../../shared/widgets/sunken_box.dart';
import 'mock_test_provider.dart';
import 'marker_provider.dart';
import 'planner_provider.dart';
import 'sound_player.dart';
import '../progress/streak_provider.dart';

const plannerMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String shortDate(DateTime d) => '${d.day} ${plannerMonths[d.month - 1]}';

String fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime todayDay() => PlannerTask.day(DateTime.now());

/// If [picked] already passed, roll to the next occurrence of that
/// clock time (today if still ahead, otherwise tomorrow).
DateTime advancePast(DateTime picked) {
  final now = DateTime.now();
  if (picked.isAfter(now)) return picked;
  var next = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next;
}

bool sameMinute(DateTime a, DateTime b) =>
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day &&
    a.hour == b.hour &&
    a.minute == b.minute;

/// Where a task lands when added from a bucket.
enum Bucket { today, upcoming, backlog }

/* ------------------------------------------------------------ time stepper */

class TimeStepper extends StatelessWidget {
  const TimeStepper({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceFaint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

/* ----------------------------------------------------------- bucket pills */

class BucketPills extends StatelessWidget {
  const BucketPills({super.key, required this.bucket, required this.onBucket});

  final Bucket bucket;
  final ValueChanged<Bucket> onBucket;

  static const List<(Bucket, String)> _items = [
    (Bucket.today, 'Add to Today'),
    (Bucket.upcoming, 'Add to Upcoming'),
    (Bucket.backlog, 'Add to Backlog'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (b, label) in _items)
          GestureDetector(
            key: Key('bucket-${b.name}'),
            onTap: () => onBucket(b),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bucket == b ? AppColors.accentSoft : AppColors.surfaceFaint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: bucket == b ? AppColors.accent : AppColors.border,
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: bucket == b ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Single date pill used when adding from the calendar view — tap to
/// nudge the target day forward.
class CustomDatePill extends StatelessWidget {
  const CustomDatePill({super.key, required this.date, required this.onCycle});

  final DateTime date;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        GestureDetector(
          key: const Key('custom-date-pill'),
          onTap: onCycle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.accent, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shortDate(date),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.refresh,
                    size: 11, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------ sound chips */

class SoundChip extends StatelessWidget {
  const SoundChip({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
    this.keyPrefix = '',
    this.dark = false,
  });

  final SoundOption option;
  final bool selected;
  final VoidCallback onTap;

  /// Distinguishes pickers living in different places at once
  /// (planner add-row, timer card, full-screen timer).
  final String keyPrefix;

  /// Light-on-dark variant for the full-screen timer.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('${keyPrefix}sound-${option.id}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dark
              ? (selected ? Colors.white24 : Colors.white10)
              : (selected ? AppColors.accentSoft : AppColors.surfaceFaint),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: dark
                ? (selected ? AppColors.accent : Colors.white24)
                : (selected ? AppColors.accent : AppColors.border),
            width: 1,
          ),
        ),
        child: Text(
          option.label,
          style: AppTypography.caption.copyWith(
            color: dark
                ? (selected ? AppColors.accent : Colors.white70)
                : (selected ? AppColors.accent : AppColors.textSecondary),
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------- add row */

/// The "+ Add task" row — opens an inline composer with a bucket picker
/// (Today / Upcoming / Backlog), an optional exact alarm time and a
/// sound picker that previews on tap. When [customDate] is set the
/// bucket pills are replaced by a date pill for that day.
class PlannerAddRow extends StatelessWidget {
  const PlannerAddRow({
    super.key,
    required this.adding,
    required this.ctrl,
    required this.bucket,
    required this.customDate,
    required this.reminderOn,
    required this.hour,
    required this.minute,
    required this.sound,
    required this.notifyOnly,
    required this.onOpen,
    required this.onSubmit,
    required this.onBucket,
    required this.onCycleCustomDate,
    required this.onReminderToggle,
    required this.onNotifyOnly,
    required this.onHourSet,
    required this.onMinuteSet,
    required this.onSoundSelected,
    required this.ringSeconds,
    required this.onRingSeconds,
  });

  final bool adding;
  final TextEditingController ctrl;
  final Bucket bucket;
  final DateTime? customDate;
  final bool reminderOn;
  final int hour;
  final int minute;
  final String sound;
  final bool notifyOnly;
  final int ringSeconds;
  final VoidCallback onOpen;
  final Future<void> Function() onSubmit;
  final ValueChanged<Bucket> onBucket;
  final VoidCallback onCycleCustomDate;
  final VoidCallback onReminderToggle;
  final VoidCallback onNotifyOnly;
  final ValueChanged<int> onHourSet;
  final ValueChanged<int> onMinuteSet;
  final ValueChanged<String> onSoundSelected;
  final ValueChanged<int> onRingSeconds;

  @override
  Widget build(BuildContext context) {
    if (!adding) {
      return GestureDetector(
        key: const Key('add-task-row'),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceFaint,
            borderRadius: BorderRadius.circular(AppRadius.standard),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.md),
              Text('Add task',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  )),
            ],
          ),
        ),
      );
    }

    return DataCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Icon(Icons.add_circle,
                    size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  cursorColor: AppColors.accent,
                  style: AppTypography.body,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  decoration: const InputDecoration(
                    hintText: 'Type a task…',
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                key: const Key('add-save'),
                onTap: onSubmit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.raised,
                  ),
                  child: Text(
                    'Add',
                    style: AppTypography.label.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: customDate == null
                    ? BucketPills(
                        bucket: bucket,
                        onBucket: onBucket,
                      )
                    : CustomDatePill(
                        date: customDate!,
                        onCycle: onCycleCustomDate,
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                key: const Key('reminder-toggle'),
                onTap: onReminderToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: reminderOn ? AppColors.accentSoft : AppColors.surfaceFaint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: reminderOn ? AppColors.accent : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        reminderOn ? Icons.alarm_on : Icons.alarm_add,
                        size: 14,
                        color: reminderOn ? AppColors.accent : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        reminderOn ? 'Time on' : 'Set time',
                        style: AppTypography.caption.copyWith(
                          color: reminderOn
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (reminderOn) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.schedule, size: 14),
                ),
                ClockInput(
                  keyPrefix: 'time-hour',
                  isHour: true,
                  value: hour,
                  onChanged: onHourSet,
                ),
                const SizedBox(width: AppSpacing.md),
                ClockInput(
                  keyPrefix: 'time-min',
                  isHour: false,
                  value: minute,
                  onChanged: onMinuteSet,
                ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  key: const Key('alarm-preview'),
                  onTap: () => playSound(sound == 'none' ? 'chime' : sound),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      children: [
                        Text('Preview',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            )),
                        const SizedBox(width: 4),
                        Icon(Icons.volume_up,
                            size: 12, color: AppColors.accent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              key: const Key('notify-only-toggle'),
              onTap: onNotifyOnly,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: notifyOnly
                      ? AppColors.accentSoft
                      : AppColors.surfaceFaint,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: notifyOnly ? AppColors.accent : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      notifyOnly
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      size: 14,
                      color: notifyOnly
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      notifyOnly
                          ? 'Notification only — no sound'
                          : 'Notification only',
                      style: AppTypography.caption.copyWith(
                        color: notifyOnly
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in soundCatalog)
                SoundChip(
                  option: s,
                  selected: sound == s.id,
                  onTap: () => onSoundSelected(s.id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Ring for',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              )),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (sec, label) in ringDurationOptions)
                GestureDetector(
                  key: Key('dur-$sec'),
                  onTap: () => onRingSeconds(sec),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ringSeconds == sec
                          ? AppColors.accentSoft
                          : AppColors.surfaceFaint,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: ringSeconds == sec
                            ? AppColors.accent
                            : AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: ringSeconds == sec
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------------- calendar */

const _weekdayHeaders = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

/// Month grid with per-day task badges; tapping a day selects it and
/// the list below shows that day's tasks.
class CalendarView extends ConsumerWidget {
  const CalendarView({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(plannerProvider);
    ref.watch(mockDaysProvider);
    ref.watch(markersProvider);
    ref.watch(streakGoalProvider);
    final notifier = ref.read(plannerProvider.notifier);
    final markersNotifier = ref.read(markersProvider.notifier);
    final goal = ref.read(streakGoalProvider);
    final today = todayDay();
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;
    final leading =
        DateTime(month.year, month.month, 1).weekday - 1; // Mo = 0
    final now = DateTime.now();

    int doneOn(DateTime d) => notifier
        .tasksOn(d)
        .where((t) => t.done)
        .length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CalNavBtn(
              key: const Key('cal-prev'),
              icon: Icons.chevron_left,
              onTap: onPrevMonth,
            ),
            Text(
              '${plannerMonths[month.month - 1]} ${month.year}',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            CalNavBtn(
              key: const Key('cal-next'),
              icon: Icons.chevron_right,
              onTap: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final w in _weekdayHeaders)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var week = 0;
            week * 7 < leading + daysInMonth;
            week++)
          Row(
            children: [
              for (var wd = 0; wd < 7; wd++)
                Expanded(
                  child: CalCell(
                    day: week * 7 + wd - leading + 1,
                    month: month,
                    today: today,
                    selected: selectedDay,
                    pending: (DateTime day) =>
                        notifier.pendingOn(day),
                    isMock: (DateTime day) =>
                        ref.read(mockDaysProvider).contains(mockDayKey(day)),
                    isGreen: (DateTime day) => doneOn(day) >= goal,
                    markerColor: (DateTime day) =>
                        markersNotifier.markerAt(day)?.color,
                    markerLabel: (DateTime day) {
                      final m = markersNotifier.markerAt(day);
                      if (m == null || m.name.isEmpty) return null;
                      return m.name[0].toUpperCase();
                    },
                    now: now,
                    onTap: onSelectDay,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class CalNavBtn extends StatelessWidget {
  const CalNavBtn({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceFaint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

class CalCell extends StatelessWidget {
  const CalCell({
    super.key,
    required this.day,
    required this.month,
    required this.today,
    required this.selected,
    required this.pending,
    required this.isMock,
    required this.isGreen,
    required this.markerColor,
    required this.markerLabel,
    required this.now,
    required this.onTap,
  });

  final int day;
  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final int Function(DateTime) pending;
  final bool Function(DateTime) isMock;
  final bool Function(DateTime) isGreen;
  final Color? Function(DateTime) markerColor;
  final String? Function(DateTime) markerLabel;
  final DateTime now;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    if (day < 1 || day > DateTime(month.year, month.month + 1, 0).day) {
      return const SizedBox(height: 44);
    }
    final date = DateTime(month.year, month.month, day);
    final isToday = date == today;
    final isSelected = date == selected;
    final count = pending(date);
    final mock = isMock(date);
    final green = isGreen(date);
    final marker = markerColor(date);
    final markerChar = markerLabel(date);
    final isPast = date.isBefore(now);
    final highlighted = isToday || mock || marker != null;

    return GestureDetector(
      key: Key('cal-${date.year}-${date.month}-${date.day}'),
      onTap: () => onTap(date),
      child: Container(
        height: 44,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent
              : marker != null
                  ? marker.withValues(alpha: 0.16)
                  : green
                      ? AppColors.success.withValues(alpha: 0.22)
                      : highlighted
                          ? AppColors.accentSoft
                          : AppColors.surfaceFaint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : marker != null
                    ? marker
                    : green
                        ? AppColors.successDeep
                        : highlighted
                            ? AppColors.accent
                            : AppColors.border,
            width: isSelected || highlighted || green ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: AppTypography.label.copyWith(
                color: isSelected
                    ? Colors.white
                    : green && !isPast
                        ? AppColors.successDeep
                        : isPast
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
            if (mock || marker != null || count > 0 || green)
              Container(
                margin: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (green)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : AppColors.successDeep,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 9,
                          color: isSelected
                              ? AppColors.successDeep
                              : Colors.white,
                        ),
                      ),
                    if (mock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'M',
                          style: AppTypography.caption.copyWith(
                            color: isSelected
                                ? AppColors.accent
                                : Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                    if (mock || green) const SizedBox(width: 2),
                    if (marker != null && markerChar != null) ...[
                      if (mock || green) const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : marker,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          markerChar,
                          style: AppTypography.caption.copyWith(
                            color: isSelected ? marker : Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                    if (count > 0) ...[
                      if (mock ||
                          (marker != null && markerChar != null) ||
                          green)
                        const SizedBox(width: 2),
                      Container(
                        width: 14,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : AppColors.warning,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------- task cards */

/// Overflow menu on every task row: park in Backlog / pull to Today,
/// set a reminder, flip notification-only, or delete.
class _TaskMoreMenu extends ConsumerWidget {
  const _TaskMoreMenu({required this.task, required this.onRequestDelete});

  final PlannerTask task;
  final VoidCallback onRequestDelete;

  Future<void> _openReminderDialog(BuildContext context, WidgetRef ref) async {
    final n = ref.read(plannerProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (_) => _TaskReminderDialog(task: task, notifier: n),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('task-more'),
      icon: Icon(Icons.more_vert, size: 16, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      color: AppColors.surface,
      onSelected: (value) async {
        final n = ref.read(plannerProvider.notifier);
        switch (value) {
          case 'backlog':
            await n.addToBacklog(task.id);
          case 'today':
            await n.bringToToday(task.id);
          case 'reminder':
            await _openReminderDialog(context, ref);
          case 'notify':
            await n.setReminder(task.id, task.alarmAt,
                notifyOnly: !task.notifyOnly);
          case 'repeat':
            await n.setRepeatDaily(task.id, !task.repeatDaily);
          case 'delete':
            onRequestDelete();
        }
      },
      itemBuilder: (context) => [
        if (!task.done && task.isToday && !task.backlog)
          PopupMenuItem(
            value: 'backlog',
            child: Row(children: [
              Icon(Icons.move_to_inbox, size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              Text('Add to Backlog',
                  style: TextStyle(color: AppColors.textPrimary)),
            ]),
          ),
        if (!task.done && task.backlog)
          PopupMenuItem(
            value: 'today',
            child: Row(children: [
              Icon(Icons.today, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Text('Move to Today',
                  style: TextStyle(color: AppColors.textPrimary)),
            ]),
          ),
        PopupMenuItem(
          value: 'reminder',
          child: Row(children: [
            Icon(Icons.alarm, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Text('Set reminder…',
                style: TextStyle(color: AppColors.textPrimary)),
          ]),
        ),
        if (task.hasAlarm)
          CheckedPopupMenuItem(
            value: 'notify',
            checked: task.notifyOnly,
            child: Row(children: [
              Icon(Icons.notifications_none,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text('Notification only',
                  style: TextStyle(color: AppColors.textPrimary)),
            ]),
          ),
        CheckedPopupMenuItem(
          value: 'repeat',
          checked: task.repeatDaily && !task.done,
          child: Row(children: [
            Icon(Icons.repeat, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Text('Repeat daily',
                style: TextStyle(color: AppColors.textPrimary)),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            const SizedBox(width: 10),
            Text('Delete', style: TextStyle(color: AppColors.danger)),
          ]),
        ),
      ],
    );
  }
}

/// Per-task reminder editor — the same controls as the add-row composer
/// (time, notification-only, sound, ring duration) for an existing task.
class _TaskReminderDialog extends ConsumerStatefulWidget {
  const _TaskReminderDialog({required this.task, required this.notifier});

  final PlannerTask task;
  final PlannerNotifier notifier;

  @override
  ConsumerState<_TaskReminderDialog> createState() =>
      _TaskReminderDialogState();
}

class _TaskReminderDialogState extends ConsumerState<_TaskReminderDialog> {
  late bool _on;
  late int _hour;
  late int _minute;
  late String _sound;
  late int _seconds;
  late bool _notifyOnly;

  @override
  void initState() {
    super.initState();
    _on = widget.task.hasAlarm;
    _hour = widget.task.alarmAt?.hour ?? 9;
    _minute = widget.task.alarmAt?.minute ?? 0;
    _sound = widget.task.sound;
    _seconds = widget.task.ringSeconds;
    _notifyOnly = widget.task.notifyOnly;
  }

  @override
  Widget build(BuildContext context) {
    final use24h = ref.read(timeFormatProvider);
    final time = widget.task.hasAlarm
        ? fmtClockTime(widget.task.alarmAt!.hour, widget.task.alarmAt!.minute,
            use24h: use24h)
        : 'off';
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Row(children: [
        Icon(Icons.alarm, size: 20, color: AppColors.accent),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('Reminder for “${widget.task.title}”',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Status: $time',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    )),
                const Spacer(),
                GestureDetector(
                  key: const Key('task-rem-onoff'),
                  onTap: () => setState(() => _on = !_on),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _on ? AppColors.accentSoft : AppColors.surfaceFaint,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: _on ? AppColors.accent : AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _on ? 'On' : 'Off',
                      style: AppTypography.label.copyWith(
                        color: _on ? AppColors.accent : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_on) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClockInput(
                    keyPrefix: 'task-rem-hour',
                    isHour: true,
                    value: _hour,
                    onChanged: (v) => setState(() => _hour = v % 24),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(':',
                        style: AppTypography.titleMedium.copyWith(fontSize: 18)),
                  ),
                  ClockInput(
                    keyPrefix: 'task-rem-min',
                    isHour: false,
                    value: _minute,
                    onChanged: (v) => setState(() => _minute = v % 60),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                key: const Key('task-rem-notify'),
                onTap: () => setState(() => _notifyOnly = !_notifyOnly),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _notifyOnly
                        ? AppColors.accentSoft
                        : AppColors.surfaceFaint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: _notifyOnly ? AppColors.accent : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _notifyOnly
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        size: 14,
                        color: _notifyOnly
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _notifyOnly
                            ? 'Notification only — no sound'
                            : 'Notification only',
                        style: AppTypography.caption.copyWith(
                          color: _notifyOnly
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in soundCatalog)
                    SoundChip(
                      keyPrefix: 'task-rem-',
                      option: s,
                      selected: _sound == s.id,
                      onTap: () => setState(() => _sound = s.id),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Ring for',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  )),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (sec, label) in ringDurationOptions)
                    GestureDetector(
                      key: Key('task-rem-dur-$sec'),
                      onTap: () => setState(() => _seconds = sec),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _seconds == sec
                              ? AppColors.accentSoft
                              : AppColors.surfaceFaint,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: _seconds == sec
                                ? AppColors.accent
                                : AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: AppTypography.caption.copyWith(
                            color: _seconds == sec
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('task-rem-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          key: const Key('task-rem-save'),
          onPressed: () async {
            final day = PlannerTask.day(widget.task.date);
            final at = _on
                ? advancePast(
                    DateTime(day.year, day.month, day.day, _hour, _minute))
                : null;
            await widget.notifier.setReminder(
              widget.task.id,
              at,
              sound: _sound,
              ringSeconds: _seconds,
              notifyOnly: _notifyOnly,
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save reminder'),
        ),
      ],
    );
  }
}

/// The task list card shared by every segment and the calendar day view.
class PlannerTaskCard extends StatelessWidget {
  const PlannerTaskCard({
    super.key,
    required this.title,
    required this.emptyLabel,
    required this.tasks,
    required this.renamingId,
    required this.renameCtrl,
    required this.deleteConfirmId,
    required this.notifier,
    required this.onStartRename,
    required this.onCommitRename,
    required this.onRequestDelete,
    required this.onConfirmDelete,
    this.onReorder,
  });

  final String title;
  final String emptyLabel;
  final List<PlannerTask> tasks;
  final String? renamingId;
  final TextEditingController renameCtrl;
  final String? deleteConfirmId;
  final PlannerNotifier notifier;
  final void Function(PlannerTask) onStartRename;
  final Future<void> Function(PlannerTask) onCommitRename;
  final void Function(String id) onRequestDelete;
  final Future<void> Function(PlannerTask) onConfirmDelete;

  /// When set, rows become draggable (long-press on mobile, mouse drag
  /// on web) and [onReorder] receives the standard ReorderableListView
  /// indices to persist the new priority order.
  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: DataCard(
          title: title,
          subtitle: emptyLabel,
          body: const SizedBox.shrink(),
        ),
      );
    }
    final reorderable = onReorder != null;
    return DataCard(
      title: title,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      body: reorderable
          ? ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              onReorderItem: onReorder,
              children: [
                for (final task in tasks)
                  KeyedSubtree(
                    key: ValueKey('task-row-${task.id}'),
                    child: PlannerTaskRow(
                      task: task,
                      renaming: renamingId == task.id,
                      renameCtrl: renameCtrl,
                      deleteConfirm: deleteConfirmId == task.id,
                      onToggle: () => notifier.toggle(task.id),
                      onStartRename: () => onStartRename(task),
                      onCommitRename: () => onCommitRename(task),
                      onRequestDelete: () => onRequestDelete(task.id),
                      onConfirmDelete: () => onConfirmDelete(task),
                      onShiftDate: () => notifier.reschedule(
                          task.id, task.date.add(const Duration(days: 1))),
                      onMoveToday: () => notifier.reschedule(
                          task.id, todayDay()),
                    ),
                  ),
              ],
            )
          : Column(
              children: [
                for (final task in tasks)
                  PlannerTaskRow(
                    task: task,
                    renaming: renamingId == task.id,
                    renameCtrl: renameCtrl,
                    deleteConfirm: deleteConfirmId == task.id,
                    onToggle: () => notifier.toggle(task.id),
                    onStartRename: () => onStartRename(task),
                    onCommitRename: () => onCommitRename(task),
                    onRequestDelete: () => onRequestDelete(task.id),
                    onConfirmDelete: () => onConfirmDelete(task),
                    onShiftDate: () => notifier.reschedule(
                        task.id, task.date.add(const Duration(days: 1))),
                    onMoveToday: () =>
                        notifier.reschedule(task.id, todayDay()),
                  ),
              ],
            ),
    );
  }
}

class PlannerTaskRow extends ConsumerWidget {
  const PlannerTaskRow({
    super.key,
    required this.task,
    required this.renaming,
    required this.renameCtrl,
    required this.deleteConfirm,
    required this.onToggle,
    required this.onStartRename,
    required this.onCommitRename,
    required this.onRequestDelete,
    required this.onConfirmDelete,
    required this.onShiftDate,
    required this.onMoveToday,
  });

  final PlannerTask task;
  final bool renaming;
  final TextEditingController renameCtrl;
  final bool deleteConfirm;
  final VoidCallback onToggle;
  final VoidCallback onStartRename;
  final VoidCallback onCommitRename;
  final VoidCallback onRequestDelete;
  final VoidCallback onConfirmDelete;
  final VoidCallback onShiftDate;
  final VoidCallback onMoveToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = task.isOverdue;
    final use24h = ref.watch(timeFormatProvider);
    final time = task.hasAlarm
        ? fmtClockTime(
            task.alarmAt!.hour, task.alarmAt!.minute, use24h: use24h)
        : null;
    String? subtitle;
    if (task.backlog && !task.done) {
      subtitle = 'In backlog · tap to move to today';
    } else if (isOverdue) {
      subtitle = 'Past due · tap to do today';
    } else if (!task.isToday) {
      subtitle = shortDate(task.date);
    }
    if (!task.done && task.repeatDaily) {
      final repeat = 'Repeats daily';
      subtitle = subtitle == null ? repeat : '$repeat · $subtitle';
    }
    if (time != null) {
      subtitle = subtitle == null ? time : '$subtitle · $time';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            key: const Key('task-check-circle'),
            onTap: onToggle,
            child: task.done
                ? SunkenBox(
                    radius: 12,
                    color: AppColors.success,
                    intensity: 0.5,
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  )
                : Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: renaming
                ? SunkenBox(
                    radius: AppRadius.standard,
                    color: AppColors.surfaceFaint,
                    child: TextField(
                      controller: renameCtrl,
                      autofocus: true,
                      cursorColor: AppColors.accent,
                      style: AppTypography.body,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onCommitRename(),
                      onTapOutside: (_) => onCommitRename(),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  )
                : GestureDetector(
                    key: const Key('task-title'),
                    onTap: onStartRename,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AppTypography.bodyMedium.copyWith(
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.done
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: task.backlog || isOverdue
                                ? onMoveToday
                                : onShiftDate,
                            child: Text(
                              subtitle,
                              style: AppTypography.caption.copyWith(
                                color: task.backlog || isOverdue
                                    ? AppColors.warning
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (task.hasAlarm) ...[
            Icon(Icons.alarm, size: 14, color: AppColors.accent),
            const SizedBox(width: AppSpacing.xs),
          ],
          _TaskMoreMenu(task: task, onRequestDelete: onRequestDelete),
          IconButton(
            icon: Icon(
              deleteConfirm ? Icons.delete : Icons.delete_outline,
              size: 16,
              color: deleteConfirm ? AppColors.danger : AppColors.textSecondary,
            ),
            onPressed:
                deleteConfirm ? onConfirmDelete : onRequestDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------- ring UI */

/// Shown while an alarm is ringing: start the task, reschedule it, or
/// just silence the sound. Picking any option stops the sound.
class _RingingDialog extends StatelessWidget {
  const _RingingDialog({
    required this.ring,
    required this.onStart,
    required this.onReschedule,
    required this.onStop,
  });

  final Ringing ring;
  final VoidCallback onStart;
  final VoidCallback onReschedule;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final soundName = soundCatalog
        .where((s) => s.id == ring.sound)
        .firstOrNull
        ?.label ?? ring.sound;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Row(
        children: [
          Icon(Icons.alarm, size: 20, color: AppColors.accent),
          SizedBox(width: AppSpacing.sm),
          Text('Alarm',
              style: TextStyle(color: AppColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            key: const Key('ring-close'),
            onTap: onStop,
            child: Icon(Icons.close,
                size: 20, color: AppColors.textSecondary),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '“${ring.title}”',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sound: $soundName · rings for ${ring.seconds}s',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RingOption(
            key: const Key('ring-start'),
            icon: Icons.check_circle_outline,
            label: 'Start the task',
            onTap: onStart,
          ),
          _RingOption(
            key: const Key('ring-reschedule'),
            icon: Icons.schedule,
            label: 'Reschedule alarm',
            onTap: onReschedule,
          ),
          _RingOption(
            key: const Key('ring-stop'),
            icon: Icons.stop_circle_outlined,
            label: 'Stop sound',
            onTap: onStop,
          ),
        ],
      ),
    );
  }
}

class _RingOption extends StatelessWidget {
  const _RingOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceFaint,
          borderRadius: BorderRadius.circular(AppRadius.standard),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: AppSpacing.sm),
            Text(label,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                )),
          ],
        ),
      ),
    );
  }
}

/// Picks a new date + clock time for a rescheduled task.
class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.initial});

  final DateTime initial;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  late DateTime _date;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _date = PlannerTask.day(widget.initial);
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2036),
    );
    if (picked != null) {
      setState(() => _date = PlannerTask.day(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text('Reschedule alarm',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.event, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${_date.day} ${plannerMonths[_date.month - 1]}',
                key: const Key('res-date-label'),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                key: const Key('res-change-date'),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Change date',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClockInput(
                keyPrefix: 'res-hour',
                isHour: true,
                value: _hour,
                onChanged: (v) => setState(() => _hour = v),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(':',
                    style: AppTypography.titleMedium.copyWith(fontSize: 18)),
              ),
              ClockInput(
                keyPrefix: 'res-min',
                isHour: false,
                value: _minute,
                onChanged: (v) => setState(() => _minute = v),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('res-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          key: const Key('res-confirm'),
          onPressed: () => Navigator.of(context).pop(
            DateTime(_date.year, _date.month, _date.day, _hour, _minute),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reschedule task'),
        ),
      ],
    );
  }
}

/// Offered when the chosen time collides with other tasks: push those
/// tasks forward by the picked offset. Their sound + ring duration are
/// untouched and they still ring at their new time.
class _ConflictDialog extends StatefulWidget {
  const _ConflictDialog({required this.tasks, required this.at});

  final List<PlannerTask> tasks;
  final DateTime at;

  @override
  State<_ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<_ConflictDialog> {
  int _hours = 0;
  int _minutes = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text('Task conflict',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Already scheduled at ${fmtTime(widget.at)}:',
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          for (final t in widget.tasks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.alarm,
                      size: 13, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '“${t.title}”',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Push those tasks forward by:',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClockInput(
                keyPrefix: 'conf-hour',
                isHour: true,
                value: _hours,
                onChanged: (v) => setState(() => _hours = v),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('h',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: AppSpacing.md),
              ClockInput(
                keyPrefix: 'conf-min',
                isHour: false,
                value: _minutes,
                onChanged: (v) => setState(() => _minutes = v),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('min',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('conf-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          key: const Key('conf-confirm'),
          onPressed: () => Navigator.of(context).pop(
            Duration(hours: _hours, minutes: _minutes),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Move tasks forward'),
        ),
      ],
    );
  }
}

/// Global alarm ring host — lives in the shell so a due alarm fires on
/// ANY page. Shows the ringing dialog (Start / Reschedule / Stop), the
/// reschedule picker and conflict resolution while the sound loops.
class RingDialogHandler extends ConsumerStatefulWidget {
  const RingDialogHandler({super.key});

  @override
  ConsumerState<RingDialogHandler> createState() => _RingDialogHandlerState();
}

class _RingDialogHandlerState extends ConsumerState<RingDialogHandler> {
  bool _ringDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(ringingProvider, (prev, next) {
      if (prev == null && next != null) {
        _showRingDialog();
      } else if (prev != null && next == null) {
        _dismissRingDialog();
      }
    });
    return const SizedBox.shrink();
  }

  Future<void> _showRingDialog() async {
    if (_ringDialogOpen) return;
    final ring = ref.read(ringingProvider);
    if (ring == null) return;
    _ringDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RingingDialog(
        ring: ring,
        onStart: () {
          final n = ref.read(plannerProvider.notifier);
          final r = ref.read(ringingProvider);
          if (r == null) return;
          n.markDone(r.id, true);
          ref.read(ringingProvider.notifier).stop();
        },
        onReschedule: () {
          final r = ref.read(ringingProvider);
          if (r == null) return;
          // sound goes off the moment an option is picked
          ref.read(ringingProvider.notifier).stop();
          _openReschedule(r);
        },
        onStop: () {
          ref.read(ringingProvider.notifier).stop();
        },
      ),
    );
    _ringDialogOpen = false;
  }

  void _dismissRingDialog() {
    if (!_ringDialogOpen) return;
    _ringDialogOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Picks a new day + time for the ringing task. If another task is
  /// already scheduled at that exact moment, offers to push the
  /// conflicting tasks forward by the chosen offset (their sound and
  /// ring duration stay as configured).
  Future<void> _openReschedule(Ringing r) async {
    final task = ref.read(plannerProvider).where((t) => t.id == r.id).firstOrNull;
    if (task == null) return;
    final initial = advancePast(DateTime(
      task.date.year,
      task.date.month,
      task.date.day,
      task.hasAlarm ? task.alarmAt!.hour : 9,
      task.hasAlarm ? task.alarmAt!.minute : 0,
    ));
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _RescheduleDialog(initial: initial),
    );
    if (picked == null || !mounted) return;
    final safe = advancePast(picked);
    final notifier = ref.read(plannerProvider.notifier);
    final conflicts = ref
        .read(plannerProvider)
        .where((t) =>
            t.id != r.id && t.hasAlarm && sameMinute(t.alarmAt!, safe))
        .toList();
    Duration? offset;
    if (conflicts.isNotEmpty) {
      offset = await showDialog<Duration>(
        context: context,
        builder: (_) => _ConflictDialog(tasks: conflicts, at: safe),
      );
      if (offset == null || !mounted) return;
      for (final c in conflicts) {
        await notifier.setReminder(
          c.id,
          c.alarmAt!.add(offset),
          sound: c.sound,
          ringSeconds: c.ringSeconds,
        );
      }
    }
    await notifier.reschedule(r.id, PlannerTask.day(safe));
    await notifier.setReminder(
      r.id,
      safe,
      sound: r.sound,
      ringSeconds: r.seconds,
    );
  }
}
