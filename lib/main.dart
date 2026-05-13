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
import 'package:herbascan/core/services/ota_model_service.dart';
// Desktop-only: init SQLite FFI so DB works on Windows/Linux/macOS. Mobile and web unchanged.
import 'package:herbascan/core/init_database_factory_stub.dart'
    if (dart.library.ffi) 'package:herbascan/core/init_database_factory_ffi.dart' as db_factory;
import 'package:herbascan/core/platform_utils_stub.dart'
    if (dart.library.io) 'package:herbascan/core/platform_utils_io.dart' as platform_utils;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preparation step timer notifications (mobile)
  await PreparationNotificationService().init();

  // Initialize SQLite for desktop (Windows/Linux/macOS). No change to mobile or web.
  if (!kIsWeb && platform_utils.isDesktop()) {
    db_factory.initDatabaseFactory();
  }

  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // OTA disabled — Supabase live-models bucket holds a stale model whose
  // class index order does not match the bundled class_indices.json.
  // Force the app to use the bundled assets until Supabase is updated.
  // await OtaModelService.instance.initialize();

  // Start tracking app start time
  final performanceMonitor = PerformanceMonitor();
  performanceMonitor.startTimer(PerformanceOperation.appStart);

  // Lock app to portrait orientation (skip on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

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
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: MediaQuery.of(context).textScaler.clamp(
                      minScaleFactor: 0.85,
                      maxScaleFactor: 1.15,
                    ),
                  ),
                  child: child!,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
