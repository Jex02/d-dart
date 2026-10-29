import 'package:flutter/material.dart';
import 'signup.dart';
import 'main_dashboard.dart';

const Color panelColor = Color(0xFF8F1F0D);
const Color accentColor = Color(0xFFD4AF37);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),

            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),

              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),

                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 700;

                    return Stack(
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
                            color: Colors.white.withOpacity(0.62),
                          ),
                        ),

                        // ==================================================
                        // BRANDING
                        // ==================================================

                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 440,
                          child: _Branding(),
                        ),

                        // ==================================================
                        // LOGIN PANEL
                        // ==================================================

                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _LoginPanel(
                            compact: compact,
                            rememberMe: _rememberMe,
                            obscurePassword: _obscurePassword,

                            onRememberChanged: (value) {
                              setState(() {
                                _rememberMe = value;
                              });
                            },

                            onPasswordVisibilityChanged: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
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
// BRANDING
// ============================================================

class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          45,
          24,
          20,
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'D-DART',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 42,
                fontWeight: FontWeight.w500,
                letterSpacing: 3,
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

            const SizedBox(height: 20),

            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 19,
                  letterSpacing: 3,
                ),

                children: [
                  TextSpan(
                    text: 'Order.',
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  ),

                  TextSpan(
                    text: 'Run.',
                    style: TextStyle(
                      color: accentColor,
                    ),
                  ),

                  TextSpan(
                    text: 'Deliver.',
                    style: TextStyle(
                      color: panelColor,
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

// ============================================================
// LOGIN PANEL
// ============================================================

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.compact,
    required this.rememberMe,
    required this.obscurePassword,
    required this.onRememberChanged,
    required this.onPasswordVisibilityChanged,
  });

  final bool compact;
  final bool rememberMe;
  final bool obscurePassword;

  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onPasswordVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      // Full bottom panel.
      height: compact ? 400 : 440,

      padding: EdgeInsets.fromLTRB(
        34,
        compact ? 26 : 32,
        34,
        24,
      ),

      decoration: const BoxDecoration(
        color: panelColor,

        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 14,
            offset: Offset(0, -2),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================================================
          // WELCOME
          // ==================================================

          const Text(
            'Welcome !',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w400,
            ),
          ),

          SizedBox(
            height: compact ? 20 : 25,
          ),

          // ==================================================
          // EMAIL
          // ==================================================

          const _LoginTextField(
            hintText: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),

          SizedBox(
            height: compact ? 12 : 16,
          ),

          // ==================================================
          // PASSWORD
          // ==================================================

          _LoginTextField(
            hintText: 'Password',
            obscureText: obscurePassword,

            suffix: IconButton(
              onPressed: onPasswordVisibilityChanged,

              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,

                color: Colors.black45,
                size: 21,
              ),
            ),
          ),

          // ==================================================
          // REMEMBER / FORGOT PASSWORD
          // ==================================================

          const SizedBox(height: 8),

          Row(
            children: [
              SizedBox(
                width: 27,
                height: 27,

                child: Checkbox(
                  value: rememberMe,

                  shape: const CircleBorder(),

                  activeColor: Colors.white,

                  checkColor: panelColor,

                  side: const BorderSide(
                    color: Colors.white,
                    width: 1.5,
                  ),

                  onChanged: (value) {
                    onRememberChanged(
                      value ?? false,
                    );
                  },
                ),
              ),

              const SizedBox(width: 6),

              const Text(
                'Remember',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),

              const Spacer(),

              TextButton(
                onPressed: () {},

                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,

                  padding: EdgeInsets.zero,

                  minimumSize: const Size(
                    0,
                    30,
                  ),

                  tapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                ),

                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          // ==================================================
          // EXTRA SPACE BEFORE LOGIN
          // ==================================================

          SizedBox(
            height: compact ? 15 : 20,
          ),

          // ==================================================
          // LOGIN BUTTON
          // ==================================================

          Center(
            child: SizedBox(
              width: 115,
              height: 38,

              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          const MainDashboard(),
                    ),
                  );
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,

                  elevation: 0,

                  padding: EdgeInsets.zero,

                  shape: const StadiumBorder(),
                ),

                child: const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // ==================================================
          // PUSH SIGNUP SECTION TOWARD BOTTOM
          // ==================================================

          const Spacer(),

          const Divider(
            color: Colors.white54,
            height: 1,
          ),

          const SizedBox(height: 16),

          // ==================================================
          // SIGN UP
          // ==================================================

          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Text(
                  "Don't have account yet ?  ",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const SignupPage(),
                      ),
                    );
                  },

                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),

                    minimumSize: Size.zero,

                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),

                  child: const Text(
                    'Sign up',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOGIN TEXT FIELD
// ============================================================

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,

      child: TextField(
        keyboardType: keyboardType,

        obscureText: obscureText,

        style: const TextStyle(
          fontSize: 13,
        ),

        decoration: InputDecoration(
          hintText: hintText,

          hintStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
          ),

          filled: true,

          fillColor: Colors.white,

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),

          suffixIcon: suffix,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: accentColor,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}