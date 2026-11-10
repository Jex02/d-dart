import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/main.dart';
import 'package:sd2/models/user_profile.dart';
import 'package:sd2/pending_verification_screen.dart';
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

  testWidgets('Responsive auto-layout renders without overflow on narrow mobile (320px) and desktop (1200px)',
      (WidgetTester tester) async {
    const pendingStudent = UserProfile(
      id: 'test-1',
      fullName: 'Juan Dela Cruz',
      studentId: '23-1626-937',
      accountType: 'student',
      verificationStatus: 'pending',
      corVerified: true,
    );

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PendingVerificationScreen(initialProfile: pendingStudent),
      ),
    );
    expect(find.text('Pending Admin Verification'), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 850);
    await tester.pumpWidget(const MaterialApp(home: SignupPage()));
    expect(find.text('Create an Account'), findsOneWidget);
  });
}
