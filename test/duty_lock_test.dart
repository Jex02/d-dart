import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/models/class_schedule.dart';
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

  test('blocks non-student, unverified, and empty-schedule accounts', () {
    DutyLockService.verifiedSchedule = [
      ClassSession(day: 'Monday', startTime: '09:00', endTime: '11:00', subject: 'CS 321'),
    ];
    DutyLockService.isRunnerScheduleUploaded = true;

    final facultyCheck = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 14, 0), // Tuesday
      profile: facultyAccount,
    );
    expect(facultyCheck['isLocked'], isTrue);
    expect(facultyCheck['code'], 'not_student');

    final pendingCheck = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 14, 0),
      profile: unverifiedStudent,
    );
    expect(pendingCheck['isLocked'], isTrue);
    expect(pendingCheck['code'], 'unverified_cor');

    DutyLockService.reset();
    final noScheduleCheck = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 14, 0),
      profile: verifiedStudent,
    );
    expect(noScheduleCheck['isLocked'], isTrue);
    expect(noScheduleCheck['code'], 'no_schedule');
  });

  test('enforces active class and 15-minute pre-class buffer', () {
    DutyLockService.verifiedSchedule = [
      ClassSession(day: 'Tuesday', startTime: '09:00', endTime: '11:00', subject: 'CS 321'),
    ];
    DutyLockService.isRunnerScheduleUploaded = true;

    // 08:44 on Tuesday (16 min before class) -> authorized
    final beforeBuffer = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 8, 44),
      profile: verifiedStudent,
    );
    expect(beforeBuffer['isLocked'], isFalse);
    expect(beforeBuffer['code'], 'authorized');

    // 08:45 on Tuesday (15 min before class) -> locked by pre-class buffer
    final insideBuffer = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 8, 45),
      profile: verifiedStudent,
    );
    expect(insideBuffer['isLocked'], isTrue);
    expect(insideBuffer['code'], 'pre_class_buffer');

    // 09:30 on Tuesday (during class) -> locked by active class
    final inClass = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 9, 30),
      profile: verifiedStudent,
    );
    expect(inClass['isLocked'], isTrue);
    expect(inClass['code'], 'in_class');

    // 11:01 on Tuesday (after class) -> authorized
    final afterClass = DutyLockService.checkDutyStatus(
      now: DateTime(2026, 11, 10, 11, 1),
      profile: verifiedStudent,
    );
    expect(afterClass['isLocked'], isFalse);
  });
}
