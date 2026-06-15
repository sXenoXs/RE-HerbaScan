import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/botanical_auth_header.dart';
import 'package:herbascan/features/auth/forgot_password_screen.dart';
import 'package:herbascan/features/auth/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Brute-force throttle (S-02 / S-13 fix) ────────────────────────────
  static const int _maxAttempts = 5;
  static const int _cooldownDurationSeconds = 30;
  int _failedAttempts = 0;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  bool get _isCoolingDown => _cooldownSeconds > 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = _cooldownDurationSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _cooldownSeconds = 0;
          t.cancel();
        }
      });
    });
  }

  Future<void> _submit() async {
    if (_isCoolingDown) return; // hard-block during cooldown
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      await context.read<AuthProvider>().signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // Await role refresh before routing to ensure isAdmin is up-to-date
      await context.read<AuthProvider>().refreshRole();
      
      // Reset on success
      _failedAttempts = 0;
      if (mounted) {
        final authAfter = context.read<AuthProvider>();
        if (kIsWeb && authAfter.isAdmin) {
          context.go('/admin');
        } else if (context.canPop()) {
          Navigator.of(context).pop(true);
        } else {
          context.go(authAfter.isAdmin ? '/admin' : '/home');
        }
      }
    } catch (e) {
      _failedAttempts++;
      setState(() {
        final raw = e.toString();
        if (raw.contains('invalid_credentials') ||
            raw.contains('Invalid login credentials')) {
          _errorMessage = 'Email or password does not match.';
        } else {
          _errorMessage = raw
              .replaceFirst('AuthException: ', '')
              .replaceFirst('AuthApiException(message: ', '')
              .replaceAll(RegExp(r', statusCode: \d+, code: \w+\)'), '');
          if (_errorMessage!.isEmpty || _errorMessage == raw) {
            _errorMessage = 'Sign in failed. Please try again.';
          }
        }
        _isLoading = false;
      });
      // After max attempts, enforce client-side cooldown.
      if (_failedAttempts >= _maxAttempts) {
        _failedAttempts = 0;
        _startCooldown();
        setState(() => _errorMessage =
            'Too many failed attempts. Please wait $_cooldownDurationSeconds seconds.');
      }
    }
  }

  void _showWebBackMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop(); // Close bottom sheet
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (context.mounted) context.push('/settings');
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        toolbarHeight: kIsWeb ? kToolbarHeight : 0,
        leading: kIsWeb
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to app',
                onPressed: () => _showWebBackMenu(context),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter): _submit,
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BotanicalAuthHeader(
                        title: 'Personal Herbarium',
                        subtitle:
                            'Sign in to sync your scan history and images to the cloud.',
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
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your email';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password — no prefixIcon, suffix only
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Enter your password';
                          return null;
                        },
                      ),

                      // "Forgot password?" — right-aligned, directly below field
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: (_isLoading || _isCoolingDown) ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : _isCoolingDown
                                  ? Text('Wait ${_cooldownSeconds}s')
                                  : const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Separator
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'New to HerbaScan?',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // "Create an account" — full-width OutlinedButton
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SignUpScreen(),
                                    ),
                                  );
                                },
                          child: const Text('Create an Account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
