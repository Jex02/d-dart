import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/mock_data.dart';
import 'package:sd2/models/delivery_order.dart';

void main() {
  setUp(() {
    mockDeliveryRequests.clear();
  });

  test('DeliveryOrder computes total, cancellation, and expiration accurately', () {
    final baseTime = DateTime.utc(2026, 11, 10, 10, 0);
    final order = DeliveryOrder(
      id: 'ORD-500',
      pickupLocation: 'Main Canteen',
      dropoffLocation: 'ALLIED Building',
      description: '2x Siomai Rice',
      estimatedPrice: 85.0,
      deliveryFee: 20.0,
      status: 'pending',
      verificationCode: '4321',
      expiresAt: baseTime.add(const Duration(minutes: 30)),
    );

    expect(order.totalAmount, 105.0);
    expect(order.isExpiredAt(baseTime.add(const Duration(minutes: 10))), isFalse);
    expect(order.canCancelAt(baseTime.add(const Duration(minutes: 10))), isTrue);

    expect(order.isExpiredAt(baseTime.add(const Duration(minutes: 31))), isTrue);
    expect(order.canCancelAt(baseTime.add(const Duration(minutes: 31))), isFalse);
    expect(order.effectiveStatus(baseTime.add(const Duration(minutes: 31))), 'expired');
  });

  test('prevents duplicate claims and cancels only unclaimed requests', () {
    final created = addPabiliRequest(
      orderId: 'ORD-777',
      pickup: 'Main Canteen',
      dropoff: 'GLE Building',
      description: 'Bottled Water',
      price: 25.0,
    );
    expect(created['status'], 'pending');

    // First runner succeeds; second runner is blocked
    expect(claimMockOrder('ORD-777', runnerId: 'runner-1'), isTrue);
    expect(claimMockOrder('ORD-777', runnerId: 'runner-2'), isFalse);

    // Claimed order can no longer be cancelled
    expect(cancelMockOrder('ORD-777'), isFalse);
  });

  test('cancels pending order and blocks claiming cancelled or expired orders', () {
    addPabiliRequest(
      orderId: 'ORD-888',
      pickup: 'College Canteen',
      dropoff: 'Main Building',
      description: 'Iced Coffee',
      price: 55.0,
    );
    expect(cancelMockOrder('ORD-888'), isTrue);
    expect(claimMockOrder('ORD-888', runnerId: 'runner-1'), isFalse);

    addPabiliRequest(
      orderId: 'ORD-999',
      pickup: 'Campus Kiosks',
      dropoff: 'University Library',
      description: 'Notebook',
      price: 40.0,
      expiresIn: const Duration(minutes: 5),
    );
    final future = DateTime.now().toUtc().add(const Duration(minutes: 10));
    expect(expireStaleMockOrders(now: future), 1);
    expect(claimMockOrder('ORD-999', runnerId: 'runner-1', now: future), isFalse);
  });
}
