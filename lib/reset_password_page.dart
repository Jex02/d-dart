import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'services/supabase_service.dart';
import 'utils/validators.dart';

const Color _resetPanelColor = Color(0xFF8F1F0D);
const Color _resetGoldAccent = Color(0xFFD4AF37);

enum _ResetStep {
  requestEmail,
  verifyCode,
  setNewPassword,
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.initialEmail,
    this.startInUpdateMode = false,
    this.initialErrorMessage,
  });

  final String? initialEmail;

  /// When true, opens directly on the "Set New Password" step (e.g., after
  /// clicking the Supabase password recovery link in email).
  final bool startInUpdateMode;

  /// Optional error message surfaced from an expired or invalid recovery link.
  final String? initialErrorMessage;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  late _ResetStep _step;
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail?.trim() ??
        SupabaseService().currentUser?.email ??
        '';
    _step = widget.startInUpdateMode
        ? _ResetStep.setNewPassword
        : _ResetStep.requestEmail;

    if (widget.initialErrorMessage != null &&
        widget.initialErrorMessage!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnack(
          widget.initialErrorMessage!,
          background: Colors.redAccent,
        );
      });
    }

    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          if (data.event == AuthChangeEvent.passwordRecovery && mounted) {
            setState(() {
              if (data.session?.user.email != null) {
                _emailCtrl.text = data.session!.user.email!;
              }
              _step = _ResetStep.setNewPassword;
            });
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          final msg = error is AuthException
              ? error.message
              : 'Your reset link is invalid or has expired. Please request a new one.';
          _showSnack(msg, background: Colors.redAccent);
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {Color background = Colors.black87}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: background),
      );
  }

  Future<void> _sendResetEmail() async {
    final email = _emailCtrl.text.trim();
    final err = Validators.validateEmail(email);
    if (err != null) {
      _showSnack(err, background: Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService().resetPassword(email);
      if (mounted) {
        setState(() => _step = _ResetStep.verifyCode);
        _showSnack(
          'Recovery code sent to $email. Check your inbox!',
          background: Colors.green,
        );
      }
    } on AuthException catch (e) {
      _showSnack(e.message, background: Colors.redAccent);
    } catch (e) {
      _showSnack('Could not send reset email: $e', background: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyRecoveryCode() async {
    final email = _emailCtrl.text.trim();
    final code = _otpCtrl.text.replaceAll(RegExp(r'[\s-]+'), '');

    final emailErr = Validators.validateEmail(email);
    if (emailErr != null) {
      _showSnack(emailErr, background: Colors.redAccent);
      return;
    }
    if (code.length < 6) {
      _showSnack(
        'Please enter the recovery code from your email.',
        background: Colors.redAccent,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService().verifyRecoveryOtp(email: email, token: code);
      if (mounted) {
        setState(() => _step = _ResetStep.setNewPassword);
        _showSnack(
          'Code verified! Enter your new password below.',
          background: Colors.green,
        );
      }
    } on AuthException catch (e) {
      _showSnack(e.message, background: Colors.redAccent);
    } catch (e) {
      _showSnack('Invalid or expired code: $e', background: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    final err = Validators.validatePassword(newPassword) ??
        Validators.validateConfirmPassword(confirmPassword, newPassword);
    if (err != null) {
      _showSnack(err, background: Colors.redAccent);
      return;
    }

    if (!SupabaseService().isAuthenticated) {
      _showSnack(
        'Your recovery session has expired. Please request a new reset email.',
        background: Colors.redAccent,
      );
      setState(() => _step = _ResetStep.requestEmail);
      return;
    }

    setState(() => _isLoading = true);
    final emailForLogin =
        SupabaseService().currentUser?.email ?? _emailCtrl.text.trim();

    try {
      await SupabaseService().updatePassword(newPassword);
      // Sign out the temporary recovery session so the user signs in cleanly with their new password
      await SupabaseService().signOut();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Flexible(child: Text('Password Updated!')),
            ],
          ),
          content: const Text(
            'Your D-DART password has been reset successfully. You can now log in using your new password.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _resetPanelColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(initialEmail: emailForLogin),
        ),
        (_) => false,
      );
    } on AuthException catch (e) {
      _showSnack(e.message, background: Colors.redAccent);
    } catch (e) {
      _showSnack('Failed to update password: $e', background: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _backToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginPage(initialEmail: _emailCtrl.text.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth > 600;

    final content = SafeArea(
      child: Column(
        children: [
          // Top white header bar matching SignupPage
          Container(
            height: 56,
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to Login',
                  icon: const Icon(Icons.arrow_back, color: _resetPanelColor),
                  onPressed: _backToLogin,
                ),
                Expanded(
                  child: Center(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 18,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(text: 'Order.', style: TextStyle(color: Colors.black87)),
                          TextSpan(text: 'Run.', style: TextStyle(color: _resetGoldAccent)),
                          TextSpan(text: 'Deliver.', style: TextStyle(color: _resetPanelColor)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _resetPanelColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        child: Icon(
                          _step == _ResetStep.setNewPassword
                              ? Icons.lock_open_rounded
                              : _step == _ResetStep.verifyCode
                                  ? Icons.mark_email_read_outlined
                                  : Icons.lock_reset_rounded,
                          color: _resetGoldAccent,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _step == _ResetStep.setNewPassword
                          ? 'Set New Password'
                          : _step == _ResetStep.verifyCode
                              ? 'Check Your Email'
                              : 'Reset Password',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'serif',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _step == _ResetStep.setNewPassword
                          ? 'Choose a strong new password (at least 6 characters) for your D-DART account.'
                          : _step == _ResetStep.verifyCode
                              ? 'We sent a recovery code to ${_emailCtrl.text.trim()}. Enter the code from your email below to verify your account.'
                              : 'Enter your registered email address and we will send you a recovery code to reset your password.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_step == _ResetStep.requestEmail) ..._buildRequestStep(),
                    if (_step == _ResetStep.verifyCode) ..._buildVerifyCodeStep(),
                    if (_step == _ResetStep.setNewPassword) ..._buildSetPasswordStep(),

                    const SizedBox(height: 24),
                    const Divider(color: Colors.white30, height: 1),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton.icon(
                        onPressed: _backToLogin,
                        icon: const Icon(Icons.arrow_back, size: 15, color: Colors.white),
                        label: const Text(
                          'Return to Login',
                          style: TextStyle(color: Colors.white, fontSize: 12.5),
                        ),
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
                constraints: const BoxConstraints(maxWidth: 450, maxHeight: 880),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: content,
                ),
              ),
            )
          : content,
    );
  }

  List<Widget> _buildRequestStep() {
    return [
      _buildInputField(
        controller: _emailCtrl,
        hintText: 'Registered Email Address',
        keyboardType: TextInputType.emailAddress,
        prefixIcon: Icons.email_outlined,
        onSubmitted: (_) => _sendResetEmail(),
      ),
      const SizedBox(height: 20),
      _buildPrimaryButton(
        label: 'Send Recovery Code',
        onPressed: _sendResetEmail,
      ),
      const SizedBox(height: 14),
      Center(
        child: TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() => _step = _ResetStep.verifyCode),
          child: const Text(
            'Already have a recovery code? Enter it here',
            style: TextStyle(color: _resetGoldAccent, fontSize: 12),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildVerifyCodeStep() {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: _resetGoldAccent, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Check your inbox (and spam folder) for your D-DART password reset email, then enter the recovery code below.',
                style: TextStyle(color: Colors.white, fontSize: 11.5, height: 1.35),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildInputField(
        controller: _emailCtrl,
        hintText: 'Account Email',
        keyboardType: TextInputType.emailAddress,
        prefixIcon: Icons.email_outlined,
      ),
      const SizedBox(height: 12),
      _buildInputField(
        controller: _otpCtrl,
        hintText: 'Recovery Code (e.g. 123456)',
        keyboardType: TextInputType.number,
        prefixIcon: Icons.pin_outlined,
        onSubmitted: (_) => _verifyRecoveryCode(),
      ),
      const SizedBox(height: 18),
      _buildPrimaryButton(
        label: 'Verify Code',
        onPressed: _verifyRecoveryCode,
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _step = _ResetStep.requestEmail),
            child: const Text(
              'Change Email',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _sendResetEmail,
            child: const Text(
              'Resend Code',
              style: TextStyle(
                color: _resetGoldAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildSetPasswordStep() {
    return [
      _buildInputField(
        controller: _newPasswordCtrl,
        hintText: 'New Password (min 6 chars)',
        obscureText: _obscureNewPassword,
        prefixIcon: Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(
            _obscureNewPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.black45,
            size: 20,
          ),
          onPressed: () =>
              setState(() => _obscureNewPassword = !_obscureNewPassword),
        ),
      ),
      const SizedBox(height: 12),
      _buildInputField(
        controller: _confirmPasswordCtrl,
        hintText: 'Confirm New Password',
        obscureText: _obscureConfirmPassword,
        prefixIcon: Icons.lock_outline,
        onSubmitted: (_) => _updatePassword(),
        suffix: IconButton(
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.black45,
            size: 20,
          ),
          onPressed: () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
        ),
      ),
      const SizedBox(height: 22),
      _buildPrimaryButton(
        label: 'Update Password',
        onPressed: _updatePassword,
      ),
    ];
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black54, fontSize: 12.5),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(prefixIcon, color: _resetPanelColor, size: 19),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _resetGoldAccent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _resetGoldAccent,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
