import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/admin_dashboard_screen.dart';
import 'package:sd2/customer_home_screen.dart';
import 'package:sd2/mock_data.dart';
import 'package:sd2/models/runner_review.dart';
import 'package:sd2/runner_gig_board_screen.dart';
import 'package:sd2/runner_profile_screen.dart';
import 'package:sd2/services/supabase_service.dart';
import 'package:sd2/widgets/runner_performance_view.dart';

void main() {
  setUp(() {
    mockDeliveryRequests.clear();
    mockRunnerReviews.clear();
  });

  group('Task 8 — Customer Ratings & Reviews for Runners', () {
    test('Can submit and fetch runner review for completed order in offline/mock mode', () async {
      mockRunnerReviews.clear();

      final review = submitMockReview(
        orderId: 'ORD-TEST-REV-100',
        runnerId: 'runner-test-1',
        customerId: 'customer-test-1',
        rating: 5,
        reviewText: 'Super fast delivery and food was still warm!',
        customerName: 'Maria Santos',
      );

      expect(review['order_id'], 'ORD-TEST-REV-100');
      expect(review['rating'], 5);
      expect(review['customer_name'], 'Maria Santos');

      final fetched = await SupabaseService().fetchOrderReview('ORD-TEST-REV-100');
      expect(fetched, isNotNull);
      expect(fetched!.rating, 5);
      expect(fetched.reviewText, contains('Super fast delivery'));

      final runnerReviews = await SupabaseService().fetchRunnerReviews('runner-test-1');
      expect(runnerReviews.length, 1);
      expect(runnerReviews.first.customerName, 'Maria Santos');
    });

    test('RunnerReview serialization handles clamp and formatted date correctly', () {
      final rev = RunnerReview(
        id: 'rev-test-1',
        orderId: 'ORD-12345678',
        runnerId: 'runner-1',
        customerId: 'cust-1',
        rating: 4,
        reviewText: 'Great service',
        createdAt: DateTime(2026, 11, 22, 14, 30),
      );

      expect(rev.formattedDate, '2026-11-22');
      expect(rev.ratingStars, '★★★★☆');
      final json = rev.toJson();
      expect(json['rating'], 4);
      expect(json['order_id'], 'ORD-12345678');
    });
  });

  group('Task 9 — Admin Runner Ratings & Performance Overview', () {
    testWidgets('Admin Console includes dedicated Runner Performance tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final perfTab = find.text('Runner Performance');
      expect(perfTab, findsOneWidget);

      await tester.tap(perfTab);
      await tester.pumpAndSettle();

      expect(find.text('Runner Ratings & Performance'), findsOneWidget);
      expect(find.text('Total Runners'), findsOneWidget);
      expect(find.text('Completed Deliveries'), findsOneWidget);
      expect(find.text('Overall Avg Rating'), findsOneWidget);
      expect(find.text('Customer Reviews'), findsOneWidget);
    });

    testWidgets('RunnerPerformanceView displays summary stats and runner rankings', (tester) async {
      mockRunnerReviews.addAll([
        {
          'id': 'rev-1',
          'order_id': 'ORD-1',
          'runner_id': 'runner-demo',
          'customer_id': 'cust-1',
          'rating': 5,
          'review_text': 'Excellent!',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'customer_name': 'Juan',
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RunnerPerformanceView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Runner Rankings'), findsOneWidget);
      expect(find.text('Sort by: '), findsOneWidget);
      expect(find.text('Highest Rating'), findsOneWidget);
      expect(find.text('Most Deliveries'), findsOneWidget);
    });
  });

  group('Task 10 — Runner Dashboard Completed Orders Tab & Profile Page', () {
    testWidgets('Runner Gig Board has 3 tabs and Profile Icon replacing refresh', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RunnerGigBoardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the 3 tabs
      expect(find.text('Available Gigs'), findsOneWidget);
      expect(find.text('My Active Deliveries'), findsOneWidget);
      expect(find.text('Completed Orders'), findsOneWidget);

      // Verify Profile Icon in AppBar
      final profileIconFinder = find.byTooltip('Runner Profile');
      expect(profileIconFinder, findsOneWidget);

      // Verify old refresh button in AppBar is replaced
      expect(find.byTooltip('Refresh eligibility'), findsNothing);
    });

    testWidgets('Runner Profile Screen displays rating, deliveries, and reviews', (tester) async {
      mockRunnerReviews.addAll([
        {
          'id': 'rev-profile-test',
          'order_id': 'ORD-PROFILE-DELIVERY',
          'runner_id': 'runner-profile-test',
          'customer_id': 'cust-alpha',
          'rating': 5,
          'review_text': 'Top notch delivery! Arrived on time.',
          'created_at': DateTime(2026, 11, 22).toIso8601String(),
          'customer_name': 'Alice Student',
        },
      ]);

      mockDeliveryRequests.add({
        'id': 'ORD-PROFILE-DELIVERY',
        'customer_id': 'cust-alpha',
        'runner_id': 'runner-profile-test',
        'pickup_location': 'Main Canteen',
        'dropoff_location': 'Room 302',
        'description': 'Sinigang Meal',
        'estimated_price': 100.0,
        'delivery_fee': 20.0,
        'status': 'completed',
        'completed_at': DateTime(2026, 11, 22).toIso8601String(),
        'created_at': DateTime(2026, 11, 22).toIso8601String(),
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: RunnerProfileScreen(
            runnerId: 'runner-profile-test',
            runnerName: 'Carlos Dalisay',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Carlos Dalisay'), findsWidgets);
      expect(find.text('Completed Deliveries'), findsOneWidget);
      expect(find.text('Customer Reviews'), findsOneWidget);
      expect(find.textContaining('5.0 ★'), findsWidgets);
      expect(find.textContaining('Top notch delivery!'), findsOneWidget);
      expect(find.text('Alice Student'), findsOneWidget);
    });
  });

  group('Task 11 — Customer Order Status Colors', () {
    testWidgets('Customer Home orders list renders green completed badge with checkmark', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDeliveryRequests.addAll([
        {
          'id': 'ORD-CUST-COMPLETED',
          'customer_id': 'mock-user',
          'runner_id': 'runner-demo',
          'pickup_location': 'Main Canteen',
          'dropoff_location': 'Allied Bldg',
          'description': 'Fried Chicken Meal',
          'estimated_price': 90.0,
          'delivery_fee': 20.0,
          'status': 'completed',
          'verification_code': '9999',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'id': 'ORD-CUST-ENROUTE',
          'customer_id': 'mock-user',
          'runner_id': 'runner-demo',
          'pickup_location': 'Mini Canteen',
          'dropoff_location': 'Library',
          'description': 'Burger and Fries',
          'estimated_price': 120.0,
          'delivery_fee': 25.0,
          'status': 'en_route',
          'verification_code': '8888',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerHomeScreen(initialTabIndex: 2),
        ),
      );
      await tester.pumpAndSettle();

      // Verify COMPLETED badge and check icon exist
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Verify EN_ROUTE badge and delivery icon exist
      expect(find.text('EN_ROUTE'), findsOneWidget);
      expect(find.byIcon(Icons.delivery_dining), findsWidgets);
    });
  });
}
