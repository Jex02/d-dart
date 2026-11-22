import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/canteen_category_screen.dart';
import 'package:sd2/canteen_menu_screen.dart';
import 'package:sd2/category_browse_screen.dart';
import 'package:sd2/cor_upload_screen.dart';
import 'package:sd2/main.dart';
import 'package:sd2/main_dashboard.dart';
import 'package:sd2/mock_data.dart';
import 'package:sd2/models/user_profile.dart';
import 'package:sd2/models/delivery_order.dart';
import 'package:sd2/order_tracking_screen.dart';
import 'package:sd2/pabili_request_screen.dart';
import 'package:sd2/pending_verification_screen.dart';
import 'package:sd2/reset_password_page.dart';
import 'package:sd2/services/cart_service.dart';
import 'package:sd2/services/duty_lock_service.dart';
import 'package:sd2/signup.dart';
import 'package:sd2/widgets/cor_timetable_dialog.dart';
import 'package:sd2/widgets/order_chat_sheet.dart';
import 'package:sd2/widgets/responsive_shell.dart';

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

    expect(find.text('Custom Order (Pabili)'), findsOneWidget);
    expect(find.text('Standard Campus Delivery Fee'), findsOneWidget);
    expect(find.text('Submit Custom Order'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      '2 orders Pork Siomai',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      '85',
    );
    await tester.pump();

    // Option A: Main Canteen -> Backgate Annex is 141.30 m (>100-200m tier = ₱25 fee), so 85 + 25 = ₱110.00
    expect(find.text('₱25.00'), findsOneWidget);
    expect(find.text('₱110.00'), findsOneWidget);
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

  testWidgets('OrderChatSheet renders recipient, preset chips, and input field',
      (WidgetTester tester) async {
    final order = DeliveryOrder(
      id: 'ORD-303',
      pickupLocation: 'Main Canteen',
      dropoffLocation: 'Library 2nd Floor',
      description: 'Pork Siomai',
      estimatedPrice: 30.0,
      status: 'claimed',
      verificationCode: '1234',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderChatSheet(
            order: order,
            isRunner: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Chat with Runner'), findsOneWidget);
    expect(find.text('Main Canteen'), findsOneWidget);
    expect(find.text('Library 2nd Floor'), findsOneWidget);
    expect(find.text('Type a message...'), findsOneWidget);
    expect(find.text('🙏 Please ask for utensils & sauce.'), findsOneWidget);
  });

  testWidgets('CorTimetableDialog renders 30-minute intervals and mid-hour classes without overlap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CorTimetableDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('07:30 AM - 08:00 AM'), findsOneWidget);
    expect(find.text('10:00 AM - 10:30 AM'), findsOneWidget);
    expect(find.text('10:30 AM - 11:00 AM'), findsOneWidget);
    // Back-to-back Wednesday classes (07:30-10:30 and 10:30-13:30) must both appear
    expect(find.text('CPE368\nGLE704'), findsOneWidget);
    expect(find.text('CPE331\nGLE703'), findsOneWidget);
  });

  testWidgets('Canteen pages navigate to Notifications (tab 2) and Profile (tab 3)',
      (WidgetTester tester) async {
    final tappedTabs = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CanteenCategoryScreen(
          canteenName: 'Main Canteen',
          userName: 'Jerick',
          onNavigateToTab: tappedTabs.add,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Notifications & Orders'));
    await tester.tap(find.byTooltip('Profile'));
    expect(tappedTabs, [2, 3]);

    tappedTabs.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: CanteenMenuScreen(
          canteenName: 'Main Canteen',
          categoryName: 'Beverages',
          userName: 'Jerick',
          onNavigateToTab: tappedTabs.add,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Notifications & Orders'));
    await tester.tap(find.byTooltip('Profile'));
    expect(tappedTabs, [2, 3]);

    tappedTabs.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryBrowseScreen(
          categoryTitle: 'Beverages',
          userName: 'Jerick',
          onNavigateToTab: tappedTabs.add,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Notifications & Orders'));
    await tester.tap(find.byTooltip('Profile'));
    expect(tappedTabs, [2, 3]);
  });

  testWidgets('ResetPasswordPage surfaces expired/invalid recovery link error',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordPage(
          initialErrorMessage: 'Email link is invalid or has expired',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Email link is invalid or has expired'), findsOneWidget);
  });

  testWidgets('CanteenMenuScreen scopes added cart item to selected canteen',
      (WidgetTester tester) async {
    CartService.instance.clearCart();
    await tester.pumpWidget(
      const MaterialApp(
        home: CanteenMenuScreen(
          canteenName: 'Highschool Canteen',
          categoryName: 'Beverages',
          userName: 'Jerick',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the first menu item card to open Add-to-Cart bottom sheet
    await tester.tap(
      find.descendant(of: find.byType(GridView), matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();

    final addButton = find.textContaining('Add to Cart');
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(CartService.instance.items, isNotEmpty);
    expect(CartService.instance.items.first.item.canteen, 'Highschool Canteen');

    // Clean up pending 2s snackbar timer and cart
    await tester.pump(const Duration(seconds: 3));
    CartService.instance.clearCart();
  });

  testWidgets('Core demo screens render cleanly in Dark Mode without overflow',
      (WidgetTester tester) async {
    addPabiliRequest(
      orderId: 'ORD-DARK-1',
      verificationCode: '9182',
      pickup: 'Main Canteen',
      dropoff: 'GLE',
      description: '1x Pork Siomai Rice',
      price: 55.0,
    );
    mockDeliveryRequests
        .firstWhere((o) => o['id'] == 'ORD-DARK-1')['status'] = 'arrived';

    await tester.pumpWidget(
      MaterialApp(
        theme: DDartTheme.darkTheme,
        home: const OrderTrackingScreen(orderId: 'ORD-DARK-1', isRunner: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('9182'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: DDartTheme.darkTheme,
        home: PendingVerificationScreen(
          initialProfile: UserProfile.fromJson({
            'id': 'u-dark-1',
            'full_name': 'Demo Wildcat',
            'student_id': '23-1626-937',
            'account_type': 'student',
            'verification_status': 'pending',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pending Admin Verification'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
