import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';

const _signupPanelColor = Color(0xFF8F1F0D);

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final studentId = _studentIdController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || studentId.isEmpty || password.isEmpty) {
      _showSnackbar('Please fill in all fields.', Colors.redAccent);
      return;
    }

    if (password != confirmPassword) {
      _showSnackbar('Passwords do not match.', Colors.redAccent);
      return;
    }

    if (password.length < 6) {
      _showSnackbar('Password must be at least 6 characters.', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService().signUp(
        email: email,
        password: password,
        fullName: name,
        phoneNumber: phone,
        studentId: studentId,
      );

      if (mounted) {
        final needsConfirmation = response.session == null;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Account Created'),
            content: Text(
              needsConfirmation
                  ? 'Your account was created! If "Confirm Email" is active in Supabase, please verify the confirmation link sent to $email before logging in (or disable "Confirm email" in Supabase Authentication settings for instant login).'
                  : 'Your CIT-U D-Dart account has been created successfully! You can now log in.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _returnToLogin();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on AuthException catch (e) {
      _showSnackbar(e.message, Colors.redAccent);
    } catch (e) {
      _showSnackbar('Signup failed: ${e.toString()}', Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _returnToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth > 600;

    Widget content = SafeArea(
      child: Column(
        children: [
          const _SignupHeader(),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _signupPanelColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(painter: _SignupTexturePainter()),
                    ),
                    SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SignupFields(
                            nameController: _nameController,
                            emailController: _emailController,
                            phoneController: _phoneController,
                            studentIdController: _studentIdController,
                            passwordController: _passwordController,
                            confirmPasswordController: _confirmPasswordController,
                          ),
                          const SizedBox(height: 24),
                          _SignupButton(
                            isLoading: _isLoading,
                            onPressed: _handleSignUp,
                          ),
                          const SizedBox(height: 20),
                          _LoginFooter(onTap: _returnToLogin),
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
    );

    return Scaffold(
      backgroundColor: isDesktopOrTablet ? const Color(0xFF252525) : Colors.white,
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

class _SignupHeader extends StatelessWidget {
  const _SignupHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      color: Colors.white,
      alignment: Alignment.center,
      child: RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w500),
          children: [
            TextSpan(text: 'Order.', style: TextStyle(color: Colors.black87)),
            TextSpan(text: 'Run.', style: TextStyle(color: Color(0xFFD4AF37))),
            TextSpan(text: 'Deliver.', style: TextStyle(color: Color(0xFF8F1F0D))),
          ],
        ),
      ),
    );
  }
}

class _SignupFields extends StatelessWidget {
  const _SignupFields({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.studentIdController,
    required this.passwordController,
    required this.confirmPasswordController,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController studentIdController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create an Account',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign up and start ordering, request errands and\nget things delivered in campus',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            height: 1.3,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 18),
        _SignupTextField(
          controller: nameController,
          hintText: 'Full Name',
        ),
        const SizedBox(height: gap),
        _SignupTextField(
          controller: emailController,
          hintText: 'Email Address',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: gap),
        _SignupTextField(
          controller: phoneController,
          hintText: 'Phone Number',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: gap),
        _SignupTextField(
          controller: studentIdController,
          hintText: 'Student Id / Teacher Id',
        ),
        const SizedBox(height: gap),
        _SignupTextField(
          controller: passwordController,
          hintText: 'Password',
          obscureText: true,
        ),
        const SizedBox(height: gap),
        _SignupTextField(
          controller: confirmPasswordController,
          hintText: 'Confirm Password',
          obscureText: true,
        ),
      ],
    );
  }
}

class _SignupTextField extends StatelessWidget {
  const _SignupTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black87, fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Colors.black45,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF0F0F0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _SignupButton extends StatelessWidget {
  const _SignupButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4AF37),
          foregroundColor: Colors.black,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: const StadiumBorder(),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Text(
                'Sign Up',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Colors.white38, height: 1),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account ?  ',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                overlayColor: Colors.white24,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignupTexturePainter extends CustomPainter {
  const _SignupTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(41);
    final darkSpecks = <Offset>[];
    final lightSpecks = <Offset>[];
    final speckCount = (size.width * size.height / 14).round();

    for (var i = 0; i < speckCount; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      (random.nextInt(4) == 0 ? lightSpecks : darkSpecks).add(point);
    }

    canvas
      ..drawPoints(
        ui.PointMode.points,
        darkSpecks,
        Paint()
          ..color = Colors.black.withOpacity(0.08)
          ..strokeWidth = 0.7,
      )
      ..drawPoints(
        ui.PointMode.points,
        lightSpecks,
        Paint()
          ..color = Colors.white.withOpacity(0.04)
          ..strokeWidth = 0.6,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
