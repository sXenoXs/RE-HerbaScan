import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/features/splash/splash_screen.dart';
import 'package:herbascan/features/splash/disclaimer_screen.dart';
import 'package:herbascan/features/auth/login_screen.dart';
import 'package:herbascan/features/home/home_screen.dart';
import 'package:herbascan/features/onboarding/onboarding_screen.dart';
import 'package:herbascan/features/admin/admin_web_screen.dart';
import 'package:herbascan/features/settings/settings_screen.dart';
import 'package:herbascan/features/auth/auth_callback_screen.dart';

/// Returns initial location for the app. On web, respects URL path; otherwise /.
String _initialLocation() {
  if (kIsWeb && Uri.base.hasAbsolutePath && Uri.base.path.isNotEmpty) {
    final path = Uri.base.path;
    if (path == '/admin' || path == '/login' || path == '/home' ||
        path == '/onboarding' || path == '/settings') {
      return path;
    }
  }
  return '/';
}

/// Builds the app router. Must be used below [MultiProvider] so redirect can access [AuthProvider].
GoRouter createAppRouter(GlobalKey<NavigatorState> navigatorKey) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: _initialLocation(),
    errorBuilder: (context, state) {
      final uriStr = state.uri.toString();
      if (uriStr.contains('auth/callback')) {
        return AuthCallbackScreen(uri: state.uri);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: const Center(
          child: Text('The requested page could not be found.'),
        ),
      );
    },
    redirect: (BuildContext context, GoRouterState state) async {
      final loc = state.matchedLocation;
      final auth = context.read<AuthProvider>();

      // Guard /admin: require login then admin role
      if (loc == '/admin') {
        if (!auth.isLoggedIn) return '/login';
        await auth.refreshRole();
        if (!context.mounted) return null;
        final authAfter = context.read<AuthProvider>();
        if (!authAfter.isAdmin) {
          if (kIsWeb) return '/login';
          return '/home?unauthorized=1';
        }
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final unauthorized = state.uri.queryParameters['unauthorized'] == '1';
          final tabIndexStr = state.uri.queryParameters['tab'];
          final tabIndex = tabIndexStr != null ? int.tryParse(tabIndexStr) ?? 0 : 0;
          return HomeScreen(
            showUnauthorizedSnackBar: unauthorized,
            initialTabIndex: tabIndex,
          );
        },
      ),
      GoRoute(
        path: '/disclaimer',
        builder: (_, state) => DisclaimerScreen(
          destination: (state.extra as String?) ?? 'home',
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminWebScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/callback',
        builder: (_, state) => AuthCallbackScreen(uri: state.uri),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (_, state) => AuthCallbackScreen(uri: state.uri),
      ),
    ],
  );
}
