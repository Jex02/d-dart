class RunnerPerformance {
  final String runnerId;
  final String fullName;
  final String email;
  final String studentId;
  final String? photoUrl;
  final int completedDeliveries;
  final int totalReviews;
  final double? averageRating;

  const RunnerPerformance({
    required this.runnerId,
    required this.fullName,
    this.email = '',
    this.studentId = '',
    this.photoUrl,
    required this.completedDeliveries,
    required this.totalReviews,
    this.averageRating,
  });

  String get runnerName => fullName;

  RunnerPerformance copyWith({
    String? runnerId,
    String? fullName,
    String? email,
    String? studentId,
    String? photoUrl,
    int? completedDeliveries,
    int? totalReviews,
    double? averageRating,
  }) {
    return RunnerPerformance(
      runnerId: runnerId ?? this.runnerId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      studentId: studentId ?? this.studentId,
      photoUrl: photoUrl ?? this.photoUrl,
      completedDeliveries: completedDeliveries ?? this.completedDeliveries,
      totalReviews: totalReviews ?? this.totalReviews,
      averageRating: averageRating ?? this.averageRating,
    );
  }

  bool get hasRatings => totalReviews > 0 && averageRating != null;

  String get ratingDisplay {
    if (!hasRatings) return 'No Ratings Yet';
    return '${averageRating!.toStringAsFixed(1)} ★';
  }

  factory RunnerPerformance.fromJson(Map<String, dynamic> json) {
    final rawDel = json['completed_deliveries'];
    final delCount = rawDel is int ? rawDel : (int.tryParse(rawDel?.toString() ?? '0') ?? 0);

    final rawRev = json['total_reviews'];
    final revCount = rawRev is int ? rawRev : (int.tryParse(rawRev?.toString() ?? '0') ?? 0);

    final rawAvg = json['avg_rating'];
    double? avg;
    if (rawAvg != null) {
      avg = rawAvg is num ? rawAvg.toDouble() : double.tryParse(rawAvg.toString());
    }

    return RunnerPerformance(
      runnerId: json['runner_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Runner',
      email: json['email']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      photoUrl: json['id_document_path']?.toString() ?? json['photo_url']?.toString(),
      completedDeliveries: delCount,
      totalReviews: revCount,
      averageRating: revCount > 0 ? avg : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'runner_id': runnerId,
      'full_name': fullName,
      'email': email,
      'student_id': studentId,
      'photo_url': photoUrl,
      'completed_deliveries': completedDeliveries,
      'total_reviews': totalReviews,
      'avg_rating': averageRating,
    };
  }
}
