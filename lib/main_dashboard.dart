import 'package:flutter/material.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  static const Color darkRed = Color(0xFF7F0000);

  String? selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    // Branding
                    const Text(
                      'Order.Run.Deliver.',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Main title
                    const Text(
                      'D-DART',
                      style: TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Peer-to-Peer Campus Delivery Application',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Choose role title
                    const Text(
                      'Choose Role',
                      style: TextStyle(
                        color: darkRed,
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Choose a role to get started',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Customer
                    _RoleCard(
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

                    const SizedBox(height: 18),

                    // Runner
                    _RoleCard(
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

                    const SizedBox(height: 35),

                    // Proceed button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: selectedRole == null
                            ? null
                            : () {
                                // TODO:
                                // Navigate to the appropriate dashboard
                                // after the Customer/Runner pages are created.
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkRed,
                          disabledBackgroundColor:
                              darkRed.withOpacity(0.35),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          selectedRole == null
                              ? 'Proceed'
                              : 'Proceed as $selectedRole',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
      ),
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

  static const Color darkRed = Color(0xFF7F0000);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? darkRed : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 90,
                height: 75,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: darkRed,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? darkRed : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}