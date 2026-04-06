import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/main_navigation_provider.dart';
import 'map/map_view.dart';
import 'profile/profile_view.dart';
import 'timeline/timeline_view.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MainNavigationProvider navigationProvider = context
        .watch<MainNavigationProvider>();

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: navigationProvider.selectedIndex,
        children: const <Widget>[MapView(), TimelineView(), ProfileView()],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: NavigationBar(
            backgroundColor: Colors.white.withOpacity(0.96),
            indicatorColor: const Color(0xFFFFE7CF),
            selectedIndex: navigationProvider.selectedIndex,
            onDestinationSelected: navigationProvider.updateSelectedIndex,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Bản đồ',
              ),
              NavigationDestination(
                icon: Icon(Icons.timeline_outlined),
                selectedIcon: Icon(Icons.timeline),
                label: 'Kỷ niệm',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Cá nhân',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
