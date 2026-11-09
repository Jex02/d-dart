import 'package:flutter/material.dart';
import 'customer_home_screen.dart';
import 'runner_gig_board_screen.dart';
import 'cor_upload_screen.dart';
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

  @override
  void initState() {
    super.initState();
    DutyLockService.syncFromSupabase();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth > 600;

    Widget content = Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            'assets/lrac.jpg',
            fit: BoxFit.cover,
          ),
        ),

        // Light Overlay
        Positioned.fill(
          child: Container(
            color: Colors.white.withOpacity(0.82),
          ),
        ),

        // Responsive Scrollable Auto-Layout
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Tagline
                    const Text(
                      'Order.Run.Deliver.',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Divider
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.black26,
                    ),
                    const SizedBox(height: 24),

                    // D-Dart Branding
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
                    const SizedBox(height: 8),

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
                    const SizedBox(height: 32),

                    // Section Heading
                    const Text(
                      'Choose Role',
                      style: TextStyle(
                        color: darkRed,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),

                    const Text(
                      'Choose a role to get started',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // CUSTOMER CARD
                    _RoleCard(
                      title: 'Customer',
                      description: 'Order food and request items to be delivered on campus.',
                      imageUrl:
                          'https://figma-alpha-api.s3.us-west-2.amazonaws.com/images/22e77230-b5a4-4f13-9fc8-a98eee5e2fe8',
                      selected: selectedRole == 'Customer',
                      onTap: () {
                        setState(() => selectedRole = 'Customer');
                      },
                    ),
                    const SizedBox(height: 16),

                    // RUNNER CARD
                    _RoleCard(
                      title: 'Runner',
                      description: 'Accept delivery requests and deliver items around campus.',
                      imageUrl:
                          'https://figma-alpha-api.s3.us-west-2.amazonaws.com/images/2bbae86b-b7ef-4e3c-b824-e73d461e5159',
                      selected: selectedRole == 'Runner',
                      onTap: () {
                        setState(() => selectedRole = 'Runner');
                      },
                    ),
                    const SizedBox(height: 28),

                    // PROCEED BUTTON
                    SizedBox(
                      width: 140,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: selectedRole == null
                            ? null
                            : () {
                                SupabaseService().updateUserRole(selectedRole!.toLowerCase());
                                if (selectedRole == 'Customer') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
                                  );
                                } else if (selectedRole == 'Runner') {
                                  final status = DutyLockService.checkDutyStatus();
                                  if (status['isLocked'] == true) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Row(
                                          children: [
                                            Icon(Icons.lock_clock, color: darkRed),
                                            SizedBox(width: 8),
                                            Text(
                                              'Academic Duty Lock',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Runner Mode is locked due to an active class session:',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              status['reason'] ?? '',
                                              style: const TextStyle(color: darkRed),
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'D-DART enforces Duty Lock to ensure academic priorities come first. Please fulfill your class duties before accepting deliveries.',
                                              style: TextStyle(fontSize: 12, color: Colors.black87),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => const CorUploadScreen(),
                                                ),
                                              );
                                            },
                                            child: const Text('Update Study Load', style: TextStyle(color: darkRed)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RunnerGigBoardScreen(),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkRed,
                          disabledBackgroundColor: darkRed.withOpacity(0.35),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Proceed',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Update Study Load Button
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CorUploadScreen()),
                        );
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
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  static const Color darkRed = Color(0xFF8F1F0D);
  static const Color gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 52,
                height: 52,
                color: Colors.grey.shade100,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    title == 'Customer' ? Icons.shopping_bag_outlined : Icons.directions_run,
                    color: darkRed,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selected ? darkRed : Colors.black87,
                    ),
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
