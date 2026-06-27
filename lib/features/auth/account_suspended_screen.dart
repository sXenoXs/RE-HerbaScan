import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

/// Shown when a user's account has been suspended (is_active = false).
/// Displays the suspension reason if provided, and a button to contact support.
class AccountSuspendedScreen extends StatelessWidget {
  /// Optional reason from profiles.suspension_reason.
  final String? reason;

  const AccountSuspendedScreen({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.surfaceColor,
        body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Icon ──────────────────────────────────────────────
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.errorBgLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      size: 48,
                      color: AppTheme.errorDeep,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Title ─────────────────────────────────────────────
                  Text(
                    AppLocalizations.of(context).accountSuspendedTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorDeep,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Subtitle ──────────────────────────────────────────
                  Text(
                    AppLocalizations.of(context).accountSuspendedSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),

                  // ── Reason card (only when a reason is given) ─────────
                  if (reason != null && reason!.trim().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkCard
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.errorDeep.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).reasonLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppTheme.errorDeep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reason!.trim(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 36),

                  // ── Contact Support ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'herbascan.official@gmail.com',
                        );
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context).couldNotOpenEmail)),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.mail_outline_rounded),
                      label: Text(AppLocalizations.of(context).contactSupportBtn),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.botanicalPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Back to Login ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        if (kIsWeb) {
                          context.go('/settings');
                        } else {
                          context.go('/home?tab=3');
                        }
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (context.mounted) {
                            context.push('/login');
                          }
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(AppLocalizations.of(context).backToSignIn),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Footer note ───────────────────────────────────────
                  Text(
                    AppLocalizations.of(context).supportMistakeMsg,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
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
