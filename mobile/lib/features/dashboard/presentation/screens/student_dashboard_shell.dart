import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_state.dart';

class StudentDashboardShell extends StatelessWidget {
  final AuthController authController;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const StudentDashboardShell({
    super.key,
    required this.authController,
    required this.themeModeNotifier,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Sign Out?',
      message: 'Are you sure you want to end your student session and sign out?',
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
    final state = authController.state;
    final User? user = state is Authenticated ? state.user : null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Student Portal'),
        actions: [
          const ThemeToggleButton(showBackground: false),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => _handleLogout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Welcome Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primaryDark.withValues(alpha: 0.3)
                    : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RoleBadgeChip(role: UserRole.student),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome back, ${user?.fullName ?? "Student"}!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ID: ${user?.studentId ?? "—"} • Year ${user?.year ?? 3}, Sem ${user?.semester ?? 1}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : const Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Profile Summary Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const Divider(height: 24),
                  _buildProfileRow('Full Name', user?.fullName ?? '—', context),
                  _buildProfileRow('Institutional Email', user?.email ?? '—', context),
                  _buildProfileRow('Student ID', user?.studentId ?? '—', context),
                  _buildProfileRow(
                    'Academic Term',
                    'Year ${user?.year ?? "—"}, Semester ${user?.semester ?? "—"}',
                    context,
                  ),
                  _buildProfileRow('Semester Upgrade', user?.semesterStatus ?? 'NONE', context),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Foundation & Preview Shortcut
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Design System Preview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explore the Emerald Scholar components, widgets, and state views.',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppPrimaryButton(
                    text: 'View Foundation Showcase',
                    height: 44,
                    onPressed: () => context.push(RouteNames.foundationPreview),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
