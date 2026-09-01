import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curriculum/presentation/screens/student_schedule_screen.dart';
import '../../../attendance/presentation/screens/student_attendance_screen.dart';
import '../../../counseling/presentation/screens/student_counseling_screen.dart';
import '../../../feedback/presentation/screens/student_feedback_screen.dart';
import '../../../profile/presentation/screens/student_profile_screen.dart';
import '../../../notifications/presentation/screens/notification_list_screen.dart';
import 'student_dashboard_screen.dart';
import '../../../../core/di/injection_container.dart';

class StudentMainScaffold extends StatefulWidget {
  final int initialIndex;

  const StudentMainScaffold({super.key, this.initialIndex = 0});

  @override
  State<StudentMainScaffold> createState() => _StudentMainScaffoldState();
}

class _StudentMainScaffoldState extends State<StudentMainScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = sl<AuthController>();
    final user = authController.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      StudentDashboardScreen(onNavigateTab: _onTabSelected),
      const StudentAttendanceScreen(),
      const StudentScheduleScreen(),
      const StudentCounselingScreen(),
      const StudentFeedbackScreen(),
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
              );
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight.withOpacity(0.12),
              child: Text(
                user != null && user.fullName.isNotEmpty
                    ? user.fullName.substring(0, 1).toUpperCase()
                    : 'S',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        title: const Center(
          child: Text(
            'JnU EduPortal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 19,
              letterSpacing: -0.3,
            ),
          ),
        ),
        actions: [
          const ThemeToggleButton(showBackground: false),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationListScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'My Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.surfaceContainerDark : AppColors.outlineLight.withOpacity(0.2),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                    : (isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight),
                letterSpacing: -0.3,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
              final isSelected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 22,
                color: isSelected
                    ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                    : (isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight),
              );
            }),
            indicatorColor: (isDark ? AppColors.primaryDark : AppColors.primaryLight).withOpacity(0.14),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            elevation: 0,
            backgroundColor: Colors.transparent,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check_rounded),
                label: 'Attendance',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: Icon(Icons.support_agent_outlined),
                selectedIcon: Icon(Icons.support_agent_rounded),
                label: 'Counsel',
              ),
              NavigationDestination(
                icon: Icon(Icons.rate_review_outlined),
                selectedIcon: Icon(Icons.rate_review_rounded),
                label: 'Feedback',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
