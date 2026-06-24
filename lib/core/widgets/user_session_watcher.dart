import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/services/admin_user_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// Listens to AuthProvider and displays real-time admin notices across the app.
class UserSessionWatcher extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const UserSessionWatcher({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<UserSessionWatcher> createState() => _UserSessionWatcherState();
}

class _UserSessionWatcherState extends State<UserSessionWatcher> {
  void _onRouteChanged() {
    if (!mounted) return;
    _onAuthChange();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().addListener(_onAuthChange);
        final navContext = widget.navigatorKey.currentContext;
        if (navContext != null) {
          GoRouter.of(navContext).routerDelegate.addListener(_onRouteChanged);
        }
        _onAuthChange();
      }
    });
  }

  @override
  void dispose() {
    if (mounted) {
      context.read<AuthProvider>().removeListener(_onAuthChange);
      final navContext = widget.navigatorKey.currentContext;
      if (navContext != null) {
        GoRouter.of(navContext).routerDelegate.removeListener(_onRouteChanged);
      }
    }
    super.dispose();
  }

  void _onAuthChange() {
    if (!mounted) return;
    
    final auth = context.read<AuthProvider>();
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;

    // Do not show dialogs or navigate if we are on Splash, Disclaimer, or Onboarding
    final path = GoRouter.of(navContext).routerDelegate.currentConfiguration.uri.path;
    if (path == '/' || path == '/disclaimer' || path == '/onboarding') {
      return; // Defer until route changes
    }

    if (auth.wasDeactivatedByAdmin) {
      final reason = auth.suspensionReason;
      auth.clearDeactivatedFlag();
      GoRouter.of(navContext).go('/suspended', extra: reason);
    } else if (auth.showForceVerifiedNotice) {
      auth.clearForceVerifiedNoticeFlag();
      _showForceVerifiedDialog(navContext);
      if (auth.user != null) {
        AdminUserService().clearForceVerifiedNotice(auth.user!.id);
      }
    } else if (auth.showRoleChangeNotice) {
      final role = auth.isAdmin ? 'admin' : 'user';
      auth.clearRoleChangeNoticeFlag();
      _showRoleChangeDialog(navContext, role);
      if (auth.user != null) {
        AdminUserService().clearRoleChangeNotice(auth.user!.id);
      }
    }
  }

  Future<void> _showForceVerifiedDialog(BuildContext ctx) async {
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(
          Icons.mark_email_read_rounded,
          color: AppTheme.safeGreen,
          size: 40,
        ),
        title: const Text('Account Verified'),
        content: const Text(
          'Your account was manually verified by an administrator. '
          'You now have full access to HerbaScan.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRoleChangeDialog(BuildContext ctx, String newRole) async {
    final isAdmin = newRole == 'admin';
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        icon: Icon(
          isAdmin
              ? Icons.admin_panel_settings_rounded
              : Icons.person_rounded,
          color: isAdmin ? AppTheme.botanicalPrimary : AppTheme.textSecondary,
          size: 40,
        ),
        title: Text(
          isAdmin ? 'Admin Access Granted' : 'Account Role Changed',
        ),
        content: Text(
          isAdmin
              ? 'You have been granted Administrator privileges. '
                'You can now access the Admin Console to manage the app, '
                'catalog, and users.'
              : 'Your account has been changed to a Standard User. '
                'You no longer have access to the Admin Console.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
