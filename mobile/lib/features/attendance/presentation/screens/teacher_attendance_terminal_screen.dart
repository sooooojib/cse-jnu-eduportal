import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../controllers/attendance_controller.dart';

class TeacherAttendanceTerminalScreen extends StatefulWidget {
  final String? preselectedCourseId;
  final AttendanceController? controller;
  final AuthController? authController;
  final List<String>? assignedCourseIds;
  final bool showAppBar;

  const TeacherAttendanceTerminalScreen({
    super.key,
    this.preselectedCourseId,
    this.controller,
    this.authController,
    this.assignedCourseIds,
    this.showAppBar = true,
  });

  @override
  State<TeacherAttendanceTerminalScreen> createState() => _TeacherAttendanceTerminalScreenState();
}

class _TeacherAttendanceTerminalScreenState extends State<TeacherAttendanceTerminalScreen> {
  late final AttendanceController _controller;
  late final AuthController? _authController;

  String? _selectedCourseId;
  int _selectedDuration = 15;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else if (sl.isRegistered<AttendanceController>()) {
      _controller = sl<AttendanceController>();
    } else {
      final repo = sl.isRegistered<AttendanceRepository>()
          ? sl<AttendanceRepository>()
          : const _FallbackAttendanceRepository();
      _controller = AttendanceController(
        getAttendanceSummaryUseCase: GetAttendanceSummaryUseCase(repo),
        verifyAttendanceCodeUseCase: VerifyAttendanceCodeUseCase(repo),
        startAttendanceSessionUseCase: StartAttendanceSessionUseCase(repo),
        deactivateAttendanceSessionUseCase: DeactivateAttendanceSessionUseCase(repo),
        getActiveAttendanceSessionUseCase: GetActiveAttendanceSessionUseCase(repo),
        getSessionRosterUseCase: GetSessionRosterUseCase(repo),
        updateAttendanceRosterUseCase: UpdateAttendanceRosterUseCase(repo),
      );
    }
    if (widget.authController != null) {
      _authController = widget.authController;
    } else if (sl.isRegistered<AuthController>()) {
      _authController = sl<AuthController>();
    } else {
      _authController = null;
    }
    _selectedCourseId = widget.preselectedCourseId;

