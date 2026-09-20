import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../providers/auth_providers.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isOtpRequested = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(authControllerProvider.notifier);
    if (!_isOtpRequested) {
      final sent = await controller.requestSignUpOtp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      if (!mounted || !sent) return;

      setState(() => _isOtpRequested = true);
      _showMessage('Verification code sent to ${_emailController.text.trim()}');
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await controller.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
      otp: _otpController.text.trim(),
    );
  }

  Future<void> _resendOtp() async {
    final sent = await ref
        .read(authControllerProvider.notifier)
        .resendSignUpOtp(email: _emailController.text.trim());
    if (!mounted || !sent) return;
    _otpController.clear();
    _showMessage('A new verification code was sent.');
  }

  void _editDetails() {
    _otpController.clear();
    setState(() => _isOtpRequested = false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    return error is AppException ? error.message : 'Something went wrong.';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        _showMessage(_errorMessage(next.error!));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: ThemeModeMenu(),
            ),
            Center(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingMd,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isOtpRequested
                              ? 'Verify your email'
                              : 'Create your account',
                          style: context.appTextStyles.displayMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _isOtpRequested
                              ? 'Enter the 6-digit code sent to ${_emailController.text.trim()}.'
                              : 'Start learning and earning XP.',
                          style: context.appTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (_isOtpRequested)
                          AppTextField(
                            key: const Key('signup-otp-field'),
                            controller: _otpController,
                            label: 'Verification code',
                            hint: '6-digit code',
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: (value) {
                              if (value == null || value.length != 6) {
                                return 'Enter the 6-digit verification code';
                              }
                              return null;
                            },
                          )
                        else ...[
                          AppTextField(
                            controller: _nameController,
                            label: 'Display name',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter a display name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              if (value == null || !value.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _passwordController,
                            label: 'Password',
                            obscureText: true,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm password',
                            obscureText: true,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: _isOtpRequested
                              ? 'Verify and create account'
                              : 'Send verification code',
                          isLoading: isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_isOtpRequested) ...[
                          TextButton(
                            onPressed: isLoading ? null : _resendOtp,
                            child: const Text('Resend code'),
                          ),
                          TextButton(
                            onPressed: isLoading ? null : _editDetails,
                            child: const Text('Change account details'),
                          ),
                        ] else
                          TextButton(
                            onPressed: () => context.go(RouteNames.login),
                            child: const Text(
                              'Already have an account? Log in',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
