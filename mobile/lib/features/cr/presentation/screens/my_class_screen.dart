import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/states/app_empty_state_view.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/cr_transfer_repository.dart';
import '../../domain/entities/cr_transfer.dart';
import '../widgets/cr_transfer_cards.dart';

/// "My Class" for Students and CRs: everyone in the same semester and session
/// with their role, plus a "CR Requests" tab.
///
/// * CR: can offer the CR role to a classmate (takes effect when accepted) and
///   sees / cancels their pending offer in the Requests tab.
/// * Student: read-only class list; offers made to them appear in the
///   Requests tab with Accept / Decline.
class MyClassScreen extends StatefulWidget {
  final CrTransferRepository? repository;
  final AuthController? authController;

  /// 0 = Classmates, 1 = CR Requests.
  final int initialTab;

  const MyClassScreen({super.key, this.repository, this.authController, this.initialTab = 0});

  @override
  State<MyClassScreen> createState() => _MyClassScreenState();
}

class _MyClassScreenState extends State<MyClassScreen> with SingleTickerProviderStateMixin {
  late final CrTransferRepository _repo;
  late final AuthController _auth;
  late final TabController _tabs;
  StreamSubscription<CrTransfer?>? _outgoingSub;
  StreamSubscription<List<CrTransfer>>? _incomingSub;

  List<User> _classmates = const [];
  CrTransfer? _outgoing;
  List<CrTransfer> _incoming = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  UserRole? _subscribedRole;
  final _searchCtrl = TextEditingController();

  User? get _me => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? sl<CrTransferRepository>();
    _auth = widget.authController ?? sl<AuthController>();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    _auth.addListener(_onAuthChanged);
    _subscribe();
    _load();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _outgoingSub?.cancel();
    _incomingSub?.cancel();
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Role changes (after a hand-over) switch which transfers we watch.
  void _onAuthChanged() {
    if (!mounted) return;
    if (_me?.role != _subscribedRole) {
      _subscribe();
      _load();
    }
    setState(() {});
  }

  void _subscribe() {
    _outgoingSub?.cancel();
    _incomingSub?.cancel();
    _outgoing = null;
    _incoming = const [];
    final me = _me;
    _subscribedRole = me?.role;
    if (me == null) return;
    if (me.role == UserRole.cr) {
      _outgoingSub = _repo.watchOutgoing(me.id).listen((t) {
        if (!mounted) return;
        setState(() => _outgoing = t);
        if (t?.status == CrTransferStatus.accepted && _me?.role == UserRole.cr) {
          // Role moved to the classmate: reload my profile (switches to student view).
          _auth.refreshCurrentUser();
        }
      }, onError: (_) {});
    } else if (me.role == UserRole.student) {
      _incomingSub = _repo.watchIncoming(me.id).listen((list) {
        if (mounted) setState(() => _incoming = list);
      }, onError: (_) {});
    }
  }

