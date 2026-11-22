import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sd2/mock_data.dart';
import 'package:sd2/models/cart_item.dart';
import 'package:sd2/models/delivery_order.dart';
import 'package:sd2/runner_gig_board_screen.dart';
import 'package:sd2/services/cart_service.dart';
import 'package:sd2/widgets/runner_order_items.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDeliveryRequests.clear();
    CartService.instance.clearCart();
  });

  group('Task 1 — Restore Custom Ordering Page & Request Data', () {
    test('Submitting custom order request saves all required fields properly', () {
      final request = addPabiliRequest(
        customerId: 'customer-user-123',
        pickup: 'Main Canteen',
        dropoff: 'Allied',
        description: '2x 500ml Mountain Dew, 1pc Cheesy Bacon Burger',
        price: 95.00,
        deliveryFee: 25.00,
        instructions: 'Please deliver near 2nd floor room 204',
      );

      expect(request['id'], isNotNull);
      expect(request['customer_id'], equals('customer-user-123'));
      expect(request['status'], equals('pending'));
      expect(request['pickup_location'], equals('Main Canteen'));
      expect(request['dropoff_location'], equals('Allied'));
      expect(request['description'], equals('2x 500ml Mountain Dew, 1pc Cheesy Bacon Burger'));
      expect(request['estimated_price'], equals(95.00));
      expect(request['delivery_fee'], equals(25.00));
      expect(request['verification_code'], isNotNull);
      expect(request['verification_code'].toString().length, equals(4));

      final order = DeliveryOrder.fromJson(request);
      expect(order.description, contains('Mountain Dew'));
      expect(order.status, equals('pending'));
    });
  });

  group('Task 2 — Persist Cart Items', () {
    test('CartItem serializes and deserializes cleanly without losing data', () {
      const menuItem = CanteenMenuItem(
        id: 'food-siomai',
        name: 'Pork Siomai with rice',
        canteen: 'Main Canteen',
        category: 'Food and snacks',
        price: 30.00,
        unitDescription: '3 for 30 Pesos',
      );

      final cartItem = CartItem(item: menuItem, quantity: 3);
      final json = cartItem.toJson();

      final restored = CartItem.fromJson(json);
      expect(restored.item.id, equals('food-siomai'));
      expect(restored.item.name, equals('Pork Siomai with rice'));
      expect(restored.item.canteen, equals('Main Canteen'));
      expect(restored.quantity, equals(3));
      expect(restored.totalPrice, equals(90.00));
    });

    test('Adding and modifying cart items updates quantities and order descriptions', () {
      const burger = CanteenMenuItem(
        id: 'food-burger',
        name: 'Cheesy Bacon Burger',
        canteen: 'Main Canteen',
        category: 'Food and snacks',
        price: 45.00,
        unitDescription: 'Classic burger',
      );
      const drink = CanteenMenuItem(
        id: 'bev-dew',
        name: 'Mountain Dew',
        canteen: 'Main Canteen',
        category: 'Beverages',
        price: 25.00,
        unitDescription: '500ml bottle',
      );

      CartService.instance.addItem(burger, quantity: 2);
      CartService.instance.addItem(drink, quantity: 1);

      expect(CartService.instance.totalItemCount, equals(3));
      expect(CartService.instance.subtotal, equals(115.00));
      expect(CartService.instance.generateOrderDescription(),
          equals('2x Cheesy Bacon Burger, 1x Mountain Dew'));

      CartService.instance.decrementQuantity('food-burger');
      expect(CartService.instance.getQuantity('food-burger'), equals(1));
      expect(CartService.instance.totalItemCount, equals(2));

      // Clearing cart (non sign-out) empties items
      CartService.instance.clearCart(isSignOut: false);
      expect(CartService.instance.isEmpty, isTrue);
    });

    test('Cart items persist and restore after simulated restart/refresh', () async {
      const siomai = CanteenMenuItem(
        id: 'food-siomai',
        name: 'Pork Siomai with rice',
        canteen: 'Main Canteen',
        category: 'Food and snacks',
        price: 30.00,
        unitDescription: '3 for 30 Pesos',
      );

      // 1. Customer adds item to cart
      CartService.instance.addItem(siomai, quantity: 2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(CartService.instance.totalItemCount, equals(2));

      // 2. Simulate complete application restart or web refresh
      // Reset memory state
      CartService.instance.clearCart(isSignOut: true);
      expect(CartService.instance.isEmpty, isTrue);

      // 3. App initializes and loads persisted cart
      await CartService.instance.loadCart();

      // 4. Cart is fully restored!
      expect(CartService.instance.isNotEmpty, isTrue);
      expect(CartService.instance.totalItemCount, equals(2));
      expect(CartService.instance.items.first.item.id, equals('food-siomai'));
      expect(CartService.instance.subtotal, equals(60.00));
    });
  });

  group('Task 3 — Prevent Customers from Claiming Their Own Orders', () {
    test('Customer claiming their own order is strictly rejected', () {
      final req = addPabiliRequest(
        customerId: 'student-user-456',
        pickup: 'Main Canteen',
        dropoff: 'GLE',
        description: 'Tapsilog Special',
        price: 65.00,
        deliveryFee: 20.00,
      );
      final orderId = req['id'].toString();

      // Attempt claim with matching runnerId == customerId
      final claimSelfResult = claimMockOrder(orderId, runnerId: 'student-user-456');
      expect(claimSelfResult, isFalse, reason: 'A student account must never claim its own order');

      // The order must remain pending and unclaimed
      final order = mockDeliveryRequests.firstWhere((r) => r['id'].toString() == orderId);
      expect(order['status'], equals('pending'));
      expect(order['runner_id'], isNull);
    });

    test('Different eligible runner can successfully claim the customer order', () {
      final req = addPabiliRequest(
        customerId: 'student-user-456',
        pickup: 'Main Canteen',
        dropoff: 'GLE',
        description: 'Tapsilog Special',
        price: 65.00,
        deliveryFee: 20.00,
      );
      final orderId = req['id'].toString();

      // Claim with different runnerId
      final claimOtherResult = claimMockOrder(orderId, runnerId: 'runner-student-789');
      expect(claimOtherResult, isTrue, reason: 'A different student runner can claim the order');

      final order = mockDeliveryRequests.firstWhere((r) => r['id'].toString() == orderId);
      expect(order['status'], equals('claimed'));
      expect(order['runner_id'], equals('runner-student-789'));
    });
  });

  group('Task 4 — Remove Claimed Orders from Available Orders List', () {
    test('Successfully claimed order disappears from available orders pool', () {
      final req = addPabiliRequest(
        customerId: 'customer-111',
        pickup: 'Mini Canteen',
        dropoff: 'SAL',
        description: 'Mozzarella Corndog',
        price: 45.00,
        deliveryFee: 25.00,
      );
      final orderId = req['id'].toString();

      var available = mockDeliveryRequests.where((r) => r['status'] == 'pending').toList();
      expect(available.any((r) => r['id'].toString() == orderId), isTrue);

      // Claim by runner
      final claimed = claimMockOrder(orderId, runnerId: 'runner-222');
      expect(claimed, isTrue);

      // Verify it is removed from available orders
      available = mockDeliveryRequests.where((r) => r['status'] == 'pending').toList();
      expect(available.any((r) => r['id'].toString() == orderId), isFalse);

      // Another runner attempting to claim the already claimed order is rejected
      final secondClaim = claimMockOrder(orderId, runnerId: 'runner-333');
      expect(secondClaim, isFalse, reason: 'Already claimed order cannot be claimed again');
    });
  });

  group('Task 5 — Allow Runners to Cancel/Release Mistakenly Claimed Orders', () {
    test('Runner can release mistakenly claimed order back to available status', () {
      final req = addPabiliRequest(
        customerId: 'customer-111',
        pickup: 'Mini Canteen',
        dropoff: 'SAL',
        description: 'Mozzarella Corndog',
        price: 45.00,
        deliveryFee: 25.00,
      );
      final orderId = req['id'].toString();

      // 1. Runner claims order
      claimMockOrder(orderId, runnerId: 'runner-222');
      var order = mockDeliveryRequests.firstWhere((r) => r['id'].toString() == orderId);
      expect(order['status'], equals('claimed'));
      expect(order['runner_id'], equals('runner-222'));

      // 2. Non-claiming runner attempts release -> rejected
      final unauthorizedRelease = releaseMockOrder(orderId, runnerId: 'unauthorized-runner-999');
      expect(unauthorizedRelease, isFalse, reason: 'Runner cannot release another runner\'s order');

      // 3. Claiming runner releases their own order
      final releaseResult = releaseMockOrder(orderId, runnerId: 'runner-222');
      expect(releaseResult, isTrue);

      // 4. Verify order details and status
      order = mockDeliveryRequests.firstWhere((r) => r['id'].toString() == orderId);
      expect(order['status'], equals('pending'), reason: 'Order returns to pending status');
      expect(order['runner_id'], isNull, reason: 'Runner assignment cleared');
      expect(order['customer_id'], equals('customer-111'), reason: 'Customer details preserved');
      expect(order['description'], equals('Mozzarella Corndog'), reason: 'Order description intact');
      expect(order['estimated_price'], equals(45.00));
      expect(order['delivery_fee'], equals(25.00));

      // 5. Another runner can now claim the released order
      final secondRunnerClaim = claimMockOrder(orderId, runnerId: 'runner-333');
      expect(secondRunnerClaim, isTrue, reason: 'Another eligible runner can claim the released order');

      order = mockDeliveryRequests.firstWhere((r) => r['id'].toString() == orderId);
      expect(order['status'], equals('claimed'));
      expect(order['runner_id'], equals('runner-333'));
    });
  });

  group('Task 6 — Change Completed Order Status to Green (Runner Side)', () {
    testWidgets('Completed orders in runner Past Orders section display green badge indicator', (tester) async {
      mockDeliveryRequests.addAll([
        {
          'id': 'ORD-PAST-COMPLETED-1',
          'pickup_location': 'Main Canteen',
          'dropoff_location': 'Science Bldg',
          'description': 'Burger × 2 | Fries × 1',
          'estimated_price': 120.0,
          'delivery_fee': 25.0,
          'status': 'completed',
          'verification_code': '1234',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'id': 'ORD-PAST-CANCELLED-1',
          'pickup_location': 'Mini Canteen',
          'dropoff_location': 'Allied',
          'description': 'Fruit Shake',
          'estimated_price': 60.0,
          'delivery_fee': 20.0,
          'status': 'cancelled',
          'verification_code': '5678',
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

      // Navigate to 'My Active Deliveries' tab
      await tester.tap(find.text('My Active Deliveries'));
      await tester.pumpAndSettle();

      // Past Orders section header exists
      expect(find.textContaining('Past Orders'), findsAtLeastNWidgets(1));

      // Verify the COMPLETED status text exists
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);

      // Verify Completed badge has green styling
      final completedText = tester.widget<Text>(find.text('COMPLETED'));
      expect(completedText.style?.color, equals(Colors.green.shade800));

      // Verify check circle icon in Completed badge
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Verify non-completed statuses retain their distinct non-green colors (cancelled = red)
      final cancelledText = tester.widget<Text>(find.text('CANCELLED'));
      expect(cancelledText.style?.color, equals(Colors.red.shade800));
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });
  });

  group('Task 7 — Display Runner Order Items One per Line', () {
    test('parseRunnerOrderItems splits pipe, comma, newline and formats one per line', () {
      // Pipe separated
      final pipeItems = parseRunnerOrderItems('Burger × 2 | Fries × 1 | Iced Tea × 3');
      expect(pipeItems, equals(['Burger × 2', 'Fries × 1', 'Iced Tea × 3']));

      // Comma separated with quantity prefixes
      final commaItems = parseRunnerOrderItems('2x Pork Siomai with rice, 1x Mountain Dew');
      expect(commaItems, equals(['Pork Siomai with rice × 2', 'Mountain Dew × 1']));

      // Order counts and single items
      final countItems = parseRunnerOrderItems('2 orders Chicken Joy, 1 Peach Mango Pie');
      expect(countItems, equals(['Chicken Joy × 2', 'Peach Mango Pie × 1']));

      // Newline separated
      final newlineItems = parseRunnerOrderItems('Cheeseburger × 1\nLarge Fries × 2');
      expect(newlineItems, equals(['Cheeseburger × 1', 'Large Fries × 2']));
    });

    testWidgets('RunnerOrderItemsList renders items vertically one per line with bullets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RunnerOrderItemsList(
              description: 'Burger × 2 | Fries × 1 | Iced Tea × 3',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify each individual item is displayed
      expect(find.text('Burger × 2'), findsOneWidget);
      expect(find.text('Fries × 1'), findsOneWidget);
      expect(find.text('Iced Tea × 3'), findsOneWidget);

      // Verify bullets are rendered for each line (3 items -> 3 bullets)
      expect(find.text('- '), findsNWidgets(3));
    });

    testWidgets('Runner Gig Board displays items one per line in feeds', (tester) async {
      mockDeliveryRequests.addAll([
        {
          'id': 'ORD-ACTIVE-ITEMS-1',
          'pickup_location': 'Main Canteen',
          'dropoff_location': 'Science Bldg',
          'description': 'Burger × 2 | Fries × 1',
          'estimated_price': 120.0,
          'delivery_fee': 25.0,
          'status': 'claimed',
          'verification_code': '1234',
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

      // Switch to deliveries tab
      await tester.tap(find.text('My Active Deliveries'));
      await tester.pumpAndSettle();

      // Verify ordered items section header and vertical items
      expect(find.text('Ordered Items:'), findsOneWidget);
      expect(find.text('Burger × 2'), findsOneWidget);
      expect(find.text('Fries × 1'), findsOneWidget);
      expect(find.text('- '), findsNWidgets(2));
    });
  });
}