    _controller.addListener(_onControllerChanged);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCourseAndSession();
    });
  }

  void _initCourseAndSession() {
    final assignedIds = widget.assignedCourseIds ??
        _authController?.currentUser?.assignedCourseIds ??
        [];

    if (_selectedCourseId == null && assignedIds.isNotEmpty) {
      _selectedCourseId = assignedIds.first;
    }

    if (_selectedCourseId != null) {
      _controller.loadActiveSession(_selectedCourseId!);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final session = _controller.activeSession;
    if (session != null && session.expiresAt != null) {
      _startTimer(session.expiresAt!);
    } else {
      _countdownTimer?.cancel();
      _timeLeft = Duration.zero;
    }
    setState(() {});
  }

  void _startTimer(DateTime expiresAt) {
    _countdownTimer?.cancel();
    final diff = expiresAt.difference(DateTime.now());
    _timeLeft = diff.isNegative ? Duration.zero : diff;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = expiresAt.difference(DateTime.now());
      if (remaining.isNegative) {
        timer.cancel();
        setState(() {
          _timeLeft = Duration.zero;
        });
      } else {
        setState(() {
          _timeLeft = remaining;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _searchController.dispose();
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  Future<void> _handleStartSession() async {
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an authorized course first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final session = await _controller.startSession(
        courseId: _selectedCourseId!,
        durationMinutes: _selectedDuration,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Active session started! Code: ${session.code}'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleDeactivateSession() async {
    final session = _controller.activeSession;
    if (session == null) return;

    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Deactivate Session?',
      message: 'This will immediately close code "${session.code}". Students will no longer be able to submit attendance.',
      confirmText: 'Deactivate',
      isDestructive: true,
      icon: Icons.stop_circle_rounded,
    );

    if (confirmed == true && mounted) {
      try {
        await _controller.deactivateSession(session.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance session closed successfully.'),
              backgroundColor: Color(0xFF047857),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSaveRoster() async {
    try {
      await _controller.saveRoster();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance roster saved successfully.'),
            backgroundColor: Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verification code "$code" copied to clipboard.'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF047857),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _authController?.currentUser;
    final assignedIds = widget.assignedCourseIds ?? user?.assignedCourseIds ?? [];
    final activeSession = _controller.activeSession;
    final rosterList = _controller.editableRoster;

    final filteredRoster = rosterList.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.studentName.toLowerCase().contains(_searchQuery) ||
             item.studentRoll.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Attendance Terminal',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: RoleBadgeChip(role: UserRole.teacher, isCompact: true, customLabel: 'Faculty'),
          ),
        ],
      )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Course Selection Section
            _buildCourseSelector(assignedIds, isDark),

            const SizedBox(height: 16),

            // 2. Active Session Card OR Start Session Controls
            if (activeSession != null && activeSession.isActive)
              _buildActiveSessionCard(activeSession, isDark)
            else
              _buildStartSessionCard(isDark),

            const SizedBox(height: 20),

            // 3. Roster Management Section
            if (activeSession != null || rosterList.isNotEmpty)
              _buildRosterSection(filteredRoster, isDark),
          ],
        ),
      ),
      bottomNavigationBar: (activeSession != null || rosterList.isNotEmpty)
          ? _buildBottomActionStickyBar(isDark)
          : null,
    );
  }

  Widget _buildCourseSelector(List<String> assignedIds, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Authorized Course Target',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (assignedIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No courses assigned. Showing standard department catalog.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assignedIds.map((cid) {
                final isSelected = _selectedCourseId == cid;
                return ChoiceChip(
                  label: Text(
                    cid,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: isDark ? const Color(0xFF0F1E33) : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected && _selectedCourseId != cid) {
                      setState(() => _selectedCourseId = cid);
                      _controller.loadActiveSession(cid);
                    }
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard(AttendanceSession session, bool isDark) {
    final timerString = _timeLeft == Duration.zero
        ? 'Expired'
        : '${_timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds.remainder(60)).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B192C) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SESSION ACTIVE · ${session.courseCode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Text(
                      timerString,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Verification Code',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _copyCode(session.code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13263E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      session.code.split('').join(' '),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy_rounded, color: Color(0xFF059669), size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Present: ${_controller.presentCount} / ${_controller.editableRoster.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _controller.isDeactivatingSession ? null : _handleDeactivateSession,
              icon: _controller.isDeactivatingSession
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                    )
                  : const Icon(Icons.stop_circle_rounded, color: Color(0xFFDC2626)),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Deactivate Attendance Session',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartSessionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Launch Live Attendance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Generates an authoritative 6-char verification code',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Validity Window',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [10, 15, 30].map((mins) {
              final isSel = _selectedDuration == mins;
              return ChoiceChip(
                label: Text('$mins Minutes'),
                selected: isSel,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedDuration = mins);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _controller.isStartingSession ? null : _handleStartSession,
              icon: _controller.isStartingSession
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _controller.isStartingSession ? 'Authorizing & Creating Session...' : 'Start Attendance Session',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterSection(List<AttendanceRosterItem> roster, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Enrolled Student Roster (${roster.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _controller.markAll('PRESENT'),
                  child: const Text('Mark All Present'),
                ),
                TextButton(
                  onPressed: () => _controller.markAll('ABSENT'),
                  child: const Text('Mark All Absent', style: TextStyle(color: Color(0xFFDC2626))),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by student name or roll number...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: isDark ? const Color(0xFF13263E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_controller.isLoadingRoster)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (roster.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _searchQuery.isEmpty ? 'No enrolled students found for this cohort.' : 'No students matching "$_searchQuery"',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: roster.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = roster[index];
              final isPresent = student.isPresent;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13263E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isPresent
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F1E33) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        student.studentRoll,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (student.isManualOverride)
                            const Text(
                              'Manual override',
                              style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _controller.toggleStudentStatus(student.studentId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPresent
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              size: 16,
                              color: isPresent ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isPresent ? 'PRESENT' : 'ABSENT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isPresent ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBottomActionStickyBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _controller.isSavingRoster ? null : _handleSaveRoster,
            icon: _controller.isSavingRoster
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _controller.isSavingRoster ? 'Saving Roster...' : 'Save Attendance (${_controller.presentCount} Present)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackAttendanceRepository implements AttendanceRepository {
  const _FallbackAttendanceRepository();

  @override
  Future<AttendanceSummary> getMySummary() async {
    return const AttendanceSummary(
      overallPercentage: 0,
      totalAttended: 0,
      totalSessions: 0,
      courseSummaries: [],
      recentRecords: [],
    );
  }

  @override
  Future<AttendanceVerificationResult> verifyCode(String code, {String? courseId}) async {
    return const AttendanceVerificationResult(
      success: false,
      message: 'Not connected',
    );
  }

  @override
  Future<AttendanceSession> startSession({required String courseId, int? durationMinutes}) async {
    return AttendanceSession(
      id: 'mock_sess',
      courseId: courseId,
      courseCode: courseId,
      courseTitle: courseId,
      teacherId: 'teacher',
      teacherName: 'Faculty',
      code: '000000',
      isActive: true,
      status: 'ACTIVE',
      sessionDate: '2026-10-19',
      totalPresentCount: 0,
      createdAt: '2026-10-19T10:00:00Z',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<void> deactivateSession({required String sessionId}) async {}

  @override
  Future<AttendanceSession?> getActiveSession({required String courseId}) async => null;

  @override
  Future<SessionRoster> getSessionRoster({required String sessionId}) async {
    return const SessionRoster(
      sessionId: 'mock_sess',
      courseCode: '',
      courseTitle: '',
      sessionDate: '2026-10-19',
      isActive: false,
      totalEnrolled: 0,
      totalPresent: 0,
      roster: [],
    );
  }

  @override
  Future<void> updateRoster({required String sessionId, required List<AttendanceRosterItem> updates}) async {}
}
