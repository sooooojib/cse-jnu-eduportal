import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/context_extensions.dart';

/// Minimalist Branded Launch / Splash View
///
/// Features a pure, distraction-free aesthetic matching the JnU EduPortal theme:
/// - Center: Adaptive squircle badge with the JnU Academic Cap emblem
/// - Bottom: Refined institutional brand lockup
/// - Theme-adaptive: Deep Emerald on clean Ivory (#F8F9FF) in Light Mode,
///   Obsidian Container on Midnight Navy (#0B1C30) with luminous Mint in Dark Mode.
class AppMinimalLaunchView extends StatelessWidget {
  final String? statusMessage;
  final bool showIndicator;

  const AppMinimalLaunchView({
    super.key,
    this.statusMessage,
    this.showIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Emblem & Activity Indicator
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Signature Branded Squircle Emblem
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.primary,
                      borderRadius: BorderRadius.circular(22),
                      border: isDark
                          ? Border.all(
                              color: AppColors.terminalGlow.withValues(alpha: 0.28),
                              width: 1.5,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? AppColors.terminalGlow.withValues(alpha: 0.12)
                              : AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/images/academic_cap_logo.png',
                      width: 44,
                      height: 44,
                      color: isDark ? const Color(0xFF34D399) : Colors.white,
                      fit: BoxFit.contain,
                    ),
                  ),

                  if (showIndicator) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? const Color(0xFF34D399) : AppColors.primary,
                        ),
                      ),
                    ),
                    if (statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        statusMessage!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // Bottom Brand Lockup (LinkedIn-style Anchored Wordmark)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'JnU EduPortal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isDark ? Colors.white : const Color(0xFF0B1C30),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Department of Computer Science & Engineering',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'JAGANNATH UNIVERSITY',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
