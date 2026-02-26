import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
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

  /// Validates password: at least 8 chars, one uppercase, one lowercase, one digit, one special char.
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

  /// Maps Supabase auth errors to user-friendly messages.
  static String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('over_email_send_rate_limit') ||
        lower.contains('email rate limit') ||
        lower.contains('rate limit') && lower.contains('email') ||
        raw.contains('429')) {
      return 'Too many signup emails sent. Please try again in about an hour.';
    }
    if (lower.contains('invalid_credentials') || lower.contains('invalid login')) {
      return 'Email or password does not match.';
    }
    if (lower.contains('email already registered') || lower.contains('already registered')) {
      return 'This email is already registered. Try signing in.';
    }
    // Strip common exception wrappers for other errors
    return raw
        .replaceFirst('AuthException: ', '')
        .replaceFirst('AuthApiException(message: ', '')
        .replaceAll(RegExp(r', statusCode: \d+, code: \w+\)'), '')
        .trim();
  }

  bool _hasMinLength(String? value) =>
      (value?.length ?? 0) >= _minPasswordLength;
  bool _hasUppercase(String? value) =>
      value != null && value.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String? value) =>
      value != null && value.contains(RegExp(r'[a-z]'));
  bool _hasDigit(String? value) =>
      value != null && value.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String? value) =>
      value != null &&
      value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/]'));

  Widget _buildPasswordRequirements(ThemeData theme) {
    final value = _passwordController.text;
    final requirements = <({String label, bool met})>[
      (label: 'At least 8 characters', met: _hasMinLength(value)),
      (label: 'One capital letter', met: _hasUppercase(value)),
      (label: 'One lowercase letter', met: _hasLowercase(value)),
      (label: 'One number', met: _hasDigit(value)),
      (label: 'One special character (!@#\$%^&* etc.)', met: _hasSpecial(value)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: requirements
            .map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      r.met ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: r.met
                          ? (theme.colorScheme.primary)
                          : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: r.met
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: r.met ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildConfirmPasswordStatus(ThemeData theme) {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (confirm.isEmpty) return const SizedBox.shrink();
    final match = password.isNotEmpty && password == confirm;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            match ? Icons.check_circle : Icons.cancel_outlined,
            size: 20,
            color: match
                ? theme.colorScheme.primary
                : theme.colorScheme.error.withOpacity(0.9),
          ),
          const SizedBox(width: 10),
          Text(
            match ? 'Passwords match' : 'Passwords do not match',
            style: theme.textTheme.bodySmall?.copyWith(
              color: match
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
            builder: (context) => EnterSignupCodeScreen(email: email),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Personal Herbarium',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create an account to back up your scans to the cloud.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter a strong password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: validatePassword,
                ),
                _buildPasswordRequirements(theme),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    hintText: 'Re-enter your password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                _buildConfirmPasswordStatus(theme),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
