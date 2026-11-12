import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/cor_upload_screen.dart';
import 'package:sd2/main.dart';
import 'package:sd2/main_dashboard.dart';
import 'package:sd2/mock_data.dart';
import 'package:sd2/models/user_profile.dart';
import 'package:sd2/order_tracking_screen.dart';
import 'package:sd2/pabili_request_screen.dart';
import 'package:sd2/pending_verification_screen.dart';
import 'package:sd2/services/duty_lock_service.dart';
import 'package:sd2/signup.dart';

void main() {
  setUp(() {
    mockDeliveryRequests.clear();
    DutyLockService.reset();
  });

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

  testWidgets('PabiliRequestScreen shows cost summary and validates inputs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PabiliRequestScreen()));

    expect(find.text('New Pabili Request'), findsOneWidget);
    expect(find.text('Standard Campus Delivery Fee'), findsOneWidget);
    expect(find.text('Post Delivery Request'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g., Pork Siomai w/ rice, Mountain Dew'),
      '2 orders Pork Siomai',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '85.00'),
      '85',
    );
    await tester.pump();

    expect(find.text('₱105.00'), findsOneWidget);
  });

  testWidgets('OrderTrackingScreen reveals OTP only on arrival and enforces runner flow',
      (WidgetTester tester) async {
    addPabiliRequest(
      orderId: 'ORD-101',
      verificationCode: '4821',
      pickup: 'Main Canteen',
      dropoff: 'ALLIED Building',
      description: 'Pork Siomai Rice',
      price: 85.0,
    );

    // Customer view while pending: OTP locked, cancel available
    await tester.pumpWidget(
      const MaterialApp(
        home: OrderTrackingScreen(orderId: 'ORD-101', isRunner: false),
      ),
    );
    await tester.pump();

    expect(find.text('Waiting for Runner'), findsAtLeastNWidgets(1));
    expect(find.text('4821'), findsNothing);
    expect(find.text('Cancel Unclaimed Request'), findsOneWidget);

    // Arrived customer order reveals OTP and hides cancel button
    addPabiliRequest(
      orderId: 'ORD-202',
      verificationCode: '7391',
      pickup: 'College Canteen',
      dropoff: 'GLE Building',
      description: 'Iced Tea',
      price: 35.0,
    );
    mockDeliveryRequests
        .firstWhere((o) => o['id'] == 'ORD-202')['status'] = 'arrived';

    await tester.pumpWidget(
      const MaterialApp(
        home: OrderTrackingScreen(
          key: ValueKey('customer-202'),
          orderId: 'ORD-202',
          isRunner: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('7391'), findsOneWidget);
    expect(find.text('Cancel Unclaimed Request'), findsNothing);

    // Runner view on arrived order prompts for 4-digit code
    await tester.pumpWidget(
      const MaterialApp(
        home: OrderTrackingScreen(
          key: ValueKey('runner-202'),
          orderId: 'ORD-202',
          isRunner: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enter Customer 4-Digit Code:'), findsOneWidget);
    expect(find.text('Confirm Handover & Complete'), findsOneWidget);
  });

  testWidgets('CorUploadScreen and MainDashboard render cleanly on mobile and desktop',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CorUploadScreen()));
    expect(find.text('Upload Certificate of Registration (COR)'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: MainDashboard()));
    await tester.pumpAndSettle();
    expect(find.text('Choose Mode'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Runner'), findsOneWidget);
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
