import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/role_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../controllers/schedule_controller.dart';
import '../widgets/schedule_slot_form_dialog.dart';
import '../widgets/exam_management_view.dart';
import '../../../../core/communication/whatsapp_share_dialog.dart';
import '../../../../core/communication/whatsapp_share_service.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen>
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
    await Future.wait([
      _scheduleController.fetchSchedule(
        day: _selectedDay == 'ALL' ? null : _selectedDay,
        year: user?.year,
        semester: user?.semester,
      ),
      _examsController.fetchExams(),
    ]);
  }

  void _onDaySelected(String day) {
    setState(() => _selectedDay = day);
    final user = _authController.currentUser;
    _scheduleController.fetchSchedule(
      day: day == 'ALL' ? null : day,
      year: user?.year,
      semester: user?.semester,
    );
  }

  Future<void> _handleDeleteSlot(ScheduleSlot slot) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Cancel Scheduled Class?',
      message: 'Are you sure you want to cancel the scheduled class for ${slot.courseCode} on ${slot.dayOfWeek} at ${slot.startTime}?',
      confirmText: 'Cancel Class',
      isDestructive: true,
      icon: Icons.event_busy_rounded,
    );

    if (confirmed == true && mounted) {
      final success = await _scheduleController.deleteSlot(slot.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Class schedule removed successfully.' : (_scheduleController.actionError ?? 'Failed to delete slot.'),
            ),
            backgroundColor: success ? AppColors.primary : Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openScheduleDialog({ScheduleSlot? existingSlot}) async {
    final user = _authController.currentUser;
    final userRole = user?.role ?? UserRole.student;

    final result = await ScheduleSlotFormDialog.show(
      context: context,
      existingSlot: existingSlot,
      userRole: userRole,
      defaultYear: user?.year,
      defaultSemester: user?.semester,
    );

    if (result == true && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existingSlot != null ? 'Class updated successfully.' : 'Class scheduled successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _handleWhatsAppBroadcast() async {
    final user = _authController.currentUser;
    final broadcast = await _scheduleController.fetchWhatsAppBroadcast(
      year: user?.year,
      semester: user?.semester,
    );

    if (!mounted || broadcast == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate WhatsApp broadcast.')),
      );
      return;
    }

    await WhatsAppShareDialog.show(
      context,
      title: 'WhatsApp Broadcast',
      subtitle: 'Tomorrow (${broadcast.dayOfWeek}, ${broadcast.date}) — ${broadcast.slotCount} Classes',
      messageText: broadcast.broadcastText,
      shareService: sl.isRegistered<WhatsAppShareService>() ? sl<WhatsAppShareService>() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _authController.currentUser;
    final isCr = currentUser?.role == UserRole.cr;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Tab bar header with List/Calendar view toggle
          Container(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppColors.outlineDark.withOpacity(0.2)
                      : AppColors.outlineLight.withOpacity(0.15),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Class Routine'),
                  Tab(text: 'Exam Schedule'),
                ],
              ),
            ),
          ),

          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildClassRoutineTab(isDark, isCr),
                _buildExamScheduleTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassRoutineTab(bool isDark, bool isCr) {
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
                // CR Announcement Card (screens/12_CRs_Schedule_-_EduPortal.html)
                if (isCr) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.stars_rounded, color: Color(0xFFC2410C), size: 20),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'CR Schedule Terminal',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFC2410C),
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFED7AA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Tomorrow Only',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC2410C),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'As Class Representative, you can schedule extra/make-up classes strictly for tomorrow. Collisions across rooms and faculty are prevented atomically.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF7C2D12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _openScheduleDialog(),
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                              label: const Text('Schedule for Tomorrow'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC2410C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _handleWhatsAppBroadcast,
                              icon: const Icon(Icons.forum_outlined, size: 16, color: Color(0xFF25D366)),
                              label: const Text('Broadcast on WhatsApp', style: TextStyle(color: Color(0xFF25D366))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF25D366)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                const SizedBox(height: 16),

                // Loading / Error / Empty / Loaded States
                if (state is ScheduleLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (state is ScheduleError)
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                        const SizedBox(height: 8),
                        Text(state.message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (state is ScheduleLoaded && state.slots.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 40, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No classes scheduled for this filter.',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        if (isCr) ...[
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => _openScheduleDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Schedule for Tomorrow'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC2410C),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else if (state is ScheduleLoaded)
                  _buildListView(state.slots, isDark, isCr),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(List<ScheduleSlot> slots, bool isDark, bool isCr) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final slot = slots[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: slot.isExtraClass
                  ? Colors.orange.withOpacity(0.5)
                  : (isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time block
              Container(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot.startTime,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slot.endTime,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        slot.dayOfWeek.substring(0, 3),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            slot.courseCode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (slot.isExtraClass) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFED7AA)),
                            ),
                            child: const Text(
                              'Extra',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            slot.courseTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 15, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            slot.teacherName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.room_outlined, size: 15, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            slot.room,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions for CR
              if (isCr)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildExamScheduleTab(bool isDark) {
    final user = _authController.currentUser;
    final role = user?.role ?? UserRole.student;
    return ExamManagementView(
      userRole: role,
      academicYear: user?.year,
      academicSemester: user?.semester,
      onRefresh: _loadData,
    );
  }
}