  Future<void> _load() async {
    final me = _me;
    if (me == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getClassmates(me);
      if (!mounted) return;
      setState(() {
        _classmates = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _offer(User classmate) async {
    final me = _me;
    if (me == null) return;
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Transfer CR role?',
      message: '${classmate.fullName} will be asked to become the Class Representative. '
          'You stay CR until they accept. When they accept, you become a regular student.',
      confirmText: 'Send Request',
      icon: Icons.swap_horiz_rounded,
    );
    if (confirmed != true || !mounted) return;
    await _run(() => _repo.requestTransfer(from: me, to: classmate), 'Request sent to ${classmate.fullName}');
  }

  Future<void> _cancel() async {
    final me = _me;
    if (me == null) return;
    await _run(() => _repo.cancel(me.id), 'Transfer request cancelled');
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success), backgroundColor: const Color(0xFF047857)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _requestCount {
    if (_me?.role == UserRole.cr) return (_outgoing?.isPending ?? false) ? 1 : 0;
    return _incoming.length;
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final count = _requestCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Class'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Classmates'),
            Tab(
              key: const ValueKey('cr_requests_tab'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('CR Requests'),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2410C),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$count',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: me == null
          ? const SizedBox.shrink()
          : TabBarView(
              controller: _tabs,
              children: [
                _buildClassmatesTab(context, me),
                _buildRequestsTab(context, me),
              ],
            ),
    );
  }

  // ─── Classmates tab ────────────────────────────────────────────────────────

  Widget _buildClassmatesTab(BuildContext context, User me) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSession = me.session != null && me.session!.trim().isNotEmpty;

    if (!hasSession) {
      return const Center(
        child: AppEmptyStateView(
          title: 'Session Not Set',
          message: 'Your academic session is not set, so your classmates cannot be listed. '
              'Ask the Admin or Chairman to set it from the User Directory.',
          icon: Icons.school_outlined,
        ),
      );
    }
    if (_loading) return const Center(child: AppLoadingView(message: 'Loading your class...'));
    if (_error != null) {
      return Center(child: AppErrorStateView(title: 'Unable to Load Class', message: _error!, onRetry: _load));
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    final everyone = [me, ..._classmates];
    final visible = everyone
        .where((u) =>
            q.isEmpty ||
            u.fullName.toLowerCase().contains(q) ||
            (u.studentId?.toLowerCase().contains(q) ?? false))
        .toList();
    final isCr = me.role == UserRole.cr;
    final pending = (_outgoing?.isPending ?? false) ? _outgoing : null;
    final crCount = everyone.where((u) => u.role == UserRole.cr).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          Text(
            'Year ${me.year} · Semester ${me.semester} · Session ${me.session}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          Text(
            '${everyone.length} students · $crCount CR',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (pending != null)
            _banner(
              key: const ValueKey('cr_transfer_pending_banner'),
              icon: Icons.hourglass_top_rounded,
              text: 'Waiting for ${pending.toName} to accept the CR role.',
              action: TextButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel')),
            ),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Search by name or student ID...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('No classmates found.', style: TextStyle(color: Colors.grey))),
            )
          else
            ...visible.map((u) => _classmateTile(
                  u,
                  isDark,
                  isMe: u.id == me.id,
                  canOffer: isCr && u.id != me.id && pending == null && !_busy,
                )),
        ],
      ),
    );
  }

  Widget _banner({Key? key, required IconData icon, required String text, Widget? action}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9A3412)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF9A3412), fontWeight: FontWeight.w600)),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _classmateTile(User u, bool isDark, {required bool isMe, required bool canOffer}) {
    final initials =
        u.fullName.split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
    final isCr = u.role == UserRole.cr;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCr ? const Color(0xFFFDBA74) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: ListTile(
        key: ValueKey('classmate_${u.id}'),
        leading: CircleAvatar(
          backgroundColor: isCr ? const Color(0xFFFFEDD5) : const Color(0xFFECFDF5),
          child: Text(
            initials.isEmpty ? 'S' : initials,
            style: TextStyle(
              color: isCr ? const Color(0xFFC2410C) : const Color(0xFF047857),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        title: Text(
          isMe ? '${u.fullName} (You)' : u.fullName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              RoleBadgeChip(
                role: isCr ? UserRole.cr : UserRole.student,
                isCompact: true,
                customLabel: isCr ? 'CR' : 'Student',
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text('ID: ${u.studentId ?? '-'}',
                    style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        trailing: canOffer && !isCr
            ? TextButton.icon(
                key: ValueKey('make_cr_${u.id}'),
                onPressed: () => _offer(u),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Make CR'),
              )
            : null,
      ),
    );
  }

  // ─── CR Requests tab ───────────────────────────────────────────────────────

  Widget _buildRequestsTab(BuildContext context, User me) {
    if (me.role == UserRole.student) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CrTransferInvitationCard(
            repository: _repo,
            authController: _auth,
            emptyPlaceholder: const Padding(
              padding: EdgeInsets.only(top: 60),
              child: AppEmptyStateView(
                title: 'No CR Requests',
                message: 'If your CR offers you the Class Representative role, it will appear here.',
                icon: Icons.inbox_outlined,
              ),
            ),
          ),
        ],
      );
    }

    // CR: status of the offer they sent.
    final t = _outgoing;
    final Widget content;
    if (t == null || t.status == CrTransferStatus.cancelled) {
      content = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: AppEmptyStateView(
          title: 'No Active Request',
          message: 'To hand over the CR role, open Classmates and tap "Make CR" next to a student.',
          icon: Icons.inbox_outlined,
        ),
      );
    } else {
      final (label, color, detail) = switch (t.status) {
        CrTransferStatus.pending => ('Waiting for reply', const Color(0xFFC2410C), 'You stay CR until ${t.toName} accepts.'),
        CrTransferStatus.declined => ('Declined', const Color(0xFF64748B), '${t.toName} declined. You are still the CR.'),
        CrTransferStatus.accepted => ('Accepted', const Color(0xFF047857), '${t.toName} is now the CR.'),
        CrTransferStatus.cancelled => ('Cancelled', const Color(0xFF64748B), ''),
      };
      content = Container(
        key: const ValueKey('cr_outgoing_request'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF13263E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Color(0xFFC2410C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('CR role offered to ${t.toName}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, style: const TextStyle(fontSize: 13)),
            if (t.isPending) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _cancel,
                  child: const Text('Cancel Request'),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return ListView(padding: const EdgeInsets.all(16), children: [content]);
  }
}
