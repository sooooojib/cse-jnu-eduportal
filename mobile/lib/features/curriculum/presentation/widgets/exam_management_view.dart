import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../controllers/schedule_controller.dart';
import 'exam_details_dialog.dart';
import 'exam_form_dialog.dart';

class ExamManagementView extends StatefulWidget {
  final UserRole userRole;
  final int? academicYear;
  final int? academicSemester;
  final String? teacherId;
  final List<String>? teacherAssignedCourseIds;
  final VoidCallback? onRefresh;

  const ExamManagementView({
    super.key,
    required this.userRole,
    this.academicYear,
    this.academicSemester,
    this.teacherId,
    this.teacherAssignedCourseIds,
    this.onRefresh,
  });

  @override
  State<ExamManagementView> createState() => _ExamManagementViewState();
}

class _ExamManagementViewState extends State<ExamManagementView>
    with SingleTickerProviderStateMixin {
  late final ExamsController _examsController;
  late final AuthController _authController;
  late final TabController _subTabController;

  String? _selectedTypeFilter;
  String? _selectedCourseFilter;
  List<Course> _availableCourses = [];

  final List<String> _typeFilters = [
    'ALL',
    'MID_TERM',
    'FINAL',
    'QUIZ',
    'LAB_EXAM',
    'CT',
  ];

  @override
  void initState() {
    super.initState();
    _examsController = sl<ExamsController>();
    _authController = sl<AuthController>();
    _subTabController = TabController(length: 2, vsync: this);

    _loadData();
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _examsController.fetchExams(
      year: widget.academicYear,
      semester: widget.academicSemester,
    );
    _loadCourseFilters();
  }

  Future<void> _loadCourseFilters() async {
    try {
      final courses = await _examsController.fetchAvailableCourses(
        year: widget.academicYear,
        semester: widget.academicSemester,
      );
      if (mounted) {
        setState(() => _availableCourses = courses);
      }
    } catch (_) {}
  }

  bool get canSchedule {
    return widget.userRole == UserRole.admin ||
        widget.userRole == UserRole.cr ||
        widget.userRole == UserRole.teacher;
  }

  Future<void> _openScheduleDialog() async {
    final user = _authController.currentUser;
    final created = await ExamFormDialog.show(
      context: context,
      userRole: widget.userRole,
      defaultYear: widget.academicYear,
      defaultSemester: widget.academicSemester,
      preselectedTeacherId: widget.teacherId ?? user?.id,
      preselectedTeacherName: user?.fullName,
      teacherAssignedCourseIds: widget.teacherAssignedCourseIds,
    );

    if (created == true) {
      if (widget.onRefresh != null) widget.onRefresh!();
      _loadData();
    }
  }

  Future<void> _openDetails(Exam exam) async {
    final user = _authController.currentUser;
    final changed = await ExamDetailsDialog.show(
      context: context,
      exam: exam,
      userRole: widget.userRole,
      userYear: widget.academicYear ?? user?.year,
      userSemester: widget.academicSemester ?? user?.semester,
      userId: user?.id,
      teacherAssignedCourseIds: widget.teacherAssignedCourseIds,
    );

    if (changed == true) {
      if (widget.onRefresh != null) widget.onRefresh!();
      _loadData();
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'FINAL':
        return Colors.deepPurple;
      case 'MID_TERM':
        return AppColors.primary;
      case 'QUIZ':
        return Colors.amber.shade800;
      case 'LAB_EXAM':
        return Colors.teal;
      case 'CT':
        return Colors.blueAccent;
      default:
        return AppColors.primary;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'FINAL':
        return 'Final';
      case 'MID_TERM':
        return 'Mid-Term';
      case 'QUIZ':
        return 'Quiz';
      case 'LAB_EXAM':
        return 'Lab';
      case 'CT':
        return 'Class Test';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _examsController,
      builder: (context, _) {
        final state = _examsController.state;

        return Column(
          children: [
            // Sub-Segmented Control (Upcoming vs Past) & Action Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainerHighDark : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _subTabController,
                        indicator: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: [
                          Tab(
                            text: state is ExamsLoaded
                                ? 'Upcoming (${state.filteredUpcoming.length})'
                                : 'Upcoming',
                          ),
                          Tab(
                            text: state is ExamsLoaded
                                ? 'Past (${state.filteredPast.length})'
                                : 'Past',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (canSchedule) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      key: const Key('schedule_exam_button'),
                      onPressed: _openScheduleDialog,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Schedule'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Filter Chips Bar (where approved)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  ..._typeFilters.map((type) {
                    final isSelected = (_selectedTypeFilter == null && type == 'ALL') ||
                        (_selectedTypeFilter == type);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        key: Key('filter_chip_$type'),
                        label: Text(
                          type == 'ALL' ? 'All Types' : _getTypeLabel(type),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        onSelected: (_) {
                          setState(() {
                            _selectedTypeFilter = type == 'ALL' ? null : type;
                          });
                          _examsController.setFilter(
                            courseId: _selectedCourseFilter,
                            type: _selectedTypeFilter,
                          );
                        },
                      ),
                    );
                  }),
                  if (_availableCourses.isNotEmpty) ...[
                    PopupMenuButton<String?>(
                      tooltip: 'Filter by Course',
                      icon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedCourseFilter != null
                              ? AppColors.primary.withOpacity(0.15)
                              : (isDark ? AppColors.surfaceContainerHighDark : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(20),
                          border: _selectedCourseFilter != null
                              ? Border.all(color: AppColors.primary)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              size: 14,
                              color: _selectedCourseFilter != null ? AppColors.primary : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedCourseFilter != null
                                  ? _availableCourses.firstWhere((c) => c.id == _selectedCourseFilter, orElse: () => _availableCourses.first).code
                                  : 'Course',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _selectedCourseFilter != null ? FontWeight.bold : FontWeight.normal,
                                color: _selectedCourseFilter != null ? AppColors.primary : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onSelected: (cid) {
                        setState(() => _selectedCourseFilter = cid);
                        _examsController.setFilter(
                          courseId: _selectedCourseFilter,
                          type: _selectedTypeFilter,
                        );
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String?>(
                          value: null,
                          child: Text('All Courses', style: TextStyle(fontSize: 13)),
                        ),
                        ..._availableCourses.map((c) {
                          return PopupMenuItem<String?>(
                            value: c.id,
                            child: Text('${c.code}: ${c.title}', style: const TextStyle(fontSize: 13)),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: state is ExamsLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : state is ExamsError
                      ? _buildErrorView(state.message)
                      : state is ExamsLoaded
                          ? TabBarView(
                              controller: _subTabController,
                              children: [
                                _buildExamList(state.filteredUpcoming, isDark, isPastTab: false),
                                _buildExamList(state.filteredPast, isDark, isPastTab: true),
                              ],
                            )
                          : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Exams',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamList(List<Exam> exams, bool isDark, {required bool isPastTab}) {
    if (exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerHighDark : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPastTab ? Icons.history_edu_rounded : Icons.event_available_rounded,
                size: 44,
                color: Colors.grey.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isPastTab ? 'No past exams found.' : 'No upcoming exams scheduled.',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              isPastTab
                  ? 'Completed examination records will appear here.'
                  : 'You have no pending tests or exams at this time.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (!isPastTab && canSchedule) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openScheduleDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Schedule an Exam'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: exams.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final exam = exams[index];
          final typeColor = _getTypeColor(exam.type);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openDetails(exam),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainerDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course code + Type badge + Cohort
                    Row(
                      children: [
                        Text(
                          exam.courseCode,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: typeColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getTypeLabel(exam.type),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Y${exam.year} • S${exam.semester}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      exam.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exam.courseTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Date & Time, Room, Invigilator Row
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Text(
                          exam.examDate,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Text(
                          '${exam.startTime} - ${exam.endTime}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.room_rounded, size: 14, color: Colors.deepOrange),
                        const SizedBox(width: 4),
                        Text(
                          exam.room,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (exam.invigilatorName != null && exam.invigilatorName!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.person_outline_rounded, size: 14, color: Colors.teal),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              exam.invigilatorName!,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
