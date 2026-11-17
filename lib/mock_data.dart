import 'dart:math';

// Shared in-memory delivery store for offline/demo testing
List<Map<String, dynamic>> mockDeliveryRequests = [
  {
    'id': 'ORD-101',
    'pickup_location': 'Main Canteen',
    'dropoff_location': 'ALLIED Building - 3rd Floor Lab',
    'description': '2 orders Pork Siomai with rice, 1 C2 Apple',
    'estimated_price': 85.00,
    'delivery_fee': 20.00,
    'status': 'pending',
    'verification_code': '4821',
    'special_instructions': 'Extra chili oil please',
    'expires_at':
        DateTime.now().toUtc().add(const Duration(minutes: 30)).toIso8601String(),
    'created_at': DateTime.now().toUtc().toIso8601String(),
  },
];

Map<String, dynamic> addPabiliRequest({
  required String pickup,
  required String dropoff,
  required String description,
  required double price,
  double deliveryFee = 20.0,
  String? instructions,
  String? orderId,
  String? verificationCode,
  String? customerId,
  Duration expiresIn = const Duration(minutes: 30),
}) {
  final otp = verificationCode ?? (Random().nextInt(9000) + 1000).toString();
  final now = DateTime.now().toUtc();
  final record = <String, dynamic>{
    'id': orderId ?? 'ORD-${Random().nextInt(900) + 100}',
    'customer_id': ?customerId,
    'pickup_location': pickup,
    'dropoff_location': dropoff,
    'description': description,
    'estimated_price': price,
    'delivery_fee': deliveryFee,
    'status': 'pending',
    'verification_code': otp,
    'special_instructions': instructions ?? '',
    'expires_at': now.add(expiresIn).toIso8601String(),
    'created_at': now.toIso8601String(),
  };
  mockDeliveryRequests.insert(0, record);
  return record;
}

bool claimMockOrder(String orderId, {String? runnerId, DateTime? now}) {
  expireStaleMockOrders(now: now);
  final index =
      mockDeliveryRequests.indexWhere((r) => r['id'].toString() == orderId);
  if (index == -1) return false;
  final current = mockDeliveryRequests[index];
  if (current['status'] != 'pending') return false;
  current['status'] = 'claimed';
  if (runnerId != null) current['runner_id'] = runnerId;
  current['claimed_at'] = (now ?? DateTime.now().toUtc()).toIso8601String();
  return true;
}

bool cancelMockOrder(String orderId, {DateTime? now}) {
  expireStaleMockOrders(now: now);
  final index =
      mockDeliveryRequests.indexWhere((r) => r['id'].toString() == orderId);
  if (index == -1) return false;
  final current = mockDeliveryRequests[index];
  if (current['status'] != 'pending') return false;
  current['status'] = 'cancelled';
  current['cancelled_at'] = (now ?? DateTime.now().toUtc()).toIso8601String();
  return true;
}

int expireStaleMockOrders({DateTime? now}) {
  final ref = (now ?? DateTime.now().toUtc()).toUtc();
  int count = 0;
  for (final req in mockDeliveryRequests) {
    if (req['status'] == 'pending' && req['expires_at'] != null) {
      final exp = DateTime.tryParse(req['expires_at'].toString())?.toUtc();
      if (exp != null && !ref.isBefore(exp)) {
        req['status'] = 'expired';
        count++;
      }
    }
  }
  return count;
}

// In-memory messages store for active orders (offline/demo testing)
List<Map<String, dynamic>> mockOrderMessages = [
  {
    'id': 'msg-101-1',
    'order_id': 'ORD-101',
    'sender_id': 'runner-demo',
    'sender_role': 'runner',
    'sender_name': 'Mark (Runner)',
    'message': 'Hello! I am heading to the Main Canteen now to purchase your items.',
    'created_at': DateTime.now().toUtc().subtract(const Duration(minutes: 6)).toIso8601String(),
  },
  {
    'id': 'msg-101-2',
    'order_id': 'ORD-101',
    'sender_id': 'customer-demo',
    'sender_role': 'customer',
    'sender_name': 'Customer',
    'message': 'Thank you! Please make sure the siomai has extra chili oil.',
    'created_at': DateTime.now().toUtc().subtract(const Duration(minutes: 3)).toIso8601String(),
  },
];

List<Map<String, dynamic>> getMockMessagesForOrder(String orderId) {
  return mockOrderMessages
      .where((m) => m['order_id'].toString() == orderId)
      .toList()
    ..sort((a, b) {
      final aTime = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.now();
      final bTime = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.now();
      return aTime.compareTo(bTime);
    });
}

Map<String, dynamic> addMockOrderMessage({
  required String orderId,
  required String message,
  required String senderRole,
  String? senderName,
  String? senderId,
}) {
  final now = DateTime.now().toUtc();
  final msg = <String, dynamic>{
    'id': 'msg-${Random().nextInt(90000) + 10000}',
    'order_id': orderId,
    'sender_id': senderId ?? 'user-demo',
    'sender_role': senderRole,
    'sender_name': senderName ?? (senderRole == 'runner' ? 'Runner' : 'Customer'),
    'message': message.trim(),
    'created_at': now.toIso8601String(),
  };
  mockOrderMessages.add(msg);
  return msg;
}

