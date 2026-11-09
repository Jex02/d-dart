import '../models/class_schedule.dart';
import 'supabase_service.dart';

class DutyLockService {
  // Global verified runner schedule stored in memory
  static List<ClassSession> verifiedSchedule = [
    ClassSession(day: 'Monday', startTime: '09:00', endTime: '12:00', subject: 'CS 321 - Software Dev 2'),
    ClassSession(day: 'Wednesday', startTime: '13:00', endTime: '15:30', subject: 'IT 312 - Database Systems'),
    ClassSession(day: 'Thursday', startTime: '18:00', endTime: '21:00', subject: 'CS 322 - Algorithms'),
  ];

  static bool isRunnerScheduleUploaded = true;

  /// Sync schedule from Supabase for logged-in user
  static Future<void> syncFromSupabase() async {
    try {
      final sessions = await SupabaseService().fetchClassSchedule();
      if (sessions.isNotEmpty) {
        verifiedSchedule = sessions;
        isRunnerScheduleUploaded = true;
      }
    } catch (_) {}
  }

  // Returns true if current time falls within any confirmed class session + 15 min buffer
  static Map<String, dynamic> checkDutyStatus() {
    if (!isRunnerScheduleUploaded || verifiedSchedule.isEmpty) {
      return {
        'isLocked': true,
        'reason': 'No verified COR schedule uploaded. Please upload your study load to activate Runner mode.',
      };
    }

    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDay = weekdays[now.weekday - 1];

    for (var session in verifiedSchedule) {
      if (session.day.toLowerCase() == currentDay.toLowerCase()) {
        final startParts = session.startTime.split(':');
        final endParts = session.endTime.split(':');

        if (startParts.length == 2 && endParts.length == 2) {
          final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]) - 15; // 15-min pre-class buffer
          final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
          final currentMinutes = now.hour * 60 + now.minute;

          if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
            return {
              'isLocked': true,
              'reason': 'Active Class: ${session.subject} (${session.startTime} - ${session.endTime})',
              'currentSession': session,
            };
          }
        }
      }
    }

    return {
      'isLocked': false,
      'reason': 'Vacant period. Runner Mode is authorized.',
    };
  }
}
