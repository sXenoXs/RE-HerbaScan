import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';

/// Screen for entering the 6-digit (or token) code from the signup confirmation email.
/// On success, confirms the account and pops with [true] (user may be signed in automatically).
class EnterSignupCodeScreen extends StatefulWidget {
  const EnterSignupCodeScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<EnterSignupCodeScreen> createState() => _EnterSignupCodeScreenState();
}

class _EnterSignupCodeScreenState extends State<EnterSignupCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Enter the code from your email';
        _isLoading = false;
      });
      return;
    }
    try {
      await context.read<AuthProvider>().verifySignupOtp(email: widget.email, token: code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          final raw = e.toString();
          if (raw.contains('otp_expired') || raw.contains('expired')) {
            _errorMessage = 'Code expired. Request a new one from the signup screen.';
          } else {
            _errorMessage = raw
                .replaceFirst('AuthException: ', '')
                .replaceFirst('AuthApiException(message: ', '')
                .replaceAll(RegExp(r', statusCode: \d+, code: \w+\)'), '');
            if (_errorMessage!.isEmpty) _errorMessage = 'Invalid code. Try again.';
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm your email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Enter the code from your email',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to ${widget.email}. Enter it below to activate your account. The code may expire after about an hour.',
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
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    hintText: '000000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin),
                    counterText: '',
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter the 6-digit code';
                    }
                    if (v.trim().length < 6) {
                      return 'Code must be 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Activate account'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Back to sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
