import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../admin/domain/repositories/admin_repository.dart';
import '../../../admin/presentation/widgets/admin_filter_dropdown.dart';
import '../../../admin/presentation/widgets/signup_approval_dialog.dart';
import '../../../auth/domain/entities/signup_request.dart';
import '../../../profile/domain/entities/semester_status.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';
import 'package:cse_jnu_eduportal/core/utils/refresh_on_reopen.dart';

/// The teacher's "Requests" side of the dashboard, with two tabs:
///
/// * **Signups** – new Student / CR accounts waiting for approval.
/// * **Semester** – students asking to move to another semester.
///
/// Rows are calm and readable; tapping one opens a details sheet where the
/// teacher approves or rejects. Teacher signups and everything else stay with
/// the Admin / Chairman.
class DelegateAdminView extends StatefulWidget {
  final AdminRepository? repository;

  const DelegateAdminView({super.key, this.repository});

  @override
  State<DelegateAdminView> createState() => _DelegateAdminViewState();
}

class _DelegateAdminViewState extends State<DelegateAdminView> with RefreshOnReopen {
  late final AdminRepository _repository;
  List<SignupRequest>? _signups;
  List<SemesterUpgradeRequest>? _semester;
  String? _error;
  int _tab = 0; // 0 = Signups, 1 = Semester

  // Filters (same dropdown as the User Directory). Null = all.
  String? _sessionFilter; // Signups: academic session, e.g. "2021-22"
  String? _levelFilter; // Semester: current level, e.g. "Year 3 · Sem 1"

  static String _levelOf(SemesterUpgradeRequest r) => 'Year ${r.currentYear} · Sem ${r.currentSemester}';

  // S2-13: new signups / semester requests show up when reopened.
  @override
  void onReopened() => _load();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<AdminRepository>();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repository.getPendingSignupRequests(),
        _repository.getPendingSemesterRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        // Teachers decide Student / CR signups only.
        _signups = (results[0] as List<SignupRequest>).where((r) => r.role.isStudentSide).toList();
        _semester = results[1] as List<SemesterUpgradeRequest>;
        _error = null;
        // A filter whose requests are all decided falls back to "All".
        if (_sessionFilter != null && !_signups!.any((r) => r.session == _sessionFilter)) _sessionFilter = null;
        if (_levelFilter != null && !_semester!.any((r) => _levelOf(r) == _levelFilter)) _levelFilter = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  String _friendly(Object e) {
    final raw = friendlyError(e).trim();
    if (raw.toLowerCase().contains('permission')) {
      return 'You can\'t make this decision. It may already be decided, or it needs the Admin / Chairman.';
    }
    return raw;
  }

