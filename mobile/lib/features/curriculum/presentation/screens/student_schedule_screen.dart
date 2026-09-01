import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../controllers/schedule_controller.dart';
import '../../domain/entities/curriculum_entities.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> with SingleTickerProviderStateMixin {
  late final ScheduleController _scheduleController;
  late final ExamsController _examsController;
  late final TabController _tabController;
  String? _selectedDay;

  final List<String> _days = ['ALL', 'SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY'];

  @override
  void initState() {
    super.initState();
    _scheduleController = sl<ScheduleController>();
    _examsController = sl<ExamsController>();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _scheduleController.fetchSchedule(day: _selectedDay == 'ALL' ? null : _selectedDay),
      _examsController.fetchExams(),
    ]);
  }

  void _onDaySelected(String day) {
    setState(() {
      _selectedDay = day;
    });
    _scheduleController.fetchSchedule(day: day == 'ALL' ? null : day);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Tab bar header
          Container(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primaryLight,
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
                _buildClassRoutineTab(isDark),
                _buildExamScheduleTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassRoutineTab(bool isDark) {
    return AnimatedBuilder(
      animation: _scheduleController,
      builder: (context, _) {
        final state = _scheduleController.state;

        return RefreshIndicator(
          color: AppColors.primaryLight,
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
                        selectedColor: AppColors.primaryLight,
                        backgroundColor: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                if (state is ScheduleLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
                  )
                else if (state is ScheduleError)
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                        const SizedBox(height: 8),
                        Text(state.message),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
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
                      children: const [
                        Icon(Icons.calendar_today_outlined, size: 40, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No classes scheduled for this filter.',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else if (state is ScheduleLoaded)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.slots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final slot = state.slots[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Time block
                            Container(
                              width: 68,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    slot.startTime.length >= 5 ? slot.startTime.substring(0, 5) : slot.startTime,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryLight,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    slot.endTime.length >= 5 ? slot.endTime.substring(0, 5) : slot.endTime,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      slot.dayOfWeek.substring(0, 3),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryLight,
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
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          slot.courseTitle,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 15, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        slot.teacherName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.room_outlined, size: 15, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        slot.room,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
      },
    );
  }

  Widget _buildExamScheduleTab(bool isDark) {
    return AnimatedBuilder(
      animation: _examsController,
      builder: (context, _) {
        final state = _examsController.state;

        if (state is ExamsLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
        }

        if (state is ExamsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                const SizedBox(height: 8),
                Text(state.message),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => _examsController.fetchExams(), child: const Text('Retry')),
              ],
            ),
          );
        }

        final exams = state is ExamsLoaded ? state.exams : <Exam>[];

        if (exams.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.assignment_turned_in_outlined, size: 44, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No upcoming examination schedules published yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primaryLight,
          onRefresh: () => _examsController.fetchExams(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: exams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final exam = exams[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.event, color: Colors.purple, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            exam.examDate.length >= 10 ? exam.examDate.substring(5, 10) : exam.examDate,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                              fontSize: 12,
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
                                  color: Colors.purple.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  exam.courseCode,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  exam.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            exam.courseTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${exam.startTime.substring(0, 5)} - ${exam.endTime.substring(0, 5)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.room_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                exam.room,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
