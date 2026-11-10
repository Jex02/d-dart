import '../models/class_schedule.dart';
import '../models/system_config.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class DutyLockService {
  /// Confirmed runner schedule for the active user (empty until synced/uploaded).
  static List<ClassSession> verifiedSchedule = [];

  static bool isRunnerScheduleUploaded = false;
  static SystemConfig activeConfig = const SystemConfig();
  static int completedDeliveriesToday = 0;

  /// Reset in-memory state (e.g., on sign out).
  static void reset() {
    verifiedSchedule = [];
    isRunnerScheduleUploaded = false;
    activeConfig = const SystemConfig();
    completedDeliveriesToday = 0;
  }

  /// Sync profile, system configuration, daily delivery count, and schedule from Supabase.
  static Future<void> syncFromSupabase() async {
    try {
      final service = SupabaseService();
      final profile = await service.fetchUserProfileModel();
      activeConfig = await service.fetchSystemConfig();
      completedDeliveriesToday = await service.fetchRunnerCompletedTodayCount();

      final sessions = await service.fetchClassSchedule();
      if (sessions.isNotEmpty) {
        verifiedSchedule = sessions;
        isRunnerScheduleUploaded = true;
        return;
      }

      // Check if schedule was captured in auth user metadata during signup
      final metaSchedule = service.currentUser?.userMetadata?['schedule'];
      if (metaSchedule is List && metaSchedule.isNotEmpty) {
        final parsed = metaSchedule
            .map((m) => ClassSession.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        verifiedSchedule = parsed;
        isRunnerScheduleUploaded = true;
        await service.saveClassSchedule(parsed);
        return;
      }

      if (profile != null && !profile.corVerified) {
        verifiedSchedule = [];
        isRunnerScheduleUploaded = false;
      }
    } catch (_) {}
  }

  /// Evaluates whether the user is currently eligible to operate in Runner Mode
  /// or claim new delivery requests. Enforces:
  /// 1. Account type & admin verification status
  /// 2. Daily completed delivery limit
  /// 3. Verified COR schedule presence
  /// 4. Active class period + configurable pre-class buffer
  static Map<String, dynamic> checkDutyStatus({
    DateTime? now,
    UserProfile? profile,
    int? preClassBufferMinutes,
    int? dailyDeliveryLimit,
    int? completedTodayCount,
  }) {
    final buffer = preClassBufferMinutes ?? activeConfig.preClassBufferMinutes;
    final dailyLimit = dailyDeliveryLimit ?? activeConfig.dailyDeliveryLimit;
    final completed = completedTodayCount ?? completedDeliveriesToday;

    if (profile != null) {
      if (profile.isRejected) {
        return {
          'isLocked': true,
          'code': 'account_rejected',
          'reason':
              'Your account verification was rejected. Runner access is disabled.',
        };
      }
      if (!profile.isStudent) {
        return {
          'isLocked': true,
          'code': 'not_student',
          'reason': 'Runner Mode is restricted to verified CIT-U student accounts.',
        };
      }
      if (!profile.isVerified) {
        return {
          'isLocked': true,
          'code': 'pending_admin_verification',
          'reason':
              'Your account is awaiting administrator verification before Runner Mode is enabled.',
        };
      }
      if (!profile.corVerified) {
        return {
          'isLocked': true,
          'code': 'unverified_cor',
          'reason':
              'Your COR study load has not been confirmed yet. Please upload your COR first.',
        };
      }
    }

    if (dailyLimit > 0 && completed >= dailyLimit) {
      return {
        'isLocked': true,
        'code': 'daily_limit_reached',
        'reason':
            'Daily delivery limit reached ($completed/$dailyLimit completed today). Resume tomorrow!',
      };
    }

    if (!isRunnerScheduleUploaded || verifiedSchedule.isEmpty) {
      return {
        'isLocked': true,
        'code': 'no_schedule',
        'reason':
            'No verified COR schedule uploaded. Please upload your study load to activate Runner Mode.',
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
          final bufferedStart = start - buffer;
          if (currentMinutes >= bufferedStart && currentMinutes <= end) {
            final inBufferOnly = currentMinutes < start;
            return {
              'isLocked': true,
              'code': inBufferOnly ? 'pre_class_buffer' : 'in_class',
              'reason': inBufferOnly
                  ? 'Pre-Class Buffer ($buffer min): ${session.subject} starts at ${session.startTime}.'
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
      'reason': 'Vacant period. Runner Mode is authorized ($completed/$dailyLimit today).',
    };
  }
}
