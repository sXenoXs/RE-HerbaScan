import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/providers/app_provider.dart';
import 'package:herbascan/core/providers/auth_provider.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/providers/camera_provider.dart';
import 'package:herbascan/core/providers/language_provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/routing/app_router.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/services/performance_monitor.dart';
import 'package:herbascan/core/widgets/auth_deeplink_handler.dart';
import 'package:herbascan/core/services/preparation_notification_service.dart';
import 'package:herbascan/core/services/inactivity_timer_service.dart';
// Desktop-only: init SQLite FFI so DB works on Windows/Linux/macOS. Mobile and web unchanged.
import 'package:herbascan/core/init_database_factory_stub.dart'
    if (dart.library.ffi) 'package:herbascan/core/init_database_factory_ffi.dart' as db_factory;
import 'package:herbascan/core/platform_utils_stub.dart'
    if (dart.library.io) 'package:herbascan/core/platform_utils_io.dart' as platform_utils;
import 'package:herbascan/core/services/web_session_storage.dart';
import 'package:herbascan/core/services/ota_model_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preparation step timer notifications (mobile)
  if (!kIsWeb) {
    try {
      await PreparationNotificationService().init();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  // Initialize SQLite for desktop (Windows/Linux/macOS). No change to mobile or web.
  if (!kIsWeb && platform_utils.isDesktop()) {
    db_factory.initDatabaseFactory();
  }

  if (isSupabaseConfigured) {
    final webStorage = getWebSessionStorage();
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      authOptions: webStorage != null
          ? FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
              localStorage: webStorage,
            )
          : const FlutterAuthClientOptions(),
    );
  }

  await OtaModelService.instance.initialize();

  // Start tracking app start time
  final performanceMonitor = PerformanceMonitor();
  performanceMonitor.startTimer(PerformanceOperation.appStart);



  runApp(const HerbaScanApp());
}

class HerbaScanApp extends StatefulWidget {
  const HerbaScanApp({super.key});

  @override
  State<HerbaScanApp> createState() => _HerbaScanAppState();
}

class _HerbaScanAppState extends State<HerbaScanApp> {
  final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  late final GoRouter _router = createAppRouter(_rootNavigatorKey);

  @override
  void dispose() {
    InactivityTimerService().stop();
    super.dispose();
  }

  // ── Inactivity timeout handler ─────────────────────────────────────────────

  /// Called when the user has been inactive for 60 minutes while signed in.
  /// Signs the user out and navigates to the login screen.
  void _handleInactivityTimeout(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    auth.signOut();
    final navigator = _rootNavigatorKey.currentContext;
    if (navigator == null) return;
    if (kIsWeb) {
      // On web (admin portal), go directly to /login.
      _router.go('/login');
    } else {
      // On mobile, show a non-dismissible dialog informing the user.
      showDialog<void>(
        context: navigator,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Session Expired'),
          content: const Text(
            'You have been signed out due to 60 minutes of inactivity. '
            'Please sign in again to continue.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // ── Start / stop timer based on auth state ────────────────────────────────

  void _syncInactivityTimer(BuildContext context, AuthProvider auth) {
    if (auth.isLoggedIn && !InactivityTimerService().isActive) {
      InactivityTimerService().start(
        onTimeout: () => _handleInactivityTimeout(context),
        duration: InactivityTimerService.defaultTimeout, // 60 min
      );
    } else if (!auth.isLoggedIn && InactivityTimerService().isActive) {
      InactivityTimerService().stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlantProvider()),
        ChangeNotifierProvider(create: (_) => CameraProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
      ],
      child: Consumer2<LanguageProvider, AppProvider>(
        builder: (context, languageProvider, appProvider, child) {
          return AuthDeepLinkHandler(
            navigatorKey: _rootNavigatorKey,
            child: MaterialApp.router(
              routerConfig: _router,
              scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
              // Key by locale only so theme toggle does not replace the whole tree (avoids _dependents.isEmpty).
              key: ValueKey(languageProvider.locale.toString()),
              title: 'HerbaScan',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: appProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              locale: languageProvider.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en', 'US'), // English
                Locale('fil', 'PH'), // Filipino
              ],
              builder: (context, child) {
                // ── Inactivity wrapper ──────────────────────────────────────
                // Listen to AuthProvider; start/stop timer when login state changes.
                return Consumer<AuthProvider>(
                  builder: (ctx, auth, _) {
                    _syncInactivityTimer(ctx, auth);
                    // Listener intercepts every pointer-down event (tap, scroll, drag start)
                    // and resets the inactivity countdown.
                    return Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => InactivityTimerService().reset(),
                      child: MediaQuery(
                        data: MediaQuery.of(ctx).copyWith(
                          textScaler: MediaQuery.of(ctx).textScaler.clamp(
                            minScaleFactor: 0.85,
                            maxScaleFactor: 1.15,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
