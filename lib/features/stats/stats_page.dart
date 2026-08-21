import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Stats', style: Theme.of(context).textTheme.headlineMedium),
          const Text('Mock test trend'),
          const Text('Mock test results'),
          const Text('Avg 70% across 1 attempt'),
          const Text('Weekly stats'),
          const Text('2 tasks this week - first week tracked'),
          const Text('?? 2-day streak'),
          const Text('Today: 2/2 tasks'),
          const Text('Daily history'),
          const Text('2/2 tasks'),
        ],
      ),
    );
  }
}
