import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  String get dohApproved =>
      _localizedValues[locale.languageCode]!['dohApproved']!;
  String get settings => _localizedValues[locale.languageCode]!['settings']!;

  // Home Screen
  String get welcomeMessage =>
      _localizedValues[locale.languageCode]!['welcomeMessage']!;
  String get scanPlant => _localizedValues[locale.languageCode]!['scanPlant']!;
  String get browsePlants =>
      _localizedValues[locale.languageCode]!['browsePlants']!;
  String get recentScans =>
      _localizedValues[locale.languageCode]!['recentScans']!;
  String get dohPlants => _localizedValues[locale.languageCode]!['dohPlants']!;

  // Camera Screen
  String get positionPlant =>
      _localizedValues[locale.languageCode]!['positionPlant']!;
  String get captureImage =>
      _localizedValues[locale.languageCode]!['captureImage']!;
  String get scanningTips =>
      _localizedValues[locale.languageCode]!['scanningTips']!;
  String get goodLighting =>
      _localizedValues[locale.languageCode]!['goodLighting']!;
  String get keepLeafFlat =>
      _localizedValues[locale.languageCode]!['keepLeafFlat']!;
  String get avoidShadows =>
      _localizedValues[locale.languageCode]!['avoidShadows']!;
  String get focusOnSingleLeaf =>
      _localizedValues[locale.languageCode]!['focusOnSingleLeaf']!;

  // Results Screen
  String get scanResults =>
      _localizedValues[locale.languageCode]!['scanResults']!;
  String get matchFound =>
      _localizedValues[locale.languageCode]!['matchFound']!;
  String get possibleMatch =>
      _localizedValues[locale.languageCode]!['possibleMatch']!;
  String get viewDetails =>
      _localizedValues[locale.languageCode]!['viewDetails']!;
  String get saveResult =>
      _localizedValues[locale.languageCode]!['saveResult']!;

  // Plant Information
  String get taxonomy => _localizedValues[locale.languageCode]!['taxonomy']!;
  String get morphology =>
      _localizedValues[locale.languageCode]!['morphology']!;
  String get ecology => _localizedValues[locale.languageCode]!['ecology']!;
  String get medicinalUses =>
      _localizedValues[locale.languageCode]!['medicinalUses']!;
  String get preparationMethods =>
      _localizedValues[locale.languageCode]!['preparationMethods']!;
  String get preparation =>
      _localizedValues[locale.languageCode]!['preparation']!;
  String get details => _localizedValues[locale.languageCode]!['details']!;
  String get habitat => _localizedValues[locale.languageCode]!['habitat']!;
  String get localNames =>
      _localizedValues[locale.languageCode]!['localNames']!;
  String get safetyWarnings =>
      _localizedValues[locale.languageCode]!['safetyWarnings']!;
  String get noMedicinalUses =>
      _localizedValues[locale.languageCode]!['noMedicinalUses']!;
  String get noSafetyWarnings =>
      _localizedValues[locale.languageCode]!['noSafetyWarnings']!;
  String get noPreparationMethods =>
      _localizedValues[locale.languageCode]!['noPreparationMethods']!;
  String get importantWarnings =>
      _localizedValues[locale.languageCode]!['importantWarnings']!;
  String get steps => _localizedValues[locale.languageCode]!['steps']!;
  String get dosageAndFrequency =>
      _localizedValues[locale.languageCode]!['dosageAndFrequency']!;
  String get dosage => _localizedValues[locale.languageCode]!['dosage']!;
  String get frequency => _localizedValues[locale.languageCode]!['frequency']!;
  String get duration => _localizedValues[locale.languageCode]!['duration']!;
  String get warnings => _localizedValues[locale.languageCode]!['warnings']!;
  String get effectiveness =>
      _localizedValues[locale.languageCode]!['effectiveness']!;
  String get activeCompounds =>
      _localizedValues[locale.languageCode]!['activeCompounds']!;
  String get consultHealthcareDisclaimer =>
      _localizedValues[locale.languageCode]!['consultHealthcareDisclaimer']!;
  String get startPreparationFocusMode =>
      _localizedValues[locale.languageCode]!['startPreparationFocusMode']!;
  String get addScheduleToCalendar =>
      _localizedValues[locale.languageCode]!['addScheduleToCalendar']!;
  String get timerFinished =>
      _localizedValues[locale.languageCode]!['timerFinished']!;
  String get openingCalendar =>
      _localizedValues[locale.languageCode]!['openingCalendar']!;
  String get preparationGuide =>
      _localizedValues[locale.languageCode]!['preparationGuide']!;

  // Contraindication Engine (Safety Informatics)
  String get drugInteractions =>
      _localizedValues[locale.languageCode]!['drugInteractions']!;
  String get notSafeForPregnancy =>
      _localizedValues[locale.languageCode]!['notSafeForPregnancy']!;
  String get knownSideEffects =>
      _localizedValues[locale.languageCode]!['knownSideEffects']!;
  String get strictContraindications =>
      _localizedValues[locale.languageCode]!['strictContraindications']!;
  String get generallySafeForConsumption =>
      _localizedValues[locale.languageCode]!['generallySafeForConsumption']!;
  String get safetyDisclaimerEducational =>
      _localizedValues[locale.languageCode]!['safetyDisclaimerEducational']!;
  String get noStructuredSafetyData =>
      _localizedValues[locale.languageCode]!['noStructuredSafetyData']!;
  String get avoidUseWith =>
      _localizedValues[locale.languageCode]!['avoidUseWith']!;

  // Static Habitat Heatmap
  String get viewHabitatMap =>
      _localizedValues[locale.languageCode]!['viewHabitatMap']!;
  String get noHabitatData =>
      _localizedValues[locale.languageCode]!['noHabitatData']!;
  String get noHabitatDataSubtitle =>
      _localizedValues[locale.languageCode]!['noHabitatDataSubtitle']!;
  String get knownHabitatRegions =>
      _localizedValues[locale.languageCode]!['knownHabitatRegions']!;
  String get climateNotes =>
      _localizedValues[locale.languageCode]!['climateNotes']!;
  String get whereItGrows =>
      _localizedValues[locale.languageCode]!['whereItGrows']!;
  String get habitatLoadError =>
      _localizedValues[locale.languageCode]!['habitatLoadError']!;

  // 2D Interactive Plant Silhouette (anatomy)
  String get explorePlantParts =>
      _localizedValues[locale.languageCode]!['explorePlantParts']!;

  // Settings
  String get language => _localizedValues[locale.languageCode]!['language']!;
  String get offlineMode =>
      _localizedValues[locale.languageCode]!['offlineMode']!;
  String get showConfidenceScores =>
      _localizedValues[locale.languageCode]!['showConfidenceScores']!;
  String get showGradCAM =>
      _localizedValues[locale.languageCode]!['showGradCAM']!;
  String get showTop3Results =>
      _localizedValues[locale.languageCode]!['showTop3Results']!;

  // Common
  String get loading => _localizedValues[locale.languageCode]!['loading']!;
  String get error => _localizedValues[locale.languageCode]!['error']!;
  String get retry => _localizedValues[locale.languageCode]!['retry']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get save => _localizedValues[locale.languageCode]!['save']!;
  String get delete => _localizedValues[locale.languageCode]!['delete']!;
  String get search => _localizedValues[locale.languageCode]!['search']!;
  String get filter => _localizedValues[locale.languageCode]!['filter']!;
  String get all => _localizedValues[locale.languageCode]!['all']!;
  String get viewAll => _localizedValues[locale.languageCode]!['viewAll']!;
  String get noResults => _localizedValues[locale.languageCode]!['noResults']!;
  String get clear => _localizedValues[locale.languageCode]!['clear']!;

  // Browse Screen
  String get searchPlants =>
      _localizedValues[locale.languageCode]!['searchPlants']!;
  String get allPlants => _localizedValues[locale.languageCode]!['allPlants']!;
  String get byCondition =>
      _localizedValues[locale.languageCode]!['byCondition']!;
  String get plantCount =>
      _localizedValues[locale.languageCode]!['plantCount']!;
  String get noResultsFound =>
      _localizedValues[locale.languageCode]!['noResultsFound']!;
  String get tryDifferentSearch =>
      _localizedValues[locale.languageCode]!['tryDifferentSearch']!;

  // History Screen
  String get scanHistory =>
      _localizedValues[locale.languageCode]!['scanHistory']!;
  String get noScansYet =>
      _localizedValues[locale.languageCode]!['noScansYet']!;
  String get startScanning =>
      _localizedValues[locale.languageCode]!['startScanning']!;
  String get deleteAll => _localizedValues[locale.languageCode]!['deleteAll']!;
  String get confirmDelete =>
      _localizedValues[locale.languageCode]!['confirmDelete']!;
  String get deleteConfirmation =>
      _localizedValues[locale.languageCode]!['deleteConfirmation']!;
  String get confidence =>
      _localizedValues[locale.languageCode]!['confidence']!;

  // Condition Search
  String get browseByCondition =>
      _localizedValues[locale.languageCode]!['browseByCondition']!;
  String get selectCondition =>
      _localizedValues[locale.languageCode]!['selectCondition']!;
  String get commonConditions =>
      _localizedValues[locale.languageCode]!['commonConditions']!;

  // DOH Specific
  String get dohApprovedLabel =>
      _localizedValues[locale.languageCode]!['dohApprovedLabel']!;
  String get philippineDepartmentOfHealth =>
      _localizedValues[locale.languageCode]!['philippineDepartmentOfHealth']!;
  String get clinicallyValidated =>
      _localizedValues[locale.languageCode]!['clinicallyValidated']!;

  // Warnings
  String get medicalDisclaimer =>
      _localizedValues[locale.languageCode]!['medicalDisclaimer']!;
  String get consultHealthcareProvider =>
      _localizedValues[locale.languageCode]!['consultHealthcareProvider']!;
  String get notForPregnantWomen =>
      _localizedValues[locale.languageCode]!['notForPregnantWomen']!;

  // Error States
  String get poorImageQuality =>
      _localizedValues[locale.languageCode]!['poorImageQuality']!;
  String get imageQualityTooLow =>
      _localizedValues[locale.languageCode]!['imageQualityTooLow']!;
  String get improveImageQuality =>
      _localizedValues[locale.languageCode]!['improveImageQuality']!;
  String get noMatchFound =>
      _localizedValues[locale.languageCode]!['noMatchFound']!;
  String get noMatchDescription =>
      _localizedValues[locale.languageCode]!['noMatchDescription']!;
  String get tryAgain => _localizedValues[locale.languageCode]!['tryAgain']!;
  String get retake => _localizedValues[locale.languageCode]!['retake']!;
  String get browseManually =>
      _localizedValues[locale.languageCode]!['browseManually']!;
  String get scanningTipsTitle =>
      _localizedValues[locale.languageCode]!['scanningTipsTitle']!;

  // Help & Tips
  String get helpAndTutorial =>
      _localizedValues[locale.languageCode]!['helpAndTutorial']!;
  String get bestPractices =>
      _localizedValues[locale.languageCode]!['bestPractices']!;
  String get useBrightLight =>
      _localizedValues[locale.languageCode]!['useBrightLight']!;
  String get holdSteady =>
      _localizedValues[locale.languageCode]!['holdSteady']!;
  String get cleanLeaf => _localizedValues[locale.languageCode]!['cleanLeaf']!;
  String get singleLeafFocus =>
      _localizedValues[locale.languageCode]!['singleLeafFocus']!;
  String get avoidShadowsAndReflections =>
      _localizedValues[locale.languageCode]!['avoidShadowsAndReflections']!;
  String get fillFrame => _localizedValues[locale.languageCode]!['fillFrame']!;
  String get matureLeaf =>
      _localizedValues[locale.languageCode]!['matureLeaf']!;
  String get plainBackground =>
      _localizedValues[locale.languageCode]!['plainBackground']!;

  // Feedback Screen
  String get sendFeedback =>
      _localizedValues[locale.languageCode]!['sendFeedback']!;
  String get yourFeedbackMatters =>
      _localizedValues[locale.languageCode]!['yourFeedbackMatters']!;
  String get rateYourExperience =>
      _localizedValues[locale.languageCode]!['rateYourExperience']!;
  String get feedbackCategory =>
      _localizedValues[locale.languageCode]!['feedbackCategory']!;
  String get yourComments =>
      _localizedValues[locale.languageCode]!['yourComments']!;
  String get featureSuggestion =>
      _localizedValues[locale.languageCode]!['featureSuggestion']!;
  String get optional => _localizedValues[locale.languageCode]!['optional']!;
  String get submitFeedback =>
      _localizedValues[locale.languageCode]!['submitFeedback']!;
  String get pleaseProvideRating =>
      _localizedValues[locale.languageCode]!['pleaseProvideRating']!;
  String get pleaseEnterComment =>
      _localizedValues[locale.languageCode]!['pleaseEnterComment']!;
  String get thankYou => _localizedValues[locale.languageCode]!['thankYou']!;
  String get feedbackSubmitted =>
      _localizedValues[locale.languageCode]!['feedbackSubmitted']!;
  String get done => _localizedValues[locale.languageCode]!['done']!;
  String get appPerformance =>
      _localizedValues[locale.languageCode]!['appPerformance']!;
  String get viewPerformanceData =>
      _localizedValues[locale.languageCode]!['viewPerformanceData']!;

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'HerbaScan',
      'scan': 'Scan',
      'browse': 'Browse',
      'history': 'History',
      'dohApproved': 'DOH',
      'settings': 'Settings',
      'welcomeMessage':
          'Identify medicinal plants using AI-powered recognition technology',
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
      'preparation': 'Preparation',
      'details': 'Details',
      'habitat': 'Habitat',
      'localNames': 'Local Names',
      'safetyWarnings': 'Safety Warnings',
      'noMedicinalUses': 'No medicinal uses documented',
      'noSafetyWarnings': 'No safety warnings documented',
      'noPreparationMethods': 'No preparation methods available',
      'importantWarnings': 'Important Warnings',
      'steps': 'Steps',
      'dosageAndFrequency': 'Dosage & Frequency',
      'dosage': 'Dosage',
      'frequency': 'Frequency',
      'duration': 'Duration',
      'warnings': 'Warnings',
      'effectiveness': 'Effectiveness',
      'activeCompounds': 'Active Compounds',
      'consultHealthcareDisclaimer':
          'Always consult healthcare professionals before using any herbal remedies',
      'startPreparationFocusMode': 'Start Preparation (Focus Mode)',
      'addScheduleToCalendar': 'Add Schedule to Device Calendar',
      'timerFinished': 'Timer finished',
      'openingCalendar': 'Opening calendar to add event',
      'preparationGuide': 'Preparation Guide',
      'drugInteractions': 'Drug interactions',
      'notSafeForPregnancy': 'Not safe for pregnancy',
      'knownSideEffects': 'Known side effects',
      'strictContraindications': 'Strict contraindications',
      'generallySafeForConsumption': 'Generally safe for normal consumption.',
      'safetyDisclaimerEducational':
          'This app is for educational purposes only. It is not a replacement for professional medical advice. Always consult a healthcare professional before using herbal remedies, especially if you are pregnant, nursing, taking medications, or have existing medical conditions.',
      'noStructuredSafetyData': 'No structured safety data for this plant.',
      'avoidUseWith': 'Avoid use with',
      'viewHabitatMap': 'Habitat Map',
      'noHabitatData': 'No habitat data',
      'noHabitatDataSubtitle':
          'Known habitat regions for this plant are not yet in the database. Data is from curated sources (e.g. DOST-PCHRD, DA).',
      'knownHabitatRegions': 'Known habitat regions',
      'climateNotes': 'Climate & habitat notes',
      'whereItGrows': 'Where it grows',
      'habitatLoadError': 'Failed to load habitat data.',
      'explorePlantParts': 'Explore plant parts',
      'language': 'Language / Wika',
      'offlineMode': 'Offline Mode',
      'showConfidenceScores': 'Show Confidence Scores',
      'showGradCAM': 'Score-CAM Visualization',
      'showTop3Results': 'Top-3 Results',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'search': 'Search',
      'filter': 'Filter',
      'all': 'All',
      'viewAll': 'View All',
      'noResults': 'No Results',
      'clear': 'Clear',
      'searchPlants': 'Search plants...',
      'allPlants': 'All Plants',
      'byCondition': 'By Condition',
      'plantCount': 'plants',
      'noResultsFound': 'No plants found',
      'tryDifferentSearch': 'Try a different search term',
      'scanHistory': 'Scan History',
      'noScansYet': 'No scans yet',
      'startScanning': 'Start by scanning your first plant!',
      'deleteAll': 'Delete All',
      'confirmDelete': 'Confirm Delete',
      'deleteConfirmation': 'Are you sure you want to delete this scan?',
      'confidence': 'Confidence',
      'browseByCondition': 'Browse by Condition',
      'selectCondition': 'Select a medical condition',
      'commonConditions': 'Common Conditions',
      'dohApprovedLabel': '✓ DOH Approved',
      'philippineDepartmentOfHealth': 'Philippine Department of Health',
      'clinicallyValidated': 'clinically validated herbal medicines',
      'medicalDisclaimer':
          'Always consult healthcare professionals before using any herbal remedies',
      'consultHealthcareProvider':
          'Consult healthcare provider before use. Not for pregnant/nursing women.',
      'notForPregnantWomen': 'Not for pregnant/nursing women.',
      'poorImageQuality': 'Poor Image Quality',
      'imageQualityTooLow':
          'Image quality is too low for accurate identification',
      'improveImageQuality':
          'Please follow these tips to improve image quality:',
      'noMatchFound': 'No Match Found',
      'noMatchDescription': 'The plant could not be identified in our database',
      'tryAgain': 'Try Again',
      'retake': 'Retake Photo',
      'browseManually': 'Browse Manually',
      'scanningTipsTitle': 'Scanning Tips',
      'helpAndTutorial': 'Help & Tutorial',
      'bestPractices': 'Best Practices for Scanning',
      'useBrightLight': 'Use bright, natural lighting',
      'holdSteady': 'Hold device steady to avoid blur',
      'cleanLeaf': 'Use a clean, healthy leaf',
      'singleLeafFocus': 'Focus on a single leaf',
      'avoidShadowsAndReflections': 'Avoid shadows and reflections',
      'fillFrame': 'Fill the frame with the leaf',
      'matureLeaf': 'Use a mature, fully-grown leaf',
      'plainBackground': 'Use a plain, contrasting background',
      'sendFeedback': 'Send Feedback',
      'yourFeedbackMatters': 'Your Feedback Matters',
      'rateYourExperience': 'Rate Your Experience',
      'feedbackCategory': 'Feedback Category',
      'yourComments': 'Your Comments',
      'featureSuggestion': 'Feature Suggestion',
      'optional': 'Optional',
      'submitFeedback': 'Submit Feedback',
      'pleaseProvideRating': 'Please provide a rating',
      'pleaseEnterComment': 'Please enter your comment',
      'thankYou': 'Thank You!',
      'feedbackSubmitted':
          'Your feedback has been submitted successfully. Thank you for helping us improve HerbaScan!',
      'done': 'Done',
      'appPerformance': 'App Performance',
      'viewPerformanceData': 'View performance data and statistics',
    },
    'fil': {
      'appTitle': 'HerbaScan',
      'scan': 'I-scan',
      'browse': 'Tingnan',
      'history': 'Kasaysayan',
      'dohApproved': 'DOH',
      'settings': 'Mga Setting',
      'welcomeMessage':
          'Kilalanin ang mga halamang gamot gamit ang teknolohiyang AI',
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
      'preparation': 'Paghahanda',
      'details': 'Mga Detalye',
      'habitat': 'Tirahan',
      'localNames': 'Mga Lokal na Pangalan',
      'safetyWarnings': 'Mga Babala sa Kaligtasan',
      'noMedicinalUses': 'Walang dokumentadong gamit na panggamot',
      'noSafetyWarnings': 'Walang dokumentadong babala sa kaligtasan',
      'noPreparationMethods': 'Walang available na paraan ng paghahanda',
      'importantWarnings': 'Mahalagang Babala',
      'steps': 'Mga Hakbang',
      'dosageAndFrequency': 'Dosis at Dalas',
      'dosage': 'Dosis',
      'frequency': 'Dalas',
      'duration': 'Tagal',
      'warnings': 'Mga Babala',
      'effectiveness': 'Pagiging Epektibo',
      'activeCompounds': 'Mga Aktibong Sangkap',
      'consultHealthcareDisclaimer':
          'Laging kumonsulta sa mga propesyonal sa kalusugan bago gumamit ng anumang halamang gamot',
      'startPreparationFocusMode': 'Simulan ang Paghahanda (Focus Mode)',
      'addScheduleToCalendar': 'Idagdag ang Iskedyul sa Kalendaryo ng Device',
      'timerFinished': 'Tapos na ang timer',
      'openingCalendar': 'Binubuksan ang kalendaryo para magdagdag ng event',
      'preparationGuide': 'Gabay sa Paghahanda',
      'drugInteractions': 'Pakikipag-ugnayan sa gamot',
      'notSafeForPregnancy': 'Hindi ligtas para sa pagbubuntis',
      'knownSideEffects': 'Kilalang side effects',
      'strictContraindications': 'Strikto na mga kontraindikasyon',
      'generallySafeForConsumption': 'Sa pangkalahatan ay ligtas para sa normal na pagkonsumo.',
      'safetyDisclaimerEducational':
          'Ang app na ito ay para lamang sa edukasyonal na layunin. Hindi ito kapalit ng propesyonal na payo medikal. Laging kumonsulta sa propesyonal sa kalusugan bago gumamit ng halamang gamot, lalo na kung ikaw ay buntis, nagpapasuso, umiinom ng gamot, o may umiiral na kondisyong medikal.',
      'noStructuredSafetyData': 'Walang istrukturang data ng kaligtasan para sa halamang ito.',
      'avoidUseWith': 'Iwasan ang paggamit kasama ng',
      'viewHabitatMap': 'Mapa ng Tirahan',
      'noHabitatData': 'Walang data ng tirahan',
      'noHabitatDataSubtitle':
          'Ang mga kilalang rehiyong tirahan ng halamang ito ay wala pa sa database. Ang data ay mula sa mga curated na pinagmulan (hal. DOST-PCHRD, DA).',
      'knownHabitatRegions': 'Kilalang rehiyong tirahan',
      'climateNotes': 'Mga tala sa klima at tirahan',
      'whereItGrows': 'Saan ito tumutubo',
      'habitatLoadError': 'Hindi ma-load ang data ng tirahan.',
      'explorePlantParts': 'Tuklasin ang mga bahagi ng halaman',
      'language': 'Wika / Language',
      'offlineMode': 'Offline Mode',
      'showConfidenceScores': 'Ipakita ang Confidence Scores',
      'showGradCAM': 'Score-CAM Visualization',
      'showTop3Results': 'Top-3 na Resulta',
      'loading': 'Naglo-load...',
      'error': 'May Mali',
      'retry': 'Subukan Muli',
      'cancel': 'Kanselahin',
      'save': 'I-save',
      'delete': 'Tanggalin',
      'search': 'Maghanap',
      'filter': 'I-filter',
      'all': 'Lahat',
      'viewAll': 'Tingnan Lahat',
      'noResults': 'Walang Resulta',
      'clear': 'Burahin',
      'searchPlants': 'Maghanap ng halaman...',
      'allPlants': 'Lahat ng Halaman',
      'byCondition': 'Ayon sa Kondisyon',
      'plantCount': 'halaman',
      'noResultsFound': 'Walang nahanap na halaman',
      'tryDifferentSearch': 'Subukan ang ibang search term',
      'scanHistory': 'Kasaysayan ng Scan',
      'noScansYet': 'Wala pang scan',
      'startScanning': 'Magsimula sa pag-scan ng iyong unang halaman!',
      'deleteAll': 'Tanggalin Lahat',
      'confirmDelete': 'Kumpirmahin ang Pagtanggal',
      'deleteConfirmation':
          'Sigurado ka bang gusto mong tanggalin ang scan na ito?',
      'confidence': 'Confidence',
      'browseByCondition': 'Tingnan Ayon sa Kondisyon',
      'selectCondition': 'Pumili ng kondisyong medikal',
      'commonConditions': 'Mga Karaniwang Kondisyon',
      'dohApprovedLabel': '✓ Pinahintulutan ng DOH',
      'philippineDepartmentOfHealth': 'Kagawaran ng Kalusugan ng Pilipinas',
      'clinicallyValidated': 'mga halamang gamot na klinikal na napatunayan',
      'medicalDisclaimer':
          'Laging kumonsulta sa mga propesyonal sa kalusugan bago gumamit ng anumang halamang gamot',
      'consultHealthcareProvider':
          'Kumonsulta sa healthcare provider bago gamitin. Hindi para sa mga buntis/nagpapasuso.',
      'notForPregnantWomen': 'Hindi para sa mga buntis/nagpapasuso.',
      'poorImageQuality': 'Mahinang Kalidad ng Larawan',
      'imageQualityTooLow':
          'Ang kalidad ng larawan ay masyadong mababa para sa tumpak na pagkilala',
      'improveImageQuality':
          'Pakisundin ang mga tip na ito upang mapabuti ang kalidad ng larawan:',
      'noMatchFound': 'Walang Nahanap na Tugma',
      'noMatchDescription': 'Ang halaman ay hindi nakilala sa aming database',
      'tryAgain': 'Subukan Muli',
      'retake': 'Kumuha Muli ng Larawan',
      'browseManually': 'Mag-browse Nang Manu-mano',
      'scanningTipsTitle': 'Mga Tip sa Pag-scan',
      'helpAndTutorial': 'Tulong at Tutorial',
      'bestPractices': 'Pinakamahusay na Gawain sa Pag-scan',
      'useBrightLight': 'Gumamit ng maliwanag na natural na ilaw',
      'holdSteady': 'Hawakan ng matatag ang device upang maiwasan ang blur',
      'cleanLeaf': 'Gumamit ng malinis at malusog na dahon',
      'singleLeafFocus': 'Tumutok sa isang dahon lamang',
      'avoidShadowsAndReflections': 'Iwasan ang mga anino at repleksyon',
      'fillFrame': 'Punuin ang frame ng dahon',
      'matureLeaf': 'Gumamit ng matanda, ganap na lumaki na dahon',
      'plainBackground': 'Gumamit ng plain, kaibang background',
      'sendFeedback': 'Magpadala ng Feedback',
      'yourFeedbackMatters': 'Ang Iyong Feedback ay Mahalaga',
      'rateYourExperience': 'I-rate ang Iyong Karanasan',
      'feedbackCategory': 'Kategorya ng Feedback',
      'yourComments': 'Ang Iyong Mga Komento',
      'featureSuggestion': 'Mungkahi sa Feature',
      'optional': 'Opsyonal',
      'submitFeedback': 'Isumite ang Feedback',
      'pleaseProvideRating': 'Mangyaring magbigay ng rating',
      'pleaseEnterComment': 'Mangyaring ilagay ang iyong komento',
      'thankYou': 'Salamat!',
      'feedbackSubmitted':
          'Ang iyong feedback ay matagumpay na naisumite. Salamat sa pagtulong sa amin na mapabuti ang HerbaScan!',
      'done': 'Tapos na',
      'appPerformance': 'Pagganap ng App',
      'viewPerformanceData': 'Tingnan ang data at istatistika ng pagganap',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
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
