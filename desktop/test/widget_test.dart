// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/main.dart';

void main() {
  testWidgets('Displays greeting and opens account overlay', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1440, 900);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(const ZenDesktopApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Hallo Bennet'), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Account center'), findsOneWidget);
    expect(find.text('Preferences'), findsWidgets);
    expect(find.text('Dark'), findsWidgets);
  });
}
