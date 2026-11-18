import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/canteen_category_screen.dart';
import 'package:sd2/main.dart';
import 'package:sd2/services/theme_service.dart';
import 'package:sd2/widgets/cor_timetable_dialog.dart';
import 'package:sd2/widgets/responsive_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeService.instance.resetForTest();
  });

  group('ThemeService', () {
    test('defaults to light mode and persists dark mode across loads', () async {
      await ThemeService.instance.load();
      expect(ThemeService.instance.themeMode, ThemeMode.light);
      expect(ThemeService.instance.isDark, isFalse);

      await ThemeService.instance.setDarkMode(true);
      expect(ThemeService.instance.themeMode, ThemeMode.dark);
      expect(ThemeService.instance.isDark, isTrue);

      // Simulate restart by resetting in-memory state and reloading from prefs
      ThemeService.instance.resetForTest();
      expect(ThemeService.instance.isDark, isFalse);
      await ThemeService.instance.load();
      expect(ThemeService.instance.themeMode, ThemeMode.dark);
      expect(ThemeService.instance.isDark, isTrue);

      await ThemeService.instance.toggle();
      expect(ThemeService.instance.themeMode, ThemeMode.light);
      expect(ThemeService.instance.isDark, isFalse);
    });
  });

  group('Dark Mode UI', () {
    testWidgets('ThemeToggleButton switches brightness inside DDartApp',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DDartApp());
      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();

      // Starts in light mode
      expect(
        Theme.of(tester.element(find.text('Login'))).brightness,
        Brightness.light,
      );

      await tester.tap(find.byTooltip('Switch to Dark Mode'));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.text('Login'))).brightness,
        Brightness.dark,
      );

      await tester.tap(find.byTooltip('Switch to Light Mode'));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.text('Login'))).brightness,
        Brightness.light,
      );
    });

    testWidgets('CanteenCategoryScreen and CorTimetableDialog render cleanly in dark mode',
        (WidgetTester tester) async {
      await ThemeService.instance.setDarkMode(true);
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: DDartTheme.lightTheme,
          darkTheme: DDartTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const CanteenCategoryScreen(
            canteenName: 'Main Canteen',
            userName: 'Jerick',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('MAIN CANTEEN'), findsOneWidget);
      expect(find.byTooltip('Switch to Light Mode'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: DDartTheme.lightTheme,
          darkTheme: DDartTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: CorTimetableDialog()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TIME (30-MIN)'), findsOneWidget);
      expect(find.text('10:30 AM - 11:00 AM'), findsOneWidget);
    });
  });
}
