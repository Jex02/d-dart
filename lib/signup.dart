import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'login.dart';

const _signupPanelColor = Color(0xFF8F1F0D);

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF252525),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    const _SignupHeader(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxHeight < 620;
                          return _SignupPanel(
                            compact: compact,
                            onLoginTap: _returnToLogin,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _returnToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => const LoginPage()),
    );
  }
}

class _SignupHeader extends StatelessWidget {
  const _SignupHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 57,
      width: double.infinity,
      color: Colors.white,
      alignment: Alignment.center,
      child: RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 18, letterSpacing: 3),
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

class _SignupPanel extends StatelessWidget {
  const _SignupPanel({
    required this.compact,
    required this.onLoginTap,
  });

  final bool compact;
  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    final fields = _SignupFields(compact: compact);

    if (compact) {
      return Container(
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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fields,
                    const SizedBox(height: 32),
                    const _SignupButton(),
                    const SizedBox(height: 30),
                    _LoginFooter(onTap: onLoginTap),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 68),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fields,
                  const Spacer(),
                  const _SignupButton(),
                  const SizedBox(height: 39),
                  _LoginFooter(onTap: onLoginTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupFields extends StatelessWidget {
  const _SignupFields({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 9.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create an Account',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign up and start ordering, request errands and\nget things delivered in campus',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            height: 1.35,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: compact ? 12 : 15),
        const _SignupTextField(hintText: 'Full Name'),
        SizedBox(height: gap),
        const _SignupTextField(
          hintText: 'Email Address',
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: gap),
        const _SignupTextField(
          hintText: 'Phone Number',
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: gap),
        const _SignupTextField(hintText: 'Student Id/Teacher Id'),
        SizedBox(height: gap),
        _SignupTextField(
          hintText: 'Password',
          obscureText: true,
        ),
        SizedBox(height: gap),
        _SignupTextField(
          hintText: 'Confirm Password',
          obscureText: true,
        ),
      ],
    );
  }
}

class _SignupTextField extends StatelessWidget {
  const _SignupTextField({
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
  });

  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        keyboardType: keyboardType,
        obscureText: obscureText,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black87, fontSize: 11),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Colors.black38,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFE0E0E0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _SignupButton extends StatelessWidget {
  const _SignupButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE0E0E0),
          foregroundColor: Colors.black45,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          'Sign Up',
          style: TextStyle(fontSize: 10, letterSpacing: 1.5),
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
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account ?  ',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                overlayColor: Colors.white24,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
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
    final speckCount = (size.width * size.height / 12).round();

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
          ..color = Colors.black.withOpacity(0.09)
          ..strokeWidth = 0.7,
      )
      ..drawPoints(
        ui.PointMode.points,
        lightSpecks,
        Paint()
          ..color = Colors.white.withOpacity(0.045)
          ..strokeWidth = 0.6,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
