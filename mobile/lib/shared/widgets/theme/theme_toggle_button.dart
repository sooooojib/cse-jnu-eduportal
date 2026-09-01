import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/di/injection_container.dart';

/// An animated, interactive button to toggle between Light and Dark themes
/// with transitional icon morphing, large hit-target, and haptic feedback.
class ThemeToggleButton extends StatelessWidget {
  final bool showBackground;
  final double size;
  final EdgeInsets padding;

  const ThemeToggleButton({
    super.key,
    this.showBackground = false,
    this.size = 24,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    final themeController = sl<ThemeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, currentMode, _) {
        final tooltip = isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode';

        final iconWidget = AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return RotationTransition(
              turns: Tween<double>(begin: 0.5, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
            );
          },
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey<bool>(isDark),
            size: size,
            color: isDark ? const Color(0xFFFBBF24) : AppColors.primaryLight,
          ),
        );

        void handleToggle() {
          HapticFeedback.selectionClick();
          themeController.toggleTheme(context);
        }

        if (showBackground) {
          return IconButton(
            tooltip: tooltip,
            padding: padding,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.padded,
              backgroundColor: isDark
                  ? AppColors.surfaceContainerHighDark
                  : AppColors.surfaceContainerLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark
                      ? AppColors.outlineDark.withValues(alpha: 0.25)
                      : AppColors.outlineLight.withValues(alpha: 0.15),
                ),
              ),
            ),
            onPressed: handleToggle,
            icon: iconWidget,
          );
        }

        return IconButton(
          tooltip: tooltip,
          padding: padding,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          icon: iconWidget,
          onPressed: handleToggle,
        );
      },
    );
  }
}
