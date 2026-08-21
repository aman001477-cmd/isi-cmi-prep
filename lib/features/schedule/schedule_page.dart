import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_design_system.dart';
import 'schedule_provider.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});
  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  int _weekday = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(scheduleProvider).where((s) => s.weekday == _weekday).toList()..sort((a,b)=>a.startMin.compareTo(b.startMin));
    return Scaffold(
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i=1;i<=7;i++)
                ChoiceChip(
                  label: Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i-1]),
                  selected: _weekday==i,
                  onSelected: (_) => setState(()=> _weekday=i),
                ),
            ],
          ),
        ),
        Expanded(
          child: slots.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.schedule_rounded, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text('No schedule for ${['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][_weekday-1]}', style: AppTypography.titleMedium),
                  const SizedBox(height: 8),
                  Text('Add your first time slot', style: AppTypography.caption),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: slots.length,
                  separatorBuilder: (_,__)=> const SizedBox(height: 8),
                  itemBuilder: (context,i){
                    final s = slots[i];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.divider)),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.access_time_rounded, size: 20, color: AppColors.accent)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.title, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                          Text('${(s.startMin~/60).toString().padLeft(2,'0')}:${(s.startMin%60).toString().padLeft(2,'0')} - ${(s.endMin~/60).toString().padLeft(2,'0')}:${(s.endMin%60).toString().padLeft(2,'0')}', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                        ])),
                        if (s.locked) const Icon(Icons.lock_rounded, size: 18, color: Colors.orange),
                      ]),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: (){}, child: const Icon(Icons.add_rounded)),
    );
  }
}
