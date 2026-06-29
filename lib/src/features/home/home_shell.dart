import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../courses/bundles_screen.dart';
import '../courses/courses_screen.dart';
import '../profile/profile_screen.dart';
import '../tests/pass_screen.dart';
import '../tests/tests_screen.dart';
import 'dashboard_screen.dart';

/// The signed-in app shell: bottom navigation across the five student areas.
///
/// The PLATFORM school (MindSpan) sells the PASS as its prime offering, so for
/// it the bottom nav surfaces **PASS** as a primary tab and Bundles moves into
/// the Home page. Other schools have no PASS / external-exam footprint, so they
/// keep the original nav (Bundles stays a tab, no PASS). The split is gated on
/// `school_config.is_platform`.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Default to the non-platform nav until the config resolves (safe: every
    // school has Bundles; PASS only appears once we know it's the platform).
    final isPlatform = ref.watch(schoolConfigProvider).maybeWhen(
          data: (c) => c.isPlatform,
          orElse: () => false,
        );

    final screens = <Widget>[
      const DashboardScreen(),
      const CoursesScreen(),
      const TestsScreen(),
      isPlatform ? const PassScreen() : const BundlesScreen(),
      const ProfileScreen(),
    ];

    // Clamp the index if the config flips after a tab was selected.
    final idx = _index.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(index: idx, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: 'Courses'),
          const NavigationDestination(
              icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Test Series'),
          if (isPlatform)
            const NavigationDestination(
                icon: Icon(Icons.workspace_premium_outlined),
                selectedIcon: Icon(Icons.workspace_premium), label: 'PASS')
          else
            const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2), label: 'Bundles'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
