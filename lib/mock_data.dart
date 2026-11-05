import 'dart:math';

// Shared in-memory delivery store for local testing
List<Map<String, dynamic>> mockDeliveryRequests = [
  {
    'id': 'ORD-101',
    'pickup_location': 'Main Canteen',
    'dropoff_location': 'ALLIED Building - 3rd Floor Lab',
    'description': '2 orders Pork Siomai with rice, 1 C2 Apple',
    'estimated_price': 85.00,
    'delivery_fee': 20.00,
    'status': 'pending', // pending, claimed, purchasing, en_route, arrived, completed
    'verification_code': '4821',
    'special_instructions': 'Extra chili oil please',
  },
];

void addPabiliRequest({
  required String pickup,
  required String dropoff,
  required String description,
  required double price,
  String? instructions,
}) {
  final otp = (Random().nextInt(9000) + 1000).toString();
  mockDeliveryRequests.insert(0, {
    'id': 'ORD-${Random().nextInt(900) + 100}',
    'pickup_location': pickup,
    'dropoff_location': dropoff,
    'description': description,
    'estimated_price': price,
    'delivery_fee': 20.00,
    'status': 'pending',
    'verification_code': otp,
    'special_instructions': instructions ?? '',
  });
}
