import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_design_system.dart';
import '../../core/theme/app_logo.dart';
import 'syllabus_provider.dart';

class SyllabusPage extends ConsumerWidget {
  const SyllabusPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(syllabusProvider);
    if (tree.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(Icons.menu_book_rounded, size: 48, color: AppColors.accent)),
            const SizedBox(height: 16),
            Text('No topics yet', style: AppTypography.titleLarge),
            const SizedBox(height: 8),
            Text('Start building your syllabus tree', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: (){}, icon: const Icon(Icons.add_rounded), label: const Text('Add First Topic')),
          ]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Syllabus', style: AppTypography.titleLarge)),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: tree.length,
        separatorBuilder: (_,__)=> const SizedBox(height: 12),
        itemBuilder: (context,i){
          final node = tree[i];
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.menu_book_rounded, size: 20, color: AppColors.warning)),
                const SizedBox(width: 12),
                Expanded(child: Text(node.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600))),
                if (node.locked) const Icon(Icons.lock_rounded, size: 18, color: Colors.orange),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: 0.3, backgroundColor: AppColors.warning.withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(AppColors.warning), minHeight: 6, borderRadius: BorderRadius.circular(3)),
            ]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: (){}, child: const Icon(Icons.add_rounded)),
    );
  }
}
