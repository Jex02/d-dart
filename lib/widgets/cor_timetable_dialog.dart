import 'package:flutter/material.dart';
import '../cor_upload_screen.dart';
import '../models/class_schedule.dart';
import '../models/user_profile.dart';
import '../services/duty_lock_service.dart';

class CorTimetableDialog extends StatefulWidget {
  final UserProfile? profile;
  final VoidCallback? onScheduleUpdated;

  const CorTimetableDialog({
    super.key,
    this.profile,
    this.onScheduleUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    UserProfile? profile,
    VoidCallback? onScheduleUpdated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // Allows clicking the side / backdrop to close
      barrierColor: Colors.black54,
      builder: (ctx) => CorTimetableDialog(
        profile: profile,
        onScheduleUpdated: onScheduleUpdated,
      ),
    );
  }

  @override
  State<CorTimetableDialog> createState() => _CorTimetableDialogState();
}

class _TimeSlot {
  final String label;
  final int startMinutes;
  final int endMinutes;

  const _TimeSlot(this.label, this.startMinutes, this.endMinutes);
}

class _CorTimetableDialogState extends State<CorTimetableDialog> {
  static const Color primaryMaroon = Color(0xFF7F0000);
  static const Color timetableGreen = Color(0xFF558B2F); // Exact green from student portal screenshot
  static const Color gridLineColor = Color(0xFFE0E0E0);

  bool _showTimetableGrid = true;
  bool _useSampleIfEmpty = true;

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<_TimeSlot> _timeSlots = [
    _TimeSlot('07:00 AM - 08:00 AM', 7 * 60, 8 * 60),
    _TimeSlot('08:00 AM - 09:00 AM', 8 * 60, 9 * 60),
    _TimeSlot('09:00 AM - 10:00 AM', 9 * 60, 10 * 60),
    _TimeSlot('10:00 AM - 11:00 AM', 10 * 60, 11 * 60),
    _TimeSlot('11:00 AM - 12:00 PM', 11 * 60, 12 * 60),
    _TimeSlot('12:00 PM - 01:00 PM', 12 * 60, 13 * 60),
    _TimeSlot('01:00 PM - 02:00 PM', 13 * 60, 14 * 60),
    _TimeSlot('02:00 PM - 03:00 PM', 14 * 60, 15 * 60),
    _TimeSlot('03:00 PM - 04:00 PM', 15 * 60, 16 * 60),
    _TimeSlot('04:00 PM - 05:00 PM', 16 * 60, 17 * 60),
    _TimeSlot('05:00 PM - 06:00 PM', 17 * 60, 18 * 60),
    _TimeSlot('06:00 PM - 07:00 PM', 18 * 60, 19 * 60),
    _TimeSlot('07:00 PM - 08:00 PM', 19 * 60, 20 * 60),
    _TimeSlot('08:00 PM - 09:00 PM', 20 * 60, 21 * 60),
  ];

  // Exact CIT-U CPE schedule matching the user's uploaded screenshot
  static final List<ClassSession> _sampleCpeSchedule = [
    ClassSession(day: 'Monday', startTime: '13:00', endTime: '15:00', subject: 'CPE234\nGLE704'),
    ClassSession(day: 'Monday', startTime: '18:00', endTime: '21:00', subject: 'CPEPE362/SD\nGLE705'),
    ClassSession(day: 'Tuesday', startTime: '07:30', endTime: '10:30', subject: 'CPE382\nGLE605'),
    ClassSession(day: 'Tuesday', startTime: '18:00', endTime: '21:00', subject: 'CPE366\nGLE705'),
    ClassSession(day: 'Wednesday', startTime: '07:30', endTime: '10:30', subject: 'CPE368\nGLE704'),
    ClassSession(day: 'Wednesday', startTime: '10:30', endTime: '13:30', subject: 'CPE331\nGLE703'),
    ClassSession(day: 'Wednesday', startTime: '15:00', endTime: '18:00', subject: 'CPE232\nGLE703'),
    ClassSession(day: 'Wednesday', startTime: '18:00', endTime: '21:00', subject: 'CPE334\nGLE704'),
    ClassSession(day: 'Thursday', startTime: '13:00', endTime: '15:00', subject: 'CPE234\nGLE704'),
    ClassSession(day: 'Thursday', startTime: '18:00', endTime: '21:00', subject: 'CPEPE362/SD\nGLE604'),
    ClassSession(day: 'Friday', startTime: '07:30', endTime: '10:30', subject: 'CPE368\nGLE606'),
    ClassSession(day: 'Friday', startTime: '18:00', endTime: '21:00', subject: 'CPE366\nGLE705'),
  ];

  static int? _parseMinutes(String timeStr) {
    final clean = timeStr.trim().toUpperCase();
    final isPM = clean.contains('PM');
    final isAM = clean.contains('AM');
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(clean);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final min = int.parse(match.group(2)!);
    if (isPM && hour < 12) hour += 12;
    if (isAM && hour == 12) hour = 0;
    return hour * 60 + min;
  }

  ClassSession? _findSessionForSlot(List<ClassSession> sessions, String day, _TimeSlot slot) {
    for (final s in sessions) {
      if (s.day.trim().toLowerCase() != day.trim().toLowerCase()) continue;
      final startMin = _parseMinutes(s.startTime);
      final endMin = _parseMinutes(s.endTime);
      if (startMin == null || endMin == null) continue;

      // Overlap condition
      if (startMin < slot.endMinutes && endMin > slot.startMinutes) {
        return s;
      }
    }
    return null;
  }

