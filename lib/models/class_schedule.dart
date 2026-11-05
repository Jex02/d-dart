class ClassSession {
  final String day; // Monday, Tuesday, Wednesday, Thursday, Friday, Saturday
  final String startTime; // "09:00" (24-hour format)
  final String endTime;   // "11:30" (24-hour format)
  final String subject;

  ClassSession({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
  });

  Map<String, dynamic> toJson() => {
    'day': day,
    'start_time': startTime,
    'end_time': endTime,
    'subject': subject,
  };

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      day: json['day'] ?? 'Monday',
      startTime: json['start_time'] ?? '08:00',
      endTime: json['end_time'] ?? '09:00',
      subject: json['subject'] ?? 'Enrolled Course',
    );
  }
}
