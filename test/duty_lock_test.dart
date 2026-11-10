import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/models/class_schedule.dart';
import 'package:sd2/models/system_config.dart';
import 'package:sd2/models/user_profile.dart';
import 'package:sd2/services/duty_lock_service.dart';

void main() {
  const verifiedStudent = UserProfile(
    id: 'u1',
    fullName: 'Juan Dela Cruz',
    studentId: '23-1626-937',
    accountType: 'student',
    verificationStatus: 'verified',
    corVerified: true,
  );

  const facultyAccount = UserProfile(
    id: 'u2',
    fullName: 'Prof. Santos',
    studentId: 'EMP-1024',
    accountType: 'faculty_staff',
    verificationStatus: 'verified',
    corVerified: false,
  );

  const unverifiedStudent = UserProfile(
    id: 'u3',
    fullName: 'Pending Student',
    studentId: '23-1111-222',
    accountType: 'student',
    verificationStatus: 'pending',
    corVerified: false,
  );

  tearDown(DutyLockService.reset);

  test('blocks non-student, pending-admin, and empty-schedule accounts', () {
    DutyLockService.verifiedSchedule = [
      ClassSession(day: 'Monday', startTime: '09:00', endTime: '11:00', subject: 'CS 321'),
    ];
    DutyLockService.isRunnerScheduleUploaded = true;

    final facultyCheck = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 14, 0),
      profile: facultyAccount,
    );
    expect(facultyCheck['isLocked'], isTrue);
    expect(facultyCheck['code'], 'not_student');

    final pendingCheck = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 14, 0),
      profile: unverifiedStudent,
    );
    expect(pendingCheck['isLocked'], isTrue);
    expect(pendingCheck['code'], 'pending_admin_verification');

    DutyLockService.reset();
    final noScheduleCheck = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 14, 0),
      profile: verifiedStudent,
    );
    expect(noScheduleCheck['isLocked'], isTrue);
    expect(noScheduleCheck['code'], 'no_schedule');
  });

  test('enforces active class and configurable pre-class buffer', () {
    DutyLockService.verifiedSchedule = [
      ClassSession(day: 'Tuesday', startTime: '09:00', endTime: '11:00', subject: 'CS 321'),
    ];
    DutyLockService.isRunnerScheduleUploaded = true;

    // Default 15-min buffer: 08:44 -> authorized; 08:45 -> locked
    expect(
      DutyLockService.checkDutyStatus(
        now: DateTime(2026, 11, 10, 8, 44),
        profile: verifiedStudent,
      )['isLocked'],
      isFalse,
    );

    final insideDefaultBuffer = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 8, 45),
      profile: verifiedStudent,
    );
    expect(insideDefaultBuffer['isLocked'], isTrue);
    expect(insideDefaultBuffer['code'], 'pre_class_buffer');

    // Configurable 30-min buffer: 08:30 -> locked
    final insideCustomBuffer = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 8, 30),
      profile: verifiedStudent,
      preClassBufferMinutes: 30,
    );
    expect(insideCustomBuffer['isLocked'], isTrue);
    expect(insideCustomBuffer['code'], 'pre_class_buffer');

    // In class at 09:30 -> locked
    final inClass = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 9, 30),
      profile: verifiedStudent,
    );
    expect(inClass['isLocked'], isTrue);
    expect(inClass['code'], 'in_class');
  });

  test('enforces configurable daily delivery limit and parses SystemConfig', () {
    DutyLockService.verifiedSchedule = [
      ClassSession(day: 'Monday', startTime: '09:00', endTime: '11:00', subject: 'CS 321'),
    ];
    DutyLockService.isRunnerScheduleUploaded = true;

    final config = SystemConfig.fromConfigRows([
      {'config_key': 'pre_class_buffer_minutes', 'config_value': '20'},
      {'config_key': 'daily_delivery_limit', 'config_value': '3'},
      {'config_key': 'request_expiration_minutes', 'config_value': '45'},
      {'config_key': 'standard_delivery_fee', 'config_value': '25.00'},
    ]);

    expect(config.preClassBufferMinutes, 20);
    expect(config.dailyDeliveryLimit, 3);
    expect(config.requestExpirationMinutes, 45);
    expect(config.standardDeliveryFee, 25.0);

    final underCap = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 14, 0),
      profile: verifiedStudent,
      dailyDeliveryLimit: config.dailyDeliveryLimit,
      completedTodayCount: 2,
    );
    expect(underCap['isLocked'], isFalse);

    final atCap = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 14, 0),
      profile: verifiedStudent,
      dailyDeliveryLimit: config.dailyDeliveryLimit,
      completedTodayCount: 3,
    );
    expect(atCap['isLocked'], isTrue);
    expect(atCap['code'], 'daily_limit_reached');
  });
}
