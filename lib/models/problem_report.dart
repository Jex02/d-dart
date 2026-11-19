class ProblemReport {
  static const Map<String, String> categoryLabels = {
    'wrong_item': 'Wrong / Missing Item',
    'late_delivery': 'Late Delivery',
    'payment_issue': 'Payment / Change Issue',
    'runner_behavior': 'Runner Conduct / Issue',
    'customer_behavior': 'Customer Conduct / Behavior',
    'unresponsive_user': 'Customer Unresponsive / No-show',
    'wrong_location': 'Location Inaccessible / Incorrect',
    'canteen_issue': 'Canteen Closed / Out of Stock',
    'app_issue': 'App / Technical Issue',
    'other': 'Other Issue',
  };

  static const List<String> customerCategories = [
    'wrong_item',
    'late_delivery',
    'payment_issue',
    'runner_behavior',
    'app_issue',
    'other',
  ];

  static const List<String> runnerCategories = [
    'unresponsive_user',
    'customer_behavior',
    'payment_issue',
    'wrong_location',
    'canteen_issue',
    'app_issue',
    'other',
  ];

  static const List<String> statuses = [
    'open',
    'reviewing',
    'resolved',
    'dismissed',
  ];

  final String id;
  final String? requestId;
  final String? reporterId;
  final String reporterRole;
  final String? reportedUserId;
  final String category;
  final String description;
  final String status;
  final String adminNotes;
  final String? reviewedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined / enriched metadata
  final String? reporterName;
  final String? reporterEmail;
  final String? reporterPhone;
  final String? reporterStudentId;
  final String? reportedUserName;
  final String? reportedUserEmail;
  final String? reportedUserRole;
  final String? orderPickupLocation;
  final String? orderDropoffLocation;
  final String? orderDescription;
  final String? orderStatus;
  final double? orderEstimatedPrice;
  final double? orderDeliveryFee;
  final String? reviewerName;

  const ProblemReport({
    required this.id,
    this.requestId,
    this.reporterId,
    this.reporterRole = 'customer',
    this.reportedUserId,
    required this.category,
    required this.description,
    this.status = 'open',
    this.adminNotes = '',
    this.reviewedBy,
    this.createdAt,
    this.updatedAt,
    this.reporterName,
    this.reporterEmail,
    this.reporterPhone,
    this.reporterStudentId,
    this.reportedUserName,
    this.reportedUserEmail,
    this.reportedUserRole,
    this.orderPickupLocation,
    this.orderDropoffLocation,
    this.orderDescription,
    this.orderStatus,
    this.orderEstimatedPrice,
    this.orderDeliveryFee,
    this.reviewerName,
  });

  String get categoryLabel => categoryLabels[category] ?? category;

  bool get isCustomerReport => reporterRole.toLowerCase() == 'customer';
  bool get isRunnerReport => reporterRole.toLowerCase() == 'runner';
  bool get hasOrder => requestId != null && requestId!.isNotEmpty;
  bool get hasReportedUser =>
      reportedUserName != null && reportedUserName!.isNotEmpty;

  factory ProblemReport.fromJson(Map<String, dynamic> json) {
    // Check if reporter profile is embedded as map
    final reporterMap = json['reporter'] is Map ? json['reporter'] as Map : null;
    final reportedMap = json['reported_user'] is Map ? json['reported_user'] as Map : null;
    final orderMap = json['order'] is Map
        ? json['order'] as Map
        : (json['delivery_request'] is Map ? json['delivery_request'] as Map : null);

    return ProblemReport(
      id: json['id']?.toString() ?? '',
      requestId: json['request_id']?.toString(),
      reporterId: json['reporter_id']?.toString(),
      reporterRole: json['reporter_role']?.toString() ??
          reporterMap?['role']?.toString() ??
          'customer',
      reportedUserId: json['reported_user_id']?.toString(),
      category: json['category']?.toString() ?? 'other',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      adminNotes: json['admin_notes']?.toString() ?? '',
      reviewedBy: json['reviewed_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      reporterName: json['reporter_name']?.toString() ??
          reporterMap?['full_name']?.toString(),
      reporterEmail: json['reporter_email']?.toString() ??
          reporterMap?['email']?.toString(),
      reporterPhone: json['reporter_phone']?.toString() ??
          reporterMap?['phone_number']?.toString(),
      reporterStudentId: json['reporter_student_id']?.toString() ??
          reporterMap?['student_id']?.toString(),
      reportedUserName: json['reported_user_name']?.toString() ??
          reportedMap?['full_name']?.toString(),
      reportedUserEmail: json['reported_user_email']?.toString() ??
          reportedMap?['email']?.toString(),
      reportedUserRole: json['reported_user_role']?.toString() ??
          reportedMap?['role']?.toString(),
      orderPickupLocation: json['pickup_location']?.toString() ??
          orderMap?['pickup_location']?.toString(),
      orderDropoffLocation: json['dropoff_location']?.toString() ??
          orderMap?['dropoff_location']?.toString(),
      orderDescription: json['order_description']?.toString() ??
          orderMap?['description']?.toString(),
      orderStatus: json['order_status']?.toString() ??
          orderMap?['status']?.toString(),
      orderEstimatedPrice: json['order_estimated_price'] != null
          ? double.tryParse(json['order_estimated_price'].toString())
          : (orderMap?['estimated_price'] != null
              ? double.tryParse(orderMap!['estimated_price'].toString())
              : null),
      orderDeliveryFee: json['order_delivery_fee'] != null
          ? double.tryParse(json['order_delivery_fee'].toString())
          : (orderMap?['delivery_fee'] != null
              ? double.tryParse(orderMap!['delivery_fee'].toString())
              : null),
      reviewerName: json['reviewer_name']?.toString(),
    );
  }
}
