import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/utils/context_extensions.dart';

class AdminQuickActionsGrid extends StatelessWidget {
  const AdminQuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    final actions = [
      _QuickActionItem(
        title: 'User Directory',
        subtitle: 'Directory & Roles',
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF7E22CE),
        route: RouteNames.adminUsers,
      ),
      _QuickActionItem(
        title: 'Signup Requests',
        subtitle: 'Petitions Queue',
        icon: Icons.how_to_reg_outlined,
        color: const Color(0xFFDC2626),
        route: RouteNames.adminSignupRequests,
      ),
      _QuickActionItem(
        title: 'Semester Requests',
        subtitle: 'Promotion Petitions',
        icon: Icons.school_outlined,
        color: const Color(0xFF2563EB),
        route: RouteNames.adminSemesterRequests,
      ),
      _QuickActionItem(
        title: 'Course Catalog',
        subtitle: 'Curriculum Units',
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF047857),
        route: RouteNames.adminCourses,
      ),
      _QuickActionItem(
        title: 'Teacher Courses',
        subtitle: 'Faculty Allocations',
        icon: Icons.assignment_ind_outlined,
        color: const Color(0xFFD97706),
        route: RouteNames.adminAssignCourses,
      ),
      _QuickActionItem(
        title: 'Attendance Logs',
        subtitle: 'Sessions & Audit',
        icon: Icons.verified_user_outlined,
        color: const Color(0xFF0D9488),
        route: RouteNames.adminAttendance,
      ),
      _QuickActionItem(
        title: 'Course Feedback',
        subtitle: 'Quality Assurance',
        icon: Icons.rate_review_outlined,
        color: const Color(0xFFEA580C),
        route: RouteNames.adminFeedback,
      ),
      _QuickActionItem(
        title: 'Notice & Alerts',
        subtitle: 'Broadcast Hub',
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
              onTap: () => context.push(item.route),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13263E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.02),
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
  final String route;

  const _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}
