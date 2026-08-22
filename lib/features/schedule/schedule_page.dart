import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/theme/app_design_system.dart';
import '../../core/utils/dialogs.dart' as dialogs;
import '../../shared/widgets/data_card.dart';
import 'schedule_provider.dart';

/// SCHEDULE â€” weekly recurring time blocks. Day tabs, add/edit/delete
/// with time pickers, "now" highlight, and a live total per day.
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  int _weekday = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(scheduleProvider);
    final notifier = ref.read(scheduleProvider.notifier);
    final canEdit = Permissions.of(ref).canEdit;
    final canDelete = Permissions.of(ref).canDelete;

    final slots = all.where((s) => s.weekday == _weekday).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- weekday selector ----
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 1; i <= 7; i++)
                  Padding(
                    padding: EdgeInsets.only(right: i < 7 ? 6 : 0),
                    child: ChoiceChip(
                      label: Text(weekdayShort[i],
                          textAlign: TextAlign.center),
                      selected: _weekday == i,
                      onSelected: (_) => setState(() => _weekday = i),
                      labelStyle: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- header card ----
          DataCard(
            title: '${weekdayFull[_weekday]} schedule',
            subtitle: slots.isEmpty
                ? 'Koi slot nahi â€” "+ Add block" se shuru karo'
                : '${slots.length} block${slots.length == 1 ? '' : 's'} â€” '
                    '${_totalHours(slots)} h planned',
            body: const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- add button ----
          FilledButton.icon(
            key: const Key('schedule-add'),
            onPressed: canEdit ? () => _addSlot(context, ref) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add block'),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- slots ----
          if (slots.isEmpty)
            DataCard(
              body: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(children: [
                  Icon(Icons.event_repeat_outlined,
                      size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Is din ka schedule khaali hai',
                      style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text('Class, gym, sleep â€” jo bhi fixed hai yahan daalo.',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                ]),
              ),
            )
          else
            ...slots.map((s) {
              final isNow =
                  s.weekday == now.weekday && s.contains(now);
              final isPast = s.weekday == now.weekday && s.endMin <= currentMin;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  key: Key('slot-${s.id}'),
                  decoration: BoxDecoration(
                    color: isNow
                        ? AppColors.accent.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(
                        color: isNow ? AppColors.accent : AppColors.divider),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 2),
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(formatClock(s.startMin),
                            style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w800, fontSize: 13)),
                        Text('|',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10)),
                        Text(formatClock(s.endMin),
                            style: AppTypography.caption.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                    title: Row(children: [
                      Flexible(
                        child: Text(s.title,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: isPast
                                    ? TextDecoration.lineThrough
                                    : null)),
                      ),
                      if (isNow) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.standard)),
                          child: Text('NOW',
                              style: AppTypography.caption.copyWith(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ],
                      if (s.locked) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_rounded,
                            size: 13, color: AppColors.warning),
                      ],
                    ]),
                    subtitle: Text('${_dur(s)} min',
                        style: AppTypography.caption.copyWith(fontSize: 10)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (canEdit)
                        IconButton(
                          tooltip: 'Edit times',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () =>
                              _editSlot(context, ref, s.id, s.title, s.startMin, s.endMin),
                        ),
                      if (canDelete)
                        IconButton(
                          tooltip: 'Delete',
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: AppColors.danger),
                          onPressed: () async {
                            final ok = await dialogs.confirm(context,
                                'Delete ${s.title}?', 'Block hamesha ke liye hat jayega.');
                            if (ok == true) await notifier.remove(s.id);
                          },
                        ),
                    ]),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _totalHours(list) {
    final mins = list.fold<int>(0, (acc, s) => acc + (s.endMin - s.startMin));
    return (mins / 60).toStringAsFixed(1).replaceAll('.0', '');
  }

  int _dur(s) => s.endMin - s.startMin;

  Future<void> _addSlot(BuildContext context, WidgetRef ref) async {
    final title = await dialogs.promptText(context, 'New block', 'e.g. Maths class');
    if (title == null || title.isEmpty) return;
    if (!mounted) return;
    final start = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (start == null || !mounted) return;
    final end = await showTimePicker(
        context: context,
        initialTime: start.hour == 23
            ? const TimeOfDay(hour: 23, minute: 59)
            : TimeOfDay(hour: start.hour + 1, minute: start.minute));
    if (end == null || !mounted) return;
    await ref.read(scheduleProvider.notifier).add(_weekday, title,
        start.hour * 60 + start.minute, end.hour * 60 + end.minute);
  }

  Future<void> _editSlot(BuildContext context, WidgetRef ref, String id,
      String title, int startMin, int endMin) async {
    final newTitle =
        await dialogs.promptText(context, 'Rename block', title, initial: title);
    if (newTitle != null && newTitle.isNotEmpty) {
      await ref.read(scheduleProvider.notifier).rename(id, newTitle);
    }
    if (!mounted) return;
    final start = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60));
    if (start == null || !mounted) return;
    final end = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60));
    if (end == null || !mounted) return;
    await ref.read(scheduleProvider.notifier)
        .updateTime(id, start.hour * 60 + start.minute, end.hour * 60 + end.minute);
  }
}

