import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/botanical_auth_header.dart';
import 'package:herbascan/core/widgets/password_requirements_widget.dart';
import 'package:herbascan/core/widgets/botanical_auth_header.dart';
import 'package:herbascan/core/widgets/password_requirements_widget.dart';
import 'package:herbascan/features/auth/enter_signup_code_screen.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

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

  static String? validatePassword(BuildContext context, String? value) {
    if (value == null || value.isEmpty) return AppLocalizations.of(context).enterPassword;
    if (value.length < _minPasswordLength) {
      return AppLocalizations.of(context).useAtLeast8Chars;
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return AppLocalizations.of(context).includeCapitalLetter;
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return AppLocalizations.of(context).includeLowercaseLetter;
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return AppLocalizations.of(context).includeNumber;
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/]'))) {
      return AppLocalizations.of(context).includeSpecialChar;
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

  static String _friendlyAuthError(BuildContext context, String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('over_email_send_rate_limit') ||
        lower.contains('email rate limit') ||
        (lower.contains('rate limit') && lower.contains('email')) ||
        raw.contains('429')) {
      return AppLocalizations.of(context).tooManyEmailsSent;
    }
    if (lower.contains('invalid_credentials') ||
        lower.contains('invalid login')) {
      return AppLocalizations.of(context).emailOrPasswordMismatch;
    }
    if (lower.contains('email already registered') ||
        lower.contains('already registered')) {
      return AppLocalizations.of(context).emailAlreadyRegistered;
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
        _errorMessage = _friendlyAuthError(context, e.toString());
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
      appBar: AppBar(title: Text(AppLocalizations.of(context).createAccountTitle)),
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
                BotanicalAuthHeader(
                  title: AppLocalizations.of(context).personalHerbarium,
                  subtitle: AppLocalizations.of(context).signupSubtitle,
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
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).emailLabel,
                    hintText: AppLocalizations.of(context).emailHint,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(context).enterEmail;
                    }
                    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                    if (!emailRegex.hasMatch(v)) return AppLocalizations.of(context).validEmailRequired;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password — no prefixIcon
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).passwordLabel,
                    hintText: AppLocalizations.of(context).passwordHint,
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
                  validator: (v) => validatePassword(context, v),
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
                    labelText: AppLocalizations.of(context).confirmPasswordLabel,
                    hintText: AppLocalizations.of(context).confirmPasswordHint,
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
                        ? AppLocalizations.of(context).passwordsDoNotMatch
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
                      return AppLocalizations.of(context).confirmYourPassword;
                    }
                    if (v != _passwordController.text) {
                      return AppLocalizations.of(context).passwordsDoNotMatch;
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
                        : Text(AppLocalizations.of(context).createAccountTitle),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Bypass to OTP screen
                TextButton(
                  onPressed: () {
                    final email = _emailController.text.trim();
                    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                    
                    if (email.isEmpty || !emailRegex.hasMatch(email)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context).enterValidEmailForCode),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EnterSignupCodeScreen(email: email),
                        ),
                      );
                    }
                  },
                  child: Text(
                    AppLocalizations.of(context).alreadyHaveCode,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
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
    );
  }
}
