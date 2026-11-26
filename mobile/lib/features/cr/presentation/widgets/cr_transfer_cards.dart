import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/cr_transfer_repository.dart';
import '../../domain/entities/cr_transfer.dart';

CrTransferRepository? _defaultRepo() =>
    sl.isRegistered<CrTransferRepository>() ? sl<CrTransferRepository>() : null;

/// Dashboard entry point to "My Class" for Students and CRs.
///
/// * CR: shows their pending offer, and when a classmate accepts it reloads
///   the profile so the app switches to the student view.
/// * Student: highlights a CR role offered to them and opens the
///   "CR Requests" tab directly.
class MyClassCard extends StatefulWidget {
  final CrTransferRepository? repository;
  final AuthController? authController;

  const MyClassCard({super.key, this.repository, this.authController});

  @override
  State<MyClassCard> createState() => _MyClassCardState();
}

class _MyClassCardState extends State<MyClassCard> {
  late final AuthController _auth;
  StreamSubscription<CrTransfer?>? _outgoingSub;
  StreamSubscription<List<CrTransfer>>? _incomingSub;
  CrTransfer? _outgoing;
  List<CrTransfer> _incoming = const [];

  @override
  void initState() {
    super.initState();
    _auth = widget.authController ?? sl<AuthController>();
    final me = _auth.currentUser;
    final repo = widget.repository ?? _defaultRepo();
    if (me == null || repo == null) return;

    if (me.role == UserRole.cr) {
      _outgoingSub = repo.watchOutgoing(me.id).listen((t) {
        if (!mounted) return;
        setState(() => _outgoing = t);
        if (t?.status == CrTransferStatus.accepted && _auth.currentUser?.role == UserRole.cr) {
          _auth.refreshCurrentUser();
        }
      }, onError: (_) {});
    } else if (me.role == UserRole.student) {
      _incomingSub = repo.watchIncoming(me.id).listen((list) {
        if (mounted) setState(() => _incoming = list);
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _outgoingSub?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final me = _auth.currentUser;
    final pendingOut = (_outgoing?.isPending ?? false) ? _outgoing : null;
    final offer = _incoming.isNotEmpty ? _incoming.first : null;
    final highlight = pendingOut != null || offer != null;

    final String subtitle;
    if (offer != null) {
      subtitle = '${offer.fromName} offered you the CR role. Tap to respond.';
    } else if (pendingOut != null) {
      subtitle = 'CR transfer pending: waiting for ${pendingOut.toName}';
    } else if (me?.session != null) {
      subtitle = 'Year ${me!.year} · Semester ${me.semester} · Session ${me.session}';
    } else {
      subtitle = 'See everyone in your semester and session';
    }

    return InkWell(
      key: const ValueKey('my_class_card'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(offer != null || pendingOut != null
          ? '${RouteNames.myClass}?tab=requests'
          : RouteNames.myClass),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13263E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFC2410C).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.groups_rounded, color: Color(0xFFC2410C)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('My Class', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      if (offer != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC2410C).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'CR offer',
                            style: TextStyle(color: Color(0xFFC2410C), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      // An open CR offer / pending transfer is the one thing worth colour.
                      color: highlight
                          ? const Color(0xFFC2410C)
                          : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                      fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// Offer(s) of the CR role made to the signed-in student, with Accept /
/// Decline. Renders [emptyPlaceholder] (or nothing) when there is no offer.
class CrTransferInvitationCard extends StatefulWidget {
  final CrTransferRepository? repository;
  final AuthController? authController;
  final Widget? emptyPlaceholder;

  /// Called after the student accepted or declined.
  final VoidCallback? onResponded;

  const CrTransferInvitationCard({
    super.key,
    this.repository,
    this.authController,
    this.emptyPlaceholder,
    this.onResponded,
  });

  @override
  State<CrTransferInvitationCard> createState() => _CrTransferInvitationCardState();
}

class _CrTransferInvitationCardState extends State<CrTransferInvitationCard> {
  late final AuthController _auth;
  CrTransferRepository? _repo;
  StreamSubscription<List<CrTransfer>>? _sub;
  List<CrTransfer> _offers = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.authController ?? sl<AuthController>();
    _repo = widget.repository ?? _defaultRepo();
    final me = _auth.currentUser;
    if (me != null && _repo != null && me.role == UserRole.student) {
      _sub = _repo!.watchIncoming(me.id).listen((list) {
        if (mounted) setState(() => _offers = list);
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _respond(CrTransfer t, {required bool accept}) async {
    final me = _auth.currentUser;
    if (me == null || _repo == null) return;
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: accept ? 'Become the Class Representative?' : 'Decline the CR role?',
      message: accept
          ? 'You will become the CR for Year ${t.year} · Semester ${t.semester} (Session ${t.session}). '
              '${t.fromName} will become a regular student.'
          : '${t.fromName} will stay the Class Representative.',
      confirmText: accept ? 'Accept' : 'Decline',
      isDestructive: !accept,
      icon: accept ? Icons.verified_user_outlined : Icons.close_rounded,
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (accept) {
        await _repo!.accept(t, myUid: me.id);
        messenger.showSnackBar(const SnackBar(
          content: Text('You are now the Class Representative.'),
          backgroundColor: Color(0xFF047857),
        ));
        // Reload my profile: the app then shows the CR view.
        await _auth.refreshCurrentUser();
      } else {
        await _repo!.decline(t);
        messenger.showSnackBar(const SnackBar(content: Text('CR role declined.')));
      }
      widget.onResponded?.call();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_offers.isEmpty) return widget.emptyPlaceholder ?? const SizedBox.shrink();
    final t = _offers.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('cr_transfer_invitation'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B1D0A) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: Color(0xFFC2410C)),
              SizedBox(width: 8),
              Expanded(
                child: Text('CR Role Offered',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFC2410C))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${t.fromName} wants to transfer the Class Representative role to you.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF431407)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _respond(t, accept: false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC2410C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: _busy ? null : () => _respond(t, accept: true),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
