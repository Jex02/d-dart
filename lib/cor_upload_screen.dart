import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'constants/gemini_constants.dart';
import 'models/class_schedule.dart';
import 'services/gemini_service.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'widgets/schedule_editor.dart';

class CorUploadScreen extends StatefulWidget {
  const CorUploadScreen({super.key});

  @override
  State<CorUploadScreen> createState() => _CorUploadScreenState();
}

class _CorUploadScreenState extends State<CorUploadScreen> {
  static const Color primaryMaroon = Color(0xFF7F0000);
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _isDemoFallback = false;
  List<ClassSession> _extractedSessions = [];
  bool _isReviewMode = false;

  Future<void> _pickAndProcessCOR() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _selectedImageBytes = bytes;
      _isProcessing = true;
    });

    try {
      final profile = await SupabaseService().fetchUserProfileModel();
      final result = await GeminiService.verifyAndExtractCOR(
        bytes,
        expectedStudentId: profile?.studentId,
        expectedName: profile?.fullName,
      );
      if (!result.isValid) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: primaryMaroon),
                  SizedBox(width: 8),
                  Text('Invalid Document'),
                ],
              ),
              content: Text(result.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
        return;
      }

      setState(() {
        _extractedSessions = result.sessions;
        _isDemoFallback = result.isDemoFallback;
        _isReviewMode = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Schedule parsing error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _confirmSchedule() async {
    setState(() => _isSaving = true);
    try {
      DutyLockService.verifiedSchedule = _extractedSessions;
      DutyLockService.isRunnerScheduleUploaded = _extractedSessions.isNotEmpty;
      await SupabaseService().saveClassSchedule(
        _extractedSessions,
        corImageBytes: _selectedImageBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Study load confirmed. Academic Duty Lock is now active!'),
          ),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Study Load / COR Verification',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _isSaving
                ? const Center(child: CircularProgressIndicator(color: primaryMaroon))
                : _isReviewMode
                    ? ScheduleReviewSection(
                        sessions: _extractedSessions,
                        isDemoFallback: _isDemoFallback,
                        onChanged: (updated) {
                          setState(() => _extractedSessions = updated);
                        },
                        onConfirm: _confirmSchedule,
                      )
                    : _buildUploadPromptUI(),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPromptUI() {
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner_outlined, size: 75, color: primaryMaroon),
            const SizedBox(height: 16),
            const Text(
              'Upload Certificate of Registration (COR)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'D-DART uses Google Gemini AI to extract your enrolled class hours. This protects your studies by preventing gig claims while class is in session.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 13),
            ),
            const SizedBox(height: 28),
            if (_isProcessing) ...[
              const CircularProgressIndicator(color: primaryMaroon),
              const SizedBox(height: 16),
              Text(
                'Analyzing study load with ${GeminiConstants.model}...',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _pickAndProcessCOR,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text(
                    'Select COR Photo from Gallery',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
                ),
              ),
              if (DutyLockService.verifiedSchedule.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _extractedSessions = List.from(DutyLockService.verifiedSchedule);
                      _isReviewMode = true;
                    });
                  },
                  child: const Text(
                    'Edit existing verified schedule',
                    style: TextStyle(color: primaryMaroon),
                  ),
                ),
              ],
            ]
          ],
        ),
      ),
    );
  }
}
