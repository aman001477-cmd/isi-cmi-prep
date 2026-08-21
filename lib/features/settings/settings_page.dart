import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/design_tokens.dart';
import '../../core/ui/typography.dart';
import '../auth/auth_provider.dart';
import 'models.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = supabase.auth.currentUser;
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: AppTypography.headlineMedium(context))),
      body: ListView(
        padding: const EdgeInsets.all(AppDesign.space4),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text((user?.email ?? 'U')[0].toUpperCase())),
              title: Text(user?.email ?? ''),
              subtitle: Text(isAdmin ? 'Admin' : 'User'),
            ),
          ),
          const SizedBox(height: AppDesign.space4),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign Out'),
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Version 1.0.0'),
            subtitle: const Text('ISI CMI Prep'),
          ),
        ],
      ),
    );
  }
}
