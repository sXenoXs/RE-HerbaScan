import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
    try {
      await context.read<AuthProvider>().signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) {
        if (context.canPop()) {
          Navigator.of(context).pop(true);
        } else {
          context.go('/admin');
        }
      }
    } catch (e) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, toolbarHeight: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BotanicalAuthHeader(
                  title: 'Personal Herbarium',
                  subtitle:
                      'Sign in to sync your scan history and images to the cloud.',
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
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
                                builder: (_) => const ForgotPasswordScreen(),
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
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
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
    );
  }
}
