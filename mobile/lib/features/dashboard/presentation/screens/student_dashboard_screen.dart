import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../attendance/presentation/controllers/attendance_controller.dart';
import '../../../curriculum/presentation/controllers/schedule_controller.dart';
import '../../../counseling/presentation/controllers/counseling_controller.dart';
import '../../../feedback/presentation/controllers/feedback_controller.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';

class StudentDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const StudentDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late final AttendanceController _attendanceController;
  late final ScheduleController _scheduleController;
  late final CounselingController _counselingController;
  late final FeedbackController _feedbackController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _attendanceController = sl<AttendanceController>();
    _scheduleController = sl<ScheduleController>();
    _counselingController = sl<CounselingController>();
    _feedbackController = sl<FeedbackController>();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _attendanceController.fetchSummary(),
      _scheduleController.fetchSchedule(),
      _counselingController.fetchAll(),
      _feedbackController.fetchSubmissions(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = sl<AuthController>();
    final user = authController.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryLight),
      );
    }

    // Extract stats
    double attendancePercent = 100.0;
    List<dynamic> courseSummaries = [];
    if (_attendanceController.state is AttendanceLoaded) {
      final summary = (_attendanceController.state as AttendanceLoaded).summary;
      attendancePercent = summary.overallPercentage;
      courseSummaries = summary.courseSummaries;
    }

    int activeCounselingCount = 0;
    if (_counselingController.state is CounselingLoaded) {
      final bookings = (_counselingController.state as CounselingLoaded).myBookings;
      activeCounselingCount = bookings.where((b) => b.status == 'PENDING' || b.status == 'APPROVED').length;
    }

    int feedbackCount = 0;
    if (_feedbackController.state is FeedbackLoaded) {
      feedbackCount = (_feedbackController.state as FeedbackLoaded).submissions.length;
    }

    List<ScheduleSlot> todaySlots = [];
    if (_scheduleController.state is ScheduleLoaded) {
      todaySlots = (_scheduleController.state as ScheduleLoaded).slots;
    }

    return RefreshIndicator(
      color: AppColors.primaryLight,
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome & Student Overview Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, ${user?.fullName ?? 'Student'} 👋',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Student ID: ${user?.studentId ?? 'N/A'} • Year ${user?.year ?? 3}, Sem ${user?.semester ?? 1}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryLight,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bento Metrics Cards Grid
            // 1. Avg Attendance Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF006948), Color(0xFF004D34)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF006948).withOpacity(0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Overall Attendance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.how_to_reg, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${attendancePercent.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        attendancePercent >= 75.0 ? '• Exam Eligible' : '• Low Attendance (<75%)',
                        style: TextStyle(
                          color: attendancePercent >= 75.0 ? const Color(0xFF68DBA9) : const Color(0xFFFFB4AB),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => widget.onNavigateTab?.call(1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Open Attendance Terminal',
                          style: TextStyle(
                            color: Color(0xFF85F8C4),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: Color(0xFF85F8C4), size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3 Small Bento Cards: Counseling, Feedback, Routine
            Row(
              children: [
                // Counseling Card
                Expanded(
                  child: _buildBentoCard(
                    context: context,
                    isDark: isDark,
                    title: 'Counseling',
                    value: '$activeCounselingCount',
                    icon: Icons.psychology_alt,
                    iconColor: Colors.blueAccent,
                    onTap: () => widget.onNavigateTab?.call(3),
                  ),
                ),
                const SizedBox(width: 12),
                // Feedback Card
                Expanded(
                  child: _buildBentoCard(
                    context: context,
                    isDark: isDark,
                    title: 'Feedback',
                    value: '$feedbackCount',
                    icon: Icons.rate_review_outlined,
                    iconColor: Colors.orangeAccent,
                    onTap: () => widget.onNavigateTab?.call(4),
                  ),
                ),
                const SizedBox(width: 12),
                // Schedule Card
                Expanded(
                  child: _buildBentoCard(
                    context: context,
                    isDark: isDark,
                    title: 'Classes',
                    value: '${todaySlots.length}',
                    icon: Icons.calendar_today_outlined,
                    iconColor: AppColors.primaryLight,
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Today's Academic Schedule Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Routine',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(2),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (todaySlots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.event_busy, color: Colors.grey, size: 36),
                    SizedBox(height: 8),
                    Text(
                      'No classes scheduled for today',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todaySlots.take(3).length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final slot = todaySlots[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                slot.startTime.substring(0, 5),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                slot.endTime.substring(0, 5),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      slot.courseCode,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      slot.courseTitle,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${slot.teacherName} • ${slot.room}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryLight),
                          tooltip: 'Verify Attendance',
                          onPressed: () => widget.onNavigateTab?.call(1),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 28),

            // Course Attendance Breakdown Progress
            Text(
              'Course Attendance Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
              ),
            ),
            const SizedBox(height: 12),

            if (courseSummaries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('No course attendance records found.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: courseSummaries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final course = courseSummaries[index];
                  final isEligible = course.percentage >= 75.0;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              course.courseCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${course.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isEligible ? AppColors.primaryLight : Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          course.courseTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (course.percentage / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isEligible ? AppColors.primaryLight : Colors.redAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${course.attendedClasses}/${course.totalClasses} classes attended',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                              ),
                            ),
                            if (!isEligible)
                              const Text(
                                'Below 75% requirement',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
