import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class TeacherQuickActions extends StatelessWidget {
  final VoidCallback onAttendance;
  final VoidCallback onSchedule;
  final VoidCallback onCounseling;
  final VoidCallback onFeedback;
  final VoidCallback onCourses;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const TeacherQuickActions({
    super.key,
    required this.onAttendance,
    required this.onSchedule,
    required this.onCounseling,
    required this.onFeedback,
    required this.onCourses,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 600;

    final actions = [
      _QuickActionItem(
        title: 'Attendance',
        subtitle: 'Terminal & Code',
        icon: Icons.qr_code_scanner_rounded,
        color: const Color(0xFF0284C7),
        onTap: onAttendance,
      ),
      _QuickActionItem(
        title: 'Schedule',
        subtitle: 'Routine & Classes',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF16A34A),
        onTap: onSchedule,
      ),
      _QuickActionItem(
        title: 'Counseling',
        subtitle: 'Office Hours',
        icon: Icons.groups_rounded,
        color: const Color(0xFF9333EA),
        onTap: onCounseling,
      ),
      _QuickActionItem(
        title: 'Feedback',
        subtitle: 'Student Reviews',
        icon: Icons.forum_rounded,
        color: const Color(0xFFEA580C),
        onTap: onFeedback,
      ),
      _QuickActionItem(
        title: 'Courses',
        subtitle: 'Assigned Units',
        icon: Icons.menu_book_rounded,
        color: AppColors.primaryLight,
        onTap: onCourses,
      ),
      _QuickActionItem(
        title: 'Alerts',
        subtitle: 'Department News',
        icon: Icons.notifications_active_rounded,
        color: const Color(0xFFD97706),
        onTap: onNotifications,
      ),
      _QuickActionItem(
        title: 'Profile',
        subtitle: 'Faculty Account',
        icon: Icons.person_rounded,
        color: const Color(0xFF475569),
        onTap: onProfile,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 4 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isWide ? 2.5 : 2.2,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final item = actions[index];

            return InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13263E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black26
                          : Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
