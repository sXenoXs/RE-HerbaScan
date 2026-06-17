import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/features/auth/change_password_screen.dart';

/// Handles auth deep links (herbascan://auth/callback) for password reset and
/// change-email flows. When the app is opened from such a link, recovers the
/// session and navigates to the change-password screen.
class AuthDeepLinkHandler extends StatefulWidget {
  const AuthDeepLinkHandler({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AuthDeepLinkHandler> createState() => _AuthDeepLinkHandlerState();
}

class _AuthDeepLinkHandlerState extends State<AuthDeepLinkHandler> {
  final AppLinks _appLinks = AppLinks();
  bool _deactivationDialogShown = false;

  @override
  void initState() {
    super.initState();
    if (!isSupabaseConfigured) return;
    _handleInitialUri();
    _listenToUriLinks();
  }

  Future<void> _handleInitialUri() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) await _handleAuthUri(uri);
    } catch (_) {
      // Ignore; link may not be auth-related
    }
  }

  void _listenToUriLinks() {
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) _handleAuthUri(uri);
    }, onError: (_) {});
  }

  Future<void> _handleAuthUri(Uri uri) async {
    if (uri.scheme != 'herbascan' ||
        uri.host != 'auth' ||
        !uri.path.startsWith('/callback')) {
      return;
    }
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      if (!mounted) return;
      
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      final type = fragmentParams['type'];
      
      if (type == 'recovery') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.navigatorKey.currentState?.push<void>(
            MaterialPageRoute(
              builder: (_) => const ChangePasswordScreen(isRecovery: true),
            ),
          );
        });
      }
    } catch (_) {
      // Session recovery failed; user can request a new link
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.wasDeactivatedByAdmin && !_deactivationDialogShown) {
          _deactivationDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Account deactivated'),
                content: const Text(
                  'Your account has been deactivated by an administrator.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      auth.clearDeactivatedFlag();
                      _deactivationDialogShown = false;
                      if (context.mounted) context.go('/login');
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          });
        }
        return child!;
      },
      child: widget.child,
    );
  }
}
