import 'package:flutter/material.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../curriculum/data/models/curriculum_models.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/theme/theme_mode_selector_card.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../curriculum/domain/repositories/curriculum_repository.dart';
import '../../domain/entities/semester_status.dart';
import '../controllers/profile_controller.dart';
import '../widgets/delete_account_button.dart';
import '../../../../core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

class StudentProfileScreen extends StatefulWidget {
  final ProfileController? profileController;
  const StudentProfileScreen({super.key, this.profileController});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late final ProfileController _profileController;
  List<Course> _enrolledCourses = [];
  Set<String> _retakeCourseIds = {};
  bool _isLoadingCourses = true;

  @override
  void initState() {
    super.initState();
    _profileController = widget.profileController ?? sl<ProfileController>();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoadingCourses = true);
    await _profileController.fetchSemesterStatus();
    try {
      final courses = await sl<GetMyCoursesUseCase>().execute();
      Set<String> retakeIds = {};
      final uid = sl<AuthController>().currentUser?.id;
      if (uid != null && sl.isRegistered<CurriculumRepository>()) {
        try {
          final enrollments = await sl<CurriculumRepository>().getEnrollments(studentId: uid);
          // Only the student's own RETAKE enrollments get the badge / ✕
          // (admin-created enrollments can't be removed by the student).
          retakeIds = {
            for (final e in enrollments)
              if (e is EnrollmentModel && e.isRetake) ...e.enrolledCourseIds,
          };
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _enrolledCourses = courses;
          _retakeCourseIds = retakeIds;
          _isLoadingCourses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _showAddRetakeDialog() async {
    if (!sl.isRegistered<CurriculumRepository>()) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final me = sl<AuthController>().currentUser;
      if (me?.year == null || me?.semester == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Your semester is not set yet.')));
        return;
      }
      final myLevel = me!.year! * 10 + me.semester!;
      final allCourses = await sl<CurriculumRepository>().getAllCourses();
      final existingIds = _enrolledCourses.map((c) => c.id).toSet();
      // Retakes are only for courses of an earlier semester than yours.
      final available = allCourses
          .where((c) => !existingIds.contains(c.id) && c.year * 10 + c.semester < myLevel)
          .toList()
        ..sort((a, b) => (a.year * 10 + a.semester).compareTo(b.year * 10 + b.semester) != 0
            ? (a.year * 10 + a.semester).compareTo(b.year * 10 + b.semester)
            : a.code.compareTo(b.code));
      if (!mounted) return;
      if (available.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('No earlier-semester courses available to retake.')));
        return;
      }

      Course selected = available.first;
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Retake / Backlog Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Only courses from earlier semesters. A retake appears in your schedule, attendance and exams; '
                  'attendance counts from today.',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<Course>(
                  value: selected,
                  isExpanded: true,
                  items: available
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              '${c.code} — ${c.title} (Y${c.year}S${c.semester})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selected = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await sl<CurriculumRepository>().addRetakeEnrollment(selected);
                    await _loadProfileData();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Added retake course ${selected.code}.'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(SnackBar(content: Text('Could not add course: ${friendlyError(e)}'), backgroundColor: Colors.redAccent));
                    }
                  }
                },
                child: const Text('Enroll'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Failed to load course catalog: ${friendlyError(e)}'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _removeRetakeCourse(Course course) async {
    final ok = await AppConfirmationDialog.show(
      context: context,
      title: 'Remove retake course?',
      message: '${course.code} will be removed from your schedule, attendance and exams.',
      confirmText: 'Remove',
      isDestructive: true,
      icon: Icons.remove_circle_outline_rounded,
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sl<CurriculumRepository>().removeRetakeEnrollment(course.id);
      await _loadProfileData();
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Removed ${course.code} from retake courses.')));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Failed to remove course: ${friendlyError(e)}'), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _showUpgradeDialog({int? currentYear, int? currentSemester, bool isInitial = false}) {
    int targetYear;
    int targetSemester;

    if (isInitial || currentYear == null || currentSemester == null) {
      targetYear = 1;
      targetSemester = 1;
    } else {
      targetYear = currentSemester == 2 ? (currentYear < 4 ? currentYear + 1 : 4) : currentYear;
      targetSemester = currentSemester == 2 ? 1 : 2;
    }
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isInitial ? 'Initial Semester Enrollment' : 'Request Semester Upgrade',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isInitial
                        ? 'Select your starting academic year and semester to enroll in courses and access department features.'
                        : 'Submit a request to the department administration to advance your academic semester.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: targetYear,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => targetYear = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target Semester', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: targetSemester,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: [1, 2].map((s) => DropdownMenuItem(value: s, child: Text('Sem $s'))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => targetSemester = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await _profileController.requestUpgrade(
                        requestedYear: targetYear,
                        requestedSemester: targetSemester,
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(isInitial
                                ? 'Initial enrollment request submitted for review.'
                                : 'Semester upgrade request submitted for verification.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(friendlyError(e)),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Submit Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangeRequestDialog(SemesterStatus status) {
    int targetYear = status.requestedYear ?? 1;
    int targetSemester = status.requestedSemester ?? 1;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Change Enrollment Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update the target year and semester for your pending enrollment request.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: targetYear,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => targetYear = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target Semester', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: targetSemester,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: [1, 2].map((s) => DropdownMenuItem(value: s, child: Text('Sem $s'))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => targetSemester = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await _profileController.changeUpgradeRequest(
                        requestId: status.requestId ?? '',
                        requestedYear: targetYear,
                        requestedSemester: targetSemester,
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Enrollment request updated successfully.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(friendlyError(e)),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Update Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _dismissRejection(String? requestId) async {
    if (requestId == null || requestId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileController.dismissRejection(requestId: requestId);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Rejection notice dismissed.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildSemesterStatusBadge(SemesterStatus? semesterStatus) {
    Color badgeColor;
    String label;

    if (semesterStatus?.isNoEnrollment == true) {
      badgeColor = Colors.blueGrey;
      label = 'NO ENROLLMENT';
    } else if (semesterStatus?.isPending == true) {
      badgeColor = Colors.orange;
      label = 'PENDING';
    } else if (semesterStatus?.isRejected == true) {
      badgeColor = Colors.redAccent;
      label = 'REJECTED';
    } else {
      badgeColor = Colors.green;
      label = 'ACTIVE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = sl<AuthController>();
    final user = authController.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Student Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        actions: const [
          ThemeToggleButton(showBackground: false),
          SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: _profileController,
        builder: (context, _) {
          final state = _profileController.state;
          final semesterStatus = state is ProfileLoaded ? state.semesterStatus : null;

          return RefreshIndicator(
            color: AppColors.primaryLight,
            onRefresh: _loadProfileData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User identity header card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primaryLight.withOpacity(0.15),
                          child: Text(
                            user != null && user.fullName.isNotEmpty ? user.fullName.substring(0, 1).toUpperCase() : 'S',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'Student Name',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? 'student@jnu.ac.bd',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ID: ${user?.studentId ?? 'B210305015'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Semester Advancement & Status Card (4 States: No Enrollment, Pending, Active/Approved, Rejected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(20),
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
                            const Text(
                              'Academic Semester',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            _buildSemesterStatusBadge(semesterStatus),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          semesterStatus?.isNoEnrollment == true
                              ? 'Current Enrolled: Not Enrolled'
                              : 'Current Enrolled: Year ${semesterStatus?.currentYear ?? user?.year ?? 1}, Semester ${semesterStatus?.currentSemester ?? user?.semester ?? 1}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                          ),
                        ),

                        // State 1: No Enrollment
                        if (semesterStatus?.isNoEnrollment == true) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.withOpacity(0.25)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You are not currently enrolled in an academic semester. Submit an initial enrollment request to join your cohort.',
                                    style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.school, size: 18),
                              label: const Text('Submit Initial Enrollment Request', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryLight,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () => _showUpgradeDialog(isInitial: true),
                            ),
                          ),
                        ]
                        // State 2: Pending Request
                        else if (semesterStatus?.isPending == true) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.hourglass_top, color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Upgrade request to Year ${semesterStatus?.requestedYear}, Sem ${semesterStatus?.requestedSemester} is pending CR/Admin approval.',
                                    style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.edit_calendar, size: 18),
                                  label: const Text('Change Request', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(color: Colors.orange),
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: () => _showChangeRequestDialog(semesterStatus!),
                                ),
                              ),
                            ],
                          ),
                        ]
                        // State 4: Rejected State
                        else if (semesterStatus?.isRejected == true) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Enrollment request for Year ${semesterStatus?.requestedYear ?? ''}, Sem ${semesterStatus?.requestedSemester ?? ''} was rejected.',
                                        style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                if (semesterStatus?.rejectionReason != null && semesterStatus!.rejectionReason!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Reason: ${semesterStatus.rejectionReason}',
                                    style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Dismiss Rejection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: () => _dismissRejection(semesterStatus?.requestId),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Re-apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryLight,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: () => _showUpgradeDialog(
                                    currentYear: semesterStatus?.currentYear ?? user?.year,
                                    currentSemester: semesterStatus?.currentSemester ?? user?.semester,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ]
                        // State 3: Approved / Active
                        else ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.upgrade, size: 18),
                              label: const Text('Request Semester Upgrade', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryLight,
                                side: const BorderSide(color: AppColors.primaryLight),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () => _showUpgradeDialog(
                                currentYear: semesterStatus?.currentYear ?? user?.year ?? 1,
                                currentSemester: semesterStatus?.currentSemester ?? user?.semester ?? 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Display & Theme Mode Selection Card
                  const ThemeModeSelectorCard(),
                  const SizedBox(height: 24),

                  // Enrolled Courses Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Enrolled Courses (${_enrolledCourses.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddRetakeDialog,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Retake'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_isLoadingCourses)
                    const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
                  else if (_enrolledCourses.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('No courses enrolled for this semester.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _enrolledCourses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final course = _enrolledCourses[index];
                        final isRetake = _retakeCourseIds.contains(course.id);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  course.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryLight,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            course.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        if (isRetake) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF7ED),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFFED7AA)),
                                            ),
                                            child: const Text(
                                              'Retake',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${course.credit} Credits • ${course.courseType} • ${course.teacherName ?? 'Assigned Faculty'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isRetake)
                                IconButton(
                                  tooltip: 'Remove Retake Course',
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                                  onPressed: () => _removeRetakeCourse(course),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 32),

                  // Logout Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                      label: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        await authController.logout();
                        if (mounted) {
                          context.go(RouteNames.login);
                        }
                      },
                    ),
                  ),
                  if (user?.role == UserRole.student || user?.role == UserRole.cr) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: DeleteAccountButton(
                        onDeleted: () async {
                          await authController.logout();
                          if (mounted) context.go(RouteNames.login);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
