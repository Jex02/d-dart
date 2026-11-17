class OrderMessage {
  final String id;
  final String orderId;
  final String? senderId;
  final String senderRole; // 'customer' | 'runner' | 'system'
  final String senderName;
  final String message;
  final DateTime createdAt;

  const OrderMessage({
    required this.id,
    required this.orderId,
    this.senderId,
    required this.senderRole,
    this.senderName = '',
    required this.message,
    required this.createdAt,
  });

  bool get isCustomer => senderRole.toLowerCase() == 'customer';
  bool get isRunner => senderRole.toLowerCase() == 'runner';
  bool get isSystem => senderRole.toLowerCase() == 'system';

  String formattedTime() {
    final local = createdAt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    return '$formattedHour:$minute $period';
  }

  factory OrderMessage.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['created_at'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return OrderMessage(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString(),
      senderRole: json['sender_role']?.toString() ?? 'customer',
      senderName: json['sender_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      if (senderId != null) 'sender_id': senderId,
      'sender_role': senderRole,
      'sender_name': senderName,
      'message': message,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
