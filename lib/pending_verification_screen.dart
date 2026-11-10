import 'package:flutter/material.dart';
import 'login.dart';
import 'models/user_profile.dart';
import 'services/app_router.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'widgets/responsive_shell.dart';

class PendingVerificationScreen extends StatefulWidget {
  final UserProfile initialProfile;

  const PendingVerificationScreen({
    super.key,
    required this.initialProfile,
  });

  @override
  State<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState extends State<PendingVerificationScreen> {
  late UserProfile _profile;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
  }

  Future<void> _refreshStatus() async {
    setState(() => _isChecking = true);
    await DutyLockService.syncFromSupabase();
    final updated = await SupabaseService().fetchUserProfileModel();
    if (!mounted) return;
    setState(() {
      if (updated != null) _profile = updated;
      _isChecking = false;
    });

    if (updated != null && updated.isVerified) {
      final nextScreen = await AppRouter.resolveHomeForProfile(updated);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _profile.isRejected
                ? 'Verification remains rejected.'
                : 'Still awaiting administrator approval.',
          ),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await SupabaseService().signOut();
    DutyLockService.reset();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = _profile.isRejected;
    final statusColor = isRejected ? Colors.red.shade700 : Colors.orange.shade800;

    return Scaffold(
      backgroundColor: MediaQuery.of(context).size.width > 600
          ? const Color(0xFF252525)
          : Colors.white,
      body: ResponsiveMobileShell(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRejected ? Icons.gpp_bad_outlined : Icons.verified_user_outlined,
                        size: 56,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isRejected
                          ? 'Verification Rejected'
                          : 'Pending Admin Verification',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: DDartTheme.primaryMaroon,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isRejected
                          ? 'Your account verification request was declined by an administrator.'
                          : 'Thank you for registering, ${_profile.fullName.isEmpty ? 'Wildcat' : _profile.fullName}!\n\nAn administrator needs to verify your submitted ID${_profile.isStudent ? ' and COR schedule' : ''} before Customer${_profile.isStudent ? ' and Runner modes are' : ' Mode is'} unlocked.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    if (isRejected &&
                        (_profile.rejectionReason?.trim().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Reason: ${_profile.rejectionReason}',
                          style: TextStyle(fontSize: 12.5, color: Colors.red.shade900),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account Type: ${_profile.accountTypeLabel}'),
                          const SizedBox(height: 4),
                          Text('ID Number: ${_profile.studentId.isEmpty ? '-' : _profile.studentId}'),
                          const SizedBox(height: 4),
                          Text(
                            'ID Upload: ${_profile.idDocumentPath != null ? 'Submitted' : 'Missing'}',
                          ),
                          if (_profile.isStudent) ...[
                            const SizedBox(height: 4),
                            Text(
                              'COR Status: ${_profile.corVerified ? 'AI Schedule Extracted' : 'Pending'}',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _isChecking ? null : _refreshStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DDartTheme.primaryMaroon,
                          foregroundColor: Colors.white,
                        ),
                        icon: _isChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Check Verification Status'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                      label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
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
}
