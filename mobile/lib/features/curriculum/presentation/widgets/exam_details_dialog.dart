import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/communication/whatsapp_share_dialog.dart';
import '../../../../core/communication/whatsapp_share_service.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/class_time.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/exam_support_repository.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/services/exam_rules.dart';
import '../controllers/schedule_controller.dart';
import 'exam_form_dialog.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

/// Exam details with the actions the user is allowed:
/// Edit, Cancel exam (stays listed, struck through), Share on WhatsApp, and
/// Delete (Admin / Chairman only).
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
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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

  /// Same rules as [ExamPermissions.canManage] (and the security rules).
  bool get canModify {
    if (userRole.hasAdminAccess) return true;
    if (userRole == UserRole.cr) {
      return userYear == exam.year && userSemester == exam.semester && exam.type.toUpperCase() != 'FINAL';
    }
    if (userRole.hasTeacherAccess) {
      return teacherAssignedCourseIds?.contains(exam.courseId) == true || (userId != null && exam.createdBy == userId);
    }
    return false;
  }

  bool get canDelete => userRole.hasAdminAccess;

  String get _shareText {
    final d = DateTime.tryParse(exam.examDate);
    final date = d == null ? exam.examDate : DateFormat('EEEE, MMM d, yyyy').format(d);
    final b = StringBuffer()
      ..writeln('*Department of Computer Science & Engineering, JnU*')
      ..writeln('*${ExamTypes.label(exam.type)}${exam.isCancelled ? ' (CANCELLED)' : ''}*')
      ..writeln('')
      ..writeln('*Course:* ${exam.courseTitle.isNotEmpty ? exam.courseTitle : exam.courseCode}')
      ..writeln('*Title:* ${exam.title}')
      ..writeln('*Date:* $date')
      ..writeln('*Time:* ${ClassTime.normalize(exam.startTime)} – ${ClassTime.normalize(exam.endTime)}')
      ..writeln('*Room:* ${exam.room}');
    if (exam.wasMoved) b.writeln('_Postponed from ${exam.previousDate}, ${exam.previousStartTime ?? ''}_');
    if (exam.isCancelled && (exam.statusNote ?? '').isNotEmpty) b.writeln('_Reason: ${exam.statusNote}_');
    if ((exam.instructions ?? '').isNotEmpty) b.writeln('*Syllabus / instructions:* ${exam.instructions}');
    return b.toString();
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await ExamFormDialog.show(
      context: context,
      existingExam: exam,
      userRole: userRole,
      defaultYear: userYear,
      defaultSemester: userSemester,
      preselectedTeacherId: userId,
      teacherAssignedCourseIds: teacherAssignedCourseIds,
    );
    if (updated == true && context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _cancel(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this exam?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('It stays in the list, struck through, so students know. You can reschedule it later with Edit.'),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('exam_cancel_reason'),
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (shown to students)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          TextButton(
            key: const ValueKey('exam_cancel_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Cancel Exam'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (ok != true || !context.mounted) return;
    if (!sl.isRegistered<ExamSupportRepository>()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final support = sl<ExamSupportRepository>();
      await support.cancel(exam, reason: reason);
      final user = sl.isRegistered<AuthController>() ? sl<AuthController>().currentUser : null;
      if (user != null) {
        final cancelled = exam.copyWith(status: 'CANCELLED', statusNote: reason.trim());
        final msg = ExamSupportRepositoryImpl.message(cancelled, kind: 'cancel');
        support.notifySemester(cancelled, title: msg.$1, body: msg.$2, sender: user);
      }
      messenger.showSnackBar(const SnackBar(content: Text('Exam cancelled. Students have been told.')));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not cancel: ${friendlyError(e)}'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Delete Exam Schedule?',
      message: 'Remove "${exam.title}" (${exam.courseCode}) on ${exam.examDate} completely? '
          'Usually it is better to cancel it so students can see what happened.',
      confirmText: 'Delete Exam',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (confirmed != true || !context.mounted) return;
    final examsController = sl<ExamsController>();
    final success = await examsController.deleteExam(exam.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'Exam removed.' : (examsController.actionError ?? 'Failed to delete exam.')),
      backgroundColor: success ? null : const Color(0xFFDC2626),
    ));
    if (success) Navigator.of(context).pop(true);
  }

  void _share(BuildContext context) {
    WhatsAppShareDialog.show(
      context,
      title: 'Share Exam',
      subtitle: '${ExamTypes.label(exam.type)} · Year ${exam.year}, Sem ${exam.semester}',
      messageText: _shareText,
      shareService: sl.isRegistered<WhatsAppShareService>() ? sl<WhatsAppShareService>() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final d = DateTime.tryParse(exam.examDate);
    final date = d == null ? exam.examDate : DateFormat('EEE, MMM d, yyyy').format(d);
    final rel = ExamDates.relative(exam.examDate, DateTime.now());
    final strike = exam.isCancelled ? TextDecoration.lineThrough : null;

    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: muted),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(fontSize: 14, decoration: strike))),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Text('${ExamTypes.label(exam.type)} · Year ${exam.year}, Semester ${exam.semester}',
              style: TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(exam.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, decoration: strike)),
          Text(exam.courseTitle.isNotEmpty ? exam.courseTitle : exam.courseCode,
              style: TextStyle(fontSize: 14, color: muted)),
          if (exam.isCancelled)
            _note(
              (exam.statusNote ?? '').isNotEmpty ? 'Cancelled: ${exam.statusNote}' : 'Cancelled',
              const Color(0xFFDC2626),
              Icons.event_busy_rounded,
            )
          else if (exam.wasMoved)
            _note('Postponed from ${exam.previousDate}, ${exam.previousStartTime ?? ''}', const Color(0xFFD97706),
                Icons.swap_horiz_rounded),
          const SizedBox(height: 6),
          row(Icons.event_rounded, rel.isEmpty ? date : '$date · $rel'),
          row(Icons.schedule_rounded, '${ClassTime.normalize(exam.startTime)} – ${ClassTime.normalize(exam.endTime)}'),
          row(Icons.meeting_room_outlined, exam.room),
          if ((exam.invigilatorName ?? '').isNotEmpty) row(Icons.person_outline_rounded, exam.invigilatorName!),
          if ((exam.instructions ?? '').isNotEmpty) row(Icons.notes_rounded, exam.instructions!),
          const SizedBox(height: 20),
          Row(
            children: [
              if (canModify) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: Text(exam.isCancelled ? 'Reschedule' : 'Edit'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.forum_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          if (canModify && !exam.isCancelled || canDelete) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (canModify && !exam.isCancelled)
                  TextButton.icon(
                    key: const ValueKey('exam_cancel'),
                    onPressed: () => _cancel(context),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                    icon: const Icon(Icons.event_busy_rounded, size: 18),
                    label: const Text('Cancel exam'),
                  ),
                const Spacer(),
                if (canDelete)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _note(String text, Color color, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color))),
            ],
          ),
        ),
      );
}
