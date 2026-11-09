import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/class_schedule.dart';
import 'services/gemini_service.dart';
import 'services/duty_lock_service.dart';
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

  final _picker = ImagePicker();
  Uint8List? _corImageBytes;
  String? _corImageName;

  bool _isLoading = false;
  String _loadingMessage = 'Creating account...';

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

  Future<void> _pickCORImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _corImageBytes = bytes;
        _corImageName = file.name;
      });
    } catch (e) {
      _showSnackbar('Could not select image: $e', Colors.redAccent);
    }
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

    // MANDATORY COR REQUIREMENT
    if (_corImageBytes == null) {
      _showSnackbar(
        'Please upload your CIT-U Certificate of Registration (COR) to verify your student account.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Analyzing COR with Gemini AI...';
    });

    try {
      // 1. AI Gatekeeper Verification
      final verification = await GeminiService.verifyAndExtractCOR(
        _corImageBytes!,
        expectedStudentId: studentId,
        expectedName: name,
      );

      if (!verification.isValid) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.gpp_bad, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('COR Verification Failed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(verification.message),
                  const SizedBox(height: 12),
                  const Text(
                    'D-DART requires an authentic CIT-U Certificate of Registration (COR) showing your enrolled class schedule to activate your student account.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Try Another Image'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (verification.sessions.isEmpty) {
        if (mounted) {
          _showSnackbar(
            'No class schedule detected on this COR. Please upload a clear photo of your study load.',
            Colors.redAccent,
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _loadingMessage = 'Creating your student account...';
        });
      }

      // 2. Register Account in Supabase with Verified Schedule metadata
      final response = await SupabaseService().signUp(
        email: email,
        password: password,
        fullName: name,
        phoneNumber: phone,
        studentId: studentId,
        initialSchedule: verification.sessions,
      );

      // 3. Save to DutyLockService in memory
      DutyLockService.verifiedSchedule = verification.sessions;
      DutyLockService.isRunnerScheduleUploaded = true;

      if (mounted) {
        final needsConfirmation = response.session == null;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.verified, color: Colors.green),
                SizedBox(width: 8),
                Text('Account & COR Verified!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $name!\n\n'
                  'Gemini AI successfully verified your CIT-U COR with ${verification.sessions.length} enrolled class sessions.\n\n'
                  'Academic Duty Lock is now active: you can request errands as a Customer anytime, while Runner mode will only be authorized during your vacant study periods.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                if (needsConfirmation) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Please verify the confirmation link sent to $email before logging in (or toggle "Confirm email" off in Supabase for instant login).',
                      style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _returnToLogin();
                },
                child: const Text('Proceed to Login'),
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
                            corImageBytes: _corImageBytes,
                            corImageName: _corImageName,
                            onPickCOR: _pickCORImage,
                          ),
                          const SizedBox(height: 20),
                          _SignupButton(
                            isLoading: _isLoading,
                            loadingMessage: _loadingMessage,
                            onPressed: _handleSignUp,
                          ),
                          const SizedBox(height: 16),
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
                constraints: const BoxConstraints(maxWidth: 450, maxHeight: 920),
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
    required this.corImageBytes,
    required this.corImageName,
    required this.onPickCOR,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController studentIdController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final Uint8List? corImageBytes;
  final String? corImageName;
  final VoidCallback onPickCOR;

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
        const SizedBox(height: 16),
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
          hintText: 'Student Id (e.g. 23-1626-937)',
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
        const SizedBox(height: 14),

        // COR UPLOAD SECTION
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: corImageBytes != null ? const Color(0xFFD4AF37) : Colors.white24,
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    corImageBytes != null ? Icons.verified : Icons.document_scanner,
                    color: corImageBytes != null ? const Color(0xFFD4AF37) : Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'CIT-U COR / Study Load',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: corImageBytes != null
                          ? Colors.green.withOpacity(0.25)
                          : const Color(0xFFD4AF37).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      corImageBytes != null ? 'ATTACHED' : 'REQUIRED',
                      style: TextStyle(
                        color: corImageBytes != null ? Colors.lightGreenAccent : const Color(0xFFD4AF37),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload your Certificate of Registration to verify student eligibility & schedule for runner vacant duty.',
                style: TextStyle(color: Colors.white60, fontSize: 10, height: 1.2),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: onPickCOR,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        corImageBytes != null ? Icons.photo : Icons.add_photo_alternate_outlined,
                        color: const Color(0xFF8F1F0D),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          corImageName != null
                              ? 'Selected: $corImageName (Tap to change)'
                              : 'Select COR Photo from Gallery',
                          style: const TextStyle(
                            color: Color(0xFF8F1F0D),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    required this.loadingMessage,
    required this.onPressed,
  });

  final bool isLoading;
  final String loadingMessage;
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
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    loadingMessage,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
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
