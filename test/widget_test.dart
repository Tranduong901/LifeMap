// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:lifemap/main.dart';

void main() {
  testWidgets('Dieu huong 3 tab hoat dong dung', (WidgetTester tester) async {
    await tester.pumpWidget(const LifeMapApp());

    expect(find.text('Bản đồ'), findsOneWidget);
    expect(find.text('Dòng thời gian'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
    expect(find.text('Màn hình Bản đồ'), findsOneWidget);

    await tester.tap(find.text('Dòng thời gian'));
    await tester.pump();
    expect(find.text('Màn hình Dòng thời gian'), findsOneWidget);

    await tester.tap(find.text('Cá nhân'));
    await tester.pump();
    expect(find.text('Màn hình Cá nhân'), findsOneWidget);
  });
}
