import 'package:flutter/material.dart';

import 'top_bar.dart';

class ShellDestination {
  const ShellDestination({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.index,
    required this.destinations,
    required this.onDestinationSelected,
    required this.center,
  });

  final int index;
  final List<ShellDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final Widget center;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    Widget contentWithTopBar(Widget child) {
      return Column(
        children: [
          const TopBar(),
          Expanded(child: child),
        ],
      );
    }

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: contentWithTopBar(center)),
          ],
        ),
      );
    }

    return Scaffold(
      body: contentWithTopBar(center),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
