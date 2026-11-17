import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/mock_data.dart';
import 'package:sd2/models/order_message.dart';
import 'package:sd2/services/supabase_service.dart';

void main() {
  setUp(() {
    mockOrderMessages.clear();
  });

  group('OrderMessage model tests', () {
    test('serializes and deserializes OrderMessage cleanly', () {
      final now = DateTime.utc(2026, 11, 17, 14, 30, 0);
      final msg = OrderMessage(
        id: 'msg-test-1',
        orderId: 'ORD-999',
        senderId: 'user-123',
        senderRole: 'customer',
        senderName: 'Jerick Ivan',
        message: 'Please make the siomai extra spicy!',
        createdAt: now,
      );

      final json = msg.toJson();
      expect(json['id'], 'msg-test-1');
      expect(json['order_id'], 'ORD-999');
      expect(json['sender_id'], 'user-123');
      expect(json['sender_role'], 'customer');
      expect(json['sender_name'], 'Jerick Ivan');
      expect(json['message'], 'Please make the siomai extra spicy!');
      expect(json['created_at'], now.toIso8601String());

      final fromJson = OrderMessage.fromJson(json);
      expect(fromJson.id, msg.id);
      expect(fromJson.orderId, msg.orderId);
      expect(fromJson.senderRole, 'customer');
      expect(fromJson.isCustomer, isTrue);
      expect(fromJson.isRunner, isFalse);
      expect(fromJson.isSystem, isFalse);
      expect(fromJson.message, msg.message);
    });

    test('role helper getters work properly', () {
      final runnerMsg = OrderMessage(
        id: 'm1',
        orderId: 'ORD-1',
        senderRole: 'runner',
        message: 'On my way',
        createdAt: DateTime.now(),
      );
      expect(runnerMsg.isRunner, isTrue);
      expect(runnerMsg.isCustomer, isFalse);
      expect(runnerMsg.isSystem, isFalse);

      final sysMsg = OrderMessage(
        id: 'm2',
        orderId: 'ORD-1',
        senderRole: 'system',
        message: 'Runner arrived',
        createdAt: DateTime.now(),
      );
      expect(sysMsg.isSystem, isTrue);
      expect(sysMsg.isRunner, isFalse);
      expect(sysMsg.isCustomer, isFalse);
    });

    test('formats time string accurately', () {
      final dt = DateTime(2026, 11, 17, 9, 5); // 9:05 AM
      final msg = OrderMessage(
        id: 'm3',
        orderId: 'ORD-1',
        senderRole: 'customer',
        message: 'Morning order',
        createdAt: dt,
      );
      expect(msg.formattedTime(), '9:05 AM');

      final dtPm = DateTime(2026, 11, 17, 18, 45); // 6:45 PM
      final msgPm = OrderMessage(
        id: 'm4',
        orderId: 'ORD-1',
        senderRole: 'runner',
        message: 'Evening delivery',
        createdAt: dtPm,
      );
      expect(msgPm.formattedTime(), '6:45 PM');
    });
  });

  group('Mock and SupabaseService direct messaging flow', () {
    test('adds mock order messages and filters by orderId', () {
      addMockOrderMessage(
        orderId: 'ORD-101',
        message: 'Hello from runner',
        senderRole: 'runner',
        senderName: 'Runner Dave',
      );
      addMockOrderMessage(
        orderId: 'ORD-101',
        message: 'Got it, thank you',
        senderRole: 'customer',
        senderName: 'Customer Anne',
      );
      addMockOrderMessage(
        orderId: 'ORD-202',
        message: 'Different order message',
        senderRole: 'customer',
      );

      final order101Msgs = getMockMessagesForOrder('ORD-101');
      expect(order101Msgs.length, 2);
      expect(order101Msgs[0]['message'], 'Hello from runner');
      expect(order101Msgs[1]['message'], 'Got it, thank you');

      final order202Msgs = getMockMessagesForOrder('ORD-202');
      expect(order202Msgs.length, 1);
      expect(order202Msgs[0]['message'], 'Different order message');
    });

    test('SupabaseService.sendOrderMessage dispatches to stream', () async {
      final service = SupabaseService();
      const testOrderId = 'ORD-CHAT-TEST';

      final stream = service.streamOrderMessages(testOrderId);
      final expectation = expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
          hasLength(2),
        ]),
      );

      // Allow the initial empty yield to be received by the listener
      await Future<void>.delayed(Duration.zero);

      final sent1 = await service.sendOrderMessage(
        orderId: testOrderId,
        message: 'First test message',
        senderRole: 'customer',
      );
      expect(sent1, isTrue);

      final sent2 = await service.sendOrderMessage(
        orderId: testOrderId,
        message: 'Runner reply message',
        senderRole: 'runner',
      );
      expect(sent2, isTrue);

      await expectation;
    });

    test('SupabaseService rejects empty whitespace messages', () async {
      final service = SupabaseService();
      final sentEmpty = await service.sendOrderMessage(
        orderId: 'ORD-TEST',
        message: '   ',
        senderRole: 'customer',
      );
      expect(sentEmpty, isFalse);
    });
  });
}
