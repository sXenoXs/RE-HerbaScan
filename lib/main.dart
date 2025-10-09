import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/providers/app_provider.dart';
import 'package:herbascan/core/providers/plant_provider.dart';
import 'package:herbascan/core/providers/camera_provider.dart';
import 'package:herbascan/core/providers/language_provider.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/features/splash/splash_screen.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

void main() {
  // Lock app to portrait orientation
  SystemChrome.setPreferredOrientations([
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
        ChangeNotifierProvider(create: (_) => PlantProvider()),
        ChangeNotifierProvider(create: (_) => CameraProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
      ],
      child: Consumer2<LanguageProvider, AppProvider>(
        builder: (context, languageProvider, appProvider, child) {
          return MaterialApp(
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
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
