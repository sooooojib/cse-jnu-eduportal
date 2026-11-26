import '../widgets/class_change_sheet.dart';
import '../widgets/class_changes_card.dart';
import '../widgets/class_actions_sheet.dart';
import '../widgets/class_slot_tile.dart';
import '../../../../core/utils/class_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../controllers/schedule_controller.dart';
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
  final _changesKey = GlobalKey<ClassChangesCardState>();

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

  /// CR: one-day change (extra / cancel / move) for any day this week.
  Future<void> _openChangeSheet() async {
    final user = _authController.currentUser;
    if (user == null) return;
    final saved = await ClassChangeSheet.show(context, user: user);
    if (saved == true) {
      _changesKey.currentState?.reload();
      _loadData();
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
                // One-day changes this week (students read-only; CR can change)
                if (_authController.currentUser != null) ...[
                  ClassChangesCard(
                    key: _changesKey,
                    user: _authController.currentUser!,
                    onChanged: _loadData,
                  ),
                  const SizedBox(height: 16),
                ],
                // CR: one quiet link (changing a class is the "Change" button above).
                if (isCr) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('share_routine_whatsapp'),
                      onPressed: _handleWhatsAppBroadcast,
                      icon: const Icon(Icons.forum_outlined, size: 18),
                      label: const Text('Share routine on WhatsApp'),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  AppErrorStateView(
                    message: state.message,
                    onRetry: _loadData,
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
                          OutlinedButton.icon(
                            onPressed: _openChangeSheet,
                            icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                            label: const Text('Change a Class'),
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

  /// The next date (today included) that falls on [dayOfWeek].
  static DateTime nextDateFor(String dayOfWeek, DateTime now) {
    final today = ClassTime.dateOnly(now);
    for (var i = 0; i < 7; i++) {
      final d = today.add(Duration(days: i));
      if (ClassTime.dayOfWeek(d) == dayOfWeek.toUpperCase()) return d;
    }
    return today;
  }

  Widget _buildListView(List<ScheduleSlot> slots, bool isDark, bool isCr) {
    final user = _authController.currentUser;
    final allDays = _selectedDay == null || _selectedDay == 'ALL';
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final slot = slots[index];
        // A CR may only remove old one-off classes they created themselves;
        // the weekly routine is managed by the Admin / Chairman / teachers.
        final legacyOwn = isCr && (slot.date?.isNotEmpty ?? false) && slot.createdBy == user?.id;
        final Widget? action = legacyOwn
            ? IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                tooltip: 'Delete Slot',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
                onPressed: () => _handleDeleteSlot(slot),
              )
            : (isCr && user != null)
                ? ClassModifyButton(
                    user: user,
                    slot: slot,
                    date: nextDateFor(slot.dayOfWeek, DateTime.now()),
                    onChanged: () {
                      _loadData();
                      _changesKey.currentState?.reload();
                    },
                  )
                : null;
        return ClassSlotTile(slot: slot, showDay: allDays, action: action);
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
