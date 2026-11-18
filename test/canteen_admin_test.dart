import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/admin_dashboard_screen.dart';
import 'package:sd2/canteen_menu_manager_screen.dart';
import 'package:sd2/models/user_profile.dart';
import 'package:sd2/services/app_router.dart';

void main() {
  group('Tiered Admin & Canteen Admin Roles', () {
    test('UserProfile distinguishes Super Admin vs Canteen Admin', () {
      final superAdmin = UserProfile.fromJson({
        'id': 'admin-1',
        'full_name': 'D-DART Admin',
        'email': 'admin@cit.edu',
        'role': 'admin',
        'account_type': 'admin',
        'verification_status': 'verified',
        'assigned_canteen': null,
      });

      final canteenAdmin = UserProfile.fromJson({
        'id': 'canteen-1',
        'full_name': 'Main Canteen Manager',
        'email': 'maincanteen@cit.edu',
        'role': 'admin',
        'account_type': 'admin',
        'verification_status': 'verified',
        'assigned_canteen': 'Main Canteen',
      });

      expect(superAdmin.isAdmin, isTrue);
      expect(superAdmin.isSuperAdmin, isTrue);
      expect(superAdmin.isCanteenAdmin, isFalse);
      expect(superAdmin.accountTypeLabel, 'Super Admin');

      expect(canteenAdmin.isAdmin, isTrue);
      expect(canteenAdmin.isCanteenAdmin, isTrue);
      expect(canteenAdmin.isSuperAdmin, isFalse);
      expect(canteenAdmin.assignedCanteen, 'Main Canteen');
      expect(canteenAdmin.accountTypeLabel, 'Canteen Admin (Main Canteen)');
    });

    test('AppRouter routes Super Admin and Canteen Admin to their respective consoles',
        () async {
      const superAdmin = UserProfile(
        id: 'admin-1',
        fullName: 'Super Admin',
        role: 'admin',
        accountType: 'admin',
        verificationStatus: 'verified',
      );
      const highschoolAdmin = UserProfile(
        id: 'canteen-hs',
        fullName: 'HS Canteen Manager',
        role: 'admin',
        accountType: 'admin',
        verificationStatus: 'verified',
        assignedCanteen: 'Highschool Canteen',
      );

      final superHome = await AppRouter.resolveHomeForProfile(superAdmin);
      final hsHome = await AppRouter.resolveHomeForProfile(highschoolAdmin);

      expect(superHome, isA<AdminDashboardScreen>());
      expect(hsHome, isA<CanteenMenuManagerScreen>());
      expect((hsHome as CanteenMenuManagerScreen).assignedCanteen, 'Highschool Canteen');
    });

    testWidgets('CanteenMenuManagerScreen locks scope to assigned canteen',
        (WidgetTester tester) async {
      const hsAdmin = UserProfile(
        id: 'canteen-hs',
        fullName: 'HS Manager',
        role: 'admin',
        accountType: 'admin',
        verificationStatus: 'verified',
        assignedCanteen: 'Highschool Canteen',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CanteenMenuManagerScreen(
            assignedCanteen: 'Highschool Canteen',
            profile: hsAdmin,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Highschool Canteen Manager'), findsOneWidget);
      expect(find.textContaining('Scoped to Highschool Canteen'), findsOneWidget);
      // Canteen Admin must NOT see the All Canteens selector chip
      expect(find.text('All Canteens'), findsNothing);

      // Opening Add Item locks the canteen field to Highschool Canteen
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();

      expect(find.text('Add Food Item'), findsOneWidget);
      expect(find.text('Assigned Canteen: Highschool Canteen'), findsOneWidget);
    });
  });
}
