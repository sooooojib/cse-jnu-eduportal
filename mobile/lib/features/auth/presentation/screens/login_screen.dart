import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/buttons/app_text_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/dialogs/app_dialog.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';

class LoginScreen extends StatefulWidget {
  final AuthController authController;

  const LoginScreen({
    super.key,
    required this.authController,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await widget.authController.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      final state = widget.authController.state;
      if (state is Authenticated) {
        _routeForRole(state.user.role);
      }
    } else {
      final state = widget.authController.state;
      if (state is AuthError) {
        context.showSnackBar(state.message, isError: true);
      } else if (state is AuthAccountDisabled) {
        context.showSnackBar(state.message, isError: true);
      }
    }
  }

  void _routeForRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        context.go(RouteNames.studentDashboard);
        break;
      case UserRole.teacher:
        context.go(RouteNames.teacherDashboard);
        break;
      case UserRole.cr:
        context.go(RouteNames.crDashboard);
        break;
      case UserRole.admin:
        context.go(RouteNames.adminDashboard);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 100) {
              return const SizedBox.shrink();
            }
            return AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RouteNames.welcome);
                  }
                },
              ),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: ThemeToggleButton(),
                ),
              ],
            );
          },
        ),
      ),
      body: Stack(
        children: [
          // Decorative ambient background glow orbs (IgnorePointer to never block touch)
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -100,
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -120,
                  left: -100,
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.terminalGlow.withValues(alpha: isDark ? 0.12 : 0.06),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Login Content
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                  child: ListenableBuilder(
                    listenable: widget.authController,
                    builder: (context, _) {
                      final isLoading = widget.authController.state is AuthLoading;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Brand Crest Header with Academic Cap on Books
                          Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primaryDark.withValues(alpha: 0.3)
                                  : const Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primaryDark
                                    : const Color(0xFFA7F3D0),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/academic_cap_logo.png',
                              color: isDark ? AppColors.terminalGlow : AppColors.primary,
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Brand Title & Subtitle
                          Text(
                            'JnU EduPortal',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Department of Computer Science & Engineering',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Form Card Container
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
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
                                    'Log in to Portal',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enter your credentials to continue',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Email Field
                                  AppTextField(
                                    controller: _emailController,
                                    label: 'Email address',
                                    hint: 'you@example.com',
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                                    validator: Validators.email,
                                    enabled: !isLoading,
                                  ),

                                  const SizedBox(height: 16),

                                  // Password Field
                                  AppTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    hint: '••••••••••••',
                                    isPassword: true,
                                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return 'Password is required';
                                      }
                                      return null;
                                    },
                                    onSubmitted: (_) => _handleLogin(),
                                    enabled: !isLoading,
                                  ),

                                  const SizedBox(height: 8),

                                  // Forgot password link
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        final resetEmailController = TextEditingController(text: _emailController.text.trim());
                                        AppDialog.show(
                                          context: context,
                                          title: 'Reset Password',
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Enter your registered institutional email to receive a password reset link:',
                                                style: TextStyle(fontSize: 14, height: 1.4),
                                              ),
                                              const SizedBox(height: 12),
                                              AppTextField(
                                                controller: resetEmailController,
                                                label: 'Email address',
                                                hint: 'you@example.com',
                                                keyboardType: TextInputType.emailAddress,
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            AppTextButton(
                                              text: 'Cancel',
                                              onPressed: () => Navigator.of(context).pop(),
                                            ),
                                            AppPrimaryButton(
                                              text: 'Send Link',
                                              height: 44,
                                              onPressed: () async {
                                                final email = resetEmailController.text.trim();
                                                if (email.isEmpty) {
                                                  context.showSnackBar('Please enter your email', isError: true);
                                                  return;
                                                }
                                                Navigator.of(context).pop();
                                                final sent = await widget.authController.resetPassword(email);
                                                if (!context.mounted) return;
                                                if (sent) {
                                                  context.showSnackBar('Password reset email sent. Check your inbox.');
                                                } else {
                                                  final state = widget.authController.state;
                                                  if (state is AuthError) {
                                                    context.showSnackBar(state.message, isError: true);
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        child: Text(
                                          'Forgot password?',
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF34D399) : AppColors.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Submit Button
                                  AppPrimaryButton(
                                    text: 'Sign In',
                                    icon: Icons.arrow_forward_rounded,
                                    isLoading: isLoading,
                                    onPressed: isLoading ? null : _handleLogin,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Footer Registration Link
                          Center(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.push(RouteNames.signupRequest),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: Text.rich(
                                  TextSpan(
                                    text: "Don't have an account? ",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Sign up',
                                        style: TextStyle(
                                          fontSize: 14,
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
                          ),
                        ],
                      );
                    },
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
}
