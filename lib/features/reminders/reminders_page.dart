import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/colors.dart';
import '../../core/ui/design_tokens.dart';
import '../../core/ui/typography.dart';
import '../reminders/models.dart';

class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key});

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage> {
  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text('Reminders', style: AppTypography.headlineMedium(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddReminderDialog(user.id),
            tooltip: 'Add reminder',
          ),
        ],
      ),
      body: FutureBuilder<List<Reminder>>(
        future: ReminderRepository.instance.getAll(user.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reminders = snapshot.data!;
          if (reminders.isEmpty) {
            return _EmptyReminders(onAdd: () => _showAddReminderDialog(user.id));
          }
          final upcoming = reminders.where((r) => !r.isPast).toList()
            ..sort((a, b) => a.at.compareTo(b.at));
          final past = reminders.where((r) => r.isPast).toList()
            ..sort((a, b) => b.at.compareTo(a.at));

          return ListView(
            padding: const EdgeInsets.all(AppDesign.space4),
            children: [
              if (upcoming.isNotEmpty) ...[
                _SectionHeader(title: 'Upcoming', count: upcoming.length),
                ...upcoming.map((r) => _ReminderCard(reminder: r)).toList(),
                const SizedBox(height: AppDesign.space4),
              ],
              if (past.isNotEmpty) ...[
                _SectionHeader(title: 'Past', count: past.length),
                ...past.map((r) => _ReminderCard(reminder: r)).toList(),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReminderDialog(user.id),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddReminderDialog(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddReminderSheet(userId: userId),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space4,
        vertical: AppDesign.space2,
      ),
      child: Row(
        children: [
          Text(title, style: AppTypography.titleMedium(context)),
          const SizedBox(width: AppDesign.space2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppDesign.radiusFull),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({required this.reminder});
  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPast = reminder.isPast;
    final isLocked = reminder.locked;

    return Dismissible(
      key: Key(reminder.id),
      direction: isLocked ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        ),
        child: Icon(
          Icons.delete_rounded,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (direction) async {
        if (isLocked) return false;
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete reminder?'),
                content: const Text('This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => ReminderRepository.instance.delete(reminder.id),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: AppDesign.space2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDesign.space4,
            vertical: AppDesign.space2,
          ),
          leading: Container(
            padding: const EdgeInsets.all(AppDesign.space2),
            decoration: BoxDecoration(
              color: isPast
                  ? Theme.of(context).colorScheme.errorContainer
                  : reminder.silent
                      ? Theme.of(context).colorScheme.warningContainer
                      : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppDesign.radiusMd),
            ),
            child: Icon(
              isPast
                  ? Icons.history_rounded
                  : reminder.silent
                      ? Icons.volume_off_rounded
                      : Icons.notifications_rounded,
              size: 22,
              color: isPast
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : reminder.silent
                      ? Theme.of(context).colorScheme.onWarningContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            reminder.title,
            style: TextStyle(
              decoration: isPast ? TextDecoration.lineThrough : null,
              color: isPast
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            '${_formatDate(reminder.at)} • ${_formatTime(reminder.at)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: isLocked
              ? Icon(Icons.lock_rounded, size: 18, color: AppColors.warning500)
              : null,
          onTap: () => _showDetails(context),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReminderDetailSheet(reminder: reminder),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet({required this.userId});
  final String userId;

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now().replacing(minute: 0).replacing(hour: 9);
  bool _silent = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDesign.radiusXl),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDesign.space5),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New Reminder', style: AppTypography.headlineMedium(context)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppDesign.space4),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What to remind?',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: AppDesign.space4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) setState(() => _selectedDate = date);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDesign.space3),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (time != null) setState(() => _selectedTime = time);
                      },
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(_selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDesign.space4),
              SwitchListTile(
                title: const Text('Silent (notification only)'),
                subtitle: const Text('No sound, just popup'),
                value: _silent,
                onChanged: (v) => setState(() => _silent = v),
              ),
              const SizedBox(height: AppDesign.space4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppDesign.space3),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saveReminder,
                      child: const Text('Create Reminder'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    final at = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (at.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time must be in the future')),
      );
      return;
    }

    final reminder = Reminder(
      id: '',
      userId: widget.userId,
      title: _titleController.text.trim(),
      at: at,
      silent: _silent,
    );

    await ReminderRepository.instance.create(reminder);
    if (mounted) Navigator.pop(context);
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesign.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesign.space5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppDesign.space5),
            Text('No reminders yet', style: AppTypography.titleLarge(context)),
            const SizedBox(height: AppDesign.space2),
            Text(
              'Set reminders for important deadlines',
              style: AppTypography.bodyMedium(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesign.space5),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Reminder'),
            ),
          ],
        ),
      ),
    );
  }
}