import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService().signIn(email: email, password: password);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainDashboard()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
            color: Colors.white.withOpacity(0.62),
          ),
        ),

        // Responsive Scrollable Auto-Layout
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Branding (Flexes with space)
                        const Expanded(
                          child: Center(
                            child: _Branding(),
                          ),
                        ),

                        // Login Panel at Bottom
                        _LoginPanel(
                          rememberMe: _rememberMe,
                          obscurePassword: _obscurePassword,
                          isLoading: _isLoading,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          onLogin: _handleLogin,
                          onRememberChanged: (value) {
                            setState(() => _rememberMe = value);
                          },
                          onPasswordVisibilityChanged: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isDesktopOrTablet ? const Color(0xFF2B2B2B) : panelColor,
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

class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'D-DART',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'CIT-U WILDCATS ERRAND & DELIVERY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 18),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w600),
              children: [
                TextSpan(text: 'Order.', style: TextStyle(color: Colors.black87)),
                TextSpan(text: 'Run.', style: TextStyle(color: accentColor)),
                TextSpan(text: 'Deliver.', style: TextStyle(color: panelColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.rememberMe,
    required this.obscurePassword,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onRememberChanged,
    required this.onPasswordVisibilityChanged,
  });

  final bool rememberMe;
  final bool obscurePassword;
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onPasswordVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
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
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Welcome !',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          _LoginTextField(
            controller: emailController,
            hintText: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          _LoginTextField(
            controller: passwordController,
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

          const SizedBox(height: 10),

          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: rememberMe,
                  shape: const CircleBorder(),
                  activeColor: Colors.white,
                  checkColor: panelColor,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  onChanged: (value) => onRememberChanged(value ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Remember',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Forgot Password?', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Center(
            child: SizedBox(
              width: 140,
              height: 42,
              child: ElevatedButton(
                onPressed: isLoading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: const StadiumBorder(),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          const Divider(color: Colors.white38, height: 1),
          const SizedBox(height: 16),

          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Don't have account yet ?  ",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupPage()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Sign up',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController? controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black54, fontSize: 12),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accentColor, width: 2),
          ),
        ),
      ),
    );
  }
}
