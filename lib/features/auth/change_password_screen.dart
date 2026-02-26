import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';

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
    final value = _newPasswordController.text;
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
                          ? theme.colorScheme.primary
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
    final password = _newPasswordController.text;
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

  static String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a new password';
    if (value.length < _minPasswordLength) return 'Use at least $_minPasswordLength characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Include at least one capital letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Include at least one lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Include at least one number';
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
          _errorMessage =
              e.toString().replaceFirst('AuthException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
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
                  'Choose a new password',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You will stay signed in.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscureNew = !_obscureNew);
                      },
                    ),
                  ),
                  validator: _validatePassword,
                ),
                _buildPasswordRequirements(theme),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                            () => _obscureConfirm = !_obscureConfirm);
                      },
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
                      : const Text('Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
