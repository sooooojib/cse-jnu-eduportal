import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/di/injection_container.dart';

/// A card component for settings and profile screens allowing users
/// to select System Default, Light Mode, or Dark Mode.
class ThemeModeSelectorCard extends StatelessWidget {
  const ThemeModeSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = sl<ThemeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, activeMode, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceContainerDark
                : AppColors.surfaceContainerLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppColors.outlineDark.withValues(alpha: 0.2)
                  : AppColors.outlineLight.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Appearance & Theme',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeMode == ThemeMode.system
                              ? 'Following System Mode'
                              : (activeMode == ThemeMode.dark
                                  ? 'Dark Mode Active'
                                  : 'Light Mode Active'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.outlineDark
                                : AppColors.outlineLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quick Switch
                  Switch.adaptive(
                    value: isDark,
                    activeTrackColor: AppColors.primaryLight.withValues(alpha: 0.6),
                    activeThumbColor: AppColors.primaryLight,
                    onChanged: (bool enableDark) {
                      themeController.setThemeMode(
                        enableDark ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // 3 Options Grid: System, Light, Dark
              Row(
                children: [
                  Expanded(
                    child: _buildThemeOption(
                      context: context,
                      title: 'System',
                      subtitle: 'Auto',
                      icon: Icons.brightness_auto_rounded,
                      isSelected: activeMode == ThemeMode.system,
                      isDark: isDark,
                      onTap: () => themeController.setSystem(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildThemeOption(
                      context: context,
                      title: 'Light',
                      subtitle: 'Emerald',
                      icon: Icons.light_mode_rounded,
                      isSelected: activeMode == ThemeMode.light,
                      isDark: isDark,
                      iconColor: const Color(0xFFF59E0B),
                      onTap: () => themeController.setLight(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildThemeOption(
                      context: context,
                      title: 'Dark',
                      subtitle: 'Night',
                      icon: Icons.dark_mode_rounded,
                      isSelected: activeMode == ThemeMode.dark,
                      isDark: isDark,
                      iconColor: const Color(0xFF818CF8),
                      onTap: () => themeController.setDark(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Helpful explanatory note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Dark mode optimizes battery life on OLED screens and reduces visual fatigue during late-night study sessions.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final activeColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
              : (isDark
                  ? AppColors.surfaceContainerHighDark.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark
                    ? AppColors.outlineDark.withValues(alpha: 0.2)
                    : AppColors.outlineLight.withValues(alpha: 0.15)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? activeColor
                      : (iconColor ?? (isDark ? AppColors.outlineDark : AppColors.outlineLight)),
                ),
                if (isSelected)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? activeColor
                    : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
