import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/botanical_auth_header.dart';
import 'package:herbascan/core/widgets/password_requirements_widget.dart';
import 'package:herbascan/features/auth/enter_signup_code_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  void _onPasswordChanged() => setState(() {});
  void _onConfirmPasswordChanged() => setState(() {});

  static const int _minPasswordLength = 8;

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password';
    if (value.length < _minPasswordLength) {
      return 'Use at least $_minPasswordLength characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Include at least one capital letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Include at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/]'))) {
      return 'Include at least one special character (!@#\$%^&* etc.)';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  static String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('over_email_send_rate_limit') ||
        lower.contains('email rate limit') ||
        (lower.contains('rate limit') && lower.contains('email')) ||
        raw.contains('429')) {
      return 'Too many signup emails sent. Please try again in about an hour.';
    }
    if (lower.contains('invalid_credentials') ||
        lower.contains('invalid login')) {
      return 'Email or password does not match.';
    }
    if (lower.contains('email already registered') ||
        lower.contains('already registered')) {
      return 'This email is already registered. Try signing in.';
    }
    return raw
        .replaceFirst('AuthException: ', '')
        .replaceFirst('AuthApiException(message: ', '')
        .replaceAll(RegExp(r', statusCode: \d+, code: \w+\)'), '')
        .trim();
  }

  bool _passwordsMatch() {
    final pw = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    return pw.isNotEmpty && pw == confirm;
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }
    final email = _emailController.text.trim();
    try {
      await context.read<AuthProvider>().signUp(
            email: email,
            password: _passwordController.text,
          );
      if (mounted) {
        setState(() => _isLoading = false);
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => EnterSignupCodeScreen(email: email),
          ),
        );
        if (mounted && result == true) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyAuthError(e.toString());
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirmText = _confirmPasswordController.text;
    final confirmNotEmpty = confirmText.isNotEmpty;
    final matches = _passwordsMatch();

    OutlineInputBorder confirmBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BotanicalAuthHeader(
                  title: 'Personal Herbarium',
                  subtitle:
                      'Create an account to back up your scans to the cloud.',
                  imageAsset: 'assets/icons/HerbaScan_Icon1.png',
                ),
                const SizedBox(height: 28),

                // Server error — collapses to zero when empty, no layout shift
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _errorMessage != null
                      ? Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.errorBgLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.errorDeep,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Email — no prefixIcon
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your email';
                    }
                    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                    if (!emailRegex.hasMatch(v)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password — no prefixIcon
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter a strong password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: validatePassword,
                ),

                // 2-column micro-pill requirements
                PasswordRequirementsWidget(
                  password: _passwordController.text,
                ),
                const SizedBox(height: 16),

                // Confirm — border changes based on match state
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter your password',
                    enabledBorder: confirmNotEmpty
                        ? confirmBorder(
                            matches
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          )
                        : null,
                    focusedBorder: confirmNotEmpty
                        ? confirmBorder(
                            matches
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                            width: 2,
                          )
                        : null,
                    errorText: (confirmNotEmpty && !matches)
                        ? 'Passwords do not match'
                        : null,
                    suffixIcon: confirmNotEmpty && matches
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppTheme.successColor)
                        : IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Confirm your password';
                    }
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}
