import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/constants/supabase_constants.dart';
import 'package:sd2/login.dart';
import 'package:sd2/services/remember_me_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const sessionKey = 'sb-dlarpmnaxqmhkuxssvbz-auth-token';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RememberMeService', () {
    test('defaults to rememberMe=true with empty email', () async {
      final defaults = await RememberMeService.loadLoginDefaults();
      expect(defaults.rememberMe, isTrue);
      expect(defaults.email, isEmpty);
    });

    test('rememberMe=true saves email and keeps Supabase session on restart',
        () async {
      await RememberMeService.saveOnLogin(
        email: 'student@cit.edu',
        rememberMe: true,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionKey, '{"access_token":"abc"}');

      final cleared = await RememberMeService.clearEphemeralBeforeInit(
        supabaseUrl: SupabaseConstants.url,
      );

      expect(cleared, isFalse);
      expect(prefs.getString(sessionKey), '{"access_token":"abc"}');

      final defaults = await RememberMeService.loadLoginDefaults();
      expect(defaults.rememberMe, isTrue);
      expect(defaults.email, 'student@cit.edu');
    });

    test('rememberMe=false clears email and wipes Supabase session on restart',
        () async {
      await RememberMeService.saveOnLogin(
        email: 'student@cit.edu',
        rememberMe: true,
      );
      await RememberMeService.saveOnLogin(
        email: 'student@cit.edu',
        rememberMe: false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionKey, '{"access_token":"ephemeral"}');

      final cleared = await RememberMeService.clearEphemeralBeforeInit(
        supabaseUrl: SupabaseConstants.url,
      );

      expect(cleared, isTrue);
      expect(prefs.getString(sessionKey), isNull);

      final defaults = await RememberMeService.loadLoginDefaults();
      expect(defaults.rememberMe, isFalse);
      expect(defaults.email, isEmpty);
    });

    test('skipIfRecovery=true preserves session even if previous login was ephemeral',
        () async {
      await RememberMeService.saveOnLogin(
        email: 'student@cit.edu',
        rememberMe: false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionKey, '{"access_token":"recovery"}');

      final cleared = await RememberMeService.clearEphemeralBeforeInit(
        supabaseUrl: SupabaseConstants.url,
        skipIfRecovery: true,
      );

      expect(cleared, isFalse);
      expect(prefs.getString(sessionKey), '{"access_token":"recovery"}');
    });
  });

  group('LoginPage Remember Me UI', () {
    testWidgets('pre-fills remembered email and exposes AutofillGroup hints',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'ddart_remember_me': true,
        'ddart_remembered_email': 'wildcat@cit.edu',
      });

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();

      expect(find.byType(AutofillGroup), findsOneWidget);

      final emailField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Email'),
      );
      final passwordField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Password'),
      );
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));

      expect(emailField.controller?.text, 'wildcat@cit.edu');
      expect(
        emailField.autofillHints,
        containsAll([AutofillHints.username, AutofillHints.email]),
      );
      expect(passwordField.autofillHints, contains(AutofillHints.password));
      expect(checkbox.value, isTrue);

      // Toggling Remember me off persists preference and forgets saved email
      await tester.tap(find.text('Remember me'));
      await tester.pumpAndSettle();

      final updatedDefaults = await RememberMeService.loadLoginDefaults();
      expect(updatedDefaults.rememberMe, isFalse);
      expect(updatedDefaults.email, isEmpty);
    });

    testWidgets('respects unchecked Remember me preference on reopen',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'ddart_remember_me': false,
      });

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();

      final emailField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Email'),
      );
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));

      expect(emailField.controller?.text, isEmpty);
      expect(checkbox.value, isFalse);
    });
  });
}
