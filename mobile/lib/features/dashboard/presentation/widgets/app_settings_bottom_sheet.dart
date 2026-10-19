import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class AppSettingsBottomSheet extends StatelessWidget {
  final User? user;
  final AuthController authController;

  const AppSettingsBottomSheet({
    super.key,
    required this.user,
    required this.authController,
  });

  static Future<void> show({
    required BuildContext context,
    required User? user,
    required AuthController authController,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppSettingsBottomSheet(
        user: user,
        authController: authController,
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Sign Out?',
      message: 'Are you sure you want to end your active session and sign out?',
      confirmText: 'Sign Out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(); // Dismiss bottom sheet
      await authController.logout();
      if (context.mounted) {
        context.go(RouteNames.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final themeController = sl.isRegistered<ThemeController>() ? sl<ThemeController>() : null;

    final role = user?.role ?? UserRole.student;
    final roleColor = _getRoleAccentColor(role);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1E33) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: roleColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings & Preferences',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'JnU CSE EduPortal Shell',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // 1. User Identity Capsule
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF13263E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: roleColor.withValues(alpha: 0.15),
                          child: Text(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName.substring(0, 1).toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'Authenticated User',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user?.email ?? '—',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              RoleBadgeChip(role: role),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Theme & Appearance
                  _SectionHeader(title: 'Appearance', icon: Icons.palette_outlined, isDark: isDark),
                  const SizedBox(height: 10),
                  if (themeController != null)
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeController,
                      builder: (context, currentMode, _) {
                        return Material(
                          color: isDark ? const Color(0xFF13263E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                RadioListTile<ThemeMode>(
                                  value: ThemeMode.system,
                                  groupValue: currentMode,
                                  title: const Text('System Mode'),
                                  subtitle: const Text('Follow device theme configuration'),
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    if (val != null) themeController.setThemeMode(val);
                                  },
                                ),
                                const Divider(height: 1),
                                RadioListTile<ThemeMode>(
                                  value: ThemeMode.light,
                                  groupValue: currentMode,
                                  title: const Text('Light Mode'),
                                  subtitle: const Text('Clean Emerald Scholar canvas'),
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    if (val != null) themeController.setThemeMode(val);
                                  },
                                ),
                                const Divider(height: 1),
                                RadioListTile<ThemeMode>(
                                  value: ThemeMode.dark,
                                  groupValue: currentMode,
                                  title: const Text('Dark Mode'),
                                  subtitle: const Text('Obsidian Zinc & high contrast glow'),
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    if (val != null) themeController.setThemeMode(val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),

                  // 3. Departmental & Academic Authority Info
                  _SectionHeader(title: 'Institutional System', icon: Icons.account_balance_outlined, isDark: isDark),
                  const SizedBox(height: 10),
                  Container(
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
                        _InfoRow(label: 'Institution', value: 'Jagannath University, Dhaka', isDark: isDark),
                        _InfoRow(label: 'Department', value: 'Computer Science & Engineering', isDark: isDark),
                        _InfoRow(label: 'Session', value: '2025–2026', isDark: isDark),
                        _InfoRow(label: 'Role Authority', value: role.name.toUpperCase(), isDark: isDark),
                        _InfoRow(label: 'App Version', value: '1.0.0 (Build 19)', isDark: isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Showcase & Navigation
                  _SectionHeader(title: 'Development Preview', icon: Icons.developer_mode_outlined, isDark: isDark),
                  const SizedBox(height: 10),
                  Material(
                    color: isDark ? const Color(0xFF13263E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.palette_rounded, color: AppColors.primary),
                      title: const Text('Foundation Design Showcase'),
                      subtitle: const Text('Browse typography, buttons, and tokens'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(RouteNames.foundationPreview);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Sign Out Action
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                      label: const Text(
                        'Sign Out of Session',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.06),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleAccentColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return const Color(0xFF047857);
      case UserRole.teacher:
        return const Color(0xFF1D4ED8);
      case UserRole.cr:
        return const Color(0xFFC2410C);
      case UserRole.admin:
        return const Color(0xFF7E22CE);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
