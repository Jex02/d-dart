import 'package:flutter/material.dart';
import '../models/class_schedule.dart';

const Color _primaryMaroon = Color(0xFF7F0000);

/// Opens a dialog to add or edit a single [ClassSession].
Future<ClassSession?> showClassSessionEditorDialog(
  BuildContext context, {
  ClassSession? initial,
}) {
  final subjectCtrl = TextEditingController(text: initial?.subject ?? '');
  final startCtrl = TextEditingController(text: initial?.startTime ?? '09:00');
  final endCtrl = TextEditingController(text: initial?.endTime ?? '10:30');
  String selectedDay =
      (initial != null && ClassSession.validDays.contains(initial.day))
          ? initial.day
          : ClassSession.validDays.first;
  String? errorText;

  return showDialog<ClassSession>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(initial == null ? 'Add Class Session' : 'Edit Class Session'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedDay,
                decoration: const InputDecoration(
                  labelText: 'Day',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: ClassSession.validDays
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedDay = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject / Course Code',
                  hintText: 'e.g. CS 321 - Software Dev 2',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Start (HH:mm)',
                        hintText: '09:00',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'End (HH:mm)',
                        hintText: '12:00',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryMaroon,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final subject = subjectCtrl.text.trim();
              final start = startCtrl.text.trim();
              final end = endCtrl.text.trim();
              if (subject.isEmpty) {
                setDialogState(() => errorText = 'Please enter a subject name.');
                return;
              }
              final candidate = ClassSession(
                day: selectedDay,
                startTime: start,
                endTime: end,
                subject: subject,
              );
              if (!candidate.hasValidTimeRange) {
                setDialogState(
                  () => errorText = 'Use 24h HH:mm format and ensure end is after start.',
                );
                return;
              }
              Navigator.pop(ctx, candidate);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Reusable list + controls for reviewing and editing extracted COR class sessions.
class ScheduleReviewSection extends StatelessWidget {
  final List<ClassSession> sessions;
  final bool isDemoFallback;
  final ValueChanged<List<ClassSession>> onChanged;
  final VoidCallback onConfirm;
  final String confirmLabel;

  const ScheduleReviewSection({
    super.key,
    required this.sessions,
    required this.onChanged,
    required this.onConfirm,
    this.isDemoFallback = false,
    this.confirmLabel = 'Confirm Schedule & Activate Duty Lock',
  });

  Future<void> _addSession(BuildContext context) async {
    final created = await showClassSessionEditorDialog(context);
    if (created != null) {
      onChanged([...sessions, created]);
    }
  }

  Future<void> _editSession(BuildContext context, int index) async {
    final updated = await showClassSessionEditorDialog(
      context,
      initial: sessions[index],
    );
    if (updated != null) {
      final copy = [...sessions];
      copy[index] = updated;
      onChanged(copy);
    }
  }

  void _removeSession(int index) {
    final copy = [...sessions];
    copy.removeAt(index);
    onChanged(copy);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Confirm AI-Extracted Schedule',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _primaryMaroon,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addSession(context),
              icon: const Icon(Icons.add, size: 18, color: _primaryMaroon),
              label: const Text('Add Class', style: TextStyle(color: _primaryMaroon)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Review your enrolled class times and edit or add sessions before confirming.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        if (isDemoFallback) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: const Text(
              'Demo OCR mode active (no live GEMINI_API_KEY). Edit these sample sessions if needed.',
              style: TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ],
        const Divider(height: 20),
        Expanded(
          child: sessions.isEmpty
              ? const Center(
                  child: Text(
                    'No class sessions listed.\nTap "+ Add Class" to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _primaryMaroon.withValues(alpha: 0.15),
                          child: Text(
                            session.day.length >= 3
                                ? session.day.substring(0, 3)
                                : session.day,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _primaryMaroon,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          session.subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${session.day}: ${session.startTime} - ${session.endTime}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit session',
                              icon: const Icon(Icons.edit_outlined, color: Colors.black54),
                              onPressed: () => _editSession(context, index),
                            ),
                            IconButton(
                              tooltip: 'Remove session',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeSession(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: sessions.isEmpty ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryMaroon,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

/// Modal review dialog used during signup so students can verify/edit COR classes.
Future<List<ClassSession>?> showScheduleReviewDialog(
  BuildContext context,
  List<ClassSession> initialSessions, {
  bool isDemoFallback = false,
}) {
  var workingSessions = List<ClassSession>.from(initialSessions);
  return showDialog<List<ClassSession>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Expanded(
                  child: ScheduleReviewSection(
                    sessions: workingSessions,
                    isDemoFallback: isDemoFallback,
                    confirmLabel: 'Confirm & Complete Registration',
                    onChanged: (updated) {
                      setDialogState(() => workingSessions = updated);
                    },
                    onConfirm: () => Navigator.pop(ctx, workingSessions),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel Registration'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
