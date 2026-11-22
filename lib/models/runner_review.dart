class RunnerReview {
  final String id;
  final String orderId;
  final String runnerId;
  final String customerId;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;
  final String? customerName;
  final String? customerPhoto;

  const RunnerReview({
    required this.id,
    required this.orderId,
    required this.runnerId,
    required this.customerId,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    this.customerName,
    this.customerPhoto,
  });

  factory RunnerReview.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at'].toString());
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final rawRating = json['rating'];
    final int ratingVal = rawRating is int
        ? rawRating
        : (int.tryParse(rawRating?.toString() ?? '5') ?? 5);

    return RunnerReview(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      runnerId: json['runner_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      rating: ratingVal.clamp(1, 5),
      reviewText: json['review_text']?.toString(),
      createdAt: parsedDate,
      customerName: json['customer_name']?.toString() ??
          (json['customer'] is Map ? json['customer']['full_name']?.toString() : null),
      customerPhoto: json['customer_photo']?.toString() ??
          (json['customer'] is Map ? json['customer']['id_document_path']?.toString() : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'runner_id': runnerId,
      'customer_id': customerId,
      'rating': rating,
      'review_text': reviewText,
      'created_at': createdAt.toIso8601String(),
      if (customerName != null) 'customer_name': customerName,
      if (customerPhoto != null) 'customer_photo': customerPhoto,
    };
  }

  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }

  String get ratingStars => '★' * rating + '☆' * (5 - rating);
}
