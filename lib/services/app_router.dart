import 'package:flutter/widgets.dart';
import '../admin_dashboard_screen.dart';
import '../customer_home_screen.dart';
import '../main_dashboard.dart';
import '../models/user_profile.dart';
import '../pending_verification_screen.dart';
import 'duty_lock_service.dart';
import 'supabase_service.dart';

class AppRouter {
  /// Determines the correct initial home screen based on the user's account type
  /// and verification status (SRS 3.1.1, 3.2.1, SDD 6.1, 6.3.4).
  static Future<Widget> resolveHomeForProfile([UserProfile? knownProfile]) async {
    await DutyLockService.syncFromSupabase();
    final profile = knownProfile ?? await SupabaseService().fetchUserProfileModel();

    if (profile == null) {
      return const MainDashboard();
    }
    if (profile.isAdmin) {
      return const AdminDashboardScreen();
    }
    if (!profile.isVerified) {
      return PendingVerificationScreen(initialProfile: profile);
    }
    if (profile.isFacultyOrStaff) {
      // Faculty/Staff go straight to Customer Mode with no Runner controls (SRS 3.2.1)
      return const CustomerHomeScreen();
    }
    return const MainDashboard();
  }
}
