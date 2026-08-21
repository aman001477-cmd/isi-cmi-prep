import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_provider.dart';
import '../../features/admin/admin_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/planner/calendar_page.dart';
import '../../features/planner/planner_page.dart';
import '../../features/schedule/schedule_page.dart';
import '../../features/shell/main_shell.dart';
import '../../features/stats/stats_page.dart';
import '../../features/syllabus/syllabus_page.dart';

/// Route gate: signed out → login page, signed in → the six-pane shell
/// (plus the Admin pane for administrators). Any change of the active
/// account invalidates every provider so the UI rebinds to the new user's
/// slot.
class SessionRoot extends ConsumerWidget {
  const SessionRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionProvider, (previous, next) {
      if (previous != null &&
          previous.loading == false &&
          next.loading == false &&
          previous.account?.id != next.account?.id) {
        invalidateAllData(ref);
      }
    });
    final session = ref.watch(sessionProvider);
    if (session.loading) {
      // IntroGate splash covers this frame on first launch.
      return const SizedBox.shrink();
    }
    if (!session.signedIn) {
      return const LoginPage();
    }
    return const AppShell();
  }
}

/// Central route table. Index-based shell navigation keeps the
/// wireframe layout stable while each feature grows into its own page.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isAdmin = session.isAdmin;
    final isImpersonating = ref.watch(sessionProvider.notifier).isImpersonating;
    final impersonatedName = session.account?.name ?? '';

    final destinations = <ShellDestination>[
      const ShellDestination(
          label: 'Dashboard', icon: Icons.space_dashboard_outlined),
      const ShellDestination(
          label: 'Syllabus', icon: Icons.fact_check_outlined),
      const ShellDestination(
          label: 'To Do List', icon: Icons.event_outlined),
      const ShellDestination(
          label: 'Calendar', icon: Icons.calendar_month_outlined),
      const ShellDestination(
          label: 'Stats', icon: Icons.insights_outlined),
      const ShellDestination(
          label: 'Schedule', icon: Icons.event_repeat_outlined),
      if (isAdmin && !isImpersonating)
        const ShellDestination(
            label: 'Admin', icon: Icons.admin_panel_settings_outlined),
    ];
    final pages = <Widget>[
      const DashboardPage(),
      const SyllabusPage(),
      const PlannerPage(),
      const CalendarPage(),
      const StatsPage(),
      const SchedulePage(),
      if (isAdmin && !isImpersonating) const AdminPage(),
    ];

    if (_index >= pages.length) _index = pages.length - 1;

    final shell = MainShell(
      index: _index,
      destinations: destinations,
      onDestinationSelected: (i) => setState(() => _index = i),
      center: IndexedStack(index: _index, children: pages),
    );

    if (!isImpersonating) return shell;

    return Column(
      children: [
        Material(
          color: const Color(0xFFF59E0B),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Viewing as $impersonatedName — same UI as user',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(sessionProvider.notifier).stopImpersonating();
                      if (context.mounted) setState(() => _index = 0);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: shell),
      ],
    );
  }
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SessionRoot(),
      ),
    ],
  );
}