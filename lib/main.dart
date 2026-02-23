import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:herbascan/features/splash/splash_screen.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'package:herbascan/core/services/performance_monitor.dart';
import 'package:herbascan/core/widgets/auth_deeplink_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Start tracking app start time
  final performanceMonitor = PerformanceMonitor();
  performanceMonitor.startTimer(PerformanceOperation.appStart);

  // Lock app to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const HerbaScanApp());
}

class HerbaScanApp extends StatelessWidget {
  const HerbaScanApp({super.key});

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
          final navigatorKey = GlobalKey<NavigatorState>();
          return MaterialApp(
            navigatorKey: navigatorKey,
            key: ValueKey('${appProvider.isDarkMode}_${languageProvider.locale}'),
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
            home: AuthDeepLinkHandler(
              navigatorKey: navigatorKey,
              child: const SplashScreen(),
            ),
          );
        },
      ),
    );
  }
}
