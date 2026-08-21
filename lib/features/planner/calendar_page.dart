import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../../core/utils/time_format.dart';
import '../../shared/widgets/clock_input.dart';
import '../../shared/widgets/data_card.dart';
import '../progress/mock_results_provider.dart';
import '../progress/streak_provider.dart';
import '../reminders/reminders_provider.dart';
import 'marker_provider.dart';
import 'mock_test_provider.dart';
import 'planner_provider.dart';
import 'planner_widgets.dart';
import 'sound_player.dart';

/// Calendar — a dedicated page with a month grid of per-day task
/// badges. Tap a day to see and manage its tasks; the add row lands
/// new tasks on the selected day (with optional alarm + sound).
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = todayDay();

  bool _adding = false;
  final _addCtrl = TextEditingController();
  bool _reminderOn = false;
  int _alarmHour = 9;
  int _alarmMinute = 0;
  String _sound = 'none';
  int _ringSec = 30;
  bool _notifyOnly = false;

  String? _renamingId;
  final _renameCtrl = TextEditingController();

  String? _deleteConfirmId;
  Timer? _deleteTimer;

  /// Live diagnostics — small text under the list proving taps land.
  String? _diag;

  @override
  void dispose() {
    _addCtrl.dispose();
    _renameCtrl.dispose();
    _deleteTimer?.cancel();
    super.dispose();
  }

  void _log(String message) {
    debugPrint('[calendar] $message');
    setState(() => _diag = message);
  }

  void _openAddRow() {
    _addCtrl.clear();
    setState(() {
      _adding = true;
      _reminderOn = false;
      _alarmHour = 9;
      _alarmMinute = 0;
      _sound = 'none';
      _ringSec = 30;
      _notifyOnly = false;
    });
    _log('add row open');
  }

  DateTime? _computedAlarm() {
    if (!_reminderOn) return null;
    return advancePast(DateTime(_selectedDay.year, _selectedDay.month,
        _selectedDay.day, _alarmHour, _alarmMinute));
  }

  Future<void> _submitAdd() async {
    final title = _addCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    final day = _selectedDay;
    final alarm = _computedAlarm();
    final alarmNote = alarm == null
        ? ''
        : ' alarm ${fmtTime(alarm)}'
            '${_notifyOnly ? ' (notif only)' : ' ($_sound)'}';
    _log('adding "$title" → $day$alarmNote');
    await ref.read(plannerProvider.notifier).add(
          title,
          day,
          alarmAt: alarm,
          sound: _sound,
          ringSeconds: _ringSec,
          notifyOnly: _notifyOnly,
        );
    setState(() {
      _addCtrl.clear();
      _adding = false;
      _diag = null;
    });
  }

  void _startRename(PlannerTask task) {
    _renameCtrl.text = task.title;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _renamingId = task.id);
  }

  Future<void> _commitRename(PlannerTask task) async {
    final title = _renameCtrl.text.trim();
    setState(() => _renamingId = null);
    if (title.isEmpty || title == task.title) return;
    await ref.read(plannerProvider.notifier).rename(task.id, title);
    _log('renamed to “$title”');
  }

  void _requestDelete(String id) {
    _deleteTimer?.cancel();
    setState(() => _deleteConfirmId = id);
    _deleteTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _deleteConfirmId = null);
    });
  }

  Future<void> _confirmDelete(PlannerTask task) async {
    _deleteTimer?.cancel();
    setState(() => _deleteConfirmId = null);
    await ref.read(plannerProvider.notifier).remove(task.id);
    _log('deleted "${task.title}"');
  }

  Future<void> _removeReminderIfAny(String? id) async {
    if (id == null) return;
    await ref.read(remindersProvider.notifier).remove(id);
  }

  Future<void> _openMockAlarmDialog() async {
    final mockNotifier = ref.read(mockDaysProvider.notifier);
    final day = _selectedDay;
    final existing = mockNotifier.alarmFor(day);
    final result = await showDialog<_MockAlarmResult>(
      context: context,
      builder: (_) => _MockAlarmDialog(day: day, existing: existing),
    );
    if (result == null || !mounted) return;
    final reminders = ref.read(remindersProvider.notifier);

    if (result.remove) {
      await _removeReminderIfAny(existing?.reminderId);
      await mockNotifier.clearAlarm(day);
      if (mounted) _log('mock alarm cleared');
      return;
    }

    await _removeReminderIfAny(existing?.reminderId);
    final at = DateTime(
        day.year, day.month, day.day, result.hour!, result.minute!);
    final reminder =
        await reminders.add('Mock test', at, silent: result.notifyOnly);
    await mockNotifier.setAlarm(
      day,
      MockAlarm(
        hour: result.hour!,
        minute: result.minute!,
        reminderId: reminder.id,
        notifyOnly: result.notifyOnly,
      ),
    );
    if (mounted) _log('mock alarm ${fmtTime(at)}');
  }

  Future<void> _openMockResultDialog() async {
    final notifier = ref.read(mockResultsProvider.notifier);
    final day = _selectedDay;
    final existing = notifier.resultFor(day);
    final result = await showDialog<_MockResultPop>(
      context: context,
      builder: (_) => _MockResultDialog(day: day, existing: existing),
    );
    if (result == null || !mounted) return;
    if (result.remove) {
      await notifier.remove(day);
      _log('mock result removed');
    } else {
      await notifier.set(day, result.marks, result.max);
      _log('mock result ${result.marks}/${result.max}');
    }
  }

  /// Day-status window — green days (goal done) vs. what is still left
  /// to complete before the date turns green.
  Future<void> _openDayStatus(DateTime day) async {
    final tasks = ref.read(plannerProvider.notifier).tasksOn(day);
    final done = tasks.where((t) => t.done).length;
    final goal = ref.read(streakGoalProvider);
    await showDialog<void>(
      context: context,
      builder: (_) => _DayStatusDialog(
        day: day,
        tasks: tasks,
        done: done,
        goal: goal,
      ),
    );
  }

  Future<void> _openNewMarker() async {
    final result = await showDialog<({String name, int color})>(
      context: context,
      builder: (_) => const _NewMarkerDialog(),
    );
    if (result == null || !mounted) return;
    final id = ref
        .read(markersProvider.notifier)
        .addMarker(result.name.trim(), result.color);
    _log('marker created: ${result.name.trim()} ($id)');
  }

  /// Settings for the custom "Mark … as" options — list + delete, and a
  /// shortcut to create a new one.
  Future<void> _openMarkerSettings() async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const _MarkerManagerDialog(),
    );
    if (action == 'new' && mounted) await _openNewMarker();
  }

  Future<void> _toggleMarker(CalendarMarker marker) async {
    final markers = ref.read(markersProvider.notifier);
    final day = _selectedDay;
    final assignment = markers.assignmentAt(day);

    if (assignment?.markerId == marker.id) {
      // tapping an applied marker unmarks the day (mock-test style)
      await _removeReminderIfAny(assignment?.reminderId);
      await markers.unassign(day);
      if (mounted) _log('marker removed from ${shortDate(day)}');
      return;
    }
    await _removeReminderIfAny(assignment?.reminderId);
    await markers.assign(day, MarkerAssignment(markerId: marker.id));
    if (mounted) _log('marked ${shortDate(day)} as ${marker.name}');
  }

  Future<void> _openMarkerApply(CalendarMarker marker) async {
    final markers = ref.read(markersProvider.notifier);
    final day = _selectedDay;
    final assignment = markers.assignmentAt(day);
    final result = await showDialog<_MarkerApplyResult>(
      context: context,
      builder: (_) => _MarkerApplyDialog(
        day: day,
        marker: marker,
        assignment: assignment,
      ),
    );
    if (result == null || !mounted) return;
    final reminders = ref.read(remindersProvider.notifier);

    if (result.remove) {
      await _removeReminderIfAny(assignment?.reminderId);
      await markers.unassign(day);
      if (mounted) _log('marker removed from ${shortDate(day)}');
      return;
    }

    await _removeReminderIfAny(assignment?.reminderId);
    final reminder = result.alarm != null
        ? (await reminders.add(marker.name, result.alarm!,
            silent: result.notifyOnly))
        : null;
    await markers.assign(
      day,
      MarkerAssignment(
        markerId: marker.id,
        alarmHour: result.alarm?.hour,
        alarmMinute: result.alarm?.minute,
        reminderId: reminder?.id,
        notifyOnly: result.notifyOnly,
      ),
    );
    if (mounted) _log('applied ${marker.name} to ${shortDate(day)}');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(plannerProvider);
    final notifier = ref.read(plannerProvider.notifier);
    final pending = notifier.pendingOn(_selectedDay);
    ref.watch(mockDaysProvider);
    final mockNotifier = ref.read(mockDaysProvider.notifier);
    final selectedMock = mockNotifier.has(_selectedDay);
    final mockAlarm = mockNotifier.alarmFor(_selectedDay);
    ref.watch(mockResultsProvider);
    final mockResult = ref.read(mockResultsProvider.notifier).resultFor(_selectedDay);
    final use24h = ref.watch(timeFormatProvider);
    ref.watch(markersProvider);
    final markers = ref.read(markersProvider.notifier);
    final markersState = ref.read(markersProvider);
    final markerAtDay = markers.markerAt(_selectedDay);
    final assignmentAtDay = markers.assignmentAt(_selectedDay);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DataCard(
            title: 'Calendar',
            subtitle: 'Tap a day to see and plan its tasks',
            body: Row(
              children: [
                _HeadTile(
                    label: 'Selected',
                    value: shortDate(_selectedDay),
                    color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                _HeadTile(
                    label: 'Pending',
                    value: '$pending',
                    color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                _HeadTile(
                    label: 'Mock tests',
                    value: '${mockNotifier.countInMonth(_calMonth)}',
                    color: AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          CalendarView(
            month: _calMonth,
            selectedDay: _selectedDay,
            onSelectDay: (d) {
              setState(() => _selectedDay = d);
              _log('calendar: selected ${shortDate(d)}');
              _openDayStatus(d);
            },
            onPrevMonth: () {
              setState(() =>
                  _calMonth = DateTime(_calMonth.year, _calMonth.month - 1));
            },
            onNextMonth: () {
              setState(() =>
                  _calMonth = DateTime(_calMonth.year, _calMonth.month + 1));
            },
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            key: const Key('mock-toggle'),
            onTap: () {
              mockNotifier.toggle(_selectedDay);
              _log('mock test: ${selectedMock ? 'removed' : 'marked'} '
                  '${shortDate(_selectedDay)}');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 12),
              decoration: BoxDecoration(
                color: selectedMock
                    ? AppColors.accentSoft
                    : AppColors.surfaceFaint,
                borderRadius: BorderRadius.circular(AppRadius.standard),
                border: Border.all(
                  color: selectedMock ? AppColors.accent : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedMock ? Icons.flag : Icons.flag_outlined,
                    size: 16,
                    color: selectedMock
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      selectedMock
                          ? 'Mock test on ${shortDate(_selectedDay)} — tap to remove'
                          : 'Mark ${shortDate(_selectedDay)} as a Mock test day',
                      style: AppTypography.label.copyWith(
                        color: selectedMock
                            ? AppColors.accent
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (selectedMock) ...[
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      key: const Key('mock-result'),
                      onTap: _openMockResultDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: mockResult != null
                              ? AppColors.success
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: AppColors.successDeep, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.scoreboard_outlined,
                              size: 14,
                              color: AppColors.successDeep,
                            ),
                            if (mockResult != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${_fmtNum(mockResult.marks)}/'
                                '${_fmtNum(mockResult.max)}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.successDeep,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      key: const Key('mock-alarm'),
                      onTap: _openMockAlarmDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: mockAlarm != null
                              ? AppColors.accent
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: AppColors.accent, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.alarm,
                              size: 14,
                              color: mockAlarm != null
                                  ? Colors.white
                                  : AppColors.accent,
                            ),
                            if (mockAlarm != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                fmtClockTime(mockAlarm.hour,
                                    mockAlarm.minute,
                                    use24h: use24h),
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _MarkersSection(
            day: _selectedDay,
            markers: markersState.markers,
            markerAtDay: markerAtDay,
            assignmentAtDay: assignmentAtDay,
            use24h: use24h,
            onSettings: _openMarkerSettings,
            onToggle: _toggleMarker,
            onAlarm: _openMarkerApply,
          ),
          const SizedBox(height: AppSpacing.md),
          PlannerTaskCard(
            title: '${_selectedDay.day} ${plannerMonths[_selectedDay.month - 1]}',
            emptyLabel: 'Nothing scheduled for this day',
            tasks: notifier.tasksOn(_selectedDay),
            renamingId: _renamingId,
            renameCtrl: _renameCtrl,
            deleteConfirmId: _deleteConfirmId,
            notifier: notifier,
            onStartRename: _startRename,
            onCommitRename: _commitRename,
            onRequestDelete: _requestDelete,
            onConfirmDelete: _confirmDelete,
          ),
          PlannerAddRow(
            adding: _adding,
            ctrl: _addCtrl,
            bucket: Bucket.today,
            customDate: _selectedDay,
            reminderOn: _reminderOn,
            hour: _alarmHour,
            minute: _alarmMinute,
            sound: _sound,
            notifyOnly: _notifyOnly,
            ringSeconds: _ringSec,
            onOpen: _openAddRow,
            onSubmit: _submitAdd,
            onBucket: (_) {},
            onCycleCustomDate: () {
              setState(() =>
                  _selectedDay = _selectedDay.add(const Duration(days: 1)));
              _log('custom date: ${shortDate(_selectedDay)}');
            },
            onReminderToggle: () {
              setState(() => _reminderOn = !_reminderOn);
            },
            onNotifyOnly: () {
              setState(() => _notifyOnly = !_notifyOnly);
              _log('notify only: ${!_notifyOnly}');
            },
            onHourSet: (v) {
              setState(() => _alarmHour = v % 24);
            },
            onMinuteSet: (v) {
              setState(() => _alarmMinute = v % 60);
            },
            onSoundSelected: (id) {
              setState(() => _sound = id);
              playSound(id);
              _log('sound: $id');
            },
            onRingSeconds: (s) {
              setState(() => _ringSec = s);
              _log('ring for: $s s');
            },
          ),
          if (_diag != null && _diag!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _diag!,
              style: TextStyle(
                color: AppColors.dangerDeep,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeadTile extends StatelessWidget {
  const _HeadTile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceFaint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTypography.titleMedium.copyWith(
                  color: color,
                  fontSize: 18,
                )),
            const SizedBox(height: 2),
            Text(label,
                style: AppTypography.caption.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------- custom options */

/// "Mark <day> as …" — one toggle row per custom option, exactly like
/// the Mock test row above, plus a settings button to manage them.
class _MarkersSection extends StatelessWidget {
  const _MarkersSection({
    required this.day,
    required this.markers,
    required this.markerAtDay,
    required this.assignmentAtDay,
    required this.use24h,
    required this.onSettings,
    required this.onToggle,
    required this.onAlarm,
  });

  final DateTime day;
  final List<CalendarMarker> markers;
  final CalendarMarker? markerAtDay;
  final MarkerAssignment? assignmentAtDay;
  final bool use24h;
  final VoidCallback onSettings;
  final ValueChanged<CalendarMarker> onToggle;
  final ValueChanged<CalendarMarker> onAlarm;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(Icons.bookmarks_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Mark ${shortDate(day)} as',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                key: const Key('marker-settings'),
                onTap: onSettings,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Options',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (markers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No custom options yet — tap Options to create "Mark … '
                'as …" entries like the Mock test row above.',
                style: AppTypography.caption.copyWith(fontSize: 10),
              ),
            )
          else
            for (final m in markers) ...[
              _MarkerRow(
                marker: m,
                day: day,
                active: markerAtDay?.id == m.id,
                assignment: assignmentAtDay?.markerId == m.id
                    ? assignmentAtDay
                    : null,
                use24h: use24h,
                onToggle: () => onToggle(m),
                onAlarm: () => onAlarm(m),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

/// A single "Mark <date> as <name>" toggle row — tap to stamp/unstamp,
/// with an alarm chip once the day is marked.
class _MarkerRow extends StatelessWidget {
  const _MarkerRow({
    required this.marker,
    required this.day,
    required this.active,
    required this.assignment,
    required this.use24h,
    required this.onToggle,
    required this.onAlarm,
  });

  final CalendarMarker marker;
  final DateTime day;
  final bool active;
  final MarkerAssignment? assignment;
  final bool use24h;
  final VoidCallback onToggle;
  final VoidCallback onAlarm;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('marker-row-${marker.id}'),
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? marker.color.withValues(alpha: 0.14)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.standard),
          border: Border.all(
            color: active ? marker.color : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: marker.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                active
                    ? 'Marked ${shortDate(day)} as ${marker.name}'
                    : 'Mark ${shortDate(day)} as ${marker.name}',
                style: AppTypography.label.copyWith(
                  color: active ? marker.color : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active) ...[
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                key: Key('marker-alarm-${marker.id}'),
                onTap: onAlarm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: assignment?.hasAlarm == true
                        ? marker.color
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: marker.color, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        assignment?.hasAlarm == true
                            ? Icons.alarm
                            : Icons.alarm_add,
                        size: 14,
                        color: assignment?.hasAlarm == true
                            ? Colors.white
                            : marker.color,
                      ),
                      if (assignment?.hasAlarm == true) ...[
                        const SizedBox(width: 4),
                        Text(
                          fmtClockTime(
                            assignment!.alarmHour!,
                            assignment!.alarmMinute!,
                            use24h: use24h,
                          ),
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Settings dialog — lists every custom option with delete, plus a
/// "New option" shortcut (pops 'new' so the parent opens the creator).
class _MarkerManagerDialog extends ConsumerWidget {
  const _MarkerManagerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(markersProvider);
    final notifier = ref.read(markersProvider.notifier);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text('Custom options',
          style: TextStyle(color: AppColors.textPrimary)),
      content: SizedBox(
        width: 320,
        child: state.markers.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No custom options yet. Create your own "Mark a day '
                  'as …" entries — like the Mock test one — with a name '
                  'and colour of your choice.',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final m in state.markers) ...[
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: m.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            m.name,
                            style: AppTypography.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          key: Key('marker-delete-${m.id}'),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.delete_outline,
                              size: 17, color: AppColors.danger),
                          onPressed: () {
                            final removed =
                                notifier.removeMarker(m.id);
                            // clean up reminders attached to removed days
                            final reminders = ref
                                .read(remindersProvider.notifier);
                            for (final a in removed) {
                              if (a.reminderId != null) {
                                reminders.remove(a.reminderId!);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    if (m != state.markers.last)
                      const Divider(height: AppSpacing.md),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          key: const Key('marker-manager-new'),
          onPressed: () => Navigator.of(context).pop('new'),
          child: Text('New option',
              style: TextStyle(color: AppColors.accent)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

/* --------------------------------------------------------------- dialogs */

class _MockAlarmResult {
  const _MockAlarmResult.remove()
      : remove = true,
        hour = null,
        minute = null,
        notifyOnly = false;

  const _MockAlarmResult.saved(this.hour, this.minute,
      {this.notifyOnly = false})
      : remove = false;

  final bool remove;
  final int? hour;
  final int? minute;
  final bool notifyOnly;
}

/// Alarm time for a mock-test day — steps + typing, 12h/24h aware.
/// Formats a score number: "42" not "42.0".
String _fmtNum(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

class _MockResultPop {
  const _MockResultPop.saved(this.marks, this.max) : remove = false;
  const _MockResultPop.remove()
      : marks = 0,
        max = 0,
        remove = true;

  final double marks;
  final double max;
  final bool remove;
}

/// Log the score of a mock-test day (marks / max marks).
class _MockResultDialog extends StatefulWidget {
  const _MockResultDialog({required this.day, required this.existing});

  final DateTime day;
  final MockResult? existing;

  @override
  State<_MockResultDialog> createState() => _MockResultDialogState();
}

class _MockResultDialogState extends State<_MockResultDialog> {
  late final TextEditingController _marks = TextEditingController(
    text: widget.existing == null
        ? ''
        : '${_fmtNum(widget.existing!.marks)}',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.existing == null ? '' : '${_fmtNum(widget.existing!.max)}',
  );

  @override
  void dispose() {
    _marks.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text('Mock test result',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Score for ${shortDate(widget.day)} — shows on the trend chart.',
            style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('mock-result-marks'),
                  controller: _marks,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: style,
                  decoration: InputDecoration(
                    labelText: 'Marks scored',
                    labelStyle: AppTypography.caption,
                    filled: true,
                    fillColor: AppColors.surfaceFaint,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.standard),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: const Key('mock-result-max'),
                  controller: _max,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: style,
                  decoration: InputDecoration(
                    labelText: 'Max marks',
                    labelStyle: AppTypography.caption,
                    filled: true,
                    fillColor: AppColors.surfaceFaint,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.standard),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            key: const Key('mock-result-remove'),
            onPressed: () =>
                Navigator.of(context).pop(const _MockResultPop.remove()),
            child: Text('Remove',
                style: TextStyle(color: AppColors.danger)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          key: const Key('mock-result-save'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final marks = double.tryParse(_marks.text);
            final max = double.tryParse(_max.text);
            if (marks == null || max == null || max <= 0 || marks < 0) return;
            Navigator.of(context)
                .pop(_MockResultPop.saved(marks, max));
          },
          child: const Text('Save result'),
        ),
      ],
    );
  }
}

class _MockAlarmDialog extends ConsumerStatefulWidget {
  const _MockAlarmDialog({required this.day, required this.existing});

  final DateTime day;
  final MockAlarm? existing;

  @override
  ConsumerState<_MockAlarmDialog> createState() =>
      _MockAlarmDialogState();
}

class _MockAlarmDialogState extends ConsumerState<_MockAlarmDialog> {
  late int _hour = widget.existing?.hour ?? 9;
  late int _minute = widget.existing?.minute ?? 0;
  late bool _notifyOnly = widget.existing?.notifyOnly ?? false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text('Mock test alarm',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rings a reminder on ${shortDate(widget.day)} — even when '
            'the app is closed.',
            style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Alarm time', style: AppTypography.label),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClockInput(
                value: _hour,
                isHour: true,
                keyPrefix: 'mock-time-h',
                onChanged: (v) => setState(() => _hour = v % 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              ClockInput(
                value: _minute,
                isHour: false,
                keyPrefix: 'mock-time-m',
                onChanged: (v) => setState(() => _minute = v % 60),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            key: const Key('mock-alarm-notify-only'),
            onTap: () => setState(() => _notifyOnly = !_notifyOnly),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _notifyOnly
                    ? AppColors.accentSoft
                    : AppColors.surfaceFaint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _notifyOnly ? AppColors.accent : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _notifyOnly
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    size: 15,
                    color: _notifyOnly
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _notifyOnly
                          ? 'Notification only — no sound'
                          : 'Notification only (silent)',
                      style: AppTypography.label.copyWith(
                        color: _notifyOnly
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            key: const Key('mock-alarm-remove'),
            onPressed: () =>
                Navigator.of(context).pop(const _MockAlarmResult.remove()),
            child: Text('Remove alarm',
                style: TextStyle(color: AppColors.danger)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          key: const Key('mock-alarm-save'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(_MockAlarmResult.saved(
            _hour,
            _minute,
            notifyOnly: _notifyOnly,
          )),
          child: const Text('Save alarm'),
        ),
      ],
    );
  }
}

/// New marker: name + colour swatch.
class _NewMarkerDialog extends ConsumerStatefulWidget {
  const _NewMarkerDialog();

  @override
  ConsumerState<_NewMarkerDialog> createState() => _NewMarkerDialogState();
}

class _NewMarkerDialogState extends ConsumerState<_NewMarkerDialog> {
  final _name = TextEditingController();
  int _colorIndex = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text('New marker',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('marker-name'),
            controller: _name,
            autofocus: true,
            cursorColor: AppColors.accent,
            decoration: const InputDecoration(
              labelText: 'Marker name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < appMarkerColors.length; i++)
                GestureDetector(
                  key: Key('marker-color-$i'),
                  onTap: () => setState(() => _colorIndex = i),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(appMarkerColors[i]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorIndex == i
                            ? AppColors.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _colorIndex == i
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          key: const Key('marker-save'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop((
                    name: _name.text.trim(),
                    color: appMarkerColors[_colorIndex],
                  )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _MarkerApplyResult {
  const _MarkerApplyResult.remove()
      : remove = true,
        alarm = null,
        notifyOnly = false;
  const _MarkerApplyResult.saved(DateTime? alarm, {this.notifyOnly = false})
      : remove = false,
        alarm = alarm;

  final bool remove;
  final DateTime? alarm;
  final bool notifyOnly;
}

/// Apply a marker to the selected day — with an optional alarm.
class _MarkerApplyDialog extends ConsumerStatefulWidget {
  const _MarkerApplyDialog({
    required this.day,
    required this.marker,
    required this.assignment,
  });

  final DateTime day;
  final CalendarMarker marker;
  final MarkerAssignment? assignment;

  @override
  ConsumerState<_MarkerApplyDialog> createState() =>
      _MarkerApplyDialogState();
}

class _MarkerApplyDialogState extends ConsumerState<_MarkerApplyDialog> {
  late bool _alarmOn = widget.assignment?.hasAlarm ?? false;
  late int _hour = widget.assignment?.alarmHour ?? 9;
  late int _minute = widget.assignment?.alarmMinute ?? 0;
  late bool _notifyOnly = widget.assignment?.notifyOnly ?? false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text('Apply marker',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.marker.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${widget.marker.name} → ${shortDate(widget.day)}',
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Icon(Icons.notifications_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Ring an alarm on this day',
                    style: AppTypography.label),
              ),
              Switch(
                key: const Key('marker-alarm-toggle'),
                value: _alarmOn,
                activeThumbColor: AppColors.accent,
                onChanged: (v) => setState(() => _alarmOn = v),
              ),
            ],
          ),
          if (_alarmOn) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClockInput(
                  value: _hour,
                  isHour: true,
                  keyPrefix: 'marker-time-h',
                  onChanged: (v) => setState(() => _hour = v % 24),
                ),
                const SizedBox(width: AppSpacing.sm),
                ClockInput(
                  value: _minute,
                  isHour: false,
                  keyPrefix: 'marker-time-m',
                  onChanged: (v) => setState(() => _minute = v % 60),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              key: const Key('marker-notify-only'),
              onTap: () => setState(() => _notifyOnly = !_notifyOnly),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _notifyOnly
                      ? AppColors.accentSoft
                      : AppColors.surfaceFaint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _notifyOnly ? AppColors.accent : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _notifyOnly
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      size: 15,
                      color: _notifyOnly
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _notifyOnly
                            ? 'Notification only — no sound'
                            : 'Notification only (silent)',
                        style: AppTypography.label.copyWith(
                          color: _notifyOnly
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (widget.assignment != null)
          TextButton(
            key: const Key('marker-remove-day'),
            onPressed: () =>
                Navigator.of(context).pop(const _MarkerApplyResult.remove()),
            child: Text('Remove from this day',
                style: TextStyle(color: AppColors.danger)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          key: const Key('marker-apply'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final alarm = _alarmOn
                ? DateTime(widget.day.year, widget.day.month, widget.day.day,
                    _hour, _minute)
                : null;
            Navigator.of(context).pop(_MarkerApplyResult.saved(
              alarm,
              notifyOnly: _notifyOnly,
            ));
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/* --------------------------------------------------------- day status */

/// Day-status window shown when a calendar date is tapped: green days
/// (completed >= goal, so the streak counted) get a confirmation and the
/// completed list; other days show exactly what is still left to do.
class _DayStatusDialog extends StatelessWidget {
  const _DayStatusDialog({
    required this.day,
    required this.tasks,
    required this.done,
    required this.goal,
  });

  final DateTime day;
  final List<PlannerTask> tasks;
  final int done;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final green = done >= goal;
    final pending = tasks.where((t) => !t.done).toList();
    final completed = tasks.where((t) => t.done).toList();

    return AlertDialog(
      key: const Key('day-status'),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text(
        '${day.day} ${plannerMonths[day.month - 1]} — Day status',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: green
                    ? AppColors.success.withValues(alpha: 0.18)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.standard),
                border: Border.all(
                  color: green ? AppColors.successDeep : AppColors.warning,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    green
                        ? Icons.check_circle
                        : Icons.pending_actions_outlined,
                    size: 18,
                    color: green
                        ? AppColors.successDeep
                        : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      green
                          ? 'Day complete — ye date GREEN hai, streak count hua'
                          : 'Green karne ke liye ye baaki hai:',
                      key: green
                          ? const Key('day-status-green')
                          : const Key('day-status-pending-head'),
                      style: AppTypography.label.copyWith(
                        color: green
                            ? AppColors.successDeep
                            : AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$done of $goal tasks done today',
              key: const Key('day-status-goal'),
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (green)
              ...completed.map(
                (t) => _DayStatusRow(
                  title: t.title,
                  trailing: 'done',
                  color: AppColors.successDeep,
                  icon: Icons.check_circle_outline,
                ),
              )
            else if (pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Iss day par koi task nahi hai — neeche add row se tasks '
                  'add karo aur complete karo, phir ye date green ho jayegi.',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary, fontSize: 10),
                ),
              )
            else
              for (final (i, t) in pending.indexed)
                _DayStatusRow(
                  key: Key('day-status-pending-$i'),
                  title: t.title,
                  trailing: t.alarmAt != null ? fmtTime(t.alarmAt!) : null,
                  color: AppColors.warning,
                  icon: Icons.radio_button_unchecked,
                ),
            if (!green && pending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  done < goal
                      ? '$goal tasks complete karne par ye date GREEN ho '
                          'jayegi (streak count hoga) — tasks neeche wali '
                          'list me hain.'
                      : 'Goal to poora hai, par $pending.length tasks abhi '
                          'bhi pending hain.',
                  style: AppTypography.caption.copyWith(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('day-status-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _DayStatusRow extends StatelessWidget {
  const _DayStatusRow({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    this.trailing,
  });

  final String title;
  final Color color;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: AppTypography.body.copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}
