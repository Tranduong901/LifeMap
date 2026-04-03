// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lifemap/providers/main_navigation_provider.dart';
import 'package:lifemap/views/main_screen.dart';

void main() {
  testWidgets('Điều hướng 3 tab hoạt động đúng', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<MainNavigationProvider>(
        create: (_) => MainNavigationProvider(),
        child: const MaterialApp(home: MainScreen()),
      ),
    );

    expect(find.text('Bản đồ'), findsOneWidget);
    expect(find.text('Kỷ niệm'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
    expect(find.text('Bản đồ kỷ niệm'), findsOneWidget);

    await tester.tap(find.text('Kỷ niệm'));
    await tester.pump();
    expect(find.text('Dòng thời gian'), findsOneWidget);

    await tester.tap(find.text('Cá nhân'));
    await tester.pump();
    expect(find.text('Đăng xuất'), findsOneWidget);
  });
}
