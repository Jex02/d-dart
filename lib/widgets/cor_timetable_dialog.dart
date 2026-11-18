import 'package:flutter/material.dart';
import '../cor_upload_screen.dart';
import '../models/class_schedule.dart';
import '../models/user_profile.dart';
import '../services/duty_lock_service.dart';
import 'responsive_shell.dart';

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
  final bool _useSampleIfEmpty = true;
  final ScrollController _verticalScrollCtrl = ScrollController();
  final ScrollController _horizontalScrollCtrl = ScrollController();

  @override
  void dispose() {
    _verticalScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const int _slotIntervalMinutes = 30;
  static const int _defaultStartMinutes = 7 * 60; // 07:00 AM
  static const int _defaultEndMinutes = 21 * 60; // 09:00 PM

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

  static String _formatMinutes12h(int totalMinutes) {
    final clamped = totalMinutes.clamp(0, 24 * 60);
    final hour24 = (clamped ~/ 60) % 24;
    final minute = clamped % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final hh = hour12.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm $period';
  }

  static List<_TimeSlot> _buildHalfHourSlots(List<ClassSession> sessions) {
    int startMin = _defaultStartMinutes;
    int endMin = _defaultEndMinutes;

    for (final s in sessions) {
      final sStart = _parseMinutes(s.startTime);
      final sEnd = _parseMinutes(s.endTime);
      if (sStart != null && sStart < startMin) {
        startMin = (sStart ~/ _slotIntervalMinutes) * _slotIntervalMinutes;
      }
      if (sEnd != null && sEnd > endMin) {
        endMin = ((sEnd + _slotIntervalMinutes - 1) ~/ _slotIntervalMinutes) *
            _slotIntervalMinutes;
      }
    }

    startMin = startMin.clamp(0, 23 * 60);
    endMin = endMin.clamp(startMin + _slotIntervalMinutes, 24 * 60);

    final slots = <_TimeSlot>[];
    for (int m = startMin; m < endMin; m += _slotIntervalMinutes) {
      final next = m + _slotIntervalMinutes;
      slots.add(
        _TimeSlot(
          '${_formatMinutes12h(m)} - ${_formatMinutes12h(next)}',
          m,
          next,
        ),
      );
    }
    return slots;
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
      backgroundColor: DDartTheme.card(context),
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

            Divider(height: 1, thickness: 1, color: DDartTheme.divider(context)),

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
    final isDark = DDartTheme.isDark(context);
    final accent = DDartTheme.accentText(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      color: DDartTheme.card(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_month, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enrolled Class Schedule',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: DDartTheme.textPrimary(context),
                  ),
                ),
                Text(
                  isLocked ? 'Duty Lock Active • $reason' : 'Vacant Period • Eligible for Errand Runs',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isLocked
                        ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                        : (isDark ? Colors.green.shade300 : Colors.green.shade700),
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
            icon: Icon(Icons.close, color: DDartTheme.textSecondary(context), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(bool hasVerified) {
    final isDark = DDartTheme.isDark(context);
    final accent = DDartTheme.accentText(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: DDartTheme.cardSubtle(context),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
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
                  return accent.withValues(alpha: 0.16);
                }
                return DDartTheme.card(context);
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return accent;
                }
                return DDartTheme.textPrimary(context);
              }),
            ),
          ),
          if (!hasVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.amber.withValues(alpha: 0.18) : Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade400, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 13, color: isDark ? Colors.amber.shade200 : Colors.brown),
                  const SizedBox(width: 4),
                  Text(
                    'Previewing Sample CIT-U Schedule',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.amber.shade200 : Colors.brown,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid(List<ClassSession> sessions) {
    const double timeColWidth = 128.0;
    const double dayColWidth = 116.0;
    const double rowHeight = 32.0;

    final isDark = DDartTheme.isDark(context);
    final surface = DDartTheme.card(context);
    final headerBg = isDark ? const Color(0xFF27272E) : const Color(0xFFF5F5F5);
    final lineColor = isDark ? const Color(0xFF33333C) : gridLineColor;
    final subLineColor = isDark ? const Color(0xFF272730) : const Color(0xFFF0F0F0);
    final hourLineColor = isDark ? const Color(0xFF3F3F4A) : const Color(0xFFD6D6D6);
    final timeBgFull = isDark ? const Color(0xFF202026) : const Color(0xFFF7F7F7);
    final timeBgHalf = isDark ? const Color(0xFF1A1A20) : const Color(0xFFFCFCFC);
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);

    final timeSlots = _buildHalfHourSlots(sessions);
    final gridStartMinutes = timeSlots.first.startMinutes;
    final gridEndMinutes = timeSlots.last.endMinutes;
    final totalGridHeight = timeSlots.length * rowHeight;

    return Scrollbar(
      controller: _verticalScrollCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollCtrl,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          controller: _horizontalScrollCtrl,
          thumbVisibility: true,
          notificationPredicate: (notif) => notif.depth == 1,
          child: SingleChildScrollView(
            controller: _horizontalScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: Container(
              color: surface,
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
                          color: headerBg,
                          border: Border.all(color: lineColor, width: 0.7),
                        ),
                        child: Text(
                          'TIME (30-MIN)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      ..._days.map((day) {
                        return Container(
                          width: dayColWidth,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: headerBg,
                            border: Border.all(color: lineColor, width: 0.7),
                          ),
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  // Table Body: 30-Minute Time Column + 7 Positioned Day Columns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left 30-Minute Time Labels Column
                      Column(
                        children: timeSlots.map((slot) {
                          final isHalfHour = slot.startMinutes % 60 != 0;
                          return Container(
                            width: timeColWidth,
                            height: rowHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: isHalfHour ? timeBgHalf : timeBgFull,
                              border: Border(
                                left: BorderSide(color: lineColor, width: 0.7),
                                right: BorderSide(color: lineColor, width: 0.7),
                                top: BorderSide(
                                  color: isHalfHour ? subLineColor : hourLineColor,
                                  width: isHalfHour ? 0.5 : 0.8,
                                ),
                                bottom: BorderSide(color: lineColor, width: 0.5),
                              ),
                            ),
                            child: Text(
                              slot.label,
                              style: TextStyle(
                                fontSize: 9.2,
                                fontWeight: isHalfHour ? FontWeight.w500 : FontWeight.w700,
                                color: isHalfHour ? textSecondary : textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // 7 Day Columns with exact minute-accurate stacked class blocks
                      ..._days.map((day) {
                        final daySessions = sessions
                            .where((s) => s.day.trim().toLowerCase() == day.toLowerCase())
                            .toList();

                        return SizedBox(
                          width: dayColWidth,
                          height: totalGridHeight,
                          child: Stack(
                            children: [
                              // Background 30-minute grid cells
                              Column(
                                children: timeSlots.map((slot) {
                                  final isHalfHour = slot.startMinutes % 60 != 0;
                                  return Container(
                                    width: dayColWidth,
                                    height: rowHeight,
                                    decoration: BoxDecoration(
                                      color: surface,
                                      border: Border(
                                        left: BorderSide(color: lineColor, width: 0.5),
                                        right: BorderSide(color: lineColor, width: 0.5),
                                        top: BorderSide(
                                          color: isHalfHour ? subLineColor : hourLineColor,
                                          width: isHalfHour ? 0.5 : 0.7,
                                        ),
                                        bottom: BorderSide(
                                          color: subLineColor,
                                          width: 0.4,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              // Foreground class blocks positioned precisely to the minute
                              ...daySessions.map((session) {
                                final rawStart = _parseMinutes(session.startTime);
                                final rawEnd = _parseMinutes(session.endTime);
                                if (rawStart == null || rawEnd == null || rawEnd <= rawStart) {
                                  return const SizedBox.shrink();
                                }

                                final clampedStart =
                                    rawStart.clamp(gridStartMinutes, gridEndMinutes);
                                final clampedEnd =
                                    rawEnd.clamp(gridStartMinutes, gridEndMinutes);
                                if (clampedEnd <= clampedStart) {
                                  return const SizedBox.shrink();
                                }

                                final topOffset =
                                    ((clampedStart - gridStartMinutes) / _slotIntervalMinutes) *
                                        rowHeight;
                                final blockHeight =
                                    ((clampedEnd - clampedStart) / _slotIntervalMinutes) *
                                        rowHeight;

                                final timeRangeLabel =
                                    '${_formatMinutes12h(rawStart)} - ${_formatMinutes12h(rawEnd)}';
                                final showTimeSublabel = blockHeight >= 54;

                                return Positioned(
                                  top: topOffset + 0.5,
                                  left: 1,
                                  right: 1,
                                  height: (blockHeight - 1.0).clamp(16.0, totalGridHeight),
                                  child: Tooltip(
                                    message:
                                        '${session.subject.replaceAll('\n', ' • ')}\n$day • $timeRangeLabel',
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: timetableGreen,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.white, width: 1),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              session.subject,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: blockHeight < 36 ? 9.5 : 10.5,
                                                height: 1.15,
                                              ),
                                              maxLines: blockHeight < 36 ? 1 : 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (showTimeSublabel) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                timeRangeLabel,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
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
            .toList()
          ..sort((a, b) => (_parseMinutes(a.startTime) ?? 0)
              .compareTo(_parseMinutes(b.startTime) ?? 0));

        if (daySessions.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: DDartTheme.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DDartTheme.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: DDartTheme.accentText(context).withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Text(
                  day.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: DDartTheme.accentText(context),
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
    final accent = DDartTheme.accentText(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DDartTheme.card(context),
        border: Border(top: BorderSide(color: DDartTheme.divider(context), width: 1)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav
                  .push(MaterialPageRoute(builder: (_) => const CorUploadScreen()))
                  .then((_) => widget.onScheduleUpdated?.call());
            },
            icon: const Icon(Icons.upload_file, size: 16),
            label: Text(hasVerified ? 'Re-upload / Update COR' : 'Upload Verified COR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
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
