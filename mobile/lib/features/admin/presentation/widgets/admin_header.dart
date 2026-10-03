import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class AdminHeader extends StatelessWidget {
  final User? user;
  final AuthController authController;

  const AdminHeader({
    super.key,
    required this.user,
    required this.authController,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Sign Out?',
      message: 'Are you sure you want to end your administrator session and sign out?',
      confirmText: 'Sign Out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed == true && context.mounted) {
      await authController.logout();
      if (context.mounted) {
        context.go(RouteNames.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final name = user?.fullName.isNotEmpty == true ? user!.fullName : 'System Administrator';
    final initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top action bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF7E22CE).withValues(alpha: 0.15),
                  child: Text(
                    initials.isNotEmpty ? initials : 'AD',
                    style: const TextStyle(
                      color: Color(0xFF7E22CE),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'JnU EduPortal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: Color(0xFF7E22CE),
                      ),
                    ),
                    Text(
                      'Admin Console',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                const ThemeToggleButton(showBackground: false),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Notifications',
                  onPressed: () => context.push(RouteNames.notifications),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Sign Out',
                  onPressed: () => _handleLogout(context),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Modern Executive Welcome Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13263E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF7E22CE).withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Subtle background watermark emblem
              Positioned(
                right: -15,
                top: -15,
                child: Opacity(
                  opacity: isDark ? 0.05 : 0.035,
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 135,
                    color: Color(0xFF7E22CE),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Institution label on left, Live Administrator session on right
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF7E22CE).withValues(alpha: 0.2)
                                          : const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF7E22CE).withValues(alpha: 0.4)
                                            : const Color(0xFFDDD6FE),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_rounded,
                                      size: 13,
                                      color: Color(0xFF7E22CE),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'JAGANNATH UNIVERSITY',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Real-time active status chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                                    : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF059669).withValues(alpha: 0.4)
                                      : const Color(0xFFA7F3D0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF10B981),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.7),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Administrator',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                      color: isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Executive Greeting & Administrator Name
                        Text(
                          'Welcome, $name',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Department of Computer Science & Engineering',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Institutional Metadata Footer Capsule
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF1F5F9),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 14,
                                color: Color(0xFF7E22CE),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Central Authority',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Session 2025–26',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

