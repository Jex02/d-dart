import 'package:flutter/material.dart';
import 'cor_upload_screen.dart';
import 'customer_home_screen.dart';
import 'login.dart';
import 'models/user_profile.dart';
import 'runner_gig_board_screen.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  static const Color darkRed = Color(0xFF8F1F0D);
  static const Color gold = Color(0xFFD4AF37);

  String? selectedRole;
  UserProfile? _profile;
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _syncAccountState();
  }

  Future<void> _syncAccountState() async {
    setState(() => _isSyncing = true);
    await DutyLockService.syncFromSupabase();
    final profile = await SupabaseService().fetchUserProfileModel();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isSyncing = false;
      });
    }
  }

  Future<void> _handleProceed() async {
    if (selectedRole == null) return;
    if (_isSyncing) {
      await _syncAccountState();
    }

    if (!mounted) return;

    if (selectedRole == 'Customer') {
      await SupabaseService().updateUserRole('customer');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
      );
      return;
    }

    // Runner Mode eligibility + Academic Duty Lock checks (WBS 2.5, 4.3, 4.6)
    final dutyStatus = DutyLockService.checkDutyStatus(profile: _profile);
    if (dutyStatus['isLocked'] == true) {
      final code = dutyStatus['code']?.toString() ?? '';
      final isNotStudent = code == 'not_student' || code == 'account_rejected';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isNotStudent ? Icons.block : Icons.lock_clock,
                color: darkRed,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isNotStudent ? 'Runner Access Restricted' : 'Academic Duty Lock',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dutyStatus['reason']?.toString() ?? 'Runner Mode is currently unavailable.',
                style: const TextStyle(color: darkRed, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                isNotStudent
                    ? 'Faculty, Staff, and Administrator accounts can use Customer Mode to place Pabili requests, while Runner Mode is exclusive to verified students.'
                    : 'D-DART enforces Duty Lock during class periods (including a 15-minute pre-class buffer) and requires a verified COR study load.',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            if (!isNotStudent)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CorUploadScreen()),
                  );
                  _syncAccountState();
                },
                child: const Text('Update Study Load', style: TextStyle(color: darkRed)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await SupabaseService().updateUserRole('runner');
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RunnerGigBoardScreen()),
    );
  }

  Future<void> _handleSignOut() async {
    await SupabaseService().signOut();
    DutyLockService.reset();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth > 600;
    final runnerRestrictedForRole =
        _profile != null && (_profile!.isFacultyOrStaff || _profile!.isAdmin);

    Widget content = Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/lrac.jpg', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(color: Colors.white.withOpacity(0.84)),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Order.Run.Deliver.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sign out',
                          onPressed: _handleSignOut,
                          icon: const Icon(Icons.logout, color: darkRed, size: 20),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.black26,
                    ),
                    const SizedBox(height: 18),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                        children: [
                          TextSpan(text: 'D', style: TextStyle(color: gold)),
                          TextSpan(text: '-DART', style: TextStyle(color: darkRed)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Peer-to-Peer Campus Delivery Application',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_profile != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _profile!.isVerified
                              ? Colors.green.withOpacity(0.12)
                              : Colors.orange.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _profile!.isVerified ? Colors.green : Colors.orange,
                          ),
                        ),
                        child: Text(
                          '${_profile!.fullName.isEmpty ? _profile!.email : _profile!.fullName}  •  ${_profile!.accountTypeLabel} (${_profile!.verificationLabel})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _profile!.isVerified ? Colors.green.shade800 : Colors.orange.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (_profile != null && _profile!.isAdmin) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Text(
                          'Administrator account detected. Admin review & monitoring tools are scheduled in Week 7 (WBS 7).',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ),
                    ],

                    const Text(
                      'Choose Mode',
                      style: TextStyle(
                        color: darkRed,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select how you want to use D-DART right now',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    _RoleCard(
                      title: 'Customer',
                      description: 'Order food and request Pabili deliveries on campus.',
                      icon: Icons.shopping_bag_outlined,
                      selected: selectedRole == 'Customer',
                      onTap: () => setState(() => selectedRole = 'Customer'),
                    ),
                    const SizedBox(height: 14),

                    _RoleCard(
                      title: 'Runner',
                      description: runnerRestrictedForRole
                          ? 'Restricted to verified CIT-U student accounts.'
                          : 'Accept delivery requests during your vacant periods.',
                      icon: Icons.directions_run,
                      selected: selectedRole == 'Runner',
                      badgeText: runnerRestrictedForRole ? 'Students Only' : null,
                      onTap: () => setState(() => selectedRole = 'Runner'),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: 160,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: selectedRole == null || _isSyncing ? null : _handleProceed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkRed,
                          disabledBackgroundColor: darkRed.withOpacity(0.35),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: const StadiumBorder(),
                        ),
                        child: _isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Proceed',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),

                    if (!runnerRestrictedForRole) ...[
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CorUploadScreen()),
                          );
                          _syncAccountState();
                        },
                        icon: const Icon(Icons.school_outlined, size: 16, color: darkRed),
                        label: const Text(
                          'Manage / Update Study Load',
                          style: TextStyle(
                            fontSize: 12,
                            color: darkRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isDesktopOrTablet ? const Color(0xFF2B2B2B) : Colors.white,
      body: isDesktopOrTablet
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450, maxHeight: 900),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: content,
                ),
              ),
            )
          : content,
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badgeText,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badgeText;

  static const Color darkRed = Color(0xFF8F1F0D);
  static const Color gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? gold : darkRed.withOpacity(0.6),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? gold.withOpacity(0.2) : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: darkRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: darkRed, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: selected ? darkRed : Colors.black87,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText!,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? gold : Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
