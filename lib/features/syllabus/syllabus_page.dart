import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyllabusPage extends ConsumerWidget {
  const SyllabusPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(child: Text('Syllabus', style: Theme.of(context).textTheme.headlineMedium)),
    );
  }
}
