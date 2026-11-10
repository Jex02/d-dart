import '../models/class_schedule.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class DutyLockService {
  /// Confirmed runner schedule for the active user (empty until synced/uploaded).
  static List<ClassSession> verifiedSchedule = [];

  static bool isRunnerScheduleUploaded = false;

  /// Reset in-memory schedule state (e.g., on sign out).
  static void reset() {
    verifiedSchedule = [];
    isRunnerScheduleUploaded = false;
  }

  /// Sync profile and schedule from Supabase for the logged-in user.
  static Future<void> syncFromSupabase() async {
    try {
      final profile = await SupabaseService().fetchUserProfileModel();
      final sessions = await SupabaseService().fetchClassSchedule();
      if (sessions.isNotEmpty) {
        verifiedSchedule = sessions;
        isRunnerScheduleUploaded = true;
        return;
      }

      // Check if schedule was captured in auth user metadata during signup
      final metaSchedule = SupabaseService().currentUser?.userMetadata?['schedule'];
      if (metaSchedule is List && metaSchedule.isNotEmpty) {
        final parsed = metaSchedule
            .map((m) => ClassSession.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        verifiedSchedule = parsed;
        isRunnerScheduleUploaded = true;
        await SupabaseService().saveClassSchedule(parsed);
        return;
      }

      if (profile != null && !profile.corVerified) {
        verifiedSchedule = [];
        isRunnerScheduleUploaded = false;
      }
    } catch (_) {}
  }

  /// Evaluates whether the user is currently eligible to enter Runner Mode or claim requests.
  /// Checks account type, verification status, COR schedule existence, and class time + buffer.
  static Map<String, dynamic> checkDutyStatus({
    DateTime? now,
    UserProfile? profile,
    int preClassBufferMinutes = 15,
  }) {
    if (profile != null) {
      if (profile.isRejected) {
        return {
          'isLocked': true,
          'code': 'account_rejected',
          'reason': 'Your account verification was rejected. Runner access is disabled.',
        };
      }
      if (!profile.isStudent) {
        return {
          'isLocked': true,
          'code': 'not_student',
          'reason': 'Runner Mode is restricted to verified CIT-U student accounts.',
        };
      }
      if (!profile.isVerified || !profile.corVerified) {
        return {
          'isLocked': true,
          'code': 'unverified_cor',
          'reason': 'Your student COR verification is pending. Please upload and confirm your study load first.',
        };
      }
    }

    if (!isRunnerScheduleUploaded || verifiedSchedule.isEmpty) {
      return {
        'isLocked': true,
        'code': 'no_schedule',
        'reason': 'No verified COR schedule uploaded. Please upload your study load to activate Runner Mode.',
      };
    }

    final ref = now ?? DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final currentDay = weekdays[ref.weekday - 1];
    final currentMinutes = ref.hour * 60 + ref.minute;

    for (final session in verifiedSchedule) {
      if (session.day.toLowerCase() == currentDay.toLowerCase()) {
        final start = ClassSession.parseTimeMinutes(session.startTime);
        final end = ClassSession.parseTimeMinutes(session.endTime);

        if (start != null && end != null) {
          final bufferedStart = start - preClassBufferMinutes;
          if (currentMinutes >= bufferedStart && currentMinutes <= end) {
            final inBufferOnly = currentMinutes < start;
            return {
              'isLocked': true,
              'code': inBufferOnly ? 'pre_class_buffer' : 'in_class',
              'reason': inBufferOnly
                  ? 'Pre-Class Buffer ($preClassBufferMinutes min): ${session.subject} starts at ${session.startTime}.'
                  : 'Active Class: ${session.subject} (${session.startTime} - ${session.endTime}).',
              'currentSession': session,
            };
          }
        }
      }
    }

    return {
      'isLocked': false,
      'code': 'authorized',
      'reason': 'Vacant period. Runner Mode is authorized.',
    };
  }
}
