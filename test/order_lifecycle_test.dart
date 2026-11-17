import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/mock_data.dart';
import 'package:sd2/models/campus_location.dart';
import 'package:sd2/models/delivery_order.dart';
import 'package:sd2/models/problem_report.dart';
import 'package:sd2/models/user_profile.dart';

void main() {
  setUp(() {
    mockDeliveryRequests.clear();
  });

  test('DeliveryOrder computes total, cancellation, and expiration accurately', () {
    final baseTime = DateTime.utc(2026, 11, 10, 10, 0);
    final order = DeliveryOrder(
      id: 'ORD-500',
      pickupLocation: 'Main Canteen',
      dropoffLocation: 'ALLIED Building',
      description: '2x Siomai Rice',
      estimatedPrice: 85.0,
      deliveryFee: 20.0,
      status: 'pending',
      verificationCode: '4321',
      expiresAt: baseTime.add(const Duration(minutes: 30)),
    );

    expect(order.totalAmount, 105.0);
    expect(order.isExpiredAt(baseTime.add(const Duration(minutes: 10))), isFalse);
    expect(order.canCancelAt(baseTime.add(const Duration(minutes: 10))), isTrue);

    expect(order.isExpiredAt(baseTime.add(const Duration(minutes: 31))), isTrue);
    expect(order.canCancelAt(baseTime.add(const Duration(minutes: 31))), isFalse);
    expect(order.effectiveStatus(baseTime.add(const Duration(minutes: 31))), 'expired');
  });

  test('prevents duplicate claims and cancels only unclaimed requests', () {
    final created = addPabiliRequest(
      orderId: 'ORD-777',
      pickup: 'Main Canteen',
      dropoff: 'GLE Building',
      description: 'Bottled Water',
      price: 25.0,
    );
    expect(created['status'], 'pending');

    // First runner succeeds; second runner is blocked
    expect(claimMockOrder('ORD-777', runnerId: 'runner-1'), isTrue);
    expect(claimMockOrder('ORD-777', runnerId: 'runner-2'), isFalse);

    // Claimed order can no longer be cancelled
    expect(cancelMockOrder('ORD-777'), isFalse);
  });

  test('cancels pending order and blocks claiming cancelled or expired orders', () {
    addPabiliRequest(
      orderId: 'ORD-888',
      pickup: 'College Canteen',
      dropoff: 'Main Building',
      description: 'Iced Coffee',
      price: 55.0,
    );
    expect(cancelMockOrder('ORD-888'), isTrue);
    expect(claimMockOrder('ORD-888', runnerId: 'runner-1'), isFalse);

    addPabiliRequest(
      orderId: 'ORD-999',
      pickup: 'Campus Kiosks',
      dropoff: 'University Library',
      description: 'Notebook',
      price: 40.0,
      expiresIn: const Duration(minutes: 5),
    );
    final future = DateTime.now().toUtc().add(const Duration(minutes: 10));
    expect(expireStaleMockOrders(now: future), 1);
    expect(claimMockOrder('ORD-999', runnerId: 'runner-1', now: future), isFalse);
  });

  test('UserProfile, CampusLocation, and ProblemReport models parse roles and labels', () {
    final admin = UserProfile.fromJson({
      'id': 'a1',
      'full_name': 'Admin User',
      'email': 'admin@cit.edu',
      'role': 'admin',
      'account_type': 'admin',
      'verification_status': 'verified',
    });
    expect(admin.isAdmin, isTrue);
    expect(admin.isStudent, isFalse);
    expect(admin.isVerified, isTrue);

    final faculty = UserProfile.fromJson({
      'id': 'f1',
      'full_name': 'Prof. Reyes',
      'account_type': 'faculty_staff',
      'verification_status': 'verified',
    });
    expect(faculty.isFacultyOrStaff, isTrue);
    expect(faculty.accountTypeLabel, 'Faculty / Staff');

    final report = ProblemReport.fromJson({
      'id': 'r1',
      'category': 'wrong_item',
      'description': 'Missing extra chili oil',
      'status': 'open',
    });
    expect(report.categoryLabel, 'Wrong / Missing Item');

    expect(CampusLocation.defaultPickups.length, 3);
    expect(CampusLocation.defaultDropoffs.length, 11);
  });

  test('UserProfile correctly transitions when promoted to Co-Admin and demoted', () {
    final student = UserProfile.fromJson({
      'id': 'u-student-1',
      'full_name': 'Jerick Davidon',
      'email': 'jerick@cit.edu',
      'student_id': '23-1626-937',
      'account_type': 'student',
      'role': 'customer',
      'verification_status': 'verified',
    });
    expect(student.isStudent, isTrue);
    expect(student.isAdmin, isFalse);

    // Simulated payload returned after promoteUserToAdmin
    final promoted = UserProfile.fromJson({
      'id': student.id,
      'full_name': student.fullName,
      'email': student.email,
      'student_id': student.studentId,
      'account_type': 'admin',
      'role': 'admin',
      'verification_status': 'verified',
    });
    expect(promoted.isAdmin, isTrue);
    expect(promoted.accountTypeLabel, 'Administrator');

    // Simulated payload returned after demoteAdminToUser
    final demoted = UserProfile.fromJson({
      'id': student.id,
      'full_name': student.fullName,
      'email': student.email,
      'student_id': student.studentId,
      'account_type': 'student',
      'role': 'customer',
      'verification_status': 'verified',
    });
    expect(demoted.isAdmin, isFalse);
    expect(demoted.isStudent, isTrue);
  });
}
