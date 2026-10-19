import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/role_colors.dart';
import '../../domain/entities/cr_dashboard_data.dart';
import 'cr_metric_card.dart';

class CrMetricsGrid extends StatelessWidget {
  final CrDashboardData data;
  final VoidCallback onAttendanceTap;
  final VoidCallback onClassesTodayTap;
  final VoidCallback onCounselingTap;
  final VoidCallback onUpcomingExamsTap;

  const CrMetricsGrid({
    super.key,
    required this.data,
    required this.onAttendanceTap,
    required this.onClassesTodayTap,
    required this.onCounselingTap,
    required this.onUpcomingExamsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final crColors = RoleColors.forRole(data.role, isDark: isDark);

    return Column(
      children: [
        Row(
          children: [
            // 1. My Attendance
            Expanded(
              child: CrMetricCard(
                title: 'My Attendance',
                count: '${data.attendancePercentage.toStringAsFixed(1)}%',
                icon: Icons.fingerprint_rounded,
                iconBackgroundColor: isDark
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : const Color(0xFFECFDF5),
                iconColor: AppColors.primary,
                badgeText: data.totalClasses > 0
                    ? (data.isAttendanceEligible ? 'Eligible' : 'Low')
                    : null,
                badgeBackgroundColor: data.isAttendanceEligible
                    ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                    : const Color(0xFFFFDAD6),
                badgeTextColor: data.isAttendanceEligible
                    ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                    : const Color(0xFF93000A),
                onTap: onAttendanceTap,
              ),
            ),
            const SizedBox(width: 12),

            // 2. Classes Today
            Expanded(
              child: CrMetricCard(
                title: 'Classes Today',
                count: '${data.classesTodayCount} Slots',
                icon: Icons.calendar_today_rounded,
                iconBackgroundColor: isDark
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                onTap: onClassesTodayTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // 3. Counseling Slots
            Expanded(
              child: CrMetricCard(
                title: 'Counseling Slots',
                count: '${data.availableCounselingSlotsCount} Available',
                icon: Icons.psychology_rounded,
                iconBackgroundColor: isDark
                    ? crColors.primary.withValues(alpha: 0.2)
                    : crColors.background,
                iconColor: crColors.primary,
                badgeText: data.myActiveCounselingCount > 0
                    ? '${data.myActiveCounselingCount} Booked'
                    : null,
                badgeBackgroundColor: isDark
                    ? crColors.primary.withValues(alpha: 0.25)
                    : crColors.background,
                badgeTextColor: isDark
                    ? crColors.text
                    : crColors.text,
                onTap: onCounselingTap,
              ),
            ),
            const SizedBox(width: 12),

            // 4. Upcoming Exams
            Expanded(
              child: CrMetricCard(
                title: 'Upcoming',
                count: '${data.upcomingExamsCount} Exams',
                icon: Icons.assignment_rounded,
                iconBackgroundColor: isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
                    : const Color(0xFFFEF2F2),
                iconColor: const Color(0xFFDC2626),
                badgeText: data.upcomingExamsCount > 0 ? 'Term Exam' : null,
                badgeBackgroundColor: const Color(0xFFFFDAD6),
                badgeTextColor: const Color(0xFF93000A),
                onTap: onUpcomingExamsTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
