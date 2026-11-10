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
import 'utils/validators.dart';
import 'widgets/schedule_editor.dart';

const _signupPanelColor = Color(0xFF8F1F0D);
const _goldAccent = Color(0xFFD4AF37);

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _picker = ImagePicker();

  String _accountType = 'student'; // 'student' or 'faculty_staff'
  Uint8List? _idImageBytes;
  String? _idImageName;
  Uint8List? _corImageBytes;
  String? _corImageName;

  bool _isLoading = false;
  String _loadingMessage = 'Creating account...';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentImage({required bool isCor}) async {
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
        if (isCor) {
          _corImageBytes = bytes;
          _corImageName = file.name;
        } else {
          _idImageBytes = bytes;
          _idImageName = file.name;
        }
      });
    } catch (e) {
      _showSnackbar('Could not select image: $e', Colors.redAccent);
    }
  }

  String _extractFileExtension(String? filename) {
    if (filename == null || !filename.contains('.')) return 'jpg';
    return filename.split('.').last.toLowerCase();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final idNumber = _idNumberController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final validationError = Validators.validateFullName(name) ??
        Validators.validateEmail(email) ??
        Validators.validatePhoneNumber(phone) ??
        Validators.validateIdNumber(idNumber, _accountType) ??
        Validators.validatePassword(password) ??
        Validators.validateConfirmPassword(confirmPassword, password);

    if (validationError != null) {
      _showSnackbar(validationError, Colors.redAccent);
      return;
    }

    if (_idImageBytes == null) {
      _showSnackbar(
        _accountType == 'student'
            ? 'Please upload a photo of your Student ID.'
            : 'Please upload a photo of your Faculty / Employee ID.',
        Colors.redAccent,
      );
      return;
    }

    if (_accountType == 'student' && _corImageBytes == null) {
      _showSnackbar(
        'Please upload your CIT-U Certificate of Registration (COR) to verify your student account.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = _accountType == 'student'
          ? 'Analyzing COR with Gemini AI...'
          : 'Creating account...';
    });

    try {
      List<ClassSession> confirmedSessions = [];

      if (_accountType == 'student') {
        final verification = await GeminiService.verifyAndExtractCOR(
          _corImageBytes!,
          expectedStudentId: idNumber,
          expectedName: name,
        );

        if (!verification.isValid) {
          if (mounted) {
            await showDialog(
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
                      'D-DART requires an authentic CIT-U Certificate of Registration (COR) showing your enrolled class schedule to activate Student Runner privileges.',
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

        if (!mounted) return;
        final reviewed = await showScheduleReviewDialog(
          context,
          verification.sessions,
          isDemoFallback: verification.isDemoFallback,
        );
        if (reviewed == null || reviewed.isEmpty) {
          _showSnackbar('Registration cancelled. Confirm your schedule to proceed.', Colors.orange);
          return;
        }
        confirmedSessions = reviewed;
      }

      if (mounted) {
        setState(() {
          _loadingMessage = 'Saving account & documents...';
        });
      }

      final response = await SupabaseService().signUp(
        email: email,
        password: password,
        fullName: name,
        phoneNumber: phone,
        studentId: idNumber,
        accountType: _accountType,
        corVerified: _accountType == 'student' && confirmedSessions.isNotEmpty,
        initialSchedule: confirmedSessions,
        idDocumentBytes: _idImageBytes,
        idDocumentExt: _extractFileExtension(_idImageName),
        corDocumentBytes: _corImageBytes,
        corDocumentExt: _extractFileExtension(_corImageName),
      );

      if (_accountType == 'student') {
        DutyLockService.verifiedSchedule = confirmedSessions;
        DutyLockService.isRunnerScheduleUploaded = true;
      } else {
        DutyLockService.reset();
      }

      if (mounted) {
        final needsConfirmation = response.session == null;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.verified, color: Colors.green),
                SizedBox(width: 8),
                Flexible(child: Text('Account Registered!')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _accountType == 'student'
                      ? 'Welcome, $name!\n\n'
                          'Your Student ID and COR (${confirmedSessions.length} class sessions) have been submitted.\n\n'
                          'Your account is now pending Administrator verification before Customer and Runner modes unlock.'
                      : 'Welcome, $name!\n\n'
                          'Your Faculty / Staff account and ID have been submitted.\n\n'
                          'Your account is now pending Administrator verification before Customer Mode unlocks.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                if (needsConfirmation) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Please verify the confirmation link sent to $email before logging in (or disable "Confirm email" in Supabase Auth settings for instant login).',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
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
                            'Sign up and start ordering, requesting errands,\nand delivering around CIT-U campus.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.3,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Account Type Selector (WBS 2.1)
                          _AccountTypeSelector(
                            selectedType: _accountType,
                            onChanged: (type) {
                              setState(() {
                                _accountType = type;
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          _SignupFields(
                            accountType: _accountType,
                            nameController: _nameController,
                            emailController: _emailController,
                            phoneController: _phoneController,
                            idNumberController: _idNumberController,
                            passwordController: _passwordController,
                            confirmPasswordController: _confirmPasswordController,
                            idImageBytes: _idImageBytes,
                            idImageName: _idImageName,
                            corImageBytes: _corImageBytes,
                            corImageName: _corImageName,
                            onPickId: () => _pickDocumentImage(isCor: false),
                            onPickCOR: () => _pickDocumentImage(isCor: true),
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

class _AccountTypeSelector extends StatelessWidget {
  const _AccountTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  final String selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypePill(
            label: 'Student',
            subtitle: 'Customer + Runner',
            icon: Icons.school_outlined,
            selected: selectedType == 'student',
            onTap: () => onChanged('student'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TypePill(
            label: 'Faculty / Staff',
            subtitle: 'Customer Only',
            icon: Icons.badge_outlined,
            selected: selectedType == 'faculty_staff',
            onTap: () => onChanged('faculty_staff'),
          ),
        ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? _goldAccent : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _goldAccent : Colors.white30,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.black : Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: selected ? Colors.black87 : Colors.white70,
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
            TextSpan(text: 'Run.', style: TextStyle(color: _goldAccent)),
            TextSpan(text: 'Deliver.', style: TextStyle(color: _signupPanelColor)),
          ],
        ),
      ),
    );
  }
}

class _SignupFields extends StatelessWidget {
  const _SignupFields({
    required this.accountType,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.idNumberController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.idImageBytes,
    required this.idImageName,
    required this.corImageBytes,
    required this.corImageName,
    required this.onPickId,
    required this.onPickCOR,
  });

  final String accountType;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController idNumberController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final Uint8List? idImageBytes;
  final String? idImageName;
  final Uint8List? corImageBytes;
  final String? corImageName;
  final VoidCallback onPickId;
  final VoidCallback onPickCOR;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    final isStudent = accountType == 'student';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          hintText: 'Phone Number (e.g. 09171234567)',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: gap),
        _SignupTextField(
          controller: idNumberController,
          hintText: isStudent
              ? 'Student ID (e.g. 23-1626-937)'
              : 'Employee / Faculty ID (e.g. EMP-1024)',
        ),
        const SizedBox(height: gap),
        _SignupTextField(
          controller: passwordController,
          hintText: 'Password (min 6 chars)',
          obscureText: true,
        ),
        const SizedBox(height: gap),
        _SignupTextField(
          controller: confirmPasswordController,
          hintText: 'Confirm Password',
          obscureText: true,
        ),
        const SizedBox(height: 14),

        // Student ID / Faculty-Employee ID Upload Card (WBS 2.4)
        _DocumentUploadCard(
          title: isStudent ? 'CIT-U Student ID Photo' : 'Faculty / Employee ID Photo',
          subtitle: isStudent
              ? 'Upload a clear photo of your official CIT-U Student ID card.'
              : 'Upload a clear photo of your CIT-U Faculty or Employee ID card.',
          icon: Icons.badge_outlined,
          buttonLabel: isStudent ? 'Select Student ID Photo' : 'Select Employee ID Photo',
          fileName: idImageName,
          hasFile: idImageBytes != null,
          onTap: onPickId,
        ),

        if (isStudent) ...[
          const SizedBox(height: 12),
          _DocumentUploadCard(
            title: 'CIT-U COR / Study Load',
            subtitle:
                'Upload your Certificate of Registration to verify schedule & unlock Runner Mode.',
            icon: Icons.document_scanner,
            buttonLabel: 'Select COR Photo from Gallery',
            fileName: corImageName,
            hasFile: corImageBytes != null,
            onTap: onPickCOR,
          ),
        ],
      ],
    );
  }
}

class _DocumentUploadCard extends StatelessWidget {
  const _DocumentUploadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.buttonLabel,
    required this.fileName,
    required this.hasFile,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String buttonLabel;
  final String? fileName;
  final bool hasFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile ? _goldAccent : Colors.white24,
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
                hasFile ? Icons.verified : icon,
                color: hasFile ? _goldAccent : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasFile
                      ? Colors.green.withValues(alpha: 0.25)
                      : _goldAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasFile ? 'ATTACHED' : 'REQUIRED',
                  style: TextStyle(
                    color: hasFile ? Colors.lightGreenAccent : _goldAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 10, height: 1.2),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onTap,
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
                    hasFile ? Icons.photo : Icons.add_photo_alternate_outlined,
                    color: _signupPanelColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      fileName != null
                          ? 'Selected: $fileName (Tap to change)'
                          : buttonLabel,
                      style: const TextStyle(
                        color: _signupPanelColor,
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
            letterSpacing: 0.6,
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
            borderSide: BorderSide(color: _goldAccent, width: 1.5),
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
          backgroundColor: _goldAccent,
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
                  Flexible(
                    child: Text(
                      loadingMessage,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
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
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
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
          ..color = Colors.black.withValues(alpha: 0.08)
          ..strokeWidth = 0.7,
      )
      ..drawPoints(
        ui.PointMode.points,
        lightSpecks,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04)
          ..strokeWidth = 0.6,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
