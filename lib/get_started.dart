import 'package:flutter/material.dart';
import 'login.dart';

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 30,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Stack(
                children: [
                // Background image
                Positioned.fill(
                  child: Image.asset(
                    'assets/lrac.jpg',
                    fit: BoxFit.cover,
                  ),
                ),

                // Light overlay to match the Figma
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withOpacity(0.58),
                  ),
                ),

                // Get Started panel
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 180,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF8F1F0D),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
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
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_up,
                                color: Colors.white70,
                                size: 65,
                              ),

                              SizedBox(height: 2),

                              Text(
                                'GET STARTED',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 21,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // D-Dart branding
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 180,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'D-DART',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 3,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 10),

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

                          const SizedBox(height: 35),

                          RichText(
                            textAlign: TextAlign.left,
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 28,
                                letterSpacing: 4,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Order.\n',
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Run.\n',
                                  style: TextStyle(
                                    color: Color(0xFFD4AF37),
                                  ),
                                ),
                                TextSpan(
                                  text: 'Deliver.',
                                  style: TextStyle(
                                    color: Color(0xFF8F1F0D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}