import 'package:flutter/material.dart';
import '../../domain/entities/admin_stats.dart';

class AdminOverviewGrid extends StatelessWidget {
  final AdminOverviewStats stats;
  final VoidCallback? onStudentsTap;
  final VoidCallback? onFacultyTap;
  final VoidCallback? onCrsTap;
  final VoidCallback? onCoursesTap;
  final VoidCallback? onPendingSignupsTap;
  final VoidCallback? onPendingSemesterTap;
  final VoidCallback? onUsersTap;

  const AdminOverviewGrid({
    super.key,
    required this.stats,
    this.onStudentsTap,
    this.onFacultyTap,
    this.onCrsTap,
    this.onCoursesTap,
    this.onPendingSignupsTap,
    this.onPendingSemesterTap,
    this.onUsersTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            InkWell(
              onTap: onUsersTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Total Users: ${stats.totalUsers}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // 1. Total Students
            _buildStatCard(
              context,
              title: 'Total Students',
              value: '${stats.totalStudents}',
              subtitle: 'Enrolled',
              icon: Icons.school_rounded,
              accentColor: const Color(0xFF047857),
              bgColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFECFDF5),
              onTap: onStudentsTap ?? onUsersTap,
            ),

            // 2. Total Faculty
            _buildStatCard(
              context,
              title: 'Total Faculty',
              value: '${stats.totalTeachers}',
              subtitle: 'Professors',
              icon: Icons.person_outline_rounded,
              accentColor: const Color(0xFF1D4ED8),
              bgColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
              onTap: onFacultyTap ?? onUsersTap,
            ),

            // 3. Total CRs
            _buildStatCard(
              context,
              title: 'Class Reps',
              value: '${stats.totalCrs}',
              subtitle: 'Batch Leaders',
              icon: Icons.campaign_outlined,
              accentColor: const Color(0xFFC2410C),
              bgColor: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.25) : const Color(0xFFFFF7ED),
              onTap: onCrsTap ?? onUsersTap,
            ),

            // 4. Department Courses
            _buildStatCard(
              context,
              title: 'Total Courses',
              value: '${stats.totalCourses}',
              subtitle: 'Curriculum Units',
              icon: Icons.menu_book_rounded,
              accentColor: const Color(0xFF4F46E5),
              bgColor: isDark ? const Color(0xFF312E81).withValues(alpha: 0.25) : const Color(0xFFEEF2FF),
              onTap: onCoursesTap,
            ),

            // 5. Pending Signups
            _buildStatCard(
              context,
              title: 'Pending Signups',
              value: '${stats.pendingSignups}',
              subtitle: stats.pendingSignups > 0 ? 'Requires Action' : 'All Clear',
              icon: Icons.how_to_reg_rounded,
              accentColor: const Color(0xFFDC2626),
              bgColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.25) : const Color(0xFFFEF2F2),
              hasPulse: stats.pendingSignups > 0,
              onTap: onPendingSignupsTap,
            ),

            // 6. Pending Semester Requests
            _buildStatCard(
              context,
              title: 'Semester Requests',
              value: '${stats.pendingSemesterRequests}',
              subtitle: stats.pendingSemesterRequests > 0 ? 'Pending Review' : 'Up to date',
              icon: Icons.upgrade_rounded,
              accentColor: const Color(0xFF7E22CE),
              bgColor: isDark ? const Color(0xFF581C87).withValues(alpha: 0.25) : const Color(0xFFFAF5FF),
              hasPulse: stats.pendingSemesterRequests > 0,
              onTap: onPendingSemesterTap,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    bool hasPulse = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13263E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasPulse
                ? accentColor.withValues(alpha: 0.5)
                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
            width: hasPulse ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                if (hasPulse)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
