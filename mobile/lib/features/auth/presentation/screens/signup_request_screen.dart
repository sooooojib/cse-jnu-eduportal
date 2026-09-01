import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/dialogs/app_dialog.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../domain/usecases/signup_request_usecase.dart';

class SignupRequestScreen extends StatefulWidget {
  final SignupRequestUseCase signupRequestUseCase;

  const SignupRequestScreen({
    super.key,
    required this.signupRequestUseCase,
  });

  @override
  State<SignupRequestScreen> createState() => _SignupRequestScreenState();
}

class _SignupRequestScreenState extends State<SignupRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleIdController = TextEditingController();

  UserRole _selectedRole = UserRole.student;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleIdController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.signupRequestUseCase.execute(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole.value,
        studentId: _selectedRole != UserRole.teacher ? _roleIdController.text.trim() : null,
        phone: _selectedRole == UserRole.teacher ? _roleIdController.text.trim() : null,
      );

      if (!mounted) return;

      await AppDialog.show(
        context: context,
        title: 'Request Submitted',
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined, size: 40, color: AppColors.primary),
        ),
        content: const Text(
          'Your registration request has been submitted for administrative review. You will receive an email with your initial credentials once approved by the department.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          AppPrimaryButton(
            text: 'Return to Login',
            height: 48,
            onPressed: () {
              Navigator.of(context).pop();
              context.go(RouteNames.login);
            },
          ),
        ],
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is Failure ? e.message : e.toString();
      context.showSnackBar(message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Account Request'),
        actions: const [
          ThemeToggleButton(showBackground: false),
          SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Ambient Lighting Orbs (IgnorePointer to never block touches)
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.terminalGlow.withValues(alpha: isDark ? 0.12 : 0.06),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Card Container
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create an Account',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Submit registration request for administrative review',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Account Type Selection
                              Text(
                                'Account Type',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildRoleChoice(UserRole.student, 'Student'),
                                  const SizedBox(width: 8),
                                  _buildRoleChoice(UserRole.teacher, 'Teacher'),
                                  const SizedBox(width: 8),
                                  _buildRoleChoice(UserRole.cr, 'CR'),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Full Name
                              AppTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                hint: 'e.g. Farhan Tanvir',
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                                validator: (val) => Validators.required(val, 'Full name is required'),
                                enabled: !_isSubmitting,
                              ),

                              const SizedBox(height: 16),

                              // Role-Specific Identifier
                              AppTextField(
                                controller: _roleIdController,
                                label: _selectedRole == UserRole.teacher ? 'Phone Number' : 'Student ID',
                                hint: _selectedRole == UserRole.teacher ? '01700000000' : 'B210305015',
                                keyboardType: _selectedRole == UserRole.teacher
                                    ? TextInputType.phone
                                    : TextInputType.text,
                                prefixIcon: Icon(
                                  _selectedRole == UserRole.teacher
                                      ? Icons.phone_outlined
                                      : Icons.badge_outlined,
                                ),
                                validator: _selectedRole == UserRole.teacher
                                    ? Validators.phone
                                    : Validators.studentId,
                                enabled: !_isSubmitting,
                              ),

                              const SizedBox(height: 16),

                              // Email Address
                              AppTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                hint: 'you@example.com',
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: const Icon(Icons.mail_outline_rounded),
                                validator: Validators.email,
                                enabled: !_isSubmitting,
                              ),

                              const SizedBox(height: 24),

                              // Submit Button
                              AppPrimaryButton(
                                text: 'Submit Request',
                                icon: Icons.arrow_forward_rounded,
                                isLoading: _isSubmitting,
                                onPressed: !_isSubmitting ? _handleSubmit : null,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Return to Login
                      Center(
                        child: GestureDetector(
                          onTap: () => context.go(RouteNames.login),
                          child: Text.rich(
                            TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              children: [
                                TextSpan(
                                  text: 'Log in',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF34D399) : AppColors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildRoleChoice(UserRole role, String label) {
    final isSelected = _selectedRole == role;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: _isSubmitting
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedRole = role);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF006948) : AppColors.primary)
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: isSelected
                    ? (isDark ? const Color(0xFF34D399) : AppColors.primary)
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                width: isSelected ? 2.0 : 1.2,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? const Color(0xFF34D399) : Colors.white)
                      : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF334155)),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
