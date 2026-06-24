import 'dart:async';
import 'package:flutter/material.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

/// Shown after successful OTP verification during sign-up.
/// Displays a success animation, user's email, and a 5-second countdown
/// timer before auto-navigating to the login screen.
class AccountVerifiedScreen extends StatefulWidget {
  final String email;

  const AccountVerifiedScreen({super.key, required this.email});

  @override
  State<AccountVerifiedScreen> createState() => _AccountVerifiedScreenState();
}

class _AccountVerifiedScreenState extends State<AccountVerifiedScreen> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
          // Pop native stack then navigate to Settings tab
          Navigator.of(context).popUntil((route) => route.isFirst);
          if (kIsWeb) {
            context.go('/settings');
          } else {
            context.go('/home?tab=3');
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppTheme.botanicalPrimary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 56,
                      color: AppTheme.botanicalPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Success title
                  Text(
                    'Account Verified!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Email confirmation
                  Text(
                    'Your account has been created as\n${widget.email}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.65),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are now signed in. Welcome to your Personal Herbarium.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Countdown indicator
                  Text(
                    'Redirecting to settings in $_countdown...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Countdown progress bar
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _countdown / 5,
                        minHeight: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: AppTheme.botanicalPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Manual "Sign In Now" button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        _timer?.cancel();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        if (kIsWeb) {
                          context.go('/settings');
                        } else {
                          context.go('/home?tab=3');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.botanicalPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Go to Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
