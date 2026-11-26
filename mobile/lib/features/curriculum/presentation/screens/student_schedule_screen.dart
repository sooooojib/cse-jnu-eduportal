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
import '../../data/repositories/class_change_repository.dart';
import '../../data/repositories/holiday_repository.dart';
import '../../domain/entities/class_change.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../../domain/services/effective_schedule.dart';
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
  final List<String> _days = ['TODAY', 'TOMORROW', 'ALL', 'SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY'];
  List<ClassChange> _classChanges = const [];
  Map<String, String> _holidays = const {};
  List<ScheduleSlot> _retakeSlots = const [];

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

  String? _queryDayForFilter(String? filter) {
    if (filter == null || filter == 'ALL' || filter == 'TODAY' || filter == 'TOMORROW') {
      return null;
    }
    return filter;
  }

  Future<void> _loadData() async {
    final user = _authController.currentUser;
    await Future.wait<dynamic>([
      _scheduleController.fetchSchedule(
        day: _queryDayForFilter(_selectedDay),
        year: user?.year,
        semester: user?.semester,
      ),
      _examsController.fetchExams(
        year: _examView?.$1 ?? user?.year,
        semester: _examView?.$2 ?? user?.semester,
      ),
      _loadChangesAndHolidays(),
    ]);
  }

  Future<void> _loadChangesAndHolidays() async {
    final user = _authController.currentUser;
    List<ClassChange> changes = const [];
    Map<String, String> holidays = const {};

    if (user?.year != null && user?.semester != null && sl.isRegistered<ClassChangeRepository>()) {
      try {
        final now = ClassTime.now();
        final dates = [...ClassTime.pastDates(now).reversed, ...ClassTime.upcomingDates(now)];
        changes = await sl<ClassChangeRepository>().changesForBatch(
          year: user!.year!,
          semester: user.semester!,
          from: dates.first,
          to: dates.last,
        );
      } catch (_) {}
    }

    if (sl.isRegistered<HolidayRepository>()) {
      try {
        holidays = await sl<HolidayRepository>().holidayMap();
      } catch (_) {}
    }

    List<ScheduleSlot> retakeSlots = const [];
    if (user != null && sl.isRegistered<CurriculumRepository>()) {
      try {
        final repo = sl<CurriculumRepository>();
        final enrollments = await repo.getEnrollments(studentId: user.id);
        final retakeYearsSems = <String, (int, int)>{};
        final retakeCourseIds = <String>{};
        for (final e in enrollments) {
          retakeCourseIds.addAll(e.enrolledCourseIds);
          retakeYearsSems['${e.year}_${e.semester}'] = (e.year, e.semester);
        }
        if (retakeCourseIds.isNotEmpty) {
          final fetched = await Future.wait(
            retakeYearsSems.values.map((ys) => repo.getSchedule(year: ys.$1, semester: ys.$2)),
          );
          // Kept for every weekday; the day chip filters at build time, so
          // switching chips works without reloading.
          retakeSlots = [
            for (final list in fetched)
              for (final s in list)
                if (retakeCourseIds.contains(s.courseId)) s,
          ];
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _classChanges = changes;
      _holidays = holidays;
      _retakeSlots = retakeSlots;
    });
  }

  void _onDaySelected(String day) {
    setState(() => _selectedDay = day);
    final user = _authController.currentUser;
    _scheduleController.fetchSchedule(
      day: _queryDayForFilter(day),
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
                      ? AppColors.outlineDark.withValues(alpha: 0.2)
                      : AppColors.outlineLight.withValues(alpha: 0.15),
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
                          switch (day) {
                            'TODAY' => 'Today',
                            'TOMORROW' => 'Tomorrow',
                            'ALL' => 'All Days',
                            _ => day.substring(0, 3),
                          },
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
                else if (state is ScheduleLoaded) ...[
                  Builder(
                    builder: (context) {
                      final now = ClassTime.now();
                      final DateTime? effectiveDate = switch (_selectedDay) {
                        'TODAY' => ClassTime.dateOnly(now),
                        'TOMORROW' => ClassTime.dateOnly(now.add(const Duration(days: 1))),
                        null || 'ALL' => null,
                        final d => nextDateFor(d, now),
                      };
                      final String? holidayTitle = effectiveDate == null
                          ? null
                          : _holidays[ClassTime.dateKey(effectiveDate)];
                      final chipDay = _queryDayForFilter(_selectedDay);
                      final combinedById = <String, ScheduleSlot>{
                        for (final s in state.slots) s.id: s,
                        for (final s in _retakeSlots)
                          if (chipDay == null || s.dayOfWeek.toUpperCase() == chipDay) s.id: s,
                      };
                      final combinedSlots = combinedById.values.toList();
                      final List<ScheduleSlot> visibleSlots = effectiveDate == null
                          ? combinedSlots
                          : EffectiveSchedule.forDate(
                              routine: combinedSlots,
                              changes: _classChanges,
                              date: effectiveDate,
                              holidays: _holidays,
                            );

                      if (holidayTitle != null && visibleSlots.isEmpty) {
                        return _buildHolidayNoticeCard(holidayTitle, isDark, hasExtras: false);
                      }
                      if (visibleSlots.isEmpty) {
                        return Container(
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
                        );
                      }
                      final list = _buildListView(visibleSlots, isDark, isCr, dateForActions: effectiveDate);
                      return holidayTitle == null
                          ? list
                          : Column(children: [
                              _buildHolidayNoticeCard(holidayTitle, isDark, hasExtras: true),
                              const SizedBox(height: 12),
                              list,
                            ]);
                    },
                  ),
                ],
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

  /// Calm holiday notice (same card style as the rest of the app).
  Widget _buildHolidayNoticeCard(String title, bool isDark, {required bool hasExtras}) {
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    return Container(
      key: const ValueKey('schedule_holiday_notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, size: 22, color: muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Holiday: $title', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  hasExtras
                      ? 'Regular classes are off. Extra classes below still happen.'
                      : 'No regular classes on this date.',
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    List<ScheduleSlot> slots,
    bool isDark,
    bool isCr, {
    DateTime? dateForActions,
  }) {
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
                    date: dateForActions ?? nextDateFor(slot.dayOfWeek, ClassTime.now()),
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

  /// Past semester whose exams are shown (null = current). S2-05: exams of
  /// earlier semesters stay visible after promotion.
  (int, int)? _examView;

  List<(int, int)> _semestersSoFar() {
    final user = _authController.currentUser;
    final y = user?.year, s = user?.semester;
    if (y == null || s == null) return const [];
    return [
      for (var yy = y; yy >= 1; yy--)
        for (var ss = 2; ss >= 1; ss--)
          if (!(yy == y && ss > s)) (yy, ss),
    ];
  }

  Widget _buildExamScheduleTab(bool isDark) {
    final user = _authController.currentUser;
    final list = _semestersSoFar();
    final view = _examView;
    // Past semesters are read-only (nobody schedules exams there).
    final role = view == null ? (user?.role ?? UserRole.student) : UserRole.student;
    return Column(
      children: [
        if (list.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                for (final l in list)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l == list.first ? 'Now · ${l.$1}-${l.$2}' : '${l.$1}-${l.$2}'),
                      selected: (view ?? list.first) == l,
                      onSelected: (_) => setState(() => _examView = l == list.first ? null : l),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ExamManagementView(
            key: ValueKey('exams-${view?.$1}-${view?.$2}'),
            userRole: role,
            academicYear: view?.$1 ?? user?.year,
            academicSemester: view?.$2 ?? user?.semester,
            onRefresh: _loadData,
          ),
        ),
      ],
    );
  }
}
