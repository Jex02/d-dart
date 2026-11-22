import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/models/user_profile.dart';
import 'package:sd2/services/duty_lock_service.dart';

void main() {
  group('Dedicated Demonstration Runner Account & Eligibility Tests', () {
    test('runner@gmail.com profile grants isDemoRunner and canUseRunnerMode without COR', () {
      final demoProfile = UserProfile(
        id: 'd8d46232-4eaa-4c44-8508-46207f0ea9d5',
        fullName: 'Demo Runner',
        email: 'runner@gmail.com',
        role: 'runner',
        accountType: 'student',
        verificationStatus: 'verified',
        corVerified: false,
      );

      expect(demoProfile.isDemoRunner, isTrue);
      expect(demoProfile.corVerified, isFalse);
      expect(demoProfile.canUseRunnerMode, isTrue);
    });

    test('Ordinary student without verified COR cannot access Runner Mode', () {
      final studentProfile = UserProfile(
        id: 'student-uuid-1',
        fullName: 'Juan Dela Cruz',
        email: 'juan@cit.edu',
        role: 'customer',
        accountType: 'student',
        verificationStatus: 'verified',
        corVerified: false,
      );

      expect(studentProfile.isDemoRunner, isFalse);
      expect(studentProfile.corVerified, isFalse);
      expect(studentProfile.canUseRunnerMode, isFalse);
    });

    test('DutyLockService authorizes runner@gmail.com for presentation demo without COR schedule', () {
      final demoProfile = UserProfile(
        id: 'd8d46232-4eaa-4c44-8508-46207f0ea9d5',
        fullName: 'Demo Runner',
        email: 'runner@gmail.com',
        role: 'runner',
        accountType: 'student',
        verificationStatus: 'verified',
        corVerified: false,
      );

      final status = DutyLockService.checkDutyStatus(
        profile: demoProfile,
        dailyDeliveryLimit: 5,
        completedTodayCount: 0,
      );

      expect(status['isLocked'], isFalse);
      expect(status['code'], 'authorized');
      expect(status['reason'], contains('Demonstration Runner Mode authorized'));
    });

    test('DutyLockService still enforces daily delivery limit for runner@gmail.com', () {
      final demoProfile = UserProfile(
        id: 'd8d46232-4eaa-4c44-8508-46207f0ea9d5',
        fullName: 'Demo Runner',
        email: 'runner@gmail.com',
        role: 'runner',
        accountType: 'student',
        verificationStatus: 'verified',
        corVerified: false,
      );

      final status = DutyLockService.checkDutyStatus(
        profile: demoProfile,
        dailyDeliveryLimit: 5,
        completedTodayCount: 5,
      );

      expect(status['isLocked'], isTrue);
      expect(status['code'], 'daily_limit_reached');
    });

    test('DutyLockService still locks unverified COR for ordinary students', () {
      final studentProfile = UserProfile(
        id: 'student-uuid-2',
        fullName: 'Maria Santos',
        email: 'maria@cit.edu',
        role: 'runner',
        accountType: 'student',
        verificationStatus: 'verified',
        corVerified: false,
      );

      final status = DutyLockService.checkDutyStatus(
        profile: studentProfile,
        dailyDeliveryLimit: 5,
        completedTodayCount: 0,
      );

      expect(status['isLocked'], isTrue);
      expect(status['code'], 'unverified_cor');
    });
  });
}
