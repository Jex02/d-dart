import 'package:flutter/material.dart';
import 'login.dart';

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth > 600;

    Widget content = Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            'assets/lrac.jpg',
            fit: BoxFit.cover,
          ),
        ),

        // Light overlay matching Figma
        Positioned.fill(
          child: Container(
            color: Colors.white.withValues(alpha: 0.58),
          ),
        ),

        // Auto Layout Column: Branding at top/middle, Action panel at bottom
        SafeArea(
          child: Column(
            children: [
              // Top & Center Branding (expands to fill available space)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'D-DART',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Peer-to-Peer Campus Delivery Application',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 32),
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 28,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(text: 'Order.\n', style: TextStyle(color: Colors.black87)),
                              TextSpan(text: 'Run.\n', style: TextStyle(color: Color(0xFFD4AF37))),
                              TextSpan(text: 'Deliver.', style: TextStyle(color: Color(0xFF8F1F0D))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Get Started Bottom Panel
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF8F1F0D),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white70,
                            size: 48,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'GET STARTED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isDesktopOrTablet ? const Color(0xFF2B2B2B) : const Color(0xFF8F1F0D),
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
