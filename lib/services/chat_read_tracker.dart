import 'package:flutter/foundation.dart';
import '../models/order_message.dart';

/// Tracks which order chat messages the current user has already read in-app,
/// so unread notification badges update immediately across tracking & chat UIs.
class ChatReadTracker extends ChangeNotifier {
  ChatReadTracker._();
  static final ChatReadTracker instance = ChatReadTracker._();

  final Map<String, DateTime> _lastReadAt = {};

  String _key(String orderId, bool isRunner) =>
      '$orderId|${isRunner ? 'runner' : 'customer'}';

  void markRead(
    String orderId, {
    required bool isRunner,
    DateTime? upTo,
  }) {
    final k = _key(orderId, isRunner);
    final candidate = (upTo ?? DateTime.now()).toUtc();
    final existing = _lastReadAt[k];
    if (existing != null && !candidate.isAfter(existing)) {
      return;
    }
    _lastReadAt[k] = candidate;
    notifyListeners();
  }

  int countUnread(
    String orderId,
    List<OrderMessage> messages, {
    required bool isRunner,
  }) {
    final lastRead = _lastReadAt[_key(orderId, isRunner)];
    int count = 0;
    for (final msg in messages) {
      final isIncoming = isRunner ? msg.isCustomer : msg.isRunner;
      if (!isIncoming) continue;
      if (lastRead == null || msg.createdAt.toUtc().isAfter(lastRead)) {
        count++;
      }
    }
    return count;
  }

  OrderMessage? latestIncomingMessage(
    List<OrderMessage> messages, {
    required bool isRunner,
  }) {
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (isRunner ? msg.isCustomer : msg.isRunner) {
        return msg;
      }
    }
    return null;
  }

  DateTime? latestTimestamp(List<OrderMessage> messages) {
    if (messages.isEmpty) return null;
    return messages.last.createdAt.toUtc();
  }

  void clear() {
    _lastReadAt.clear();
    notifyListeners();
  }
}
