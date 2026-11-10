import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/main.dart';
import 'package:sd2/signup.dart';

void main() {
  testWidgets('DDartApp launches on GetStartedPage and navigates to LoginPage',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DDartApp());

    expect(find.text('D-DART'), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);

    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome !'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('SignupPage toggles COR section between Student and Faculty/Staff',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupPage()));

    expect(find.text('CIT-U COR / Study Load'), findsOneWidget);
    expect(find.text('CIT-U Student ID Photo'), findsOneWidget);

    await tester.tap(find.text('Faculty / Staff'));
    await tester.pumpAndSettle();

    expect(find.text('CIT-U COR / Study Load'), findsNothing);
    expect(find.text('Faculty / Employee ID Photo'), findsOneWidget);
  });
}
