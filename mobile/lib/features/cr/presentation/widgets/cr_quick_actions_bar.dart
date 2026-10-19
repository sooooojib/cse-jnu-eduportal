import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class CrQuickActionsBar extends StatelessWidget {
  final VoidCallback onSchedule;
  final VoidCallback onExams;
  final VoidCallback onAttendance;
  final VoidCallback onCounseling;
  final VoidCallback onFeedback;
  final VoidCallback onStudentFunctions;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const CrQuickActionsBar({
    super.key,
    required this.onSchedule,
    required this.onExams,
    required this.onAttendance,
    required this.onCounseling,
    required this.onFeedback,
    required this.onStudentFunctions,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = [
      _ActionItem(
        label: 'Schedule',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2563EB),
        bgColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
        onTap: onSchedule,
      ),
      _ActionItem(
        label: 'Exams',
        icon: Icons.assignment_rounded,
        color: const Color(0xFFDC2626),
        bgColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
        onTap: onExams,
      ),
      _ActionItem(
        label: 'Attendance',
        icon: Icons.fingerprint_rounded,
        color: AppColors.primary,
        bgColor: isDark ? AppColors.primary.withValues(alpha: 0.25) : const Color(0xFFECFDF5),
        onTap: onAttendance,
      ),
      _ActionItem(
        label: 'Counseling',
        icon: Icons.psychology_rounded,
        color: const Color(0xFFEA580C),
        bgColor: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.3) : const Color(0xFFFFF7ED),
        onTap: onCounseling,
      ),
      _ActionItem(
        label: 'Feedback',
        icon: Icons.rate_review_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: isDark ? const Color(0xFF581C87).withValues(alpha: 0.3) : const Color(0xFFFAF5FF),
        onTap: onFeedback,
      ),
      _ActionItem(
        label: 'Student View',
        icon: Icons.school_rounded,
        color: const Color(0xFF0891B2),
        bgColor: isDark ? const Color(0xFF164E63).withValues(alpha: 0.3) : const Color(0xFFECFEFF),
        onTap: onStudentFunctions,
      ),
      _ActionItem(
        label: 'Alerts',
        icon: Icons.notifications_rounded,
        color: const Color(0xFFD97706),
        bgColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB),
        onTap: onNotifications,
      ),
      _ActionItem(
        label: 'Profile',
        icon: Icons.person_rounded,
        color: const Color(0xFF475569),
        bgColor: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
        onTap: onProfile,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                size: 18,
                color: const Color(0xFFEA580C),
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final a = actions[index];
              return InkWell(
                onTap: a.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: a.bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.icon, color: a.color, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}
