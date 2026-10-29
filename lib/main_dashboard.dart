import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      // Dark area surrounding the mobile-style application.
      backgroundColor: const Color(0xFF2B2B2B),

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),

            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
                maxHeight: 720,
              ),

              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),

                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),

                  child: Stack(
                    children: [
                      // ==================================================
                      // LRAC BACKGROUND
                      // ==================================================

                      Positioned.fill(
                        child: Image.asset(
                          'assets/lrac.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),

                      // ==================================================
                      // LIGHT OVERLAY
                      // ==================================================

                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withOpacity(0.78),
                        ),
                      ),

                      // ==================================================
                      // MAIN CONTENT
                      // ==================================================

                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 8,
                          ),

                          child: Column(
                            children: [
                              // ==================================================
                              // TOP TAGLINE
                              // ==================================================

                              const Text(
                                'Order.Run.Deliver.',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  letterSpacing: 2.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // ==================================================
                              // DIVIDER
                              // ==================================================

                              Container(
                                width: double.infinity,
                                height: 1,
                                color: Colors.black54,
                              ),

                              const SizedBox(height: 22),

                              // ==================================================
                              // D-DART
                              // ==================================================

                              RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 31,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),

                                  children: [
                                    TextSpan(
                                      text: 'D',
                                      style: TextStyle(
                                        color: gold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '-DART',
                                      style: TextStyle(
                                        color: Color(0xFF202020),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 3),

                              // ==================================================
                              // SUBTITLE
                              // ==================================================

                              const Text(
                                'Peer-to-Peer Campus Delivery Application',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.25,
                                ),
                              ),

                              const SizedBox(height: 22),

                              // ==================================================
                              // CHOOSE ROLE
                              // ==================================================

                              const Text(
                                'Choose Role',
                                style: TextStyle(
                                  color: darkRed,
                                  fontFamily: 'serif',
                                  fontSize: 27,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              const SizedBox(height: 5),

                              const Text(
                                'Choose role to get started',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 7,
                                ),
                              ),

                              const SizedBox(height: 25),

                              // ==================================================
                              // CUSTOMER CARD
                              // ==================================================

                              Center(
                                child: SizedBox(
                                  width: 365,

                                  child: _RoleCard(
                                    title: 'Customer',
                                    description:
                                        'Order food and request items to be delivered on campus.',
                                    imageUrl:
                                        'https://figma-alpha-api.s3.us-west-2.amazonaws.com/images/22e77230-b5a4-4f13-9fc8-a98eee5e2fe8',
                                    selected: selectedRole == 'Customer',
                                    onTap: () {
                                      setState(() {
                                        selectedRole = 'Customer';
                                      });
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 13),

                              // ==================================================
                              // RUNNER CARD
                              // ==================================================

                              Center(
                                child: SizedBox(
                                  width: 365,

                                  child: _RoleCard(
                                    title: 'Runner',
                                    description:
                                        'Accept delivery requests and deliver items around campus.',
                                    imageUrl:
                                        'https://figma-alpha-api.s3.us-west-2.amazonaws.com/images/2bbae86b-b7ef-4e3c-b824-e73d461e5159',
                                    selected: selectedRole == 'Runner',
                                    onTap: () {
                                      setState(() {
                                        selectedRole = 'Runner';
                                      });
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 55),

                              // ==================================================
                              // PROCEED BUTTON
                              // ==================================================

                              Center(
                                child: SizedBox(
                                  width: 120,
                                  height: 30,

                                  child: ElevatedButton(
                                    onPressed: selectedRole == null
                                        ? null
                                        : () {
                                            // TODO:
                                            // Navigate to the selected
                                            // Customer or Runner dashboard.
                                          },

                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: darkRed,

                                      disabledBackgroundColor:
                                          darkRed.withOpacity(0.35),

                                      foregroundColor: Colors.white,

                                      disabledForegroundColor:
                                          Colors.white,

                                      elevation: 0,

                                      padding: EdgeInsets.zero,

                                      shape: const StadiumBorder(),
                                    ),

                                    child: const Text(
                                      'Proceed',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ROLE CARD
// ============================================================

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
        height: 68,

        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),

        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),

          borderRadius: BorderRadius.circular(6),

          border: Border.all(
            color: selected ? gold : darkRed,
            width: selected ? 2 : 1,
          ),
        ),

        child: Row(
          children: [
            // ==================================================
            // ROLE IMAGE
            // ==================================================

            SizedBox(
              width: 70,
              height: 62,

              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,

                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey,
                    size: 30,
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            // ==================================================
            // ROLE INFORMATION
            // ==================================================

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style: const TextStyle(
                      color: darkRed,
                      fontFamily: 'serif',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 1),

                  Text(
                    description,

                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 6.5,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
