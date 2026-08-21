import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/theme/app_design_system.dart';
import '../../shared/widgets/data_card.dart';
import 'planner_provider.dart';
import 'planner_widgets.dart';
import 'sound_player.dart';

enum _Segment { today, upcoming, backlog }

/// To Do List — an Apple-Reminders-style task list with smart segments
/// (Today / Upcoming / Backlog), per-task bells, and exact alarm times.
/// Alarm rings are handled globally by [RingDialogHandler] in the shell.
class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  _Segment _segment = _Segment.today;

  bool _adding = false;
  final _addCtrl = TextEditingController();
  Bucket _addBucket = Bucket.today;
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
    debugPrint('[planner] $message');
    setState(() => _diag = message);
  }

  void _openAddRow() {
    _addCtrl.clear();
    setState(() {
      _adding = true;
      _addBucket = switch (_segment) {
        _Segment.today => Bucket.today,
        _Segment.upcoming => Bucket.upcoming,
        _Segment.backlog => Bucket.backlog,
      };
      _reminderOn = false;
      _alarmHour = 9;
      _alarmMinute = 0;
      _sound = 'none';
      _ringSec = 30;
      _notifyOnly = false;
    });
    _log('add row open');
  }

  DateTime _bucketDate() {
    return switch (_addBucket) {
      Bucket.today => todayDay(),
      Bucket.upcoming => todayDay().add(const Duration(days: 1)),
      Bucket.backlog => todayDay().subtract(const Duration(days: 1)),
    };
  }

  /// The task's alarm fires on its own day at the chosen clock time; if
  /// that moment already passed, roll forward to the next occurrence so
  /// the reminder still makes sense ("ring at the next 09:00").
  DateTime? _computedAlarm(DateTime taskDay) {
    if (!_reminderOn) return null;
    return advancePast(DateTime(
        taskDay.year, taskDay.month, taskDay.day, _alarmHour, _alarmMinute));
  }

  Future<void> _submitAdd() async {
    if (!Permissions.of(ref).canEdit) {
      _denied('Edit (entry add) band hai is user ke liye');
      return;
    }
    final title = _addCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    final day = _bucketDate();
    final alarm = _computedAlarm(day);
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
          backlog: _addBucket == Bucket.backlog,
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
    if (!Permissions.of(ref).canEdit) {
      _denied('Edit band hai is user ke liye');
      return;
    }
    final title = _renameCtrl.text.trim();
    setState(() => _renamingId = null);
    if (title.isEmpty || title == task.title) return;
    await ref.read(plannerProvider.notifier).rename(task.id, title);
    _log('renamed to “$title”');
  }

  void _requestDelete(String id) {
    if (!Permissions.of(ref).canDelete) {
      _denied('Delete band hai is user ke liye');
      return;
    }
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
    _log('deleted “${task.title}”');
  }

  void _onTodayReorder(
      List<PlannerTask> list, int oldIndex, int newIndex) {
    if (!Permissions.of(ref).canReenter) {
      _denied('Reenter (reorder) band hai is user ke liye');
      return;
    }
    final ids = list.map((t) => t.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    _log('reordered today list');
    ref.read(plannerProvider.notifier).reorderToday(ids);
  }

  /// Shows why an action is unavailable (admin turned the permission off).
  void _denied(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🔒 $message'),
        duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(plannerProvider);
    final notifier = ref.read(plannerProvider.notifier);
    final tasks = switch (_segment) {
      _Segment.today => notifier.today,
      _Segment.upcoming => notifier.upcoming,
      _Segment.backlog => notifier.backlog,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PlannerHeader(),
          const SizedBox(height: AppSpacing.xl),
          _SegmentControl(
            segment: _segment,
            onChanged: (s) {
              setState(() {
                _segment = s;
                _adding = false;
                _addCtrl.clear();
              });
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          PlannerTaskCard(
            title: switch (_segment) {
              _Segment.today => 'Today',
              _Segment.upcoming => 'Upcoming',
              _Segment.backlog => 'Backlog',
            },
            emptyLabel: 'All clear',
            tasks: tasks,
            renamingId: _renamingId,
            renameCtrl: _renameCtrl,
            deleteConfirmId: _deleteConfirmId,
            notifier: notifier,
            onStartRename: _startRename,
            onCommitRename: _commitRename,
            onRequestDelete: _requestDelete,
            onConfirmDelete: _confirmDelete,
            onReorder: _segment == _Segment.today
                ? (oldIndex, newIndex) =>
                    _onTodayReorder(tasks, oldIndex, newIndex)
                : null,
          ),
          PlannerAddRow(
            adding: _adding,
            ctrl: _addCtrl,
            bucket: _addBucket,
            customDate: null,
            reminderOn: _reminderOn,
            hour: _alarmHour,
            minute: _alarmMinute,
            sound: _sound,
            notifyOnly: _notifyOnly,
            ringSeconds: _ringSec,
            onOpen: _openAddRow,
            onSubmit: _submitAdd,
            onBucket: (b) {
              setState(() => _addBucket = b);
              _log('bucket: ${b.name}');
            },
            onCycleCustomDate: () {},
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

/* ------------------------------------------------------------------ header */

class _PlannerHeader extends ConsumerWidget {
  const _PlannerHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(plannerProvider);
    final notifier = ref.read(plannerProvider.notifier);

    return DataCard(
      title: 'To Do List',
      subtitle: 'Tasks · do it today, or it lands in Backlog',
      body: Row(
        children: [
          _HeadTile(label: 'Today', value: '${notifier.today.length}',
              color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          _HeadTile(label: 'Upcoming', value: '${notifier.upcoming.length}',
              color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          _HeadTile(label: 'Backlog', value: '${notifier.backlog.length}',
              color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          _HeadTile(
              label: 'Done',
              value: '${notifier.done}',
              color: AppColors.success),
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

/* --------------------------------------------------------------- segments */

class _SegmentControl extends StatelessWidget {
  const _SegmentControl({required this.segment, required this.onChanged});

  final _Segment segment;
  final ValueChanged<_Segment> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = [
      _Segment.today,
      _Segment.upcoming,
      _Segment.backlog,
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceFaint,
        borderRadius: BorderRadius.circular(AppRadius.standard),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          for (final s in labels)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: segment == s ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.standard - 2),
                    boxShadow: segment == s ? AppShadows.raised : null,
                  ),
                  child: Text(
                    switch (s) {
                      _Segment.today => 'Today',
                      _Segment.upcoming => 'Upcoming',
                      _Segment.backlog => 'Backlog',
                    },
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: segment == s
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
