import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_design_system.dart';
import '../../shared/widgets/data_card.dart';
import 'models.dart';
import 'syllabus_provider.dart';
import '../../core/utils/dialogs.dart' as dialogs;

/// SYLLABUS â€” the exam tree (Exam â†’ Unit â†’ Chapter â†’ Topic â†’ SubTopic).
/// Tap a node's chip to cycle status; long-press for rename/delete.
/// Every action lives in [SyllabusTreeNotifier]; this page only renders.
class SyllabusPage extends ConsumerWidget {
  const SyllabusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(syllabusProvider);
    final notifier = ref.read(syllabusProvider.notifier);

    final exams = tree;
    final totalNodes = tree.fold<int>(0, (s, e) => s + totalNodesOf(e));
    final doneNodes = tree.fold<int>(0, (s, e) => s + doneNodesOf(e));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ------- overview card -------
          DataCard(
            title: 'Syllabus',
            subtitle: totalNodes == 0
                ? 'Pehla exam add karo â€” phir usme units/chapters'
                : '$doneNodes / $totalNodes topics done',
            body: totalNodes == 0
                ? const SizedBox.shrink()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:
                          totalNodes == 0 ? 0 : doneNodes / totalNodes,
                      backgroundColor: AppColors.surfaceFaint,
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.accent),
                      minHeight: 8,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('syllabus-add-exam'),
                  onPressed: () => _addExam(context, ref),
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: const Text('Add Exam'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (exams.length > 1)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickExamSheet(context, ref),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text('Switch (${exams.length})'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (tree.isEmpty)
            DataCard(
              body: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.menu_book_rounded,
                          size: 36, color: AppColors.accent),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Koi exam nahi',
                        style: AppTypography.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                        'Upar "Add exam" se shuru karo â€” ISI, CMI, ya jo bhi target ho.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ...tree.map((exam) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _ExamNodeCard(node: exam, level: 0),
                )),
        ],
      ),
    );
  }

  Future<void> _addExam(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.standard)),
        title:
            Text('New exam', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          key: const Key('exam-name-field'),
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'e.g. ISI B.Math 2027'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    await ref.read(syllabusProvider.notifier).addExam(ctrl.text.trim());
  }

  void _pickExamSheet(BuildContext context, WidgetRef ref) {
    final tree = ref.read(syllabusProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in tree)
              ListTile(
                leading: Icon(Icons.school_outlined, color: AppColors.accent),
                title: Text(e.name),
                subtitle: Text('${doneNodesOf(e)}/${totalNodesOf(e)} done'),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await dialogs.confirm(context,
                        'Delete ${e.name}?', 'Uska poora tree delete ho jayega.');
                    if (ok == true) {
                      await ref.read(syllabusProvider.notifier).remove(e.id);
                    }
                  },
                ),
                onTap: () => Navigator.pop(ctx),
              ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------------------------------------- node card */

class _ExamNodeCard extends ConsumerStatefulWidget {
  const _ExamNodeCard({required this.node, required this.level});

  final ExamNode node;
  final int level;

  @override
  ConsumerState<_ExamNodeCard> createState() => _ExamNodeCardState();
}

class _ExamNodeCardState extends ConsumerState<_ExamNodeCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final notifier = ref.read(syllabusProvider.notifier);
    final done = doneNodesOf(node);
    final total = totalNodesOf(node);

    return Container(
      margin: EdgeInsets.only(left: widget.level * 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.large),
            onTap: () => setState(() => _expanded = !_expanded),
            onLongPress: () => _nodeMenu(context, ref, node),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(node.name,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w700)),
                          ),
                          if (node.locked) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.lock_rounded,
                                size: 14, color: AppColors.warning),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            statusChip(context, node.status),
                            Text('$done/$total',
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary)),
                            if (node.nextRevision != null) ...[
                              Icon(Icons.event_repeat_rounded,
                                  size: 12, color: AppColors.warning),
                              Text(
                                  '${node.nextRevision!.day}/${node.nextRevision!.month}',
                                  style: AppTypography.caption.copyWith(
                                      fontSize: 10,
                                      color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // cycle status button
                  IconButton(
                    key: Key('node-status-${node.id}'),
                    tooltip: 'Status cycle',
                    icon: Icon(statusIcon(node.status),
                        color: statusColor(node.status), size: 22),
                    onPressed: () =>
                        notifier.cycleStatus(node.id),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    icon: Icon(Icons.more_vert_rounded,
                        size: 18, color: AppColors.textSecondary),
                    onSelected: (v) async {
                      switch (v) {
                        case 'add':
                          final name = await dialogs.promptText(
                              context, 'Add under ${node.name}', 'Name');
                          if (name != null && name.trim().isNotEmpty) {
                            await notifier.addChild(node.id, name.trim());
                          }
                          break;
                        case 'rename':
                          final name = await dialogs.promptText(
                              context, 'Rename', node.name,
                              initial: node.name);
                          if (name != null && name.trim().isNotEmpty) {
                            await notifier.rename(node.id, name.trim());
                          }
                          break;
                        case 'revise':
                          await notifier.scheduleRevision(node.id, DateTime.now().add(const Duration(days: 7)));
                          break;
                        case 'attempt':
                          await notifier.bumpAttempts(node.id, 1);
                          break;
                        case 'lock':
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lock toggle — coming up')));
                          break;
                        case 'delete':
                          final ok = await dialogs.confirm(context,
                              'Delete ${node.name}?', 'Subtree bhi delete hoga.');
                          if (ok == true) {
                            await notifier.remove(node.id);
                          }
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'add',
                          child: Text('Add sub-topic')),
                      const PopupMenuItem(
                          value: 'rename', child: Text('Rename')),
                      const PopupMenuItem(
                          value: 'revise',
                          child: Text('Schedule revision')),
                      const PopupMenuItem(
                          value: 'attempt',
                          child: Text('\+1 attempt')),
                      PopupMenuItem(
                          value: 'lock',
                          child: Text(node.locked
                              ? 'Unlock'
                              : 'Lock')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && node.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
              child: Column(
                children: node.children
                    .map((c) => _ExamNodeCard(node: c, level: widget.level + 1))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _nodeMenu(BuildContext context, WidgetRef ref, ExamNode node) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${node.name}: tap â—‹ chip to cycle status â€” menu se add/rename/lock')));
  }
}

/* ------------------------------------------------------------ helpers */

int totalNodesOf(ExamNode n) =>
    1 + n.children.fold(0, (s, c) => s + totalNodesOf(c));

int doneNodesOf(ExamNode n) =>
    (n.status == NodeStatus.done ? 1 : 0) +
    n.children.fold(0, (s, c) => s + doneNodesOf(c));

IconData statusIcon(NodeStatus s) => switch (s) {
      NodeStatus.notDone => Icons.radio_button_unchecked_rounded,
      NodeStatus.doing => Icons.play_circle_outline_rounded,
      NodeStatus.partial => Icons.timelapse_rounded,
      NodeStatus.done => Icons.check_circle_rounded,
    };

Color statusColor(NodeStatus s) => switch (s) {
      NodeStatus.notDone => AppColors.textSecondary,
      NodeStatus.doing => AppColors.accent,
      NodeStatus.partial => AppColors.warning,
      NodeStatus.done => AppColors.success,
    };

Widget statusChip(BuildContext context, NodeStatus s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: statusColor(s).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      child: Text(s.name,
          style: AppTypography.caption.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: statusColor(s))),
    );



