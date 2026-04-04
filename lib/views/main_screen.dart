import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/main_navigation_provider.dart';
import 'map/map_view.dart';
import 'profile/profile_view.dart';
import 'timeline/timeline_view.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  static const Color _primaryColor = Color(0xFF1A237E);
  static const Color _accentColor = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final MainNavigationProvider navigationProvider = context
        .watch<MainNavigationProvider>();

    return Scaffold(
      body: IndexedStack(
        index: navigationProvider.selectedIndex,
        children: const <Widget>[MapView(), TimelineView(), ProfileView()],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: NavigationBar(
            height: 72,
            backgroundColor: Colors.white,
            selectedIndex: navigationProvider.selectedIndex,
            onDestinationSelected: navigationProvider.updateSelectedIndex,
            indicatorColor: _accentColor.withValues(alpha: 0.22),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.map_outlined, color: _primaryColor),
                selectedIcon: Icon(Icons.map, color: _accentColor),
                label: 'Bản đồ',
              ),
              NavigationDestination(
                icon: Icon(Icons.timeline_outlined, color: _primaryColor),
                selectedIcon: Icon(Icons.timeline, color: _accentColor),
                label: 'Kỷ niệm',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: _primaryColor),
                selectedIcon: Icon(Icons.person, color: _accentColor),
                label: 'Cá nhân',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
