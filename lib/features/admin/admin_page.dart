import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/auth/user_store.dart';
import '../../core/backup/backup_files.dart';
import '../../core/cloud/cloud_sync.dart';
import '../../core/theme/app_design_system.dart';
import '../../shared/widgets/data_card.dart';

/// ADMIN PANEL — only visible when the signed-in account is the admin.
///
/// Users (id + password), every user's details + stats, task editing,
/// per-user permissions (edit/delete/remove/reenter), per-user backups
/// and account removal.
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  List<UserAccount> _users = [];
  bool _loading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    var users = await UserStore.loadUsers();
    // merge cloud accounts (independent devices) into the local registry
    if (CloudSync.cloudReady) {
      final cloud = await CloudSync.listAccounts();
      for (final c in cloud) {
        if (!users.any((u) => u.id == c.id)) users.add(c);
      }
      if (cloud.isNotEmpty) {
        await UserStore.saveUsers(users);
        users = await UserStore.loadUsers();
      }
    }
    if (!mounted) return;
    setState(() {
      _users = users;
      _loading = false;
      if (_selectedId != null &&
          !users.any((u) => u.id == _selectedId)) {
        _selectedId = null;
      }
    });
  }

  Future<void> _addUser() async {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.standard)),
        title: Text('New user',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('admin-user-name'),
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin-user-password'),
              controller: passCtrl,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            key: const Key('admin-create-user'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final account =
        await UserStore.createUser(_users, nameCtrl.text, passCtrl.text);
    if (!mounted) return;
    // cloud identity for the same id+password, if the cloud is on
    unawaited(CloudSync.ensureAuthUser(account.id, passCtrl.text));
    unawaited(CloudSync.pushAccount(account));
    await _reload();
    await _select(account.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('User created — login id: ${account.id}')));
  }

  Future<void> _select(String id) async {
    setState(() => _selectedId = id);
  }

  Future<void> _remove(UserAccount u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.standard)),
        title: Text('Delete ${u.name}?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'User id ${u.id} ka poora data (slot, stats, backups) hamesha ke liye delete ho jayega.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            key: const Key('user-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerDeep),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final active = await UserStore.activeUserId();
    await UserStore.removeUser(_users, u.id, active);
    unawaited(CloudSync.removeSlot(u.id));
    unawaited(CloudSync.removeAccount(u.id));
    if (!mounted) return;
    await _reload();
  }

  Future<void> _changeAdminPassword() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.standard)),
        title: Text('Change admin password',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          key: const Key('admin-new-password'),
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: 'New password', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            key: const Key('admin-save-password'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || ctrl.text.isEmpty) return;
    await UserStore.setAdminPassword(ctrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin password changed')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final selected = _selectedId == null
        ? null
        : _users.where((u) => u.id == _selectedId).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- user list ----
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('Users (${_users.length})',
                          style: AppTypography.titleMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      key: const Key('admin-add-user'),
                      onPressed: _addUser,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add user'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final u in _users) ...[
                  _UserCard(
                    account: u,
                    selected: u.id == _selectedId,
                    onOpen: () => _select(u.id),
                    onDelete: u.isAdmin ? null : () => _remove(u),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.sm),
                if (_users.where((u) => u.isAdmin).isNotEmpty)
                  OutlinedButton.icon(
                    key: const Key('admin-change-pass'),
                    onPressed: _changeAdminPassword,
                    icon: const Icon(Icons.password_outlined, size: 18),
                    label: const Text('Change admin password'),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // ---- selected user detail ----
          Expanded(
            flex: 5,
            child: selected == null
                ? DataCard(
                    body: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Kisi user pe click karke uski details, stats, tasks aur permissions dekh/ede sakte ho.',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : _UserDetail(
                    account: selected,
                    onChanged: _reload,
                    onRemoveUser: () => _remove(selected),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.account,
    required this.selected,
    required this.onOpen,
    required this.onDelete,
  });

  final UserAccount account;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      key: Key('user-card-${account.id}'),
      body: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.standard),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    AppColors.accent.withValues(alpha: 0.14),
                child: Text(
                  account.name.characters.first.toUpperCase(),
                  style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      account.isAdmin
                          ? 'admin · full access'
                          : 'id: ${account.id} · user',
                      style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 18, color: AppColors.success),
              if (onDelete != null)
                IconButton(
                  key: Key('user-delete-${account.id}'),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.danger,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything about ONE user: stats, task editing, permissions, backup.
class _UserDetail extends ConsumerStatefulWidget {
  const _UserDetail({
    required this.account,
    required this.onChanged,
    required this.onRemoveUser,
  });

  final UserAccount account;
  final VoidCallback onChanged;
  final VoidCallback onRemoveUser;

  @override
  ConsumerState<_UserDetail> createState() => _UserDetailState();
}

class _UserDetailState extends ConsumerState<_UserDetail> {
  Map<String, Object?>? _slot;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _UserDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.id != widget.account.id) _load();
  }

  Future<void> _load() async {
    final slot = await UserStore.slotOf(widget.account.id);
    if (!mounted) return;
    setState(() {
      _slot = slot;
      _stats = computeStats(slot);
    });
  }

  Future<void> _export() async {
    final slot = await UserStore.slotOf(widget.account.id);
    final raw = UserStore.encodeUserBackup(widget.account.id, slot);
    final saved = await saveBackupFile(
        raw,
        'isi_user_${widget.account.id}_backup_'
        '${DateTime.now().toIso8601String().split('T').first}.json');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved
            ? '${widget.account.id} ka backup download ho gaya'
            : 'Export cancelled')));
  }

  Future<void> _import() async {
    final raw = await pickBackupFile();
    if (raw == null || !mounted) return;
    final slot = UserStore.decodeUserBackup(raw);
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not a valid user backup file')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.standard)),
        title: Text('Restore ${widget.account.name}?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Backup se user ka saara data overwrite ho jayega.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            key: const Key('user-import-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await UserStore.restoreSlot(widget.account.id, slot);
    unawaited(CloudSync.pushSlot(widget.account.id, slot));
    if (!mounted) return;
    await _load();
    widget.onChanged();
  }

  void _setPerm(String field, bool value) async {
    final users = await UserStore.loadUsers();
    final updated = users
        .map((u) => u.id == widget.account.id
            ? _patchPerm(u, field, value)
            : u)
        .toList();
    await UserStore.saveUsers(updated);
    unawaited(CloudSync.pushSlot(
        widget.account.id, await UserStore.slotOf(widget.account.id)));
    final changed =
        updated.where((u) => u.id == widget.account.id).firstOrNull;
    if (changed != null) unawaited(CloudSync.pushAccount(changed));
    if (!mounted) return;
    widget.onChanged();
  }

  static UserAccount _patchPerm(UserAccount u, String field, bool value) {
    switch (field) {
      case 'canEdit':
        return u.copyWith(canEdit: value);
      case 'canDelete':
        return u.copyWith(canDelete: value);
      case 'canRemove':
        return u.copyWith(canRemove: value);
      case 'canReenter':
        return u.copyWith(canReenter: value);
    }
    return u;
  }

  Future<void> _editTask(int index) async {
    final slot = _slot;
    final tasks = parseTasks(slot?['planner_v1']);
    if (index >= tasks.length) return;
    final t = tasks[index];
    final titleCtrl = TextEditingController(text: t['title'] as String? ?? '');
    final isDone = t['done'] == true;
    final date = t['date'] as String? ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.standard)),
        title: Text('Edit task',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('admin-task-title'),
              controller: titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: $date',
              style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            key: const Key('admin-save-task'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    t['title'] = titleCtrl.text.trim();
    t['done'] = isDone;
    tasks[index] = t;
    final newSlot = Map<String, Object?>.of(slot!);
    newSlot['planner_v1'] = jsonEncode(tasks);
    await UserStore.restoreSlot(widget.account.id, newSlot);
    unawaited(CloudSync.pushSlot(widget.account.id, newSlot));
    if (!mounted) return;
    await _load();
    widget.onChanged();
  }

  Future<void> _deleteTask(int index) async {
    final slot = _slot;
    if (slot == null) return;
    final tasks = parseTasks(slot['planner_v1']);
    if (index >= tasks.length) return;
    tasks.removeAt(index);
    final newSlot = Map<String, Object?>.of(slot);
    newSlot['planner_v1'] = jsonEncode(tasks);
    await UserStore.restoreSlot(widget.account.id, newSlot);
    unawaited(CloudSync.pushSlot(widget.account.id, newSlot));
    if (!mounted) return;
    await _load();
    widget.onChanged();
  }

  void _toggleTaskDone(int index, bool done) async {
    final slot = _slot;
    if (slot == null) return;
    final tasks = parseTasks(slot['planner_v1']);
    if (index >= tasks.length) return;
    tasks[index]['done'] = done;
    final newSlot = Map<String, Object?>.of(slot);
    newSlot['planner_v1'] = jsonEncode(tasks);
    await UserStore.restoreSlot(widget.account.id, newSlot);
    unawaited(CloudSync.pushSlot(widget.account.id, newSlot));
    if (!mounted) return;
    await _load();
    widget.onChanged();
  }

  Future<void> _toggleTaskLock(int index) async {
    final slot = _slot;
    if (slot == null) return;
    final tasks = parseTasks(slot['planner_v1']);
    if (index >= tasks.length) return;
    final currentlyLocked = tasks[index]['locked'] == true;
    tasks[index]['locked'] = !currentlyLocked;
    tasks[index]['lockedBy'] = !currentlyLocked ? 'admin' : null;
    final newSlot = Map<String, Object?>.of(slot);
    newSlot['planner_v1'] = jsonEncode(tasks);
    await UserStore.restoreSlot(widget.account.id, newSlot);
    unawaited(CloudSync.pushSlot(widget.account.id, newSlot));
    if (!mounted) return;
    await _load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.account;
    final slot = _slot;

    final tasks = parseTasks(slot?['planner_v1']);

    return DataCard(
      key: Key('user-detail-${u.id}'),
      title: u.name,
      subtitle: u.isAdmin
          ? 'Admin — full access'
          : 'id: ${u.id} · joined '
              '${u.createdAt == null ? '—' : '${u.createdAt!.day}/${u.createdAt!.month}/${u.createdAt!.year}'}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ------- stats -------
          Text('Stats',
              style: AppTypography.caption.copyWith(
                  fontSize: 10, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _stats.entries)
                _StatChip(label: e.key, value: e.value.toString()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // ------- tasks -------
          Row(
            children: [
              Text('Tasks (${tasks.length})',
                  style: AppTypography.caption.copyWith(
                      fontSize: 10, letterSpacing: 0.6)),
            ],
          ),
          const SizedBox(height: 4),
          if (tasks.isEmpty)
            Text('Koi task nahi',
                style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary))
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.28),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tasks.length,
                itemBuilder: (context, i) {
                  final t = tasks[i];
                  final title = t['title'] as String? ?? '-';
                  final date = t['date'] as String? ?? '';
                  final done = t['done'] == true;
                  final backlog = t['backlog'] == true;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      key: Key('user-task-$i'),
                      children: [
                        Checkbox(
                          value: done,
                          onChanged: (v) => _toggleTaskDone(i, v ?? false),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                                fontSize: 12,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null),
                          ),
                        ),
                        Text(
                          backlog ? 'backlog' : date,
                          style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondary),
                        ),
                        IconButton(
                          key: Key('task-edit-$i'),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _editTask(i),
                        ),
                        IconButton(
                          key: Key('task-lock-$i'),
                          icon: Icon(
                            (t['locked'] == true)
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            size: 16,
                          ),
                          color: (t['locked'] == true)
                              ? AppColors.warning
                              : AppColors.textSecondary,
                          tooltip: (t['locked'] == true) ? 'Unlock' : 'Lock',
                          onPressed: () => _toggleTaskLock(i),
                        ),
                        IconButton(
                          key: Key('task-delete-$i'),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          color: AppColors.danger,
                          onPressed: () => _deleteTask(i),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          // ------- permissions -------
          Text('Permissions',
              style: AppTypography.caption.copyWith(
                  fontSize: 10, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          if (u.isAdmin)
            Text('Admin ko sab kuch allowed hai',
                style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary))
          else ...[
            _PermToggle(
              key: Key('perm-edit-${u.id}'),
              label: 'Edit',
              hint: 'tasks/schedule/entries badal sakta hai',
              value: u.canEdit,
              onChanged: (v) => _setPerm('canEdit', v),
            ),
            _PermToggle(
              key: Key('perm-delete-${u.id}'),
              label: 'Delete',
              hint: 'entries delete kar sakta hai',
              value: u.canDelete,
              onChanged: (v) => _setPerm('canDelete', v),
            ),
            _PermToggle(
              key: Key('perm-remove-${u.id}'),
              label: 'Remove',
              hint: 'clear/bulk cleanup kar sakta hai',
              value: u.canRemove,
              onChanged: (v) => _setPerm('canRemove', v),
            ),
            _PermToggle(
              key: Key('perm-reenter-${u.id}'),
              label: 'Reenter',
              hint: 'backlog/tasks dobara schedule kar sakta hai',
              value: u.canReenter,
              onChanged: (v) => _setPerm('canReenter', v),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // ------- impersonate (same UI as user) -------
          if (!u.isAdmin)
            FilledButton.icon(
              key: Key('user-impersonate-${u.id}'),
              onPressed: () async {
                final session = ref.read(sessionProvider.notifier);
                await session.impersonate(u.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Viewing as ${u.name} — same UI as user')),
                  );
                }
              },
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('View as user — same UI'),
            ),
          const SizedBox(height: AppSpacing.md),
          // ------- backup -------
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('user-export-${u.id}'),
                  onPressed: _export,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Backup user'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('user-import-${u.id}'),
                  onPressed: _import,
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: const Text('Restore backup'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!u.isAdmin)
            OutlinedButton.icon(
              key: Key('user-remove-${u.id}'),
              onPressed: widget.onRemoveUser,
              icon: const Icon(Icons.person_off_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger),
              label: const Text('Remove this user'),
            ),
        ],
      ),
    );
  }
}

