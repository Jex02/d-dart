class ClassSession {
  static const List<String> validDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final String day; // Monday .. Saturday
  final String startTime; // "09:00" (24-hour format)
  final String endTime; // "11:30" (24-hour format)
  final String subject;

  ClassSession({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
  });

  ClassSession copyWith({
    String? day,
    String? startTime,
    String? endTime,
    String? subject,
  }) {
    return ClassSession(
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subject: subject ?? this.subject,
    );
  }

  static int? parseTimeMinutes(String hhmm) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  bool get hasValidTimeRange {
    final start = parseTimeMinutes(startTime);
    final end = parseTimeMinutes(endTime);
    return start != null && end != null && end > start;
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'start_time': startTime,
        'end_time': endTime,
        'subject': subject,
      };

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      day: json['day']?.toString() ?? 'Monday',
      startTime: json['start_time']?.toString() ?? '08:00',
      endTime: json['end_time']?.toString() ?? '09:00',
      subject: json['subject']?.toString() ?? 'Enrolled Course',
    );
  }
}

class CorVerificationResult {
  final bool isValid;
  final String message;
  final String? studentName;
  final String? studentId;
  final List<ClassSession> sessions;
  final bool isDemoFallback;

  CorVerificationResult({
    required this.isValid,
    required this.message,
    this.studentName,
    this.studentId,
    this.sessions = const [],
    this.isDemoFallback = false,
  });

  factory CorVerificationResult.invalid(String message) {
    return CorVerificationResult(
      isValid: false,
      message: message,
      sessions: const [],
    );
  }

  factory CorVerificationResult.valid({
    required String message,
    String? studentName,
    String? studentId,
    required List<ClassSession> sessions,
    bool isDemoFallback = false,
  }) {
    return CorVerificationResult(
      isValid: true,
      message: message,
      studentName: studentName,
      studentId: studentId,
      sessions: sessions,
      isDemoFallback: isDemoFallback,
    );
  }
}
