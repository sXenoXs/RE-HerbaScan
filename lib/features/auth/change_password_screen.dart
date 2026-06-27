import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/password_requirements_widget.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isRecovery;
  const ChangePasswordScreen({super.key, this.isRecovery = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
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

  static String? _validatePassword(BuildContext context, String? value) {
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
    _newPasswordController.addListener(_onNewPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _currentPasswordController.dispose();
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
    
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    
    try {
      if (!widget.isRecovery) {
        await context.read<AuthProvider>().verifyCurrentPassword(currentPassword);
      }
      
      await context.read<AuthProvider>().updatePassword(newPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).passwordUpdated)),
        );
        if (widget.isRecovery) {
          final auth = context.read<AuthProvider>();
          context.go(auth.isAdmin ? '/admin' : '/home');
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final errStr = e.toString();
          if (errStr.contains('Invalid login credentials')) {
            _errorMessage = AppLocalizations.of(context).incorrectCurrentPassword;
          } else {
            _errorMessage = errStr.replaceFirst('AuthException: ', '');
          }
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
      appBar: AppBar(title: Text(AppLocalizations.of(context).createNewPasswordTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter): _submit,
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Text(
                      AppLocalizations.of(context).createNewPasswordTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context).remainSignedIn,
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

                    if (!widget.isRecovery) ...[
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).currentPasswordLabel,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscureCurrent = !_obscureCurrent),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) return AppLocalizations.of(context).enterCurrentPassword;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // New password field — suffix only
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).newPasswordLabel,
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
                      textInputAction: TextInputAction.next,
                      validator: (v) => _validatePassword(context, v),
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
                        labelText: AppLocalizations.of(context).confirmPasswordLabel,
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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppLocalizations.of(context).confirmNewPassword;
                        }
                        if (v != _newPasswordController.text) {
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
                            : Text(AppLocalizations.of(context).updatePasswordBtn),
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
