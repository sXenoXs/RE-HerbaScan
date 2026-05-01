import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/features/splash/splash_screen.dart';
import 'package:herbascan/features/auth/login_screen.dart';
import 'package:herbascan/features/home/home_screen.dart';
import 'package:herbascan/features/onboarding/onboarding_screen.dart';
import 'package:herbascan/features/admin/admin_web_screen.dart';

/// Returns initial location for the app. On web, respects URL path; otherwise /.
String _initialLocation() {
  if (kIsWeb && Uri.base.hasAbsolutePath && Uri.base.path.isNotEmpty) {
    final path = Uri.base.path;
    if (path == '/admin' || path == '/login' || path == '/home' || path == '/onboarding') {
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
    redirect: (BuildContext context, GoRouterState state) async {
      final loc = state.matchedLocation;
      final auth = context.read<AuthProvider>();

      // Guard /admin: require login then admin role
      if (loc == '/admin') {
        if (!auth.isLoggedIn) return '/login';
        await auth.refreshRole();
        if (!context.mounted) return null;
        final authAfter = context.read<AuthProvider>();
        if (!authAfter.isAdmin) return '/home?unauthorized=1';
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
          return HomeScreen(showUnauthorizedSnackBar: unauthorized);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminWebScreen(),
      ),
    ],
  );
}