/// Stat chip rendering.
class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceFaint,
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
                fontSize: 9, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: AppTypography.body.copyWith(
                fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PermToggle extends StatelessWidget {
  const _PermToggle({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label,
            style: AppTypography.body
                .copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text(hint,
            style: AppTypography.caption.copyWith(
                fontSize: 10, color: AppColors.textSecondary)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// Parse slot JSON into per-user stats.
Map<String, dynamic> computeStats(Map<String, Object?> slot) {
  final stats = <String, dynamic>{};

  final tasks = parseTasks(slot['planner_v1']);
  final todayStr = _day(DateTime.now());
  int todayTotal = 0, todayDone = 0, open = 0, backlog = 0, doneTotal = 0;
  for (final t in tasks) {
    final done = t['done'] == true;
    final isBacklog = t['backlog'] == true;
    final date = t['date'] as String? ?? '';
    if (done) doneTotal++;
    if (isBacklog) backlog++;
    if (!done && !isBacklog) open++;
    if (date == todayStr) {
      todayTotal++;
      if (done) todayDone++;
    }
  }
  if (tasks.isNotEmpty) {
    stats['Tasks'] = '$doneTotal/$tasks.length done';
    stats['Today'] = '$todayDone/$todayTotal';
    stats['Open'] = open;
    stats['Backlog'] = backlog;
  }

  final studyRaw = slot['study_log_v1'] as String?;
  if (studyRaw != null) {
    try {
      final map = (jsonDecode(studyRaw) as Map<String, dynamic>)
          .cast<String, Object?>();
      int totalMin = 0;
      var todayMin = 0;
      final weekStart = DateTime.now()
          .subtract(Duration(days: DateTime.now().weekday - 1));
      for (final e in map.entries) {
        final m = (e.value as num?)?.toInt() ?? 0;
        totalMin += m;
        if (e.key == todayStr) todayMin = m;
      }
      // week sum separately
      var weekMin = 0;
      for (final e in map.entries) {
        final m = (e.value as num?)?.toInt() ?? 0;
        final d = DateTime.tryParse(e.key);
        if (d != null && !d.isBefore(weekStart)) weekMin += m;
      }
      stats['Study today'] = '${todayMin}m';
      stats['Study week'] = '$weekMin min';
      stats['Total study'] = '$totalMin min';
    } catch (_) {}
  }

  final marathonRaw = slot['marathon_v2'] as String?;
  if (marathonRaw != null) {
    try {
      final j = jsonDecode(marathonRaw) as Map<String, dynamic>;
      final target = (j['targetMinutes'] as num?)?.toInt() ?? 600;
      final start = DateTime.parse(j['periodStart'] as String);
      final pausedAt = j['pausedAt'] == null
          ? null
          : DateTime.parse(j['pausedAt'] as String);
      final frozen = (j['pausedAccumMs'] as num?)?.toInt() ?? 0;
      final clock = pausedAt ?? DateTime.now();
      final consumed = clock.difference(start).inSeconds - (frozen ~/ 1000);
      final remaining = target * 60 - consumed;
      stats['Marathon target'] = '${target ~/ 60}h';
      stats['Marathon left'] = remaining > 0
          ? '${remaining ~/ 3600}h ${(remaining % 3600) ~/ 60}m'
          : 'Done';
    } catch (_) {}
  }

  final sylRaw = slot['syllabus_tree_v3'] as String?;
  if (sylRaw != null) {
    try {
      final nodes = (jsonDecode(sylRaw) as List);
      var done = 0;
      for (final n in nodes) {
        final wrap = n is Map<String, dynamic> ? n : {};
        final chunks = ((wrap['chapters'] ?? wrap['children']) as List?) ??
            <Object?>[];
        for (final c in chunks) {
          final cm = c is Map<String, dynamic> ? c : {};
          final topics = ((cm['topics'] ?? cm['children']) as List?) ??
              <Object?>[];
          for (final tp in topics) {
            final tm = tp is Map<String, dynamic> ? tp : {};
            if (tm['status'] == 'done' || tm['status'] == 'revised') done++;
          }
        }
      }
      stats['Syllabus'] = '${done} done';
    } catch (_) {}
  }

  final schedRaw = slot['schedule_v1'] as String?;
  if (schedRaw != null) {
    try {
      stats['Schedule'] = '${(jsonDecode(schedRaw) as List).length} slots';
    } catch (_) {}
  }

  final remRaw = slot['reminders_v1'] as String?;
  if (remRaw != null) {
    try {
      final list = (jsonDecode(remRaw) as List);
      final pending = list.where((r) {
        final m = r is Map<String, dynamic> ? r : {};
        return m['dismissed'] != true;
      }).length;
      stats['Reminders'] = '$pending pending';
    } catch (_) {}
  }

  return stats;
}

List<Map<String, dynamic>> parseTasks(Object? raw) {
  if (raw is! String) return [];
  try {
    return (jsonDecode(raw) as List)
        .whereType<Map<String, dynamic>>()
        .toList();
  } catch (_) {
    return [];
  }
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';