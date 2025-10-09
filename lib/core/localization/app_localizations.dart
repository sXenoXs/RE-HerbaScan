import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('fil', 'PH'),
  ];

  // App Title
  String get appTitle => _localizedValues[locale.languageCode]!['appTitle']!;
  
  // Navigation
  String get scan => _localizedValues[locale.languageCode]!['scan']!;
  String get browse => _localizedValues[locale.languageCode]!['browse']!;
  String get history => _localizedValues[locale.languageCode]!['history']!;
  String get dohApproved => _localizedValues[locale.languageCode]!['dohApproved']!;
  String get settings => _localizedValues[locale.languageCode]!['settings']!;

  // Home Screen
  String get welcomeMessage => _localizedValues[locale.languageCode]!['welcomeMessage']!;
  String get scanPlant => _localizedValues[locale.languageCode]!['scanPlant']!;
  String get browsePlants => _localizedValues[locale.languageCode]!['browsePlants']!;
  String get recentScans => _localizedValues[locale.languageCode]!['recentScans']!;
  String get dohPlants => _localizedValues[locale.languageCode]!['dohPlants']!;

  // Camera Screen
  String get positionPlant => _localizedValues[locale.languageCode]!['positionPlant']!;
  String get captureImage => _localizedValues[locale.languageCode]!['captureImage']!;
  String get scanningTips => _localizedValues[locale.languageCode]!['scanningTips']!;
  String get goodLighting => _localizedValues[locale.languageCode]!['goodLighting']!;
  String get keepLeafFlat => _localizedValues[locale.languageCode]!['keepLeafFlat']!;
  String get avoidShadows => _localizedValues[locale.languageCode]!['avoidShadows']!;
  String get focusOnSingleLeaf => _localizedValues[locale.languageCode]!['focusOnSingleLeaf']!;

  // Results Screen
  String get scanResults => _localizedValues[locale.languageCode]!['scanResults']!;
  String get matchFound => _localizedValues[locale.languageCode]!['matchFound']!;
  String get possibleMatch => _localizedValues[locale.languageCode]!['possibleMatch']!;
  String get viewDetails => _localizedValues[locale.languageCode]!['viewDetails']!;
  String get saveResult => _localizedValues[locale.languageCode]!['saveResult']!;

  // Plant Information
  String get taxonomy => _localizedValues[locale.languageCode]!['taxonomy']!;
  String get morphology => _localizedValues[locale.languageCode]!['morphology']!;
  String get ecology => _localizedValues[locale.languageCode]!['ecology']!;
  String get medicinalUses => _localizedValues[locale.languageCode]!['medicinalUses']!;
  String get preparationMethods => _localizedValues[locale.languageCode]!['preparationMethods']!;

  // Settings
  String get language => _localizedValues[locale.languageCode]!['language']!;
  String get offlineMode => _localizedValues[locale.languageCode]!['offlineMode']!;
  String get showConfidenceScores => _localizedValues[locale.languageCode]!['showConfidenceScores']!;
  String get showGradCAM => _localizedValues[locale.languageCode]!['showGradCAM']!;
  String get showTop3Results => _localizedValues[locale.languageCode]!['showTop3Results']!;

  // Common
  String get loading => _localizedValues[locale.languageCode]!['loading']!;
  String get error => _localizedValues[locale.languageCode]!['error']!;
  String get retry => _localizedValues[locale.languageCode]!['retry']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get save => _localizedValues[locale.languageCode]!['save']!;
  String get delete => _localizedValues[locale.languageCode]!['delete']!;
  String get search => _localizedValues[locale.languageCode]!['search']!;
  String get filter => _localizedValues[locale.languageCode]!['filter']!;

  // DOH Specific
  String get dohApprovedLabel => _localizedValues[locale.languageCode]!['dohApprovedLabel']!;
  String get philippineDepartmentOfHealth => _localizedValues[locale.languageCode]!['philippineDepartmentOfHealth']!;
  String get clinicallyValidated => _localizedValues[locale.languageCode]!['clinicallyValidated']!;

  // Warnings
  String get medicalDisclaimer => _localizedValues[locale.languageCode]!['medicalDisclaimer']!;
  String get consultHealthcareProvider => _localizedValues[locale.languageCode]!['consultHealthcareProvider']!;
  String get notForPregnantWomen => _localizedValues[locale.languageCode]!['notForPregnantWomen']!;

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'HerbaScan',
      'scan': 'Scan',
      'browse': 'Browse',
      'history': 'History',
      'dohApproved': 'DOH',
      'settings': 'Settings',
      'welcomeMessage': 'Identify medicinal plants using AI-powered recognition technology',
      'scanPlant': 'Scan Plant',
      'browsePlants': 'Browse Plants',
      'recentScans': 'Recent Scans',
      'dohPlants': 'DOH Approved',
      'positionPlant': 'Position the plant leaf within the frame',
      'captureImage': 'Capture Image',
      'scanningTips': 'Scanning Tips',
      'goodLighting': 'Use good lighting',
      'keepLeafFlat': 'Keep leaf flat and clear',
      'avoidShadows': 'Avoid shadows and blur',
      'focusOnSingleLeaf': 'Focus on single leaf',
      'scanResults': 'Scan Results',
      'matchFound': 'MATCH FOUND',
      'possibleMatch': 'POSSIBLE MATCH',
      'viewDetails': 'View Details',
      'saveResult': 'Save Result',
      'taxonomy': 'Taxonomy',
      'morphology': 'Morphology',
      'ecology': 'Ecology & Habitat',
      'medicinalUses': 'Medicinal Uses',
      'preparationMethods': 'Preparation Methods',
      'language': 'Language / Wika',
      'offlineMode': 'Offline Mode',
      'showConfidenceScores': 'Show Confidence Scores',
      'showGradCAM': 'GradCAM Visualization',
      'showTop3Results': 'Top-3 Results',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'search': 'Search',
      'filter': 'Filter',
      'dohApprovedLabel': '✓ DOH Approved',
      'philippineDepartmentOfHealth': 'Philippine Department of Health',
      'clinicallyValidated': 'clinically validated herbal medicines',
      'medicalDisclaimer': 'Always consult healthcare professionals before using any herbal remedies',
      'consultHealthcareProvider': 'Consult healthcare provider before use. Not for pregnant/nursing women.',
      'notForPregnantWomen': 'Not for pregnant/nursing women.',
    },
    'fil': {
      'appTitle': 'HerbaScan',
      'scan': 'I-scan',
      'browse': 'Tingnan',
      'history': 'Kasaysayan',
      'dohApproved': 'DOH',
      'settings': 'Mga Setting',
      'welcomeMessage': 'Kilalanin ang mga halamang gamot gamit ang teknolohiyang AI',
      'scanPlant': 'I-scan ang Halaman',
      'browsePlants': 'Tingnan ang mga Halaman',
      'recentScans': 'Mga Kamakailang Scan',
      'dohPlants': 'Pinahintulutan ng DOH',
      'positionPlant': 'Iposisyon ang dahon ng halaman sa loob ng frame',
      'captureImage': 'Kunin ang Larawan',
      'scanningTips': 'Mga Tip sa Pag-scan',
      'goodLighting': 'Gumamit ng magandang ilaw',
      'keepLeafFlat': 'Panatilihing patag at malinaw ang dahon',
      'avoidShadows': 'Iwasan ang mga anino at malabo',
      'focusOnSingleLeaf': 'Tumutok sa isang dahon',
      'scanResults': 'Mga Resulta ng Scan',
      'matchFound': 'NAKITA ANG TUGMA',
      'possibleMatch': 'POSIBLENG TUGMA',
      'viewDetails': 'Tingnan ang Detalye',
      'saveResult': 'I-save ang Resulta',
      'taxonomy': 'Taksonomiya',
      'morphology': 'Morpolohiya',
      'ecology': 'Ekolohiya at Tirahan',
      'medicinalUses': 'Mga Gamit na Panggamot',
      'preparationMethods': 'Mga Paraan ng Paghahanda',
      'language': 'Wika / Language',
      'offlineMode': 'Offline Mode',
      'showConfidenceScores': 'Ipakita ang Confidence Scores',
      'showGradCAM': 'GradCAM Visualization',
      'showTop3Results': 'Top-3 na Resulta',
      'loading': 'Naglo-load...',
      'error': 'May Mali',
      'retry': 'Subukan Muli',
      'cancel': 'Kanselahin',
      'save': 'I-save',
      'delete': 'Tanggalin',
      'search': 'Maghanap',
      'filter': 'I-filter',
      'dohApprovedLabel': '✓ Pinahintulutan ng DOH',
      'philippineDepartmentOfHealth': 'Kagawaran ng Kalusugan ng Pilipinas',
      'clinicallyValidated': 'mga halamang gamot na klinikal na napatunayan',
      'medicalDisclaimer': 'Laging kumonsulta sa mga propesyonal sa kalusugan bago gumamit ng anumang halamang gamot',
      'consultHealthcareProvider': 'Kumonsulta sa healthcare provider bago gamitin. Hindi para sa mga buntis/nagpapasuso.',
      'notForPregnantWomen': 'Hindi para sa mga buntis/nagpapasuso.',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fil'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
