import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/password_requirements_widget.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const int _minPasswordLength = 8;

  void _onNewPasswordChanged() => setState(() {});
  void _onConfirmPasswordChanged() => setState(() {});

  bool _passwordsMatch() {
    final pw = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    return pw.isNotEmpty && pw == confirm;
  }

  static String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a new password';
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
    _newPasswordController.addListener(_onNewPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
    final newPassword = _newPasswordController.text;
    try {
      await context.read<AuthProvider>().updatePassword(newPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('AuthException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirmText = _confirmPasswordController.text;
    final confirmNotEmpty = confirmText.isNotEmpty;
    final matches = _passwordsMatch();

    // Confirm field border color based on match state
    OutlineInputBorder confirmBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Create New Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create New Password',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "You'll remain signed in on this device.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
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

                // New password field — suffix only
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: _validatePassword,
                ),

                // 2-column micro-pill requirements
                PasswordRequirementsWidget(
                  password: _newPasswordController.text,
                ),
                const SizedBox(height: 16),

                // Confirm password — border changes based on match
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
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
                    suffixIcon: confirmNotEmpty
                        ? (matches
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
                              ))
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
                      return 'Confirm your new password';
                    }
                    if (v != _newPasswordController.text) {
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
                        : const Text('Update Password'),
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
