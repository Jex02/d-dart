class ProblemReport {
  static const Map<String, String> categoryLabels = {
    'wrong_item': 'Wrong / Missing Item',
    'late_delivery': 'Late Delivery',
    'payment_issue': 'Payment / Change Issue',
    'runner_behavior': 'Runner Conduct',
    'app_issue': 'App / Technical Issue',
    'other': 'Other Issue',
  };

  static const List<String> statuses = [
    'open',
    'reviewing',
    'resolved',
    'dismissed',
  ];

  final String id;
  final String? requestId;
  final String? reporterId;
  final String category;
  final String description;
  final String status;
  final String adminNotes;
  final DateTime? createdAt;

  const ProblemReport({
    required this.id,
    this.requestId,
    this.reporterId,
    required this.category,
    required this.description,
    this.status = 'open',
    this.adminNotes = '',
    this.createdAt,
  });

  String get categoryLabel => categoryLabels[category] ?? category;

  factory ProblemReport.fromJson(Map<String, dynamic> json) {
    return ProblemReport(
      id: json['id']?.toString() ?? '',
      requestId: json['request_id']?.toString(),
      reporterId: json['reporter_id']?.toString(),
      category: json['category']?.toString() ?? 'other',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      adminNotes: json['admin_notes']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
