import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../controllers/schedule_controller.dart';
import 'exam_form_dialog.dart';

class ExamDetailsDialog extends StatelessWidget {
  final Exam exam;
  final UserRole userRole;
  final int? userYear;
  final int? userSemester;
  final String? userId;
  final List<String>? teacherAssignedCourseIds;

  const ExamDetailsDialog({
    super.key,
    required this.exam,
    required this.userRole,
    this.userYear,
    this.userSemester,
    this.userId,
    this.teacherAssignedCourseIds,
  });

  static Future<bool?> show({
    required BuildContext context,
    required Exam exam,
    required UserRole userRole,
    int? userYear,
    int? userSemester,
    String? userId,
    List<String>? teacherAssignedCourseIds,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ExamDetailsDialog(
        exam: exam,
        userRole: userRole,
        userYear: userYear,
        userSemester: userSemester,
        userId: userId,
        teacherAssignedCourseIds: teacherAssignedCourseIds,
      ),
    );
  }

  bool get canModify {
    if (userRole == UserRole.admin) return true;
    if (userRole == UserRole.cr && userYear == exam.year && userSemester == exam.semester) return true;
    if (userRole == UserRole.teacher && (teacherAssignedCourseIds?.contains(exam.courseId) == true || exam.createdBy == userId)) return true;
    if (exam.createdBy == userId && userId != null && userId!.isNotEmpty) return true;
    return false;
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
        return 'Semester Final';
      case 'MID_TERM':
        return 'Mid-Term';
      case 'QUIZ':
        return 'Quiz';
      case 'LAB_EXAM':
        return 'Lab Exam';
      case 'CT':
        return 'Class Test';
      default:
        return type;
    }
  }

  Future<void> _handleEdit(BuildContext context) async {
    final updated = await ExamFormDialog.show(
      context: context,
      existingExam: exam,
      userRole: userRole,
      defaultYear: userYear,
      defaultSemester: userSemester,
      preselectedTeacherId: userId,
      teacherAssignedCourseIds: teacherAssignedCourseIds,
    );

    if (updated == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Delete Exam Schedule?',
      message: 'Are you sure you want to remove the exam "${exam.title}" (${exam.courseCode}) scheduled on ${exam.examDate}? This action cannot be undone.',
      confirmText: 'Delete Exam',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed == true && context.mounted) {
      final examsController = sl<ExamsController>();
      final success = await examsController.deleteExam(exam.id);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exam schedule removed successfully.'),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(examsController.actionError ?? 'Failed to delete exam.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor(exam.type);
    final isPast = exam.isPast;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.surfaceContainerDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  bottom: BorderSide(
                    color: typeColor.withOpacity(0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getTypeLabel(exam.type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPast ? Colors.grey.withOpacity(0.2) : Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPast ? 'COMPLETED' : 'UPCOMING',
                          style: TextStyle(
                            color: isPast ? Colors.grey : Colors.green.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    exam.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${exam.courseCode} — ${exam.courseTitle}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                    ),
                  ),
                ],
              ),
            ),

            // Details Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Date & Time
                  _buildDetailRow(
                    icon: Icons.calendar_today_rounded,
                    iconColor: AppColors.primary,
                    title: 'Date & Time',
                    value: '${exam.examDate} • ${exam.startTime} - ${exam.endTime}',
                  ),
                  const Divider(height: 20),

                  // Room / Venue
                  _buildDetailRow(
                    icon: Icons.room_rounded,
                    iconColor: Colors.deepOrange,
                    title: 'Room / Venue',
                    value: exam.room,
                  ),
                  const Divider(height: 20),

                  // Academic Cohort
                  _buildDetailRow(
                    icon: Icons.groups_rounded,
                    iconColor: Colors.indigo,
                    title: 'Academic Cohort',
                    value: 'Year ${exam.year} • Semester ${exam.semester}',
                  ),
                  const Divider(height: 20),

                  // Invigilator Duty
                  _buildDetailRow(
                    icon: Icons.badge_rounded,
                    iconColor: Colors.teal,
                    title: 'Invigilator Duty',
                    value: (exam.invigilatorName != null && exam.invigilatorName!.isNotEmpty)
                        ? exam.invigilatorName!
                        : 'Department Faculty Assigned',
                  ),

                  // Instructions
                  if (exam.instructions != null && exam.instructions!.isNotEmpty) ...[
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: Colors.amber.shade900,
                      title: 'Instructions / Syllabus',
                      value: exam.instructions!,
                    ),
                  ],
                ],
              ),
            ),

            // Footer / Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.outlineDark.withOpacity(0.15) : AppColors.outlineLight.withOpacity(0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (canModify) ...[
                    IconButton(
                      onPressed: () => _handleDelete(context),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      tooltip: 'Delete Exam',
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _handleEdit(context),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
