import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/constants/role_constants.dart';
import '../../core/utils/context_extensions.dart';
import '../../core/utils/validators.dart';
import '../widgets/buttons/app_primary_button.dart';
import '../widgets/buttons/app_secondary_button.dart';
import '../widgets/buttons/app_text_button.dart';
import '../widgets/inputs/app_text_field.dart';
import '../widgets/cards/app_card.dart';
import '../widgets/cards/role_badge_chip.dart';
import '../widgets/cards/assigned_course_card.dart';
import '../widgets/dialogs/app_dialog.dart';
import '../widgets/dialogs/app_confirmation_dialog.dart';
import '../widgets/states/app_loading_view.dart';
import '../widgets/states/app_empty_state_view.dart';
import '../widgets/states/app_error_state_view.dart';
import '../widgets/theme/theme_toggle_button.dart';
import '../widgets/theme/theme_mode_selector_card.dart';

class FoundationPreviewScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const FoundationPreviewScreen({
    super.key,
    required this.themeModeNotifier,
  });

  @override
  State<FoundationPreviewScreen> createState() => _FoundationPreviewScreenState();
}

class _FoundationPreviewScreenState extends State<FoundationPreviewScreen> {
  bool _isLoadingButton = false;
  final _emailController = TextEditingController(text: 'student@cse.jnu.ac.bd');
  final _passwordController = TextEditingController(text: 'SecurePass123!');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design System Foundation'),
        actions: const [
          ThemeToggleButton(showBackground: false),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: isDark ? AppColors.darkAuthGradient : AppColors.authGradient,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CSE JnU EduPortal',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.onSurfaceLight,
                              ),
                            ),
                            Text(
                              'Emerald Scholar Design System',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : AppColors.onSurfaceVariantLight,
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

            const SizedBox(height: 24),

            // Theme Mode Controls
            _buildSectionHeader('Appearance & Theme Mode'),
            const SizedBox(height: 12),
            const ThemeModeSelectorCard(),

            const SizedBox(height: 32),

            // 1. Role Badges & Context Chips
            _buildSectionHeader('1. Role Context & Badges'),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RoleBadgeChip(role: UserRole.student),
                RoleBadgeChip(role: UserRole.cr),
                RoleBadgeChip(role: UserRole.teacher),
                RoleBadgeChip(role: UserRole.admin),
              ],
            ),

            const SizedBox(height: 32),

            // 2. Obsidian Terminal & Monospace Display
            _buildSectionHeader('2. Obsidian Attendance Terminal Canvas'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.terminalCanvas,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.terminalPod, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.terminalGlow.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.terminalGlow,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIVE ATTENDANCE TERMINAL',
                            style: AppTypography.codeSnippet(fontSize: 12),
                          ),
                        ],
                      ),
                      Text(
                        'CSE-3101',
                        style: AppTypography.codeSnippet(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '849201',
                    style: AppTypography.displayTerminal(fontSize: 44),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Expires in 01:45 • Algorithm Verification',
                    style: AppTypography.codeSnippet(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 3. Reusable Buttons
            _buildSectionHeader('3. Reusable Pill Buttons (52px)'),
            const SizedBox(height: 12),
            AppPrimaryButton(
              text: 'Primary Action (Submit)',
              icon: Icons.check_circle_outline,
              onPressed: () {
                context.showSnackBar('Primary button pressed');
              },
            ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              text: 'Loading Button',
              isLoading: _isLoadingButton,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _isLoadingButton = true);
                await Future.delayed(const Duration(seconds: 2));
                if (!mounted) return;
                setState(() => _isLoadingButton = false);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Action completed')),
                );
              },
            ),
            const SizedBox(height: 12),
            const AppPrimaryButton(
              text: 'Disabled Button',
              onPressed: null,
            ),
            const SizedBox(height: 12),
            AppSecondaryButton(
              text: 'Secondary Outlined Action',
              icon: Icons.refresh,
              onPressed: () {
                context.showSnackBar('Secondary button pressed');
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: AppTextButton(
                text: 'Forgot platform password?',
                onPressed: () {
                  context.showSnackBar('Forgot password link clicked');
                },
              ),
            ),

            const SizedBox(height: 32),

            // 4. Reusable Inputs
            _buildSectionHeader('4. Form Fields & Input System'),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: _emailController,
                    label: 'Institutional Email',
                    hint: 'name@cse.jnu.ac.bd',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordController,
                    label: 'Platform Password',
                    hint: '••••••••••••',
                    isPassword: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),
                  const AppTextField(
                    label: 'Student ID Validation',
                    hint: '2022CSE015',
                    prefixIcon: Icon(Icons.badge_outlined),
                    validator: Validators.studentId,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 5. Course Cards
            _buildSectionHeader('5. Course & Content Cards'),
            const SizedBox(height: 12),
            AssignedCourseCard(
              courseCode: 'CSE-3101',
              courseTitle: 'Database Management Systems & SQL Engines',
              credits: 3.0,
              courseType: 'Theory',
              instructorName: 'Dr. Hasan Rahman (Professor)',
              accentColor: AppColors.primary,
              onTap: () {
                context.showSnackBar('Course CSE-3101 tapped');
              },
            ),
            const SizedBox(height: 12),
            AssignedCourseCard(
              courseCode: 'CSE-3102',
              courseTitle: 'Database Systems Laboratory',
              credits: 1.5,
              courseType: 'Lab',
              instructorName: 'Farhana Akter (Lecturer)',
              accentColor: const Color(0xFF1D4ED8),
              onTap: () {
                context.showSnackBar('Lab CSE-3102 tapped');
              },
            ),

            const SizedBox(height: 32),

            // 6. Dialogs
            _buildSectionHeader('6. Reusable Dialogs'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    text: 'Info Dialog',
                    height: 44,
                    onPressed: () {
                      AppDialog.show(
                        context: context,
                        title: 'Academic Notice',
                        content: const Text(
                          'Semester final examinations for 3rd Year 1st Semester are scheduled to begin next month.',
                        ),
                        actions: [
                          AppPrimaryButton(
                            text: 'Understood',
                            height: 40,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    text: 'Confirm Action',
                    height: 44,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final confirmed = await AppConfirmationDialog.show(
                        context: context,
                        title: 'Sign Out?',
                        message: 'Are you sure you want to invalidate your session and log out?',
                        confirmText: 'Log Out',
                        isDestructive: true,
                        icon: Icons.logout,
                      );
                      if (confirmed == true && mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Session invalidated')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 7. State Views (Loading, Empty, Error)
            _buildSectionHeader('7. State Feedback Views'),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  const AppLoadingView(message: 'Synchronizing academic routine...'),
                  const Divider(height: 32),
                  AppEmptyStateView(
                    title: 'No Pending Counseling Requests',
                    message: 'You have no active office hour appointments booked with professors for this week.',
                    actionText: 'Book Office Hour',
                    onAction: () {
                      context.showSnackBar('Book office hour tapped');
                    },
                  ),
                  const Divider(height: 32),
                  AppErrorStateView(
                    title: 'Unable to Load Routine',
                    message: 'Could not connect to the department server. Please check your internet connection.',
                    onRetry: () {
                      context.showSnackBar('Retrying routine fetch...');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}
