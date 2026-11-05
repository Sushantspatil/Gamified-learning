import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../providers/auth_providers.dart';
import '../widgets/animated_login_button.dart';
import '../widgets/animated_login_field.dart';
import '../widgets/skillverse_auth_background.dart';
import '../widgets/skillverse_login_hero.dart';

/// Sign-up, in the same look as the login screen: the starry background, the
/// student mascot (who covers his eyes while you type the password), icons in
/// the fields, the glowing gradient button, and a live password checklist.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _isOtpRequested = false;

  late final AnimationController _entranceController;
  late final AnimationController _ambientController;

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    // Loops in the app; a single pass in tests so they can settle.
    if (_isTestEnvironment) {
      _ambientController.forward();
    } else {
      _ambientController.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ambientController.stop();
    } else if (state == AppLifecycleState.resumed &&
        !_isTestEnvironment &&
        !AppMotion.reduceMotion(context) &&
        !_ambientController.isAnimating) {
      _ambientController.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _passwordFocusNode.dispose();
    _entranceController.dispose();
    _ambientController.dispose();
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

  /// The back arrow: from the code step to the details, from the details to
  /// the login screen.
  void _goBack() {
    if (_isOtpRequested) {
      _editDetails();
    } else {
      context.go(RouteNames.login);
    }
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
    final colors = context.themeColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = AppMotion.reduceMotion(context);
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isCompact = MediaQuery.sizeOf(context).height < 700;

    if (reduceMotion && _ambientController.isAnimating) {
      _ambientController.stop();
    }

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        _showMessage(_errorMessage(next.error!));
      }
    });

    final heroHeight = isKeyboardVisible ? 90.0 : (isCompact ? 96.0 : 140.0);
    final gap = isCompact ? 10.0 : 14.0;

    Widget circleButton({
      required Widget child,
      required AlignmentGeometry alignment,
    }) {
      return Positioned(
        top: 10,
        left: alignment == Alignment.topLeft ? 16 : null,
        right: alignment == Alignment.topRight ? 16 : null,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(
              alpha: isDark ? 0.65 : 0.90,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.borderStrong.withValues(alpha: 0.70),
            ),
          ),
          child: child,
        ),
      );
    }

    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: heroHeight,
              child: SkillverseLoginHero(
                ambientAnimation: _ambientController,
                passwordFocusNode: _passwordFocusNode,
                isKeyboardVisible: isKeyboardVisible,
                reduceMotion: reduceMotion,
                height: heroHeight,
              ),
            ),
            SizedBox(height: isCompact ? 6 : 10),
            Text(
              _isOtpRequested ? 'Verify your email' : 'Create your account',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: isCompact ? 24 : 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isOtpRequested
                  ? 'Enter the 6-digit code sent to ${_emailController.text.trim()}.'
                  : 'Start learning and earning XP.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: isCompact ? 13.5 : 14.5,
                letterSpacing: 0.1,
              ),
            ),
            SizedBox(height: isCompact ? 14 : 20),
            if (_isOtpRequested)
              AnimatedLoginField(
                key: const Key('signup-otp-field'),
                controller: _otpController,
                hintText: '6-digit verification code',
                prefixIcon: Icons.verified_user_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                onFieldSubmitted: _submit,
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
              AnimatedLoginField(
                controller: _nameController,
                hintText: 'Display name',
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.nickname],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a display name';
                  }
                  return null;
                },
              ),
              SizedBox(height: gap),
              AnimatedLoginField(
                controller: _emailController,
                hintText: 'Email',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: gap),
              AnimatedLoginField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                hintText: 'Password',
                prefixIcon: Icons.lock_outline_rounded,
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: gap),
              AnimatedLoginField(
                controller: _confirmPasswordController,
                hintText: 'Confirm password',
                prefixIcon: Icons.lock_reset_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: _submit,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              _PasswordChecklist(
                password: _passwordController,
                confirm: _confirmPasswordController,
              ),
            ],
            SizedBox(height: isCompact ? 12 : 18),
            AnimatedLoginButton(
              onPressed: _submit,
              isLoading: isLoading,
              ambientAnimation: _ambientController,
              reduceMotion: reduceMotion,
              label: _isOtpRequested
                  ? 'Verify and create account'
                  : 'Send verification code',
              loadingLabel: _isOtpRequested
                  ? 'Creating account...'
                  : 'Sending...',
              icon: _isOtpRequested
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
            ),
            SizedBox(height: isCompact ? 4 : 10),
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
              Center(
                child: TextButton(
                  onPressed: () => context.go(RouteNames.login),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Already have an account? Log in',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SkillverseAuthBackground(
              ambientAnimation: _ambientController,
              reduceMotion: reduceMotion,
            ),
            SafeArea(
              child: Stack(
                children: [
                  circleButton(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: _goBack,
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  circleButton(
                    alignment: Alignment.topRight,
                    child: const ThemeModeMenu(),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: reduceMotion
                          ? content
                          : FadeTransition(
                              opacity: CurvedAnimation(
                                parent: _entranceController,
                                curve: Curves.easeOutCubic,
                              ),
                              child: content,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two quiet checks under the password fields that tick as you type: long
/// enough, and the two entries match.
class _PasswordChecklist extends StatelessWidget {
  final TextEditingController password;
  final TextEditingController confirm;

  const _PasswordChecklist({required this.password, required this.confirm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([password, confirm]),
      builder: (context, _) {
        return Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Rule(label: '6+ characters', ok: password.text.length >= 6),
            _Rule(
              label: 'Passwords match',
              ok: confirm.text.isNotEmpty && confirm.text == password.text,
            ),
          ],
        );
      },
    );
  }
}

class _Rule extends StatelessWidget {
  final String label;
  final bool ok;

  const _Rule({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final color = ok ? colors.success : colors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            key: ValueKey(ok),
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: ok ? colors.success : colors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
