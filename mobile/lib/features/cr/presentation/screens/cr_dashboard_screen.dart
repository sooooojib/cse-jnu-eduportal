import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/cr_dashboard_controller.dart';
import '../widgets/batch_dashboard_view.dart';

/// Class Representative (CR) Dashboard — delegates rendering to
/// [BatchDashboardView] with CR-level actions enabled (`isCrMode: true`).
class CrDashboardScreen extends StatefulWidget {
  final CrDashboardController? controller;
  final bool wrapWithScaffold;
  final void Function(int tabIndex)? onNavigateTab;

  const CrDashboardScreen({
    super.key,
    this.controller,
    this.wrapWithScaffold = true,
    this.onNavigateTab,
  });

  @override
  State<CrDashboardScreen> createState() => _CrDashboardScreenState();
}

class _CrDashboardScreenState extends State<CrDashboardScreen> {
  late final CrDashboardController _controller;

  /// True when this screen created the controller (from the DI factory);
  /// a controller passed in by the caller is theirs to dispose.
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? sl<CrDashboardController>();
    _controller.loadDashboardData();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BatchDashboardView(
      controller: _controller,
      authController: sl.isRegistered<AuthController>() ? sl<AuthController>() : null,
      isCrMode: true,
      wrapWithScaffold: widget.wrapWithScaffold,
      onNavigateTab: widget.onNavigateTab,
    );
  }
}
