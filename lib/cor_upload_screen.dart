import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models/class_schedule.dart';
import 'services/gemini_service.dart';
import 'services/duty_lock_service.dart';

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
  List<ClassSession> _extractedSessions = [];
  bool _isReviewMode = false;

  Future<void> _pickAndProcessCOR() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _selectedImageBytes = bytes;
      _isProcessing = true;
    });

    try {
      final sessions = await GeminiService.extractScheduleFromCOR(bytes);
      setState(() {
        _extractedSessions = sessions;
        _isReviewMode = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Schedule parsing error: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _confirmSchedule() {
    DutyLockService.verifiedSchedule = _extractedSessions;
    DutyLockService.isRunnerScheduleUploaded = true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Study load confirmed. Academic Duty Lock is now active!'),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Study Load / COR Verification', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _isReviewMode ? _buildReviewUI() : _buildUploadPromptUI(),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPromptUI() {
    return Column(
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
          'D-DART uses Google Gemini AI to read your enrolled class hours. This automatically protects your studies by preventing gig requests while class is in session.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black87, fontSize: 13),
        ),
        const SizedBox(height: 28),
        if (_isProcessing) ...[
          const CircularProgressIndicator(color: primaryMaroon),
          const SizedBox(height: 16),
          const Text('Analyzing study load with Gemini 2.5 Flash...', style: TextStyle(fontWeight: FontWeight.w600)),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _pickAndProcessCOR,
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: const Text('Select COR Photo / PDF', style: TextStyle(color: Colors.white, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              // Load demo preview
              setState(() {
                _extractedSessions = DutyLockService.verifiedSchedule;
                _isReviewMode = true;
              });
            },
            child: const Text('Or view existing verified schedule', style: TextStyle(color: primaryMaroon)),
          ),
        ]
      ],
    );
  }

  Widget _buildReviewUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm AI-Extracted Schedule',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryMaroon),
        ),
        const SizedBox(height: 6),
        const Text(
          'Please verify that all enrolled subject times match your study load. You may edit sessions before finalizing.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const Divider(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _extractedSessions.length,
            itemBuilder: (context, index) {
              final session = _extractedSessions[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryMaroon.withOpacity(0.15),
                    child: Text(session.day.substring(0, 3), style: const TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon, fontSize: 12)),
                  ),
                  title: Text(session.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${session.day}: ${session.startTime} - ${session.endTime}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _extractedSessions.removeAt(index);
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _confirmSchedule,
            style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
            child: const Text('Confirm Schedule & Activate Duty Lock', style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
