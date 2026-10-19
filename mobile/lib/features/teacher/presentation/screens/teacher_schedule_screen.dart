import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/role_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../attendance/presentation/screens/teacher_attendance_terminal_screen.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../curriculum/presentation/controllers/schedule_controller.dart';
import '../../../curriculum/presentation/widgets/schedule_slot_form_dialog.dart';
import '../../../curriculum/presentation/widgets/exam_management_view.dart';

class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final ScheduleController _scheduleController;
  late final ExamsController _examsController;
  late final AuthController _authController;
  late final TabController _tabController;

  String? _selectedDay;
  final List<String> _days = ['ALL', 'SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY'];

  @override
  void initState() {
    super.initState();
    _scheduleController = sl<ScheduleController>();
    _examsController = sl<ExamsController>();
    _authController = sl<AuthController>();
    _tabController = TabController(length: 2, vsync: this);

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = _authController.currentUser;
    await Future.wait<dynamic>([
      _scheduleController.fetchSchedule(
        day: _selectedDay == 'ALL' ? null : _selectedDay,
        teacherId: user?.id,
      ),
      _examsController.fetchExams(),
    ]);
  }

  void _onDaySelected(String day) {
    setState(() => _selectedDay = day);
    final user = _authController.currentUser;
    _scheduleController.fetchSchedule(
      day: day == 'ALL' ? null : day,
      teacherId: user?.id,
    );
  }

  Future<void> _handleDeleteSlot(ScheduleSlot slot) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Delete Class Slot?',
      message: 'Are you sure you want to remove ${slot.courseCode} scheduled on ${slot.dayOfWeek} at ${slot.startTime}? This action cannot be undone.',
      confirmText: 'Delete Slot',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed == true && mounted) {
      final success = await _scheduleController.deleteSlot(slot.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Class schedule slot removed successfully.' : (_scheduleController.actionError ?? 'Failed to delete slot.'),
            ),
            backgroundColor: success ? AppColors.primary : Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openScheduleDialog({ScheduleSlot? existingSlot}) async {
    final user = _authController.currentUser;
    final result = await ScheduleSlotFormDialog.show(
      context: context,
      existingSlot: existingSlot,
      userRole: UserRole.teacher,
      preselectedTeacherId: user?.id,
      preselectedTeacherName: user?.fullName,
    );

    if (result == true && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existingSlot != null ? 'Schedule slot updated successfully.' : 'Class scheduled successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  int _parseTimeToMinutes(String timeStr) {
    try {
      final clean = timeStr.trim();
      final isPm = clean.toUpperCase().contains('PM');
      final isAm = clean.toUpperCase().contains('AM');
      final numParts = clean.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      if (numParts.length >= 2) {
        int h = int.parse(numParts[0]);
        final m = int.parse(numParts[1]);
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        return h * 60 + m;
      }
    } catch (_) {}
    return 0;
  }

  String _determineSlotStatus(ScheduleSlot slot) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _parseTimeToMinutes(slot.startTime);
    final endMinutes = _parseTimeToMinutes(slot.endTime);

    if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
      return 'LIVE';
    } else if (currentMinutes > endMinutes) {
      return 'COMPLETED';
    }
    return 'UPCOMING';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 12,
        title: const Text(
          'Faculty Schedule Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            tooltip: 'Add Class',
            onPressed: () => _openScheduleDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Routine Grid'),
                Tab(text: 'Manage Exams'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoutineGridTab(isDark),
          _buildManageExamsTab(isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openScheduleDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
    );
  }

  Widget _buildRoutineGridTab(bool isDark) {
    return AnimatedBuilder(
      animation: _scheduleController,
      builder: (context, _) {
        final state = _scheduleController.state;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Filter Chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _days.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final day = _days[index];
                      final isSelected = (_selectedDay == null && day == 'ALL') || _selectedDay == day;

                      return FilterChip(
                        label: Text(
                          day == 'ALL' ? 'All Days' : day.substring(0, 3),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => _onDaySelected(day),
                        selectedColor: AppColors.primary,
                        backgroundColor: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Section Header: Today's Classes & Active Semester badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDay == null || _selectedDay == 'ALL' ? "Scheduled Routine" : "$_selectedDay's Classes",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Faculty Teaching Schedule & Attendance',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: RoleColors.teacher.background,
                        border: Border.all(color: RoleColors.teacher.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 13, color: RoleColors.teacher.text),
                          const SizedBox(width: 4),
                          Text(
                            'Active Semester',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: RoleColors.teacher.text),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Schedule Body
                if (state is ScheduleLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (state is ScheduleError)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(state.message, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (state is ScheduleLoaded && state.slots.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.event_available_outlined, size: 48, color: Colors.grey.withOpacity(0.6)),
                        const SizedBox(height: 12),
                        const Text(
                          'No classes scheduled for this filter.',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap "+ Add Class" to create a new routine slot.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openScheduleDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Schedule Class'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (state is ScheduleLoaded)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.slots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final slot = state.slots[index];
                      return _buildTimelineCard(slot, isDark);
                    },
                  ),

                const SizedBox(height: 80), // Padding for FAB
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineCard(ScheduleSlot slot, bool isDark) {
    final status = _determineSlotStatus(slot);
    final isLive = status == 'LIVE';
    final isCompleted = status == 'COMPLETED';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLive
              ? AppColors.primary
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: isLive ? 1.5 : 1,
        ),
        boxShadow: isLive
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live accent top bar
          if (isLive)
            Container(
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta: Time + Status Pill + Day
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: isLive ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${slot.startTime} - ${slot.endTime}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isLive ? AppColors.primary : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${slot.dayOfWeek}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: Colors.redAccent),
                            SizedBox(width: 4),
                            Text(
                              'LIVE NOW',
                              style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Completed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Upcoming', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Course Code & Title
                Text(
                  '${slot.courseCode}: ${slot.courseTitle}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Room & Location
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        slot.room,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Badges & Actions Row
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: RoleColors.student.background,
                          border: Border.all(color: RoleColors.student.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Year ${slot.targetYear} • Sem ${slot.targetSemester}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: RoleColors.student.text),
                        ),
                      ),
                    ),
                    if (slot.isExtraClass) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Extra',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                        ),
                      ),
                    ],
                    const Spacer(),

                    // Edit & Delete Buttons
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Slot',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: const EdgeInsets.all(4),
                      onPressed: () => _openScheduleDialog(existingSlot: slot),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: 'Delete Slot',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: const EdgeInsets.all(4),
                      onPressed: () => _handleDeleteSlot(slot),
                    ),
                  ],
                ),

                // Live CTA: Start Attendance Terminal
                if (isLive) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TeacherAttendanceTerminalScreen(
                              preselectedCourseId: slot.courseId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Start Attendance Terminal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageExamsTab(bool isDark) {
    final user = _authController.currentUser;
    return ExamManagementView(
      userRole: UserRole.teacher,
      teacherId: user?.id,
      teacherAssignedCourseIds: user?.assignedCourseIds,
      onRefresh: _loadData,
    );
  }
}
