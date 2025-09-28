// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desktop/main.dart';
import 'package:desktop/src/state/user_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.init();
  });

  testWidgets('Displays greeting and opens account overlay', (
    WidgetTester tester,
  ) async {
    tester.binding.window.physicalSizeTestValue = const Size(1440, 900);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(const ZenDesktopApp());
    await tester.pumpAndSettle();

    expect(find.text('Hallo, wie geht es dir?'), findsOneWidget);

    final accountIconFinder = find.byIcon(Icons.account_circle_outlined);
    final loginIconFinder = find.byIcon(Icons.login);
    expect(
      accountIconFinder.evaluate().isNotEmpty ||
          loginIconFinder.evaluate().isNotEmpty,
      isTrue,
      reason: 'Expected either the account or login icon to be present.',
    );
    final userIconFinder = accountIconFinder.evaluate().isNotEmpty
        ? accountIconFinder
        : loginIconFinder;

    await tester.tap(userIconFinder);
    await tester.pumpAndSettle();

    expect(find.text('Account center'), findsOneWidget);
    expect(find.text('Preferences'), findsWidgets);

    await tester.tap(find.text('Preferences').first);
    await tester.pumpAndSettle();

    expect(find.text('Dark'), findsWidgets);
  });
}
