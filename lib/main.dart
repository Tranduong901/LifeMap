import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/main_navigation_provider.dart';
import 'views/map/map_view.dart';
import 'views/profile/profile_view.dart';
import 'views/timeline/timeline_view.dart';

void main() {
  runApp(const LifeMapApp());
}

class LifeMapApp extends StatelessWidget {
  const LifeMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MainNavigationProvider>(
          create: (_) => MainNavigationProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LifeMap',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MainNavigationProvider navigationProvider = context
        .watch<MainNavigationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('LifeMap')),
      body: IndexedStack(
        index: navigationProvider.selectedIndex,
        children: const <Widget>[MapView(), TimelineView(), ProfileView()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationProvider.selectedIndex,
        onTap: navigationProvider.updateSelectedIndex,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Bản đồ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_outlined),
            activeIcon: Icon(Icons.timeline),
            label: 'Dòng thời gian',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}
