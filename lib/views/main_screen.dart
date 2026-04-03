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
      body: IndexedStack(
        index: navigationProvider.selectedIndex,
        children: const <Widget>[MapView(), TimelineView(), ProfileView()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationProvider.selectedIndex,
        selectedItemColor: Colors.indigo,
        onTap: navigationProvider.updateSelectedIndex,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Bản đồ'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Kỷ niệm'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}