  Future<bool> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success), backgroundColor: const Color(0xFF047857)));
      _load();
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_friendly(e)), backgroundColor: const Color(0xFFDC2626)));
      return false;
    }
  }

  Future<String?> _askReason(String title) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const ValueKey('reject_reason'),
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason (shown to the student)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          TextButton(
            key: const ValueKey('reject_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    return ok == true ? text : null;
  }

  static String _ago(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('MMM d').format(t);
  }

  // ─── Details sheets ────────────────────────────────────────────────────

  Future<void> _openSignup(SignupRequest r) async {
    final action = await _sheet<String>(
      title: r.fullName,
      subtitle: '${r.role.label} signup · ${_ago(r.createdAt)}',
      rows: [
        ('Roll / ID', r.studentId ?? '—'),
        ('Email', r.email),
        if ((r.phone ?? '').isNotEmpty) ('Phone', r.phone!),
        ('Session', r.session ?? '—'),
        ('Applied', _date(r.createdAt)),
      ],
      approveLabel: 'Approve',
    );
    if (!mounted || action == null) return;
    if (action == 'approve') {
      final decision = await SignupApprovalDialog.show(context, r);
      if (decision == null) return;
      await _run(
        () => _repository.approveSignup(requestId: r.id, assignedYear: decision.year, assignedSemester: decision.semester),
        'Approved ${r.fullName}',
      );
    } else {
      final reason = await _askReason('Reject ${r.fullName}?');
      if (reason == null) return;
      await _run(
        () => _repository.rejectSignup(requestId: r.id, reason: reason.isEmpty ? 'Not approved.' : reason),
        'Rejected ${r.fullName}',
      );
    }
  }

  Future<void> _openSemester(SemesterUpgradeRequest r) async {
    final action = await _sheet<String>(
      title: r.studentName,
      subtitle: 'Semester change · ${_ago(r.createdAt)}',
      rows: [
        ('Roll', r.studentRoll.isEmpty ? '—' : r.studentRoll),
        ('Now', r.currentLabel),
        ('Wants', r.requestedLabel),
        if ((r.notes ?? '').trim().isNotEmpty) ('Note', r.notes!.trim()),
        ('Asked', _date(r.createdAt)),
      ],
      approveLabel: r.hasRequestedLevel ? 'Approve' : null,
      warning: !r.hasRequestedLevel
          ? 'This request has no requested semester, so it can only be rejected.'
          : (r.requestedYear * 10 + r.requestedSemester <= r.currentYear * 10 + r.currentSemester
              ? 'This moves the student to the same or an earlier semester. Check before approving.'
              : null),
    );
    if (!mounted || action == null) return;
    if (action == 'approve') {
      await _run(
        () => _repository.approveSemesterUpgrade(requestId: r.id),
        '${r.studentName} moved to ${r.requestedLabel}',
      );
    } else {
      final reason = await _askReason('Reject ${r.studentName}\'s request?');
      if (reason == null) return;
      await _run(
        () => _repository.rejectSemesterUpgrade(requestId: r.id, reason: reason),
        'Request rejected',
      );
    }
  }

  static String _date(String iso) {
    final t = DateTime.tryParse(iso);
    return t == null ? '—' : DateFormat('EEE, MMM d · h:mm a').format(t.toLocal());
  }

  /// Bottom sheet with the details and Approve / Reject. Returns 'approve',
  /// 'reject' or null.
  Future<T?> _sheet<T>({
    required String title,
    required String subtitle,
    required List<(String, String)> rows,
    String? approveLabel,
    String? warning,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
        return Padding(
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
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Text(subtitle, style: TextStyle(fontSize: 12.5, color: muted)),
              const SizedBox(height: 14),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 84, child: Text(r.$1, style: TextStyle(fontSize: 13, color: muted))),
                      Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              if (warning != null) ...[
                const SizedBox(height: 10),
                Text(warning, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('request_reject'),
                      onPressed: () => Navigator.pop(ctx, 'reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                      child: const Text('Reject'),
                    ),
                  ),
                  if (approveLabel != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        key: const ValueKey('request_approve'),
                        onPressed: () => Navigator.pop(ctx, 'approve'),
                        child: Text(approveLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final signups = _signups;
    final semester = _semester;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Approve or reject Student / CR signups and semester requests. Teacher signups are handled by the Admin / Chairman.',
          style: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            key: const ValueKey('requests_tabs'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 0,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: Text('Signups${signups == null ? '' : ' (${signups.length})'}'),
              ),
              ButtonSegment(
                value: 1,
                icon: const Icon(Icons.school_outlined, size: 18),
                label: Text('Semester${semester == null ? '' : ' (${semester.length})'}'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        const SizedBox(height: 14),
        if (_error == null && signups != null && semester != null) ...[
          _filter(signups, semester),
          const SizedBox(height: 12),
        ],
        if (_error != null)
          AppErrorStateView(title: 'Unable to Load Requests', message: _friendly(_error!), onRetry: _load)
        else if (signups == null || semester == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: AppLoadingView(message: 'Loading requests...'),
          )
        else if (_tab == 0)
          _list(
            empty: _sessionFilter == null ? 'No signups waiting.' : 'No signups from session $_sessionFilter.',
            children: [
              for (final r in signups)
                if (_sessionFilter == null || r.session == _sessionFilter) _signupRow(r, isDark, muted),
            ],
          )
        else
          _list(
            empty: _levelFilter == null ? 'No semester requests waiting.' : 'No requests from $_levelFilter.',
            children: [
              for (final r in semester)
                if (_levelFilter == null || _levelOf(r) == _levelFilter) _semesterRow(r, isDark, muted),
            ],
          ),
      ],
    );
  }

  /// Signups: by session. Semester requests: by the student's current
  /// level. Options are the values present in the waiting requests.
  Widget _filter(List<SignupRequest> signups, List<SemesterUpgradeRequest> semester) {
    if (_tab == 0) {
      final sessions = {for (final r in signups) if ((r.session ?? '').isNotEmpty) r.session!}.toList()
        ..sort((a, b) => b.compareTo(a)); // newest session first
      final shown = signups.where((r) => _sessionFilter == null || r.session == _sessionFilter).length;
      return AdminFilterDropdown<String>(
        key: const ValueKey('requests_session_filter'),
        label: 'Session${_sessionFilter == null ? '' : ' · $shown'}',
        icon: Icons.calendar_month_outlined,
        value: _sessionFilter,
        options: [
          const FilterOption(null, 'All sessions'),
          for (final v in sessions) FilterOption(v, v),
        ],
        onChanged: (v) => setState(() => _sessionFilter = v),
      );
    }
    final levels = {for (final r in semester) _levelOf(r)}.toList()..sort();
    final shown = semester.where((r) => _levelFilter == null || _levelOf(r) == _levelFilter).length;
    return AdminFilterDropdown<String>(
      key: const ValueKey('requests_level_filter'),
      label: 'Current semester${_levelFilter == null ? '' : ' · $shown'}',
      icon: Icons.school_outlined,
      value: _levelFilter,
      options: [
        const FilterOption(null, 'All semesters'),
        for (final v in levels) FilterOption(v, v),
      ],
      onChanged: (v) => setState(() => _levelFilter = v),
    );
  }

  Widget _list({required String empty, required List<Widget> children}) {
    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(empty, style: const TextStyle(color: Color(0xFF64748B)))),
      );
    }
    return Column(
      children: [
        for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
      ],
    );
  }

  Widget _block({required Key key, required VoidCallback onTap, required bool isDark, required Widget child}) => Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: child,
          ),
        ),
      );

  Widget _signupRow(SignupRequest r, bool isDark, Color muted) {
    return _block(
      key: ValueKey('signup_${r.id}'),
      onTap: () => _openSignup(r),
      isDark: isDark,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [r.studentId ?? '', r.role.label, if ((r.session ?? '').isNotEmpty) 'Session ${r.session}']
                      .where((x) => x.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(fontSize: 12.5, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_ago(r.createdAt), style: TextStyle(fontSize: 12, color: muted)),
          Icon(Icons.chevron_right_rounded, color: muted),
        ],
      ),
    );
  }

  Widget _semesterRow(SemesterUpgradeRequest r, bool isDark, Color muted) {
    final green = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
    return _block(
      key: ValueKey('semester_${r.id}'),
      onTap: () => _openSemester(r),
      isDark: isDark,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.studentName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                if (r.studentRoll.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(r.studentRoll, style: TextStyle(fontSize: 12.5, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: r.currentLabel, style: TextStyle(color: muted)),
                    const TextSpan(text: '  →  '),
                    TextSpan(
                      text: r.requestedLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r.hasRequestedLevel ? green : const Color(0xFFB45309),
                      ),
                    ),
                  ]),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_ago(r.createdAt), style: TextStyle(fontSize: 12, color: muted)),
          Icon(Icons.chevron_right_rounded, color: muted),
        ],
      ),
    );
  }
}
