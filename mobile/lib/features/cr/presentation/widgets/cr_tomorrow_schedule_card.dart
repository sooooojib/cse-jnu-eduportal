import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/role_colors.dart';
import '../../../../core/communication/whatsapp_share_dialog.dart';
import '../../../../core/communication/whatsapp_share_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/cr_dashboard_data.dart';

class CrTomorrowScheduleCard extends StatefulWidget {
  final CrDashboardData data;
  final VoidCallback onManageTomorrowTap;
  final bool isCr;

  const CrTomorrowScheduleCard({
    super.key,
    required this.data,
    required this.onManageTomorrowTap,
    this.isCr = true,
  });

  @override
  State<CrTomorrowScheduleCard> createState() => _CrTomorrowScheduleCardState();
}

class _CrTomorrowScheduleCardState extends State<CrTomorrowScheduleCard> {
  int _selectedTab = 0; // 0 for Classes, 1 for Exams

  void _handleWhatsAppBroadcast(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('📢 *CSE JnU EduPortal — Class Routine for Tomorrow*');
    buffer.writeln('📅 *Date:* ${widget.data.tomorrowDateLabel}');
    buffer.writeln('🎓 *Batch:* Year ${widget.data.year}, Semester ${widget.data.semester}');
    buffer.writeln('────────────────────────────────────────');

    if (widget.data.tomorrowClasses.isEmpty) {
      buffer.writeln('🏖️ *No classes scheduled for tomorrow.*');
      buffer.writeln('Enjoy your study day and prepare for upcoming assignments!');
    } else {
      for (int i = 0; i < widget.data.tomorrowClasses.length; i++) {
        final slot = widget.data.tomorrowClasses[i];
        buffer.writeln('${i + 1}. *${slot.courseCode}: ${slot.courseTitle}*');
        buffer.writeln('   ⏰ Time: ${slot.startTime} - ${slot.endTime}');
        buffer.writeln('   📍 Room: ${slot.room}');
        if (slot.teacherName.isNotEmpty) {
          buffer.writeln('   👨‍🏫 Faculty: ${slot.teacherName}');
        }
        if (slot.isExtraClass) {
          buffer.writeln('   ⚠️ *Extra Class*');
        }
        buffer.writeln('');
      }
    }

    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('Generated via *JnU EduPortal* CR Terminal.');

    final messageText = buffer.toString();

    WhatsAppShareDialog.show(
      context,
      title: 'WhatsApp Broadcast',
      subtitle: '${widget.data.tomorrowDateLabel} (Year ${widget.data.year}, Sem ${widget.data.semester})',
      messageText: messageText,
      shareService: sl.isRegistered<WhatsAppShareService>() ? sl<WhatsAppShareService>() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final crColors = RoleColors.forRole(widget.data.role, isDark: isDark);

    if (widget.isCr) {
      // ───────────────────────────────────────────────────────────────────────
      // CR View: Manage Tomorrow's Schedule & Broadcast Hub (Faculty-inspired)
      // ───────────────────────────────────────────────────────────────────────
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13263E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Title, Date & Action Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1D3552).withValues(alpha: 0.6)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "Manage Tomorrow's Schedule",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                                        : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Next-Day',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.data.tomorrowDateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? crColors.primary.withValues(alpha: 0.2)
                              : const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.data.tomorrowClasses.length} Slots',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: crColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Add / Edit Slot Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: crColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Add Class Slot',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                          onPressed: widget.onManageTomorrowTap,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Broadcast on WhatsApp
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.1),
                            foregroundColor: const Color(0xFF075E54),
                            side: BorderSide(
                              color: const Color(0xFF25D366).withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.forum_rounded, size: 16, color: Color(0xFF075E54)),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Broadcast',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF075E54),
                              ),
                            ),
                          ),
                          onPressed: () => _handleWhatsAppBroadcast(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Body Description
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Adjust tomorrow’s class timings, rooms, or add extra sessions and broadcast directly to your batch group.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Student View: Next-Day Time-Aware Class Schedule (Identical to Faculty)
    // ─────────────────────────────────────────────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title & Date (Matching Faculty TimeAwareClassesCard with Next-Day Badge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1D3552).withValues(alpha: 0.6)
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _selectedTab == 0 ? "Tomorrow's Schedule" : "Tomorrow's Exams",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                                      : const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Next-Day',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.data.tomorrowDateLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : const Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedTab == 0 ? Icons.schedule_rounded : Icons.assignment_rounded,
                        color: AppColors.primaryLight,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Toggle Segmented Control (Classes vs Exams)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F1E33)
                        : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildToggleItem(
                          title: "Classes",
                          count: widget.data.tomorrowClasses.length,
                          index: 0,
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildToggleItem(
                          title: "Exams",
                          count: 0,
                          index: 1,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body: Classes Timeline / Empty State
          Padding(
            padding: const EdgeInsets.all(20),
            child: _selectedTab == 0
                ? (widget.data.tomorrowClasses.isEmpty
                    ? _buildEmptyState(context, isDark)
                    : _buildClassesTimeline(context, isDark))
                : _buildExamsEmptyState(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required int count,
    required int index,
    required bool isDark,
  }) {
    final bool isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                          : const Color(0xFF0284C7).withValues(alpha: 0.12))
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 36,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No classes scheduled for tomorrow',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your next-day timetable is clear for research or self-study.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamsEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_turned_in_rounded,
                size: 36,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No exams scheduled for tomorrow',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No upcoming semester examinations scheduled for tomorrow.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesTimeline(BuildContext context, bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.data.tomorrowClasses.length + 1, // +1 for "End of scheduled classes" footer
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        if (index == widget.data.tomorrowClasses.length) {
          // End of scheduled classes footer
          return Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.done_all_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'End of scheduled classes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          );
        }

        final slot = widget.data.tomorrowClasses[index];
        final bool isFirst = index == 0;
        final bool isLab = slot.courseCode.endsWith('2') ||
            slot.courseCode.endsWith('4') ||
            slot.courseTitle.toLowerCase().contains('lab');

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left icon marker
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isFirst
                    ? (isDark
                        ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                        : const Color(0xFFE0F2FE))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFirst
                      ? (isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFFBAE6FD))
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isLab ? Icons.laptop_mac_rounded : Icons.school_rounded,
                size: 18,
                color: isFirst
                    ? (isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF0284C7))
                    : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          slot.courseTitle.isNotEmpty
                              ? '${slot.courseCode}: ${slot.courseTitle}'
                              : slot.courseCode,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFirst
                              ? (isDark
                                  ? const Color(0xFF0284C7).withValues(alpha: 0.25)
                                  : const Color(0xFFE0F2FE))
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          slot.startTime,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isFirst
                                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          slot.courseCode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isLab
                              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                              : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isLab ? 'Lab' : (slot.isExtraClass ? 'Extra' : 'Theory'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isLab
                                ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          slot.room,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (slot.teacherName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '• ${slot.teacherName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
