import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sound/custom_sound.dart';
import '../../core/theme/app_design_system.dart';
import '../../core/utils/time_format.dart';
import '../../shared/widgets/data_card.dart';
import '../../shared/widgets/neu_button.dart';
import '../planner/sound_player.dart';
import 'reminder_model.dart';
import 'reminders_provider.dart';

/// Reminders card — list of one-shot date-time alarms with add/delete.
class RemindersCard extends ConsumerWidget {
  const RemindersCard({super.key});

  Future<void> _add(WidgetRef ref, BuildContext context) async {
    final reminder = await showDialog<Reminder>(
      context: context,
      builder: (_) => const _AddReminderDialog(),
    );
    if (reminder == null) return;
    await ref
        .read(remindersProvider.notifier)
        .add(reminder.title, reminder.at);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Reminder set for '
                '${fmtClockTime(reminder.at.hour, reminder.at.minute, use24h: ref.read(timeFormatProvider))}')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final use24h = ref.watch(timeFormatProvider);
    final upcoming = ref.read(remindersProvider.notifier).upcoming;

    return DataCard(
      title: 'Reminders',
      subtitle: 'Date-time alarms — ring & pop up even when the app is closed',
      trailing: NeuButton(
        label: 'Add Reminder',
        icon: Icons.alarm_add,
        height: 40,
        onPressed: () => _add(ref, context),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RingtoneRow(),
          const SizedBox(height: AppSpacing.md),
          if (reminders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No reminders yet — set one for any date & time.'),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in upcoming) ...[
                  _ReminderRow(reminder: r, use24h: use24h),
                  const SizedBox(height: 6),
                ],
                if (upcoming.length != reminders.length) ...[
                  const Divider(height: AppSpacing.lg),
                  Text('Past & due',
                      style: AppTypography.caption.copyWith(
                          fontSize: 10, letterSpacing: 0.6)),
                  for (final r in reminders)
                    if (!upcoming.contains(r)) ...[
                      const SizedBox(height: 6),
                      _ReminderRow(reminder: r, use24h: use24h, past: true),
                    ],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// "Custom ringtone" row — pick an audio file from the device, preview
/// it, or remove it again (falls back to the bundled chime). Shown in
/// the Reminders card and the profile sheet.
class RingtoneRow extends StatelessWidget {
  const RingtoneRow({super.key});

  static const _audioType = XTypeGroup(
    label: 'Audio',
    extensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'oga', 'flac'],
    mimeTypes: [
      'audio/mpeg',
      'audio/wav',
      'audio/x-wav',
      'audio/mp4',
      'audio/x-m4a',
      'audio/aac',
      'audio/ogg',
      'audio/flac',
    ],
  );

  Future<void> _pick(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await openFile(acceptedTypeGroups: const [_audioType]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ok = await CustomSoundStore.instance.save(bytes, file.name);
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Could not save that audio — keep it under 6 MB.'),
        ));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not read that file.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CustomSound?>(
      valueListenable: customSoundNotifier,
      builder: (context, sound, _) => Container(
        key: const Key('ringtone-row'),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: sound == null
              ? AppColors.surfaceFaint
              : AppColors.accentSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sound == null ? AppColors.border : AppColors.accent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              sound == null
                  ? Icons.music_note_outlined
                  : Icons.music_note,
              size: 16,
              color:
                  sound == null ? AppColors.textSecondary : AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Custom ringtone',
                      style: AppTypography.label.copyWith(
                        color: sound == null
                            ? AppColors.textPrimary
                            : AppColors.accent,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    sound == null
                        ? 'Default — bundled chime'
                        : sound.name,
                    style: AppTypography.caption.copyWith(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (sound != null) ...[
              IconButton(
                key: const Key('ringtone-preview'),
                tooltip: 'Preview',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.play_arrow,
                    size: 18, color: AppColors.accent),
                onPressed: () {
                  stopSound();
                  playSound('custom');
                },
              ),
              IconButton(
                key: const Key('ringtone-remove'),
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close,
                    size: 18, color: AppColors.danger),
                onPressed: () => CustomSoundStore.instance.clear(),
              ),
            ],
            TextButton(
              key: const Key('ringtone-pick'),
              onPressed: () => _pick(context),
              child: Text(sound == null ? 'Choose' : 'Change',
                  style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({
    required this.reminder,
    required this.use24h,
    this.past = false,
  });

  final Reminder reminder;
  final bool use24h;
  final bool past;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = reminder.at;
    final month = const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][at.month - 1];

    return Container(
      key: Key('reminder-${reminder.id}'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: past ? AppColors.surfaceFaint : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: past ? AppColors.divider : AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            past ? Icons.alarm_off : Icons.alarm,
            size: 16,
            color: past ? AppColors.textSecondary : AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: AppTypography.label.copyWith(
                    color: past ? AppColors.textSecondary : AppColors.textPrimary,
                    decoration: past ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${at.day} $month · '
                  '${fmtClockTime(at.hour, at.minute, use24h: use24h)}'
                  '${past ? ' — due' : ''}',
                  style: AppTypography.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('reminder-delete-${reminder.id}'),
            icon: Icon(Icons.delete_outline,
                size: 17, color: AppColors.danger),
            onPressed: () async {
              await ref.read(remindersProvider.notifier).remove(reminder.id);
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Add dialog: title + date + time.
class _AddReminderDialog extends ConsumerStatefulWidget {
  const _AddReminderDialog();

  @override
  ConsumerState<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends ConsumerState<_AddReminderDialog> {
  final _title = TextEditingController();
  DateTime _date = DateTime.now();

  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _time = TimeOfDay(
      hour: (now.hour + (now.minute + 5) ~/ 60) % 24,
      minute: (now.minute + 5) % 60,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final use24h = ref.watch(timeFormatProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      title: Text('New Reminder',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('reminder-title'),
            controller: _title,
            autofocus: true,
            cursorColor: AppColors.accent,
            decoration: const InputDecoration(
              labelText: 'Reminder text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('reminder-date'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2036),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 15),
                  label: Text(
                    '${_date.day}/${_date.month}/${_date.year}',
                    style: AppTypography.label,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('reminder-time'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _time,
                      helpText: 'Reminder time',
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            alwaysUse24HourFormat: use24h),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => _time = picked);
                  },
                  icon: const Icon(Icons.access_time, size: 15),
                  label: Text(
                    fmtClockTime(_time.hour, _time.minute, use24h: use24h),
                    style: AppTypography.label,
                  ),
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
        TextButton(
          key: const Key('reminder-save'),
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            final at = DateTime(
              _date.year,
              _date.month,
              _date.day,
              _time.hour,
              _time.minute,
            );
            Navigator.of(context).pop(
              Reminder(id: '', title: title, at: at),
            );
          },
          child: Text('Save', style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }
}

/// Global popup host — shows a dialog (with a close ✕, Snooze and
/// Dismiss) the moment a reminder becomes due, on any page.
class ReminderPopupHandler extends ConsumerStatefulWidget {
  const ReminderPopupHandler({super.key});

  @override
  ConsumerState<ReminderPopupHandler> createState() =>
      _ReminderPopupHandlerState();
}

class _ReminderPopupHandlerState extends ConsumerState<ReminderPopupHandler> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(dueReminderProvider, (prev, next) {
      if (next != null && !_open) _show(next);
    });
    return const SizedBox.shrink();
  }

  Future<void> _show(Reminder r) async {
    _open = true;
    final notifier = ref.read(remindersProvider.notifier);
    final use24h = ref.read(timeFormatProvider);
    // "Notification only" reminders pop up without any sound.
    final isSilent = r.silent;

    if (!isSilent) {
      // rings with the user's custom audio (bundled chime as fallback)
      // while the popup is up, on platforms where in-app audio exists.
      playLoop(customSoundNotifier.value == null ? 'chime' : 'custom');
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.standard),
        ),
        title: Row(
          children: [
            Icon(Icons.alarm, size: 20, color: AppColors.accent),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Reminder')),
            GestureDetector(
              key: const Key('reminder-close'),
              onTap: () => Navigator.of(dialogContext).pop(),
              child: Icon(Icons.close,
                  size: 20, color: AppColors.textSecondary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.title,
                style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${r.at.day}/${r.at.month}/${r.at.year} · '
              '${fmtClockTime(r.at.hour, r.at.minute, use24h: use24h)}',
              style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('reminder-snooze'),
            onPressed: () {
              // Popups can come from sources other than the reminders
              // list (e.g. silent task alarms) — snooze only if the id
              // exists there, otherwise just close.
              final exists =
                  ref.read(remindersProvider).any((x) => x.id == r.id);
              if (exists) {
                notifier.snooze(r.id, const Duration(minutes: 5));
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text('Snooze 5 min',
                style: TextStyle(color: AppColors.warningDeep)),
          ),
          TextButton(
            key: const Key('reminder-dismiss'),
            onPressed: () {
              final exists =
                  ref.read(remindersProvider).any((x) => x.id == r.id);
              if (exists) {
                notifier.remove(r.id);
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text('Dismiss',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    // whatever closed it, stop the ring and clear the due flag so it
    // can fire again later
    stopSound();
    ref.read(dueReminderProvider.notifier).state = null;
    _open = false;
  }
}
