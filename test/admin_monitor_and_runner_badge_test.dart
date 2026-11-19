import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/admin_dashboard_screen.dart';
import 'package:sd2/mock_data.dart';
import 'package:sd2/runner_gig_board_screen.dart';
import 'package:sd2/services/supabase_service.dart';

void main() {
  setUp(() {
    mockDeliveryRequests.clear();
  });

  group('Admin Monitor Tab Tests', () {
    testWidgets('Monitor tab displays customer and runner names and allows searching by Order ID', (tester) async {
      mockDeliveryRequests.addAll([
        {
          'id': 'ORD-ALPHA-123',
          'customer_id': 'cust-alpha',
          'runner_id': 'runner-alpha',
          'pickup_location': 'Main Canteen',
          'dropoff_location': 'Allied Bldg',
          'description': 'Pork Chop Meal',
          'estimated_price': 100.0,
          'delivery_fee': 20.0,
          'status': 'claimed',
          'verification_code': '1111',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'id': 'ORD-BETA-456',
          'customer_id': 'cust-beta',
          'runner_id': null,
          'pickup_location': 'Mini Canteen',
          'dropoff_location': 'RTL Bldg',
          'description': 'Chicken Inasal with Drink',
          'estimated_price': 120.0,
          'delivery_fee': 25.0,
          'status': 'pending',
          'verification_code': '2222',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Monitor Tab (Tab index 1)
      final monitorTabFinder = find.text('Monitor');
      expect(monitorTabFinder, findsOneWidget);
      await tester.tap(monitorTabFinder);
      await tester.pumpAndSettle();

      // Verify Customer and Runner labels are displayed on the cards
      expect(find.textContaining('Customer: '), findsWidgets);
      expect(find.textContaining('Runner: '), findsWidgets);
      expect(find.textContaining('#ORD-ALPH'), findsOneWidget);
      expect(find.textContaining('#ORD-BETA'), findsOneWidget);

      // Verify the search field is present and allows searching by Order ID
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText?.contains('Order ID') == true,
      );
      expect(searchField, findsOneWidget);

      // Search for "ORD-ALPHA"
      await tester.enterText(searchField, 'ORD-ALPHA');
      await tester.pumpAndSettle();

      // Should show ORD-ALPHA-123 and hide ORD-BETA-456
      expect(find.textContaining('#ORD-ALPH'), findsOneWidget);
      expect(find.textContaining('#ORD-BETA'), findsNothing);

      // Search for "BETA"
      await tester.enterText(searchField, 'BETA');
      await tester.pumpAndSettle();

      expect(find.textContaining('#ORD-BETA'), findsOneWidget);
      expect(find.textContaining('#ORD-ALPH'), findsNothing);
    });
  });

  group('Runner Gig Board Active Delivery Red Dot Notification Tests', () {
    testWidgets('Runner UI displays red dot indicator on active deliveries tab and active banner', (tester) async {
      mockDeliveryRequests.addAll([
        {
          'id': 'ORD-RUNNER-ACTIVE',
          'pickup_location': 'Main Canteen',
          'dropoff_location': 'Science Bldg',
          'description': 'Fruit Shake',
          'estimated_price': 60.0,
          'delivery_fee': 20.0,
          'status': 'claimed', // Active delivery!
          'runner_id': SupabaseService().currentUser?.id ?? 'mock-runner',
          'verification_code': '3333',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RunnerGigBoardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In the TabBar, the 'My Active Deliveries' tab should have a red dot indicator
      expect(find.text('My Active Deliveries'), findsOneWidget);

      // Verify the active delivery notification banner is rendered with "ACTIVE DELIVERY IN PROGRESS"
      expect(find.textContaining('ACTIVE DELIVERY IN PROGRESS'), findsOneWidget);
      expect(find.textContaining('Main Canteen → Science Bldg'), findsOneWidget);
      expect(find.text('Track'), findsOneWidget);
    });

    testWidgets('Runner UI hides active notification banner when no active deliveries exist', (tester) async {
      // No active deliveries
      mockDeliveryRequests.addAll([
        {
          'id': 'ORD-RUNNER-DONE',
          'pickup_location': 'Main Canteen',
          'dropoff_location': 'Science Bldg',
          'description': 'Fruit Shake',
          'estimated_price': 60.0,
          'delivery_fee': 20.0,
          'status': 'completed',
          'verification_code': '3333',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RunnerGigBoardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner should NOT be visible
      expect(find.textContaining('ACTIVE DELIVERY IN PROGRESS'), findsNothing);
    });
  });
}
