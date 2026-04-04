import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lifemap/providers/main_navigation_provider.dart';

void main() {
  testWidgets('Điều hướng tab đổi index đúng', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<MainNavigationProvider>(
        create: (_) => MainNavigationProvider(),
        child: Consumer<MainNavigationProvider>(
          builder: (BuildContext context, MainNavigationProvider nav, _) {
            return MaterialApp(
              home: Scaffold(
                body: Center(child: Text('Index: ${nav.selectedIndex}')),
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: nav.selectedIndex,
                  onTap: nav.updateSelectedIndex,
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Icon(Icons.map_outlined),
                      label: 'Bản đồ',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.timeline),
                      label: 'Kỷ niệm',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline),
                      label: 'Cá nhân',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Index: 0'), findsOneWidget);

    await tester.tap(find.text('Kỷ niệm'));
    await tester.pump();
    expect(find.text('Index: 1'), findsOneWidget);

    await tester.tap(find.text('Cá nhân'));
    await tester.pump();
    expect(find.text('Index: 2'), findsOneWidget);
  });
}
