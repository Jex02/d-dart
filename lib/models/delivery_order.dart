class DeliveryOrder {
  final String id;
  final String? customerId;
  final String? runnerId;
  final String pickupLocation;
  final String dropoffLocation;
  final String description;
  final double estimatedPrice;
  final double deliveryFee;
  final String status;
  final String verificationCode;
  final String specialInstructions;
  final DateTime? expiresAt;
  final DateTime? claimedAt;
  final DateTime? cancelledAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeliveryOrder({
    required this.id,
    this.customerId,
    this.runnerId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.description,
    required this.estimatedPrice,
    this.deliveryFee = 20.0,
    this.status = 'pending',
    required this.verificationCode,
    this.specialInstructions = '',
    this.expiresAt,
    this.claimedAt,
    this.cancelledAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  double get totalAmount => estimatedPrice + deliveryFee;

  bool isExpiredAt([DateTime? reference]) {
    if (status == 'expired') return true;
    if (status != 'pending' || expiresAt == null) return false;
    final now = reference ?? DateTime.now().toUtc();
    return !now.isBefore(expiresAt!.toUtc());
  }

  bool canCancelAt([DateTime? reference]) =>
      status == 'pending' && !isExpiredAt(reference);

  String effectiveStatus([DateTime? reference]) =>
      isExpiredAt(reference) ? 'expired' : status;

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      runnerId: json['runner_id']?.toString(),
      pickupLocation: json['pickup_location']?.toString() ?? '',
      dropoffLocation: json['dropoff_location']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      estimatedPrice: (json['estimated_price'] is num)
          ? (json['estimated_price'] as num).toDouble()
          : double.tryParse(json['estimated_price']?.toString() ?? '0') ?? 0.0,
      deliveryFee: (json['delivery_fee'] is num)
          ? (json['delivery_fee'] as num).toDouble()
          : double.tryParse(json['delivery_fee']?.toString() ?? '20') ?? 20.0,
      status: json['status']?.toString() ?? 'pending',
      verificationCode: json['verification_code']?.toString() ?? '',
      specialInstructions: json['special_instructions']?.toString() ?? '',
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      claimedAt: json['claimed_at'] != null ? DateTime.tryParse(json['claimed_at'].toString()) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pickup_location': pickupLocation,
      'dropoff_location': dropoffLocation,
      'description': description,
      'estimated_price': estimatedPrice,
      'delivery_fee': deliveryFee,
      'status': status,
      'verification_code': verificationCode,
      'special_instructions': specialInstructions,
      if (customerId != null) 'customer_id': customerId,
      if (runnerId != null) 'runner_id': runnerId,
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    };
  }
}
