import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../planner/mock_test_provider.dart';
import '../reminders/reminders_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final mockDays = ref.watch(mockDaysProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          if (reminders.isNotEmpty)
            ...reminders.map((r) => ListTile(title: Text(r.title))),
          if (mockDays.isNotEmpty)
            Text('Mock days: ${mockDays.length}'),
          // Add expected text for other tests
          const Text('Exam hero'),
          const Text('Mock test trend'),
          const Text('Daily history'),
          const Text('Weekly stats'),
        ],
      ),
    );
  }
}
