import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/widgets/botanical_auth_header.dart';
import 'package:herbascan/features/auth/change_password_screen.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

/// Screen for entering the 6-digit code from the password reset email.
/// On success, establishes a recovery session and navigates to [ChangePasswordScreen].
class EnterResetCodeScreen extends StatefulWidget {
  const EnterResetCodeScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<EnterResetCodeScreen> createState() => _EnterResetCodeScreenState();
}

class _EnterResetCodeScreenState extends State<EnterResetCodeScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  final _codeNotifier = ValueNotifier<bool>(false);

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  bool _isLocked = false;
  String? _lockedUntil;
  int _attemptsLeft = 3;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(() {
      _codeNotifier.value = _pinController.text.length == 6;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    try {
      final res = await context.read<AuthProvider>().checkOtpStatus(widget.email);
      _handleStatusResponse(res);
    } catch (_) {}
  }

  void _handleStatusResponse(Map<String, dynamic> res) {
    if (!mounted) return;
    setState(() {
      if (res['allowed'] == false) {
        _isLocked = true;
        final lockedStr = res['locked_until'];
        if (lockedStr != null) {
          final lockedDate = DateTime.parse(lockedStr).toLocal();
          final diff = lockedDate.difference(DateTime.now());
          if (diff.isNegative) {
            _isLocked = false;
            _attemptsLeft = 3;
          } else {
            final hours = diff.inHours;
            final mins = diff.inMinutes % 60;
            _lockedUntil = hours > 0 ? '$hours hour(s) $mins minute(s)' : '$mins minute(s)';
          }
        }
      } else {
        _isLocked = false;
        _attemptsLeft = res['attempts_left'] ?? 3;
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    _codeNotifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _pinController.text.trim();
    if (code.length < 6) return;
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      await context.read<AuthProvider>().verifyRecoveryOtp(
            email: widget.email,
            token: code,
          );
      await context.read<AuthProvider>().recordOtpAttempt(widget.email, true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen(isRecovery: true)),
      );
    } catch (e) {
      if (mounted) {
        try {
          final res = await context.read<AuthProvider>().recordOtpAttempt(widget.email, false);
          _handleStatusResponse(res);
        } catch (_) {}

        setState(() {
          _errorMessage = e
              .toString()
              .replaceFirst('AuthException: ', '');
          if (_errorMessage!.isEmpty) _errorMessage = AppLocalizations.of(context).invalidCode;
          _isLoading = false;
        });
        _pinController.clear();
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });
    try {
      await context.read<AuthProvider>().requestPasswordReset(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).newCodeSent)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).failedToResend;
        });
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  PinTheme _buildPinTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Theme-aware fill: light mode = slight tint so boxes don't blend; dark mode = dark surface (no white)
    final defaultColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerLow;
    // Subtle border so all 6 boxes are visible in light mode when empty
    final defaultBorder = Border.all(
      color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.5 : 0.35),
      width: 1,
    );
    return PinTheme(
      width: 48,
      height: 56,
      textStyle: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
      decoration: BoxDecoration(
        color: defaultColor,
        borderRadius: BorderRadius.circular(12),
        border: defaultBorder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final defaultTheme = _buildPinTheme(context);
    final focusedTheme = defaultTheme.copyWith(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.botanicalPrimary, width: 2),
      ),
    );
    final submittedTheme = defaultTheme.copyWith(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.botanicalPrimary.withValues(alpha: 0.4),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              BotanicalAuthHeader(
                icon: Icons.mark_email_read_rounded,
                title: AppLocalizations.of(context).checkYourInbox,
                subtitle: _buildSubtitle(context),
              ),
              const SizedBox(height: 40),

              // Error area — pre-allocated height to avoid layout shift
              SizedBox(
                height: 48,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _errorMessage != null
                      ? Container(
                          key: const ValueKey('error'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorBgLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.errorDeep,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),

              const SizedBox(height: 16),

              if (_isLocked) ...[
                const SizedBox(height: 32),
                const Icon(Icons.lock_clock_rounded, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).tooManyAttemptsWait(_lockedUntil ?? ''),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(AppLocalizations.of(context).backToSignIn),
                ),
              ] else ...[
                // 6-box OTP input
                Center(
                  child: Pinput(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    length: 6,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    defaultPinTheme: defaultTheme,
                    focusedPinTheme: focusedTheme,
                    submittedPinTheme: submittedTheme,
                    onCompleted: (_) => _submit(),
                    hapticFeedbackType: HapticFeedbackType.lightImpact,
                  ),
                ),

                const SizedBox(height: 8),
                Center(
                  child: Text(
                    AppLocalizations.of(context).attemptsLeft(_attemptsLeft),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Submit button — disabled until 6 digits entered
                ValueListenableBuilder<bool>(
                  valueListenable: _codeNotifier,
                  builder: (context, isReady, _) {
                    return FilledButton(
                      onPressed: (_isLoading || !isReady) ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.botanicalPrimary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(AppLocalizations.of(context).continueBtn),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Resend button
                Center(
                  child: TextButton(
                    onPressed: (_isLoading || _isResending) ? null : _resend,
                    child: _isResending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(AppLocalizations.of(context).didntReceiveEmail),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }

  String _buildSubtitle(BuildContext context) {
    return AppLocalizations.of(context).sent6DigitCode(widget.email);
  }
}
