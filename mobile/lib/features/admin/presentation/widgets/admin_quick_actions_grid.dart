import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/utils/context_extensions.dart';

class AdminQuickActionsGrid extends StatelessWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const AdminQuickActionsGrid({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    final actions = [
      _QuickActionItem(
        title: 'User Directory',
        subtitle: 'Everyone, roles and sessions',
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF7E22CE),
        route: RouteNames.adminUsers,
        targetTabIndex: 1,
      ),
      _QuickActionItem(
        title: 'Signup Requests',
        subtitle: 'New accounts to approve',
        icon: Icons.how_to_reg_outlined,
        color: const Color(0xFFDC2626),
        route: RouteNames.adminSignupRequests,
        targetTabIndex: 2,
      ),
      _QuickActionItem(
        title: 'Semester Requests',
        subtitle: 'Students moving up a semester',
        icon: Icons.school_outlined,
        color: const Color(0xFF2563EB),
        route: RouteNames.adminSemesterRequests,
      ),
      _QuickActionItem(
        title: 'Course Catalog',
        subtitle: 'Courses and targets',
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF047857),
        route: RouteNames.adminCourses,
        targetTabIndex: 3,
      ),
      _QuickActionItem(
        title: 'Teacher Courses',
        subtitle: 'Who teaches what',
        icon: Icons.assignment_ind_outlined,
        color: const Color(0xFFD97706),
        route: RouteNames.adminAssignCourses,
      ),
      _QuickActionItem(
        title: 'Class Routine',
        subtitle: 'Weekly routine per semester',
        icon: Icons.calendar_view_week_rounded,
        color: const Color(0xFF0891B2),
        route: RouteNames.adminRoutine,
      ),
      _QuickActionItem(
        title: 'Teacher Monitoring',
        subtitle: 'Classes held, missed, not taken',
        icon: Icons.insights_outlined,
        color: const Color(0xFF4338CA),
        route: RouteNames.adminTeacherMonitoring,
      ),
      _QuickActionItem(
        title: 'Attendance Logs',
        subtitle: 'All attendance sessions',
        icon: Icons.verified_user_outlined,
        color: const Color(0xFF0D9488),
        route: RouteNames.adminAttendance,
      ),
      _QuickActionItem(
        title: 'Course Feedback',
        subtitle: 'What students said',
        icon: Icons.rate_review_outlined,
        color: const Color(0xFFEA580C),
        route: RouteNames.adminFeedback,
      ),
      _QuickActionItem(
        title: 'Notice & Alerts',
        subtitle: 'Send a notice',
        icon: Icons.campaign_rounded,
        color: const Color(0xFF6366F1),
        route: RouteNames.adminNotifications,
      ),
    ];

    final isWide = MediaQuery.of(context).size.width > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Administrative Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
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
              onTap: () {
                if (item.targetTabIndex != null && onNavigateTab != null) {
                  onNavigateTab!(item.targetTabIndex!);
                } else {
                  context.push(item.route);
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13263E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
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
  final String route;
  final int? targetTabIndex;

  const _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.targetTabIndex,
  });
}