  bool _isFirstSlotOfSession(ClassSession session, _TimeSlot slot) {
    final startMin = _parseMinutes(session.startTime);
    if (startMin == null) return true;
    return startMin >= slot.startMinutes && startMin < slot.endMinutes;
  }

  bool _isLastSlotOfSession(ClassSession session, _TimeSlot slot) {
    final endMin = _parseMinutes(session.endTime);
    if (endMin == null) return true;
    return endMin > slot.startMinutes && endMin <= slot.endMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final verifiedSessions = DutyLockService.verifiedSchedule;
    final hasVerified = verifiedSessions.isNotEmpty;
    final activeSessions = hasVerified
        ? verifiedSessions
        : (_useSampleIfEmpty ? _sampleCpeSchedule : <ClassSession>[]);

    final dutyStatus = DutyLockService.checkDutyStatus(profile: widget.profile);
    final isLocked = dutyStatus['isLocked'] == true;
    final reason = dutyStatus['reason']?.toString() ?? '';

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 700;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1040,
          maxHeight: screenSize.height * 0.90,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header with Close Button
            _buildHeader(context, isLocked, reason),

            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // View switch bar & sample toggle
            _buildControlsBar(hasVerified),

            // Timetable or List Content
            Expanded(
              child: _showTimetableGrid
                  ? _buildTimetableGrid(activeSessions)
                  : _buildListView(activeSessions, hasVerified),
            ),

            // Bottom Action Bar
            _buildFooter(context, hasVerified),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLocked, String reason) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryMaroon.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_month, color: primaryMaroon, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enrolled Class Schedule',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                Text(
                  isLocked ? 'Duty Lock Active • $reason' : 'Vacant Period • Eligible for Errand Runs',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isLocked ? Colors.red.shade700 : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close schedule (or tap outside)',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.black54, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(bool hasVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFAFAFA),
      child: Row(
        children: [
          // Segmented button for Timetable vs List
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Timetable', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.grid_on, size: 16),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('List', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.format_list_bulleted, size: 16),
              ),
            ],
            selected: {_showTimetableGrid},
            onSelectionChanged: (val) {
              setState(() => _showTimetableGrid = val.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primaryMaroon.withValues(alpha: 0.12);
                }
                return Colors.white;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primaryMaroon;
                }
                return Colors.black87;
              }),
            ),
          ),
          const Spacer(),
          if (!hasVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade400, width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.brown),
                  SizedBox(width: 4),
                  Text(
                    'Previewing Sample CIT-U Schedule',
                    style: TextStyle(fontSize: 11, color: Colors.brown, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid(List<ClassSession> sessions) {
    const double timeColWidth = 120.0;
    const double dayColWidth = 116.0;
    const double rowHeight = 48.0;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          thumbVisibility: true,
          notificationPredicate: (notif) => notif.depth == 1,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Table Header Row: Empty top-left corner + 7 Day Names
                  Row(
                    children: [
                      Container(
                        width: timeColWidth,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          border: Border.all(color: gridLineColor, width: 0.7),
                        ),
                        child: const Text(
                          'TIME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      ..._days.map((day) {
                        return Container(
                          width: dayColWidth,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            border: Border.all(color: gridLineColor, width: 0.7),
                          ),
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E2E2E),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  // Table Body: 14 Hourly Rows
                  ..._timeSlots.map((slot) {
                    return Row(
                      children: [
                        // Left Time Column
                        Container(
                          width: timeColWidth,
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            border: Border.all(color: gridLineColor, width: 0.7),
                          ),
                          child: Text(
                            slot.label,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        // 7 Day Cells for this Time Slot
                        ..._days.map((day) {
                          final session = _findSessionForSlot(sessions, day, slot);

                          if (session == null) {
                            // Empty vacant cell
                            return Container(
                              width: dayColWidth,
                              height: rowHeight,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: gridLineColor, width: 0.5),
                              ),
                            );
                          }

                          // Occupied class slot with matching green block
                          final isFirst = _isFirstSlotOfSession(session, slot);
                          final isLast = _isLastSlotOfSession(session, slot);

                          return Container(
                            width: dayColWidth,
                            height: rowHeight,
                            decoration: BoxDecoration(
                              color: timetableGreen,
                              border: Border(
                                left: const BorderSide(color: Colors.white, width: 1),
                                right: const BorderSide(color: Colors.white, width: 1),
                                top: isFirst
                                    ? const BorderSide(color: Colors.white, width: 1)
                                    : BorderSide.none,
                                bottom: isLast
                                    ? const BorderSide(color: Colors.white, width: 1)
                                    : BorderSide.none,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: isFirst
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          session.subject,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10.5,
                                            height: 1.15,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<ClassSession> sessions, bool hasVerified) {
    if (sessions.isEmpty) {
      return const Center(
        child: Text('No class sessions found.', style: TextStyle(color: Colors.black54)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _days.map((day) {
        final daySessions = sessions
            .where((s) => s.day.toLowerCase() == day.toLowerCase())
            .toList();

        if (daySessions.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryMaroon.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Text(
                  day.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: primaryMaroon,
                  ),
                ),
              ),
              ...daySessions.map((session) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: timetableGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.schedule, size: 16, color: timetableGreen),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${session.startTime} - ${session.endTime}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: timetableGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              session.subject.replaceAll('\n', ' • '),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(BuildContext context, bool hasVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CorUploadScreen()),
              ).then((_) => widget.onScheduleUpdated?.call());
            },
            icon: const Icon(Icons.upload_file, size: 16),
            label: Text(hasVerified ? 'Re-upload / Update COR' : 'Upload Verified COR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryMaroon,
              side: const BorderSide(color: primaryMaroon),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryMaroon,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
