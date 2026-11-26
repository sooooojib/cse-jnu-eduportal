import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/cache_metadata.dart';
import '../../../../shared/widgets/states/cached_data_badge.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/attendance_controller.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final AttendanceController? controller;

  const StudentAttendanceScreen({
    super.key,
    this.controller,
  });

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  late final AttendanceController _controller;
  final TextEditingController _codeController = TextEditingController();
  String? _selectedCourseId;

  /// The class the student picked from "Open now".
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? sl<AttendanceController>();
    _controller.fetchSummary();
    _controller.loadOpenSessions();
  }

  /// Current semester plus every earlier one (1-1 .. now), newest first.
  List<(int, int)> get _semesters {
    final me = sl.isRegistered<AuthController>() ? sl<AuthController>().currentUser : null;
    final y = me?.year, s = me?.semester;
    if (y == null || s == null) return const [];
    final out = <(int, int)>[];
    for (var yy = y; yy >= 1; yy--) {
      for (var ss = 2; ss >= 1; ss--) {
        if (yy == y && ss > s) continue;
        out.add((yy, ss));
      }
    }
    return out;
  }

  Widget _semesterPicker() {
    final list = _semesters;
    if (list.length < 2) return const SizedBox.shrink();
    final viewing = _controller.viewingSemester ?? list.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final l in list)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(l == list.first ? 'Now · ${l.$1}-${l.$2}' : '${l.$1}-${l.$2}'),
                  selected: viewing == l,
                  onSelected: (_) => _controller.fetchSummary(semester: l == list.first ? null : l, keepView: false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await Future.wait([_controller.fetchSummary(), _controller.loadOpenSessions()]);
  }

  /// The class the code is checked against: the one tapped, or the only one open.
  String? get _targetSessionId {
    final open = _controller.openSessions;
    if (_selectedSessionId != null && open.any((s) => s.id == _selectedSessionId)) return _selectedSessionId;
    return open.length == 1 ? open.first.id : null;
  }

  static String _shortDate(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }

  Widget _openNow(bool isDark) {
    final open = _controller.openSessions;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final target = _targetSessionId;
    return Column(
      key: const ValueKey('open_now'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                open.length > 1 ? 'Open now · tap your class' : 'Open now',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _controller.loadOpenSessions,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        if (_controller.isLoadingOpenSessions && open.isEmpty)
          const LinearProgressIndicator(minHeight: 3)
        else if (open.isEmpty)
          Text('No class is taking attendance right now.', style: TextStyle(fontSize: 13, color: muted))
        else
          for (final s in open)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: ValueKey('open_session_${s.id}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _selectedSessionId = s.id),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F5F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: s.id == target ? const Color(0xFF059669) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        s.id == target ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 20,
                        color: s.id == target ? const Color(0xFF059669) : muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.courseTitle.isNotEmpty ? s.courseTitle : s.courseCode,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (s.teacherName.isNotEmpty)
                              Text(s.teacherName, style: TextStyle(fontSize: 12.5, color: muted)),
                          ],
                        ),
                      ),
                      if (s.expiresAt != null)
                        Text(
                          'closes ${TimeOfDay.fromDateTime(s.expiresAt!).format(context)}',
                          style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-character verification code.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_controller.openSessions.length > 1 && _targetSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('More than one class is open. Tap your class first.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.submitVerificationCode(code, courseId: _selectedCourseId, sessionId: _targetSessionId);
      _codeController.clear();
      if (mounted) {
        final msg = _controller.lastVerification?.message;
        messenger.showSnackBar(
          SnackBar(
            content: Text(msg == null || msg.isEmpty || msg.contains('success') ? 'Attendance marked successfully!' : '✓ $msg'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = friendlyError(e);
        if (msg.contains('Dart exception thrown from converted Future') || msg.contains('boxed error')) {
          msg = 'Unable to verify code at this time. Please check your network and try again.';
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(msg.isEmpty ? 'Failed to verify attendance code.' : msg),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        if (state is AttendanceLoading && !_controller.isSubmittingCode) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryLight),
          );
        }

        if (state is AttendanceError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(state.message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _controller.fetchSummary(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final summary = state is AttendanceLoaded ? state.summary : null;

        return RefreshIndicator(
          color: AppColors.primaryLight,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Type the code on your teacher\'s screen to mark yourself present.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                  ),
                ),
                if (summary?.isFromCache == true) ...[
                  const SizedBox(height: 12),
                  CachedDataBadge(
                    metadata: CacheMetadata.cached(
                      message: 'Showing cached attendance records (Offline)',
                    ),
                    onRefresh: () => _controller.fetchSummary(),
                  ),
                ],
                const SizedBox(height: 20),

                // Classes of my semester taking attendance right now.
                if (_controller.service != null) ...[
                  _openNow(isDark),
                  const SizedBox(height: 14),
                ],

                // Code entry: a plain card, same as the rest of the app.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF13263E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pin_outlined, size: 20, color: isDark ? const Color(0xFF6EE7B7) : AppColors.primary),
                          const SizedBox(width: 8),
                          const Text('Enter code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _codeController,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(counterText: '', hintText: '6 characters'),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _controller.isSubmittingCode ? null : _submitCode,
                          child: _controller.isSubmittingCode
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Verify & Record Presence'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Past semesters stay visible after promotion (S2-05).
                _semesterPicker(),

                // Course Attendance Standing Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance Standing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                      ),
                    ),
                    if (summary != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Overall: ${summary.overallPercentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (summary == null || summary.courseSummaries.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('No attendance history found.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: summary.courseSummaries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = summary.courseSummaries[index];
                      final isEligible = item.percentage >= 75.0;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F5F8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          item.courseCode,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryLight,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.courseTitle.isNotEmpty ? item.courseTitle : item.courseCode,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${item.percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isEligible ? AppColors.primaryLight : Colors.redAccent,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (item.percentage / 100).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isEligible ? AppColors.primaryLight : Colors.redAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.attendedClasses} / ${item.totalClasses} lectures attended',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isEligible ? 'Eligible' : 'Non-Collegiate / Ineligible',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isEligible ? AppColors.primaryLight : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            // How far from the 75% line, in plain words.
                            if (item.totalClasses > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                isEligible
                                    ? ((item.canMiss ?? 0) == 0
                                        ? 'Don\'t miss the next class to stay above 75%.'
                                        : 'You can miss ${item.canMiss} more class${item.canMiss == 1 ? '' : 'es'} and stay above 75%.')
                                    : 'Attend the next ${item.needToAttend} class${item.needToAttend == 1 ? '' : 'es'} in a row to reach 75%.',
                                key: ValueKey('attendance_advice_${item.courseId}'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isEligible ? (isDark ? Colors.white70 : const Color(0xFF475569)) : Colors.redAccent,
                                ),
                              ),
                            ],
                            if (item.absentDates.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Missed: ${item.absentDates.take(4).map(_shortDate).join(', ')}${item.absentDates.length > 4 ? ' +${item.absentDates.length - 4} more' : ''}',
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 28),

                // Recent Attendance Logs
                Text(
                  'Recent Verifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 12),

                if (summary == null || summary.recentRecords.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('No recent attendance submissions.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: summary.recentRecords.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final record = summary.recentRecords[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.outlineDark.withOpacity(0.15) : AppColors.outlineLight.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${record.courseCode} • ${record.courseTitle}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    record.verifiedAt.length >= 10 ? record.verifiedAt.substring(0, 10) : record.verifiedAt,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'PRESENT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
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
}
