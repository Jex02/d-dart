import 'package:flutter/material.dart';
import 'customer_home_screen.dart';
import 'runner_gig_board_screen.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  static const Color darkRed = Color(0xFF7F0000);

  String? selectedRole;

  Future<void> _proceed() async {
    if (selectedRole == null) return;

    if (selectedRole == 'Customer') {
      await SupabaseService().updateUserRole('customer');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
      );
      return;
    }

    await DutyLockService.syncFromSupabase();
    final profile = await SupabaseService().fetchUserProfileModel();
    final dutyStatus = DutyLockService.checkDutyStatus(profile: profile);
    if (!mounted) return;

    if (dutyStatus['isLocked'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            dutyStatus['reason']?.toString() ?? 'Runner Mode is currently locked.',
          ),
        ),
      );
      return;
    }

    await SupabaseService().updateUserRole('runner');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RunnerGigBoardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const Text(
                    'Order.Run.Deliver.',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'D-DART',
                    style: TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Peer-to-Peer Campus Delivery Application',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Choose Role',
                    style: TextStyle(
                      color: darkRed,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose a role to get started',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _RoleCard(
                    title: 'Customer',
                    description: 'Order food and request items to be delivered on campus.',
                    icon: Icons.shopping_bag_outlined,
                    selected: selectedRole == 'Customer',
                    onTap: () {
                      setState(() => selectedRole = 'Customer');
                    },
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    title: 'Runner',
                    description: 'Accept delivery requests and deliver items around campus.',
                    icon: Icons.directions_run,
                    selected: selectedRole == 'Runner',
                    onTap: () {
                      setState(() => selectedRole = 'Runner');
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: selectedRole == null ? null : _proceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkRed,
                        disabledBackgroundColor: darkRed.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        selectedRole == null ? 'Proceed' : 'Proceed as $selectedRole',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
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
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const Color darkRed = Color(0xFF7F0000);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? darkRed : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: darkRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: darkRed, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: darkRed,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? darkRed : Colors.grey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
