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

  // Auth Flow
  String get emailOrPasswordMismatch => _localizedValues[locale.languageCode]!['emailOrPasswordMismatch']!;
  String get signInFailed => _localizedValues[locale.languageCode]!['signInFailed']!;
  String tooManyAttempts(int seconds) => _localizedValues[locale.languageCode]!['tooManyAttempts']!.replaceAll('{seconds}', seconds.toString());
  String get signInTitle => _localizedValues[locale.languageCode]!['signInTitle']!;
  String get backToApp => _localizedValues[locale.languageCode]!['backToApp']!;
  String get emailLabel => _localizedValues[locale.languageCode]!['emailLabel']!;
  String get emailHint => _localizedValues[locale.languageCode]!['emailHint']!;
  String get enterEmail => _localizedValues[locale.languageCode]!['enterEmail']!;
  String get validEmailRequired => _localizedValues[locale.languageCode]!['validEmailRequired']!;
  String get passwordLabel => _localizedValues[locale.languageCode]!['passwordLabel']!;
  String get enterPassword => _localizedValues[locale.languageCode]!['enterPassword']!;
  String get forgotPasswordLabel => _localizedValues[locale.languageCode]!['forgotPasswordLabel']!;
  String waitSeconds(int seconds) => _localizedValues[locale.languageCode]!['waitSeconds']!.replaceAll('{seconds}', seconds.toString());
  String get newToHerbaScan => _localizedValues[locale.languageCode]!['newToHerbaScan']!;
  String get createAccountBtn => _localizedValues[locale.languageCode]!['createAccountBtn']!;
  String get personalHerbarium => _localizedValues[locale.languageCode]!['personalHerbarium']!;
  String get loginSubtitle => _localizedValues[locale.languageCode]!['loginSubtitle']!;
  String get tooManyEmailsSent => _localizedValues[locale.languageCode]!['tooManyEmailsSent']!;
  String get emailAlreadyRegistered => _localizedValues[locale.languageCode]!['emailAlreadyRegistered']!;
  String get createAccountTitle => _localizedValues[locale.languageCode]!['createAccountTitle']!;
  String get signupSubtitle => _localizedValues[locale.languageCode]!['signupSubtitle']!;
  String get passwordHint => _localizedValues[locale.languageCode]!['passwordHint']!;
  String get useAtLeast8Chars => _localizedValues[locale.languageCode]!['useAtLeast8Chars']!;
  String get includeCapitalLetter => _localizedValues[locale.languageCode]!['includeCapitalLetter']!;
  String get includeLowercaseLetter => _localizedValues[locale.languageCode]!['includeLowercaseLetter']!;
  String get includeNumber => _localizedValues[locale.languageCode]!['includeNumber']!;
  String get includeSpecialChar => _localizedValues[locale.languageCode]!['includeSpecialChar']!;
  String get confirmPasswordLabel => _localizedValues[locale.languageCode]!['confirmPasswordLabel']!;
  String get confirmPasswordHint => _localizedValues[locale.languageCode]!['confirmPasswordHint']!;
  String get passwordsDoNotMatch => _localizedValues[locale.languageCode]!['passwordsDoNotMatch']!;
  String get confirmYourPassword => _localizedValues[locale.languageCode]!['confirmYourPassword']!;
  String get alreadyHaveCode => _localizedValues[locale.languageCode]!['alreadyHaveCode']!;
  String get enterValidEmailForCode => _localizedValues[locale.languageCode]!['enterValidEmailForCode']!;
  String get resetPasswordTitle => _localizedValues[locale.languageCode]!['resetPasswordTitle']!;
  String get resetPasswordSubtitle => _localizedValues[locale.languageCode]!['resetPasswordSubtitle']!;
  String get sendCodeBtn => _localizedValues[locale.languageCode]!['sendCodeBtn']!;
  String get backToSignIn => _localizedValues[locale.languageCode]!['backToSignIn']!;
  String get createNewPasswordTitle => _localizedValues[locale.languageCode]!['createNewPasswordTitle']!;
  String get remainSignedIn => _localizedValues[locale.languageCode]!['remainSignedIn']!;
  String get currentPasswordLabel => _localizedValues[locale.languageCode]!['currentPasswordLabel']!;
  String get enterCurrentPassword => _localizedValues[locale.languageCode]!['enterCurrentPassword']!;
  String get newPasswordLabel => _localizedValues[locale.languageCode]!['newPasswordLabel']!;
  String get confirmNewPassword => _localizedValues[locale.languageCode]!['confirmNewPassword']!;
  String get updatePasswordBtn => _localizedValues[locale.languageCode]!['updatePasswordBtn']!;
  String get passwordUpdated => _localizedValues[locale.languageCode]!['passwordUpdated']!;
  String get incorrectCurrentPassword => _localizedValues[locale.languageCode]!['incorrectCurrentPassword']!;
  String get emailUpdatedMsg => _localizedValues[locale.languageCode]!['emailUpdatedMsg']!;
  String get emailAddressTitle => _localizedValues[locale.languageCode]!['emailAddressTitle']!;
  String get updateEmailSubtitle => _localizedValues[locale.languageCode]!['updateEmailSubtitle']!;
  String get newEmailAddressLabel => _localizedValues[locale.languageCode]!['newEmailAddressLabel']!;
  String get enterNewEmail => _localizedValues[locale.languageCode]!['enterNewEmail']!;
  String get newEmailMustBeDifferent => _localizedValues[locale.languageCode]!['newEmailMustBeDifferent']!;
  String get confirmationLinkMsg => _localizedValues[locale.languageCode]!['confirmationLinkMsg']!;
  String get updateEmailBtn => _localizedValues[locale.languageCode]!['updateEmailBtn']!;
  String get codeExpired => _localizedValues[locale.languageCode]!['codeExpired']!;
  String get invalidCode => _localizedValues[locale.languageCode]!['invalidCode']!;
  String get newCodeSent => _localizedValues[locale.languageCode]!['newCodeSent']!;
  String get failedToResend => _localizedValues[locale.languageCode]!['failedToResend']!;
  String get checkYourInbox => _localizedValues[locale.languageCode]!['checkYourInbox']!;
  String sent6DigitCode(String email) => _localizedValues[locale.languageCode]!['sent6DigitCode']!.replaceAll('{email}', email);
  String tooManyAttemptsWait(String lockedUntil) => _localizedValues[locale.languageCode]!['tooManyAttemptsWait']!.replaceAll('{lockedUntil}', lockedUntil);
  String attemptsLeft(int attemptsLeft) => _localizedValues[locale.languageCode]!['attemptsLeft']!.replaceAll('{attemptsLeft}', attemptsLeft.toString());
  String get activateAccountBtn => _localizedValues[locale.languageCode]!['activateAccountBtn']!;
  String waitResend(int seconds) => _localizedValues[locale.languageCode]!['waitResend']!.replaceAll('{seconds}', seconds.toString());
  String get didntReceiveEmail => _localizedValues[locale.languageCode]!['didntReceiveEmail']!;
  String get continueBtn => _localizedValues[locale.languageCode]!['continueBtn']!;
  String get accountSuspendedTitle => _localizedValues[locale.languageCode]!['accountSuspendedTitle']!;
  String get accountSuspendedSubtitle => _localizedValues[locale.languageCode]!['accountSuspendedSubtitle']!;
  String get reasonLabel => _localizedValues[locale.languageCode]!['reasonLabel']!;
  String get contactSupportBtn => _localizedValues[locale.languageCode]!['contactSupportBtn']!;
  String get couldNotOpenEmail => _localizedValues[locale.languageCode]!['couldNotOpenEmail']!;
  String get supportMistakeMsg => _localizedValues[locale.languageCode]!['supportMistakeMsg']!;
  String get accountVerifiedTitle => _localizedValues[locale.languageCode]!['accountVerifiedTitle']!;
  String accountCreatedAs(String email) => _localizedValues[locale.languageCode]!['accountCreatedAs']!.replaceAll('{email}', email);
  String get nowSignedInWelcome => _localizedValues[locale.languageCode]!['nowSignedInWelcome']!;
  String redirectingSettings(int countdown) => _localizedValues[locale.languageCode]!['redirectingSettings']!.replaceAll('{countdown}', countdown.toString());
  String get goToSettingsBtn => _localizedValues[locale.languageCode]!['goToSettingsBtn']!;
  String get authenticating => _localizedValues[locale.languageCode]!['authenticating']!;
  String get authenticationTitle => _localizedValues[locale.languageCode]!['authenticationTitle']!;
  String get authErrorTitle => _localizedValues[locale.languageCode]!['authErrorTitle']!;
  String get authStatusTitle => _localizedValues[locale.languageCode]!['authStatusTitle']!;
  String get goToDashboardBtn => _localizedValues[locale.languageCode]!['goToDashboardBtn']!;

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
  String get unauthorizedAccess => _localizedValues[locale.languageCode]!['unauthorizedAccess']!;
  String get whatPlant => _localizedValues[locale.languageCode]!['whatPlant']!;
  String get tapCameraToStart => _localizedValues[locale.languageCode]!['tapCameraToStart']!;
  String get scansCount => _localizedValues[locale.languageCode]!['scansCount']!;
  String get seeAll => _localizedValues[locale.languageCode]!['seeAll']!;
  String get unknownPlant => _localizedValues[locale.languageCode]!['unknownPlant']!;
  String get dohApprovedPlants => _localizedValues[locale.languageCode]!['dohApprovedPlants']!;
  String get noDohPlantsLoaded => _localizedValues[locale.languageCode]!['noDohPlantsLoaded']!;

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
  String get plantReferences => _localizedValues[locale.languageCode]!['plantReferences']!;
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
  String get useWithStrictCaution =>
      _localizedValues[locale.languageCode]!['useWithStrictCaution']!;
  String get useWithStrictCautionBody =>
      _localizedValues[locale.languageCode]!['useWithStrictCautionBody']!;
  String get generallySafeForConsumption =>
      _localizedValues[locale.languageCode]!['generallySafeForConsumption']!;
  String get safetyDisclaimerEducational =>
      _localizedValues[locale.languageCode]!['safetyDisclaimerEducational']!;
  String get noStructuredSafetyData =>
      _localizedValues[locale.languageCode]!['noStructuredSafetyData']!;
  String get safetyInformationUnavailable =>
      _localizedValues[locale.languageCode]!['safetyInformationUnavailable']!;
  String get safetyInformationUnavailableBody =>
      _localizedValues[locale.languageCode]!['safetyInformationUnavailableBody']!;
  String get plantNotRecognized =>
      _localizedValues[locale.languageCode]!['plantNotRecognized']!;
  String get uncertainMatchBody =>
      _localizedValues[locale.languageCode]!['uncertainMatchBody']!;
  String get whyCantAppIdentify =>
      _localizedValues[locale.languageCode]!['whyCantAppIdentify']!;
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
  String get nextPart => _localizedValues[locale.languageCode]!['nextPart']!;
  String get previousPart =>
      _localizedValues[locale.languageCode]!['previousPart']!;

  // Admin Anatomy tab
  String get adminAnatomyEmpty =>
      _localizedValues[locale.languageCode]!['adminAnatomyEmpty']!;
  String get adminAnatomyAddPart =>
      _localizedValues[locale.languageCode]!['adminAnatomyAddPart']!;
  String get restoreToDefault =>
      _localizedValues[locale.languageCode]!['restoreToDefault']!;
  String get edit => _localizedValues[locale.languageCode]!['edit']!;
  String get adminAnatomyDeleteConfirm =>
      _localizedValues[locale.languageCode]!['adminAnatomyDeleteConfirm']!;
  String get savedToCatalog =>
      _localizedValues[locale.languageCode]!['savedToCatalog']!;
  String get saveFailed =>
      _localizedValues[locale.languageCode]!['saveFailed']!;
  String get deleted => _localizedValues[locale.languageCode]!['deleted']!;
  String get restoredToDefault =>
      _localizedValues[locale.languageCode]!['restoredToDefault']!;

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
  String searchPlantsCount(int count) =>
      _localizedValues[locale.languageCode]!['searchPlantsCount']!.replaceAll('{count}', count.toString());
  String showingPlants(int count) =>
      _localizedValues[locale.languageCode]!['showingPlants']!.replaceAll('{count}', count.toString());
  String get allPlants => _localizedValues[locale.languageCode]!['allPlants']!;
  String get byCondition =>
      _localizedValues[locale.languageCode]!['byCondition']!;
  String get plantCount =>
      _localizedValues[locale.languageCode]!['plantCount']!;
  String get noResultsFound =>
      _localizedValues[locale.languageCode]!['noResultsFound']!;
  String get tryDifferentSearch =>
      _localizedValues[locale.languageCode]!['tryDifferentSearch']!;
  String get medical => _localizedValues[locale.languageCode]!['medical']!;
  String get listView => _localizedValues[locale.languageCode]!['listView']!;
  String get gridView => _localizedValues[locale.languageCode]!['gridView']!;

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
  String get saveToCloud =>
      _localizedValues[locale.languageCode]!['saveToCloud']!;
  String get saveToDevice =>
      _localizedValues[locale.languageCode]!['saveToDevice']!;

  // Admin User Management
  String get makeAdmin =>
      _localizedValues[locale.languageCode]!['makeAdmin']!;
  String get removeAdmin =>
      _localizedValues[locale.languageCode]!['removeAdmin']!;
  String get userNowAdmin =>
      _localizedValues[locale.languageCode]!['userNowAdmin']!;
  String get adminRemoved =>
      _localizedValues[locale.languageCode]!['adminRemoved']!;
  String get forceVerifyEmail =>
      _localizedValues[locale.languageCode]!['forceVerifyEmail']!;
  String get emailVerified =>
      _localizedValues[locale.languageCode]!['emailVerified']!;
  String get forceVerifyNotAvailable =>
      _localizedValues[locale.languageCode]!['forceVerifyNotAvailable']!;

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
  String get browseCatalog =>
      _localizedValues[locale.languageCode]!['browseCatalog']!;
  String get toxicPlantDetected =>
      _localizedValues[locale.languageCode]!['toxicPlantDetected']!;
  String get toxicPlantBody =>
      _localizedValues[locale.languageCode]!['toxicPlantBody']!;
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
  String get didWeGetThisRight =>
      _localizedValues[locale.languageCode]!['didWeGetThisRight']!;
  String get milestoneFeedbackTitle =>
      _localizedValues[locale.languageCode]!['milestoneFeedbackTitle']!;
  String get milestoneFeedbackBody =>
      _localizedValues[locale.languageCode]!['milestoneFeedbackBody']!;
  String get rateExperience =>
      _localizedValues[locale.languageCode]!['rateExperience']!;
  String get maybeLater =>
      _localizedValues[locale.languageCode]!['maybeLater']!;
  String get appPerformance =>
      _localizedValues[locale.languageCode]!['appPerformance']!;
  String get viewPerformanceData =>
      _localizedValues[locale.languageCode]!['viewPerformanceData']!;

  // Admin Web Screen
  String get overview => _localizedValues[locale.languageCode]!['overview']!;
  String get plantCatalog => _localizedValues[locale.languageCode]!['plantCatalog']!;
  String get healthConditions => _localizedValues[locale.languageCode]!['healthConditions']!;
  String get userDirectory => _localizedValues[locale.languageCode]!['userDirectory']!;
  String get systemHealth => _localizedValues[locale.languageCode]!['systemHealth']!;
  String get feedbackMenu => _localizedValues[locale.languageCode]!['feedbackMenu']!;
  String get submissions => _localizedValues[locale.languageCode]!['submissions']!;
  String get appConfig => _localizedValues[locale.languageCode]!['appConfig']!;
  String get adminConsole => _localizedValues[locale.languageCode]!['adminConsole']!;
  String get elevatedPrivilegesActive => _localizedValues[locale.languageCode]!['elevatedPrivilegesActive']!;
  String get adminRole => _localizedValues[locale.languageCode]!['adminRole']!;
  String get signOut => _localizedValues[locale.languageCode]!['signOut']!;
  String get exitAdminConsole => _localizedValues[locale.languageCode]!['exitAdminConsole']!;
  String get selectAModule => _localizedValues[locale.languageCode]!['selectAModule']!;

  // Admin User Management
  String get makeAdminPrompt => _localizedValues[locale.languageCode]!['makeAdminPrompt']!;
  String get removeAdminPrompt => _localizedValues[locale.languageCode]!['removeAdminPrompt']!;
  String get makeAdminDesc => _localizedValues[locale.languageCode]!['makeAdminDesc']!;
  String get removeAdminDesc => _localizedValues[locale.languageCode]!['removeAdminDesc']!;
  String get deleteUserDataPrompt => _localizedValues[locale.languageCode]!['deleteUserDataPrompt']!;
  String get deleteUserDataDesc => _localizedValues[locale.languageCode]!['deleteUserDataDesc']!;
  String get typeDeleteToConfirm => _localizedValues[locale.languageCode]!['typeDeleteToConfirm']!;
  String get deleteUserDataBtn => _localizedValues[locale.languageCode]!['deleteUserDataBtn']!;
  String get deletingAccount => _localizedValues[locale.languageCode]!['deletingAccount']!;
  String get removingAccountData => _localizedValues[locale.languageCode]!['removingAccountData']!;
  String get refresh => _localizedValues[locale.languageCode]!['refresh']!;
  String get searchByEmail => _localizedValues[locale.languageCode]!['searchByEmail']!;
  String get noUsersMatch => _localizedValues[locale.languageCode]!['noUsersMatch']!;
  String get noUsersFound => _localizedValues[locale.languageCode]!['noUsersFound']!;
  String get verified => _localizedValues[locale.languageCode]!['verified']!;
  String get unverified => _localizedValues[locale.languageCode]!['unverified']!;
  String get joined => _localizedValues[locale.languageCode]!['joined']!;
  String get scanCount => _localizedValues[locale.languageCode]!['scanCount']!;
  String get adminLabel => _localizedValues[locale.languageCode]!['adminLabel']!;
  String get userLabel => _localizedValues[locale.languageCode]!['userLabel']!;
  String get suspendAccount => _localizedValues[locale.languageCode]!['suspendAccount']!;
  String get reactivateAccount => _localizedValues[locale.languageCode]!['reactivateAccount']!;

  // Admin System Health
  String get successRate => _localizedValues[locale.languageCode]!['successRate']!;
  String get avgResponse => _localizedValues[locale.languageCode]!['avgResponse']!;
  String get errorLogs => _localizedValues[locale.languageCode]!['errorLogs']!;
  String get filterAll => _localizedValues[locale.languageCode]!['filterAll']!;
  String get filterCamera => _localizedValues[locale.languageCode]!['filterCamera']!;
  String get filterAI => _localizedValues[locale.languageCode]!['filterAI']!;
  String get filterDatabase => _localizedValues[locale.languageCode]!['filterDatabase']!;
  String get filterNetwork => _localizedValues[locale.languageCode]!['filterNetwork']!;
  String get systemStable0Errors => _localizedValues[locale.languageCode]!['systemStable0Errors']!;
  String get noErrorsInLog => _localizedValues[locale.languageCode]!['noErrorsInLog']!;
  String get showLess => _localizedValues[locale.languageCode]!['showLess']!;
  String get showAllErrors => _localizedValues[locale.languageCode]!['showAllErrors']!;
  String get stackTrace => _localizedValues[locale.languageCode]!['stackTrace']!;
  String get errorContext => _localizedValues[locale.languageCode]!['errorContext']!;
  String get noAdditionalDetails => _localizedValues[locale.languageCode]!['noAdditionalDetails']!;
  String get export => _localizedValues[locale.languageCode]!['export']!;
  String get exportStatsErrors => _localizedValues[locale.languageCode]!['exportStatsErrors']!;
  String get exportAll => _localizedValues[locale.languageCode]!['exportAll']!;
  String get exportErrorLogs => _localizedValues[locale.languageCode]!['exportErrorLogs']!;
  String get clearAll => _localizedValues[locale.languageCode]!['clearAll']!;
  String get exportAllData => _localizedValues[locale.languageCode]!['exportAllData']!;
  String get errorLogEntries => _localizedValues[locale.languageCode]!['errorLogEntries']!;
  String get performanceUsageErrorLogs => _localizedValues[locale.languageCode]!['performanceUsageErrorLogs']!;
  String get format => _localizedValues[locale.languageCode]!['format']!;

  // Admin Feedback Screen
  String get markReviewed => _localizedValues[locale.languageCode]!['markReviewed']!;
  String get markResolved => _localizedValues[locale.languageCode]!['markResolved']!;
  String get markPending => _localizedValues[locale.languageCode]!['markPending']!;
  String get deleteBtn => _localizedValues[locale.languageCode]!['deleteBtn']!;
  String get showMore => _localizedValues[locale.languageCode]!['showMore']!;
  String get suggestion => _localizedValues[locale.languageCode]!['suggestion']!;

  // Admin System Health (extra)
  String get mobilenetV2MedicinalPlants => _localizedValues[locale.languageCode]!['mobilenetV2MedicinalPlants']!;
  String get webLiveModelCloud => _localizedValues[locale.languageCode]!['webLiveModelCloud']!;
  String get liveModelSupabase => _localizedValues[locale.languageCode]!['liveModelSupabase']!;
  String get bundledAssetModel => _localizedValues[locale.languageCode]!['bundledAssetModel']!;
  String get webAdminRunsLiveCloud => _localizedValues[locale.languageCode]!['webAdminRunsLiveCloud']!;
  String get versionLabel => _localizedValues[locale.languageCode]!['versionLabel']!;
  String get noOtaModelDownloaded => _localizedValues[locale.languageCode]!['noOtaModelDownloaded']!;
  String get otaModelUpdatesWebCloud => _localizedValues[locale.languageCode]!['otaModelUpdatesWebCloud']!;
  String get checkingForModelUpdate => _localizedValues[locale.languageCode]!['checkingForModelUpdate']!;
  String get checkNow => _localizedValues[locale.languageCode]!['checkNow']!;
  String get localDeviceAnalytics => _localizedValues[locale.languageCode]!['localDeviceAnalytics']!;
  String get totalScans => _localizedValues[locale.languageCode]!['totalScans']!;
  String get successful => _localizedValues[locale.languageCode]!['successful']!;

  // Admin User Management (extra)
  String get suspend => _localizedValues[locale.languageCode]!['suspend']!;
  String get suspendWarning => _localizedValues[locale.languageCode]!['suspendWarning']!;
  String get reasonOptional => _localizedValues[locale.languageCode]!['reasonOptional']!;
  String get reasonHint => _localizedValues[locale.languageCode]!['reasonHint']!;

  // Admin Dashboard
  String get approve => _localizedValues[locale.languageCode]!['approve']!;
  String get reject => _localizedValues[locale.languageCode]!['reject']!;
  String get trainingEligible => _localizedValues[locale.languageCode]!['trainingEligible']!;

  // Admin Feedback (extra)
  String get failedToLoadFeedback => _localizedValues[locale.languageCode]!['failedToLoadFeedback']!;
  String get anonymous => _localizedValues[locale.languageCode]!['anonymous']!;
  String get userText => _localizedValues[locale.languageCode]!['userText']!;
  String get couldNotLoadFeedback => _localizedValues[locale.languageCode]!['couldNotLoadFeedback']!;
  String get userFeedback => _localizedValues[locale.languageCode]!['userFeedback']!;
  String get searchFeedbackOrUser => _localizedValues[locale.languageCode]!['searchFeedbackOrUser']!;
  String get allStatuses => _localizedValues[locale.languageCode]!['allStatuses']!;
  String get pending => _localizedValues[locale.languageCode]!['pending']!;
  String get reviewed => _localizedValues[locale.languageCode]!['reviewed']!;
  String get resolved => _localizedValues[locale.languageCode]!['resolved']!;
  String get statusLabel => _localizedValues[locale.languageCode]!['statusLabel']!;
  String get allCategories => _localizedValues[locale.languageCode]!['allCategories']!;
  String get categoryLabel => _localizedValues[locale.languageCode]!['categoryLabel']!;
  String get noFeedbackInSupabase => _localizedValues[locale.languageCode]!['noFeedbackInSupabase']!;
  String get noFeedbackMatchesFilters => _localizedValues[locale.languageCode]!['noFeedbackMatchesFilters']!;
  String get deleteFeedbackPrompt => _localizedValues[locale.languageCode]!['deleteFeedbackPrompt']!;
  String get deleteFeedbackDesc => _localizedValues[locale.languageCode]!['deleteFeedbackDesc']!;
  String get feedbackRemoved => _localizedValues[locale.languageCode]!['feedbackRemoved']!;
  String get couldNotDeleteFeedback => _localizedValues[locale.languageCode]!['couldNotDeleteFeedback']!;
  String get statusUpdated => _localizedValues[locale.languageCode]!['statusUpdated']!;
  String get failedToUpdateStatus => _localizedValues[locale.languageCode]!['failedToUpdateStatus']!;

  // Admin App Config
  String get helpTutorialContent => _localizedValues[locale.languageCode]!['helpTutorialContent']!;
  String get tips => _localizedValues[locale.languageCode]!['tips']!;
  String get issues => _localizedValues[locale.languageCode]!['issues']!;
  String get features => _localizedValues[locale.languageCode]!['features']!;
  String get oodExplanation => _localizedValues[locale.languageCode]!['oodExplanation']!;
  String get saving => _localizedValues[locale.languageCode]!['saving']!;
  String get saveConfiguration => _localizedValues[locale.languageCode]!['saveConfiguration']!;
  String get add => _localizedValues[locale.languageCode]!['add']!;
  String get noItemsAdded => _localizedValues[locale.languageCode]!['noItemsAdded']!;

  // Admin Dashboard (extra)
  String get fullResolutionPinchToZoom => _localizedValues[locale.languageCode]!['fullResolutionPinchToZoom']!;
  String get deleteSubmission => _localizedValues[locale.languageCode]!['deleteSubmission']!;
  String get deleteSubmissionBody => _localizedValues[locale.languageCode]!['deleteSubmissionBody']!;
  String get deleteRequest => _localizedValues[locale.languageCode]!['deleteRequest']!;
  String get deleteRequestBody => _localizedValues[locale.languageCode]!['deleteRequestBody']!;
  String get imageAddedToTraining => _localizedValues[locale.languageCode]!['imageAddedToTraining']!;
  String get storageCopyFailed => _localizedValues[locale.languageCode]!['storageCopyFailed']!;
  String get accessDeniedAdminOnly => _localizedValues[locale.languageCode]!['accessDeniedAdminOnly']!;
  String get dataDeletionRequests => _localizedValues[locale.languageCode]!['dataDeletionRequests']!;
  String get submissionTriage => _localizedValues[locale.languageCode]!['submissionTriage']!;
  String get backToSubmissions => _localizedValues[locale.languageCode]!['backToSubmissions']!;
  String get inboxZero => _localizedValues[locale.languageCode]!['inboxZero']!;
  String get noDeletionRequests => _localizedValues[locale.languageCode]!['noDeletionRequests']!;
  String get unknown => _localizedValues[locale.languageCode]!['unknown']!;
  String get remove => _localizedValues[locale.languageCode]!['remove']!;

  // Admin App Config (extra)
  String get configSavedSuccess => _localizedValues[locale.languageCode]!['configSavedSuccess']!;
  String get failedToSave => _localizedValues[locale.languageCode]!['failedToSave']!;
  String get appConfiguration => _localizedValues[locale.languageCode]!['appConfiguration']!;
  String get appConfigDesc => _localizedValues[locale.languageCode]!['appConfigDesc']!;
  String get reloadFromServer => _localizedValues[locale.languageCode]!['reloadFromServer']!;
  String get failedToLoadConfig => _localizedValues[locale.languageCode]!['failedToLoadConfig']!;
  String get appVersionLabel => _localizedValues[locale.languageCode]!['appVersionLabel']!;
  String get appVersionDesc => _localizedValues[locale.languageCode]!['appVersionDesc']!;
  String get modelVersionLabel => _localizedValues[locale.languageCode]!['modelVersionLabel']!;
  String get modelVersionDesc => _localizedValues[locale.languageCode]!['modelVersionDesc']!;

  // Onboarding & Splash
  String get skipBtn => _localizedValues[locale.languageCode]!['skipBtn']!;
  String get getStartedBtn => _localizedValues[locale.languageCode]!['getStartedBtn']!;
  String get nextBtn => _localizedValues[locale.languageCode]!['nextBtn']!;
  String get onboardingTitle1 => _localizedValues[locale.languageCode]!['onboardingTitle1']!;
  String get onboardingDesc1 => _localizedValues[locale.languageCode]!['onboardingDesc1']!;
  String get onboardingTitle2 => _localizedValues[locale.languageCode]!['onboardingTitle2']!;
  String get onboardingDesc2 => _localizedValues[locale.languageCode]!['onboardingDesc2']!;
  String get onboardingTitle3 => _localizedValues[locale.languageCode]!['onboardingTitle3']!;
  String get onboardingDesc3 => _localizedValues[locale.languageCode]!['onboardingDesc3']!;
  String get onboardingTitle4 => _localizedValues[locale.languageCode]!['onboardingTitle4']!;
  String get onboardingDesc4 => _localizedValues[locale.languageCode]!['onboardingDesc4']!;
  
  String termsConditionsStep(String step) => 
      _localizedValues[locale.languageCode]!['termsConditionsStep']!.replaceAll('{step}', step);
  String get errorLoadingDocs => _localizedValues[locale.languageCode]!['errorLoadingDocs']!;
  String get scrollToBottomToUnlock => _localizedValues[locale.languageCode]!['scrollToBottomToUnlock']!;
  String get agreeMedicalDisclaimer => _localizedValues[locale.languageCode]!['agreeMedicalDisclaimer']!;
  String get agreeTermsOfService => _localizedValues[locale.languageCode]!['agreeTermsOfService']!;
  String get agreeEULA => _localizedValues[locale.languageCode]!['agreeEULA']!;

  // Scan & Results Screens
  String get selectAPlantImageToIdentify => _localizedValues[locale.languageCode]!['selectAPlantImageToIdentify']!;
  String get cameraNotAvailableWindows => _localizedValues[locale.languageCode]!['cameraNotAvailableWindows']!;
  String get analyzing => _localizedValues[locale.languageCode]!['analyzing']!;
  String get chooseDifferentImage => _localizedValues[locale.languageCode]!['chooseDifferentImage']!;
  String get browseImage => _localizedValues[locale.languageCode]!['browseImage']!;
  String get initializingCamera => _localizedValues[locale.languageCode]!['initializingCamera']!;
  String get cameraError => _localizedValues[locale.languageCode]!['cameraError']!;
  String get unknownError => _localizedValues[locale.languageCode]!['unknownError']!;
  String get noPlantDetected => _localizedValues[locale.languageCode]!['noPlantDetected']!;
  String get failedToIdentifyPlant => _localizedValues[locale.languageCode]!['failedToIdentifyPlant']!;
  String get imageTooUnclear => _localizedValues[locale.languageCode]!['imageTooUnclear']!;
  String get couldNotGetClearLook => _localizedValues[locale.languageCode]!['couldNotGetClearLook']!;
  String get retakePhoto => _localizedValues[locale.languageCode]!['retakePhoto']!;
  String get lowConfidenceMatch => _localizedValues[locale.languageCode]!['lowConfidenceMatch']!;
  String get noPlantMatchFound => _localizedValues[locale.languageCode]!['noPlantMatchFound']!;
  String get notConfidentEnough => _localizedValues[locale.languageCode]!['notConfidentEnough']!;
  String get dontRecognizePlant => _localizedValues[locale.languageCode]!['dontRecognizePlant']!;
  String bestGuess(String name, String pct) => _localizedValues[locale.languageCode]!['bestGuess']!.replaceAll('{name}', name).replaceAll('{pct}', pct);
  String get lookAlikePlants => _localizedValues[locale.languageCode]!['lookAlikePlants']!;
  String get uncertainMatches => _localizedValues[locale.languageCode]!['uncertainMatches']!;
  String get gotIt => _localizedValues[locale.languageCode]!['gotIt']!;

  // Plant Result Screen
  String get notIdentified => _localizedValues[locale.languageCode]!['notIdentified']!;
  String pctMatch(String pct) => _localizedValues[locale.languageCode]!['pctMatch']!.replaceAll('{pct}', pct);
  String get openPlantProfile => _localizedValues[locale.languageCode]!['openPlantProfile']!;
  String get tapToZoom => _localizedValues[locale.languageCode]!['tapToZoom']!;
  String get dohVerified => _localizedValues[locale.languageCode]!['dohVerified']!;
  String get scientificallyDocumented => _localizedValues[locale.languageCode]!['scientificallyDocumented']!;
  String get dohVerifiedPlant => _localizedValues[locale.languageCode]!['dohVerifiedPlant']!;
  String get scientificallyDocumentedPlant => _localizedValues[locale.languageCode]!['scientificallyDocumentedPlant']!;
  String get dohVerifiedBody => _localizedValues[locale.languageCode]!['dohVerifiedBody']!;
  String get scientificallyDocumentedBody => _localizedValues[locale.languageCode]!['scientificallyDocumentedBody']!;
  String get source => _localizedValues[locale.languageCode]!['source']!;
  String get alternativeMatches => _localizedValues[locale.languageCode]!['alternativeMatches']!;
  String get alternativeMatchesBody => _localizedValues[locale.languageCode]!['alternativeMatchesBody']!;
  String get noPredictionsAvailable => _localizedValues[locale.languageCode]!['noPredictionsAvailable']!;
  String get unableToIdentifyPlant => _localizedValues[locale.languageCode]!['unableToIdentifyPlant']!;
  String get saveScan => _localizedValues[locale.languageCode]!['saveScan']!;
  String get saveToCameraRoll => _localizedValues[locale.languageCode]!['saveToCameraRoll']!;
  String get share => _localizedValues[locale.languageCode]!['share']!;
  String get shareAsInfoCard => _localizedValues[locale.languageCode]!['shareAsInfoCard']!;
  String get shareAsInfoCardSub => _localizedValues[locale.languageCode]!['shareAsInfoCardSub']!;
  String get shareAsText => _localizedValues[locale.languageCode]!['shareAsText']!;
  String get shareAsTextSub => _localizedValues[locale.languageCode]!['shareAsTextSub']!;
  String get matchConfidence => _localizedValues[locale.languageCode]!['matchConfidence']!;
  String get scannedWithHerbaScan => _localizedValues[locale.languageCode]!['scannedWithHerbaScan']!;
  String get discoverMedicinalPlants => _localizedValues[locale.languageCode]!['discoverMedicinalPlants']!;
  String get imageNotFound => _localizedValues[locale.languageCode]!['imageNotFound']!;
  String get yes => _localizedValues[locale.languageCode]!['yes']!;
  String get notListed => _localizedValues[locale.languageCode]!['notListed']!;

  // Plant Detail Screen
  String get medicinal => _localizedValues[locale.languageCode]!['medicinal']!;
  String get safety => _localizedValues[locale.languageCode]!['safety']!;
  String get scientificClassification => _localizedValues[locale.languageCode]!['scientificClassification']!;
  String get kingdom => _localizedValues[locale.languageCode]!['kingdom']!;
  String get plantae => _localizedValues[locale.languageCode]!['plantae']!;
  String get family => _localizedValues[locale.languageCode]!['family']!;
  String get genus => _localizedValues[locale.languageCode]!['genus']!;
  String get species => _localizedValues[locale.languageCode]!['species']!;
  String forCondition(String condition) => _localizedValues[locale.languageCode]!['forCondition']!.replaceAll('{condition}', condition);
  String get startGuide => _localizedValues[locale.languageCode]!['startGuide']!;
  String get dataSources => _localizedValues[locale.languageCode]!['dataSources']!;
  String get dataSourcesSub => _localizedValues[locale.languageCode]!['dataSourcesSub']!;
  String get departmentOfHealth => _localizedValues[locale.languageCode]!['departmentOfHealth']!;
  String get pitahc => _localizedValues[locale.languageCode]!['pitahc']!;
  String get aiTrainingDataset => _localizedValues[locale.languageCode]!['aiTrainingDataset']!;
  String get informationNotAvailable => _localizedValues[locale.languageCode]!['informationNotAvailable']!;

  // Preparation Instructions Screen
  String get progressReset => _localizedValues[locale.languageCode]!['progressReset']!;
  String get calendarCouldNotBeOpened => _localizedValues[locale.languageCode]!['calendarCouldNotBeOpened']!;
  String couldNotOpenCalendar(String e) => _localizedValues[locale.languageCode]!['couldNotOpenCalendar']!.replaceAll('{e}', e);
  String get resetProgressTitle => _localizedValues[locale.languageCode]!['resetProgressTitle']!;
  String get resetProgressBody => _localizedValues[locale.languageCode]!['resetProgressBody']!;
  String get reset => _localizedValues[locale.languageCode]!['reset']!;
  String get generalSafetyInfo => _localizedValues[locale.languageCode]!['generalSafetyInfo']!;
  String get regimen => _localizedValues[locale.languageCode]!['regimen']!;
  String stepN(String n) => _localizedValues[locale.languageCode]!['stepN']!.replaceAll('{n}', n);
  
  // Preparation Focus Mode Screen
  String get noStepsAvailable => _localizedValues[locale.languageCode]!['noStepsAvailable']!;
  String get tapToResume => _localizedValues[locale.languageCode]!['tapToResume']!;
  String get tapToPause => _localizedValues[locale.languageCode]!['tapToPause']!;
  String get tapToStartTimer => _localizedValues[locale.languageCode]!['tapToStartTimer']!;
  String get stepDone => _localizedValues[locale.languageCode]!['stepDone']!;
  String get allDone => _localizedValues[locale.languageCode]!['allDone']!;
  String get completeAndContinue => _localizedValues[locale.languageCode]!['completeAndContinue']!;
  String get completePreparation => _localizedValues[locale.languageCode]!['completePreparation']!;
  String get preparationComplete => _localizedValues[locale.languageCode]!['preparationComplete']!;
  String get completedAllSteps => _localizedValues[locale.languageCode]!['completedAllSteps']!;
  String get returnToGuide => _localizedValues[locale.languageCode]!['returnToGuide']!;

  // Settings Screen
  String get accountLabel => _localizedValues[locale.languageCode]!['accountLabel']!;
  String get appPreferencesLabel => _localizedValues[locale.languageCode]!['appPreferencesLabel']!;
  String get scanningRecognitionLabel => _localizedValues[locale.languageCode]!['scanningRecognitionLabel']!;
  String get supportLegalAboutLabel => _localizedValues[locale.languageCode]!['supportLegalAboutLabel']!;
  String get developerOptionsLabel => _localizedValues[locale.languageCode]!['developerOptionsLabel']!;
  String get signInToBackUp => _localizedValues[locale.languageCode]!['signInToBackUp']!;
  String get administrator => _localizedValues[locale.languageCode]!['administrator']!;
  String get standardUser => _localizedValues[locale.languageCode]!['standardUser']!;
  String get updatePasswordSubtitle => _localizedValues[locale.languageCode]!['updatePasswordSubtitle']!;
  String get adminConsoleSubtitle => _localizedValues[locale.languageCode]!['adminConsoleSubtitle']!;
  String get deleteAccountSubtitle => _localizedValues[locale.languageCode]!['deleteAccountSubtitle']!;
  String get requestDataDeletion => _localizedValues[locale.languageCode]!['requestDataDeletion']!;
  String get requestDataDeletionSubtitle => _localizedValues[locale.languageCode]!['requestDataDeletionSubtitle']!;
  
  String get darkMode => _localizedValues[locale.languageCode]!['darkMode']!;
  String get lightMode => _localizedValues[locale.languageCode]!['lightMode']!;
  String get themeSubtitle => _localizedValues[locale.languageCode]!['themeSubtitle']!;
  String get english => _localizedValues[locale.languageCode]!['english']!;
  String get filipino => _localizedValues[locale.languageCode]!['filipino']!;
  String get autoSaveScans => _localizedValues[locale.languageCode]!['autoSaveScans']!;
  String get autoSaveScansSubtitle => _localizedValues[locale.languageCode]!['autoSaveScansSubtitle']!;
  String get showAlternativeMatches => _localizedValues[locale.languageCode]!['showAlternativeMatches']!;
  
  String get helpTutorialSubtitle => _localizedValues[locale.languageCode]!['helpTutorialSubtitle']!;
  String get sendFeedbackSubtitle => _localizedValues[locale.languageCode]!['sendFeedbackSubtitle']!;
  String get termsOfService => _localizedValues[locale.languageCode]!['termsOfService']!;
  String get eula => _localizedValues[locale.languageCode]!['eula']!;
  String get privacyPolicy => _localizedValues[locale.languageCode]!['privacyPolicy']!;
  String get appVersion => _localizedValues[locale.languageCode]!['appVersion']!;
  String get modelVersion => _localizedValues[locale.languageCode]!['modelVersion']!;
  
  String get refreshOfflineData => _localizedValues[locale.languageCode]!['refreshOfflineData']!;
  String get refreshOfflineDataSubtitle => _localizedValues[locale.languageCode]!['refreshOfflineDataSubtitle']!;
  String get offlineStorageInfo => _localizedValues[locale.languageCode]!['offlineStorageInfo']!;
  String get clearOfflineData => _localizedValues[locale.languageCode]!['clearOfflineData']!;
  String get clearOfflineDataSubtitle => _localizedValues[locale.languageCode]!['clearOfflineDataSubtitle']!;
  String get systemDiagnostics => _localizedValues[locale.languageCode]!['systemDiagnostics']!;
  String get systemDiagnosticsSubtitle => _localizedValues[locale.languageCode]!['systemDiagnosticsSubtitle']!;
  String get offlineModeSubtitle => _localizedValues[locale.languageCode]!['offlineModeSubtitle']!;
  String get changePassword => _localizedValues[locale.languageCode]!['changePassword']!;
  String get emailAddress => _localizedValues[locale.languageCode]!['emailAddress']!;
  String get deleteAccount => _localizedValues[locale.languageCode]!['deleteAccount']!;

  // History Screen
  String get deleteAllHistoryConfirmation => _localizedValues[locale.languageCode]!['deleteAllHistoryConfirmation']!;
  String get allScansDeleted => _localizedValues[locale.languageCode]!['allScansDeleted']!;
  String get deleteAllCloudConfirmation => _localizedValues[locale.languageCode]!['deleteAllCloudConfirmation']!;
  String itemsSelected(String count) => _localizedValues[locale.languageCode]!['itemsSelected']!.replaceAll('{count}', count);
  String get deselectAll => _localizedValues[locale.languageCode]!['deselectAll']!;
  String get selectAll => _localizedValues[locale.languageCode]!['selectAll']!;
  String get device => _localizedValues[locale.languageCode]!['device']!;
  String get cloud => _localizedValues[locale.languageCode]!['cloud']!;
  String historyStats(String count, String avgMatch) => _localizedValues[locale.languageCode]!['historyStats']!.replaceAll('{count}', count).replaceAll('{avgMatch}', avgMatch);
  String get uploadSelected => _localizedValues[locale.languageCode]!['uploadSelected']!;
  String get downloadSelected => _localizedValues[locale.languageCode]!['downloadSelected']!;
  String get signInForCloudBackup => _localizedValues[locale.languageCode]!['signInForCloudBackup']!;
  String get signIn => _localizedValues[locale.languageCode]!['signIn']!;
  String get noInternetConnection => _localizedValues[locale.languageCode]!['noInternetConnection']!;
  String get cloudScansOfflineMessage => _localizedValues[locale.languageCode]!['cloudScansOfflineMessage']!;
  String get noCloudScansYet => _localizedValues[locale.languageCode]!['noCloudScansYet']!;
  String get cloudScansBackupMessage => _localizedValues[locale.languageCode]!['cloudScansBackupMessage']!;
  String get deleteFromCloud => _localizedValues[locale.languageCode]!['deleteFromCloud']!;
  String get signInToSaveCloud => _localizedValues[locale.languageCode]!['signInToSaveCloud']!;
  String get imageFileNotFound => _localizedValues[locale.languageCode]!['imageFileNotFound']!;
  String get savedToCloud => _localizedValues[locale.languageCode]!['savedToCloud']!;
  String get failedToSaveCloud => _localizedValues[locale.languageCode]!['failedToSaveCloud']!;
  String get scanDeleted => _localizedValues[locale.languageCode]!['scanDeleted']!;
  String get sort => _localizedValues[locale.languageCode]!['sort']!;
  String get mostRecent => _localizedValues[locale.languageCode]!['mostRecent']!;
  String get oldestFirst => _localizedValues[locale.languageCode]!['oldestFirst']!;
  String get highestConfidence => _localizedValues[locale.languageCode]!['highestConfidence']!;
  String get selectItems => _localizedValues[locale.languageCode]!['selectItems']!;

  // Feedback Screen
  String get feedbackHelpText => _localizedValues[locale.languageCode]!['feedbackHelpText']!;
  String get feedbackPrivacyNotice => _localizedValues[locale.languageCode]!['feedbackPrivacyNotice']!;
  String get pleaseSelectCategory => _localizedValues[locale.languageCode]!['pleaseSelectCategory']!;
  String get commentMinLength => _localizedValues[locale.languageCode]!['commentMinLength']!;
  String get shareThoughtsHint => _localizedValues[locale.languageCode]!['shareThoughtsHint']!;
  String get suggestFeaturesHint => _localizedValues[locale.languageCode]!['suggestFeaturesHint']!;
  String get submitAnonymously => _localizedValues[locale.languageCode]!['submitAnonymously']!;
  String get submitAnonymouslySubtitle => _localizedValues[locale.languageCode]!['submitAnonymouslySubtitle']!;
  String errorOccurred(String error) => _localizedValues[locale.languageCode]!['errorOccurred']!.replaceAll('{error}', error);

  // Home Screen
  String get home => _localizedValues[locale.languageCode]!['home']!;
  String get accuracy => _localizedValues[locale.languageCode]!['accuracy']!;

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
      'plantReferences': 'Plant References',
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
      'useWithStrictCaution': 'Use with strict caution',
      'useWithStrictCautionBody': 'Preparation and dosage must be followed. Do not use without professional guidance.',
      'generallySafeForConsumption': 'Generally safe for normal consumption.',
      'safetyDisclaimerEducational':
          'This app is for educational purposes only. It is not a replacement for professional medical advice. Always consult a healthcare professional before using herbal remedies, especially if you are pregnant, nursing, taking medications, or have existing medical conditions.',
      'noStructuredSafetyData': 'No structured safety data for this plant.',
      'safetyInformationUnavailable': 'Safety Information Unavailable',
      'safetyInformationUnavailableBody':
          'Identification confidence is too low. Do not use this result for health decisions.',
      'plantNotRecognized': 'Plant Not Recognized',
      'uncertainMatchBody':
          'For your safety, do not consume or use this plant based on this result.',
      'whyCantAppIdentify': "Why can't the app identify this?",
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
      'nextPart': 'Next part',
      'previousPart': 'Previous part',
      'adminAnatomyEmpty':
          'No plant parts yet. Add parts to show the interactive silhouette on the Plant Detail screen.',
      'adminAnatomyAddPart': 'Add plant part',
      'restoreToDefault': 'Restore to default',
      'edit': 'Edit',
      'adminAnatomyDeleteConfirm': 'Delete this plant part',
      'savedToCatalog': 'Saved to catalog',
      'saveFailed': 'Save failed',
      'deleted': 'Deleted',
      'restoredToDefault': 'Restored to default',
      'language': 'Language / Wika',
      'offlineMode': 'Offline Mode',
      'showConfidenceScores': 'Show Confidence Scores',
      'showGradCAM': 'Show AI Reasoning Heatmap',
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
      'searchHistory': 'Search History',
      'scanHistory': 'Scan History',
      'noScansYet': 'No scans yet',
      'startScanning': 'Start by scanning your first plant!',
      'deleteAll': 'Delete All',
      'confirmDelete': 'Confirm Delete',
      'deleteConfirmation': 'Are you sure you want to delete this scan?',
      'confidence': 'Confidence',
      'saveToCloud': 'Save to Cloud',
      'saveToDevice': 'Save to Device',
      'makeAdmin': 'Make admin',
      'removeAdmin': 'Remove admin',
      'userNowAdmin': 'User is now an administrator.',
      'adminRemoved': 'Admin role removed.',
      'forceVerifyEmail': 'Force activate email',
      'emailVerified': 'Email verified. User can sign in without OTP.',
      'forceVerifyNotAvailable':
          'Force verify is not available. Deploy the force-verify-user Edge Function.',
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
      'browseCatalog': 'Browse Catalog',
      'toxicPlantDetected': 'Toxic plant detected',
      'toxicPlantBody':
          'This plant may be %s. Do not use for food or medicine. If ingested or exposed, seek medical attention.',
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
      'didWeGetThisRight':
          'Did we get this right? Help our research.',
      'milestoneFeedbackTitle': 'You\'ve been exploring HerbaScan!',
      'milestoneFeedbackBody':
          'Would you mind taking 30 seconds to rate your experience for our thesis research?',
      'rateExperience': 'Rate experience',
      'maybeLater': 'Maybe later',
      'appPerformance': 'App Performance',
      'viewPerformanceData': 'View performance data and statistics',
      'unauthorizedAccess': 'Unauthorized access.',
      'whatPlant': 'What plant are you identifying?',
      'tapCameraToStart': 'Tap the camera button below to start.',
      'scansCount': 'Scans',
      'seeAll': 'See All',
      'unknownPlant': 'Unknown Plant',
      'dohApprovedPlants': 'DOH Approved Plants',
      'noDohPlantsLoaded': 'No DOH approved plants loaded.',
      'searchPlantsCount': 'Search {count} Plants',
      'showingPlants': 'Showing {count} Plants',
      'medical': 'Medical',
      'listView': 'List View',
      'gridView': 'Grid View',
      'emailOrPasswordMismatch': 'Email or password does not match.',
      'signInFailed': 'Sign in failed. Please try again.',
      'tooManyAttempts': 'Too many failed attempts. Please wait {seconds} seconds.',
      'signInTitle': 'Sign In',
      'backToApp': 'Back to app',
      'emailLabel': 'Email',
      'emailHint': 'you@example.com',
      'enterEmail': 'Enter your email',
      'validEmailRequired': 'Enter a valid email',
      'passwordLabel': 'Password',
      'enterPassword': 'Enter your password',
      'forgotPasswordLabel': 'Forgot password?',
      'waitSeconds': 'Wait {seconds}s',
      'newToHerbaScan': 'New to HerbaScan?',
      'createAccountBtn': 'Create an Account',
      'personalHerbarium': 'Personal Herbarium',
      'loginSubtitle': 'Sign in to sync your scan history and images to the cloud.',
      'tooManyEmailsSent': 'Too many signup emails sent. Please try again in about an hour.',
      'emailAlreadyRegistered': 'This email is already registered. Try signing in.',
      'createAccountTitle': 'Create Account',
      'signupSubtitle': 'Create an account to back up your scans to the cloud.',
      'passwordHint': 'Enter a strong password',
      'useAtLeast8Chars': 'Use at least 8 characters',
      'includeCapitalLetter': 'Include at least one capital letter',
      'includeLowercaseLetter': 'Include at least one lowercase letter',
      'includeNumber': 'Include at least one number',
      'includeSpecialChar': 'Include at least one special character (!@#\$%^&* etc.)',
      'confirmPasswordLabel': 'Confirm Password',
      'confirmPasswordHint': 'Re-enter your password',
      'passwordsDoNotMatch': 'Passwords do not match',
      'confirmYourPassword': 'Confirm your password',
      'alreadyHaveCode': 'Already have a verification code?',
      'enterValidEmailForCode': 'Please enter your valid email above to verify your code.',
      'resetPasswordTitle': 'Reset Password',
      'resetPasswordSubtitle': 'Enter your email and we\'ll send you a 6-digit code to reset your password.',
      'sendCodeBtn': 'Send Code',
      'backToSignIn': 'Back to Sign In',
      'createNewPasswordTitle': 'Create New Password',
      'remainSignedIn': 'You\'ll remain signed in on this device.',
      'currentPasswordLabel': 'Current password',
      'enterCurrentPassword': 'Enter your current password',
      'newPasswordLabel': 'New password',
      'confirmNewPassword': 'Confirm your new password',
      'updatePasswordBtn': 'Update Password',
      'passwordUpdated': 'Password updated successfully',
      'incorrectCurrentPassword': 'The current password you entered is incorrect.',
      'emailUpdatedMsg': 'Email updated. Check your new inbox to confirm the change.',
      'emailAddressTitle': 'Email Address',
      'updateEmailSubtitle': 'Update the email address linked to your account.',
      'newEmailAddressLabel': 'New email address',
      'enterNewEmail': 'Enter a new email',
      'newEmailMustBeDifferent': 'New email must be different',
      'confirmationLinkMsg': 'We\'ll send a confirmation link to your new address. Changes take effect once verified.',
      'updateEmailBtn': 'Update Email',
      'codeExpired': 'Code expired. Tap "Resend" to get a new one.',
      'invalidCode': 'Invalid code. Try again.',
      'newCodeSent': 'A new code has been sent to your email.',
      'failedToResend': 'Failed to resend. Please try again.',
      'checkYourInbox': 'Check your inbox',
      'sent6DigitCode': 'We sent a 6-digit code to\n{email}',
      'tooManyAttemptsWait': 'Too many attempts.\nTry again in {lockedUntil}.',
      'attemptsLeft': 'Attempts left: {attemptsLeft}',
      'activateAccountBtn': 'Activate Account',
      'waitResend': 'Wait {seconds}s to resend',
      'didntReceiveEmail': 'Didn\'t receive the email? Resend',
      'continueBtn': 'Continue',
      'accountSuspendedTitle': 'Account Suspended',
      'accountSuspendedSubtitle': 'Your HerbaScan account has been temporarily suspended and cannot be accessed right now.',
      'reasonLabel': 'Reason',
      'contactSupportBtn': 'Contact Support',
      'couldNotOpenEmail': 'Could not open email client.',
      'supportMistakeMsg': 'If you believe this is a mistake, please contact our support team.',
      'accountVerifiedTitle': 'Account Verified!',
      'accountCreatedAs': 'Your account has been created as\n{email}',
      'nowSignedInWelcome': 'You are now signed in. Welcome to your Personal Herbarium.',
      'redirectingSettings': 'Redirecting to settings in {countdown}...',
      'goToSettingsBtn': 'Go to Settings',
      'authenticating': 'Authenticating...',
      'authenticationTitle': 'Authentication',
      'authErrorTitle': 'Authentication Error',
      'authStatusTitle': 'Status',
      'goToDashboardBtn': 'Go to Dashboard',
      // Admin Web Screen
      'overview': 'Overview',
      'plantCatalog': 'Plant Catalog',
      'healthConditions': 'Health Conditions',
      'userDirectory': 'User Directory',
      'systemHealth': 'System Health',
      'feedbackMenu': 'Feedback',
      'submissions': 'Submissions',
      'appConfig': 'App Config',
      'adminConsole': 'Admin Console',
      'elevatedPrivilegesActive': 'Elevated Privileges Active',
      'adminRole': 'Admin',
      'signOut': 'Sign Out',
      'exitAdminConsole': 'Exit Admin Console',
      'selectAModule': 'Select a module from the sidebar to get started.',
      // Admin User Management
      'makeAdminPrompt': 'Make Admin',
      'removeAdminPrompt': 'Remove Admin',
      'makeAdminDesc': 'Grant this user administrator privileges?',
      'removeAdminDesc': 'Remove administrator privileges from this user?',
      'deleteUserDataPrompt': 'Delete User Data',
      'deleteUserDataDesc': 'This will permanently delete all data for this user. This action cannot be undone.',
      'typeDeleteToConfirm': 'Type DELETE to confirm',
      'deleteUserDataBtn': 'Delete User Data',
      'deletingAccount': 'Deleting account...',
      'removingAccountData': 'Removing account data...',
      'refresh': 'Refresh',
      'searchByEmail': 'Search by email...',
      'noUsersMatch': 'No users match your search.',
      'noUsersFound': 'No users found.',
      'verified': 'Verified',
      'unverified': 'Unverified',
      'joined': 'Joined',
      'scanCount': 'Scans',
      'adminLabel': 'Admin',
      'userLabel': 'User',
      'suspendAccount': 'Suspend Account',
      'reactivateAccount': 'Reactivate Account',
      // Admin System Health
      'successRate': 'Success Rate',
      'avgResponse': 'Avg Response',
      'errorLogs': 'Error Logs',
      'filterAll': 'All',
      'filterCamera': 'Camera',
      'filterAI': 'AI',
      'filterDatabase': 'Database',
      'filterNetwork': 'Network',
      'systemStable0Errors': 'System stable — 0 errors',
      'noErrorsInLog': 'No errors in the log.',
      'showLess': 'Show Less',
      'showAllErrors': 'Show All Errors',
      'stackTrace': 'Stack Trace',
      'errorContext': 'Error Context',
      'noAdditionalDetails': 'No additional details.',
      'export': 'Export',
      'exportStatsErrors': 'Export Stats & Errors',
      'exportAll': 'Export All',
      'exportErrorLogs': 'Export Error Logs',
      'clearAll': 'Clear All',
      'exportAllData': 'Export All Data',
      'errorLogEntries': 'error log entries',
      'performanceUsageErrorLogs': 'Performance, Usage & Error Logs',
      'format': 'Format',
      // Admin Feedback Screen
      'markReviewed': 'Mark as Reviewed',
      'markResolved': 'Mark as Resolved',
      'markPending': 'Mark as Pending',
      'deleteBtn': 'Delete',
      'showMore': 'Show more',
      'suggestion': 'Suggestion',
      // Admin System Health (extra)
      'mobilenetV2MedicinalPlants': 'MobileNetV2 – Medicinal Plants',
      'webLiveModelCloud': 'Web: Live Model (Cloud)',
      'liveModelSupabase': 'Live Model (Supabase)',
      'bundledAssetModel': 'Bundled Asset Model',
      'webAdminRunsLiveCloud': 'Web/Admin always runs the live cloud model.',
      'versionLabel': 'v',
      'noOtaModelDownloaded': 'No OTA model downloaded',
      'otaModelUpdatesWebCloud': 'OTA model updates are web/cloud-only.',
      'checkingForModelUpdate': 'Checking for model update...',
      'checkNow': 'Check Now',
      'localDeviceAnalytics': 'Local Device Analytics',
      'totalScans': 'Total Scans',
      'successful': 'Successful',
      // Admin User Management (extra)
      'suspend': 'Suspend',
      'suspendWarning': 'This will prevent the user from signing in.',
      'reasonOptional': 'Reason (optional)',
      'reasonHint': 'e.g. Violating community guidelines',
      // Admin Dashboard
      'approve': 'Approve',
      'reject': 'Reject',
      'trainingEligible': 'Training Eligible',
      // Admin Feedback (extra)
      'failedToLoadFeedback': 'Failed to load feedback.',
      'anonymous': 'Anonymous',
      'userText': 'User',
      'couldNotLoadFeedback': 'Could not load feedback.',
      'userFeedback': 'User Feedback',
      'searchFeedbackOrUser': 'Search feedback or user...',
      'allStatuses': 'All Statuses',
      'pending': 'Pending',
      'reviewed': 'Reviewed',
      'resolved': 'Resolved',
      'statusLabel': 'Status',
      'allCategories': 'All Categories',
      'categoryLabel': 'Category',
      'noFeedbackInSupabase': 'No feedback in Supabase.',
      'noFeedbackMatchesFilters': 'No feedback matches your filters.',
      'deleteFeedbackPrompt': 'Delete Feedback',
      'deleteFeedbackDesc': 'Are you sure you want to permanently delete this feedback?',
      'feedbackRemoved': 'Feedback removed.',
      'couldNotDeleteFeedback': 'Could not delete feedback.',
      'statusUpdated': 'Status updated.',
      'failedToUpdateStatus': 'Failed to update status.',
      // Admin App Config
      'helpTutorialContent': 'Help & Tutorial Content',
      'tips': 'Tips',
      'issues': 'Issues',
      'features': 'Features',
      'oodExplanation': 'OOD Explanation',
      'saving': 'Saving...',
      'saveConfiguration': 'Save Configuration',
      'add': 'Add',
      'noItemsAdded': 'No items added.',
      // Admin Dashboard (extra)
      'fullResolutionPinchToZoom': 'Full Resolution (Pinch to Zoom)',
      'deleteSubmission': 'Delete Submission',
      'deleteSubmissionBody': 'Are you sure you want to delete this submission?',
      'deleteRequest': 'Delete Request',
      'deleteRequestBody': 'Are you sure you want to delete this deletion request?',
      'imageAddedToTraining': 'Image added to training set.',
      'storageCopyFailed': 'Storage copy failed.',
      'accessDeniedAdminOnly': 'Access denied. Admins only.',
      'dataDeletionRequests': 'Data Deletion Requests',
      'submissionTriage': 'Submission Triage',
      'backToSubmissions': 'Back to Submissions',
      'inboxZero': 'Inbox zero!',
      'noDeletionRequests': 'No deletion requests.',
      'unknown': 'Unknown',
      'remove': 'Remove',
      // Admin App Config (extra)
      'configSavedSuccess': 'Configuration saved.',
      'failedToSave': 'Failed to save.',
      'appConfiguration': 'App Configuration',
      'appConfigDesc': 'Manage app settings and content configuration.',
      'reloadFromServer': 'Reload from Server',
      'failedToLoadConfig': 'Failed to load configuration.',
      'appVersionLabel': 'App Version',
      'appVersionDesc': 'The current version of HerbaScan displayed to users.',
      'modelVersionLabel': 'Model Version',
      'modelVersionDesc': 'The active AI model version used for plant identification.',
      // Onboarding & Disclaimer
      'skipBtn': 'Skip',
      'getStartedBtn': 'Get Started',
      'nextBtn': 'Next',
      'onboardingTitle1': 'AI-Powered Plant Recognition',
      'onboardingDesc1': 'Instantly identify Philippine medicinal plants with high accuracy just by snapping a photo.',
      'onboardingTitle2': 'Works Offline',
      'onboardingDesc2': 'Scan and access herbal remedies anywhere. No internet connection required.',
      'onboardingTitle3': 'DOH Approved Plants',
      'onboardingDesc3': 'Discover clinically validated herbal medicines endorsed by the Department of Health.',
      'onboardingTitle4': 'Transparent AI',
      'onboardingDesc4': 'See exactly which parts of the leaf the AI used to make its identification, ensuring you can trust the results.',
      'termsConditionsStep': 'Terms & Conditions ({step}/3)',
      'errorLoadingDocs': 'Error loading documents. Please try again later.',
      'scrollToBottomToUnlock': 'Please scroll to the bottom to unlock the agreement.',
      'agreeMedicalDisclaimer': 'I have read and agree to the Medical Disclaimer',
      'agreeTermsOfService': 'I have read and agree to the Terms of Service',
      'agreeEULA': 'I have read and agree to the End-User License Agreement (EULA)',
      // Scan & Results Screens
      'selectAPlantImageToIdentify': 'Select a plant image to identify',
      'cameraNotAvailableWindows': 'Camera is not available on Windows desktop',
      'analyzing': 'Analyzing...',
      'chooseDifferentImage': 'Choose Different Image',
      'browseImage': 'Browse Image',
      'initializingCamera': 'Initializing camera...',
      'cameraError': 'Camera Error',
      'unknownError': 'Unknown error',
      'noPlantDetected': 'No plant detected.',
      'failedToIdentifyPlant': 'Failed to identify plant.',
      'imageTooUnclear': 'Image Too Unclear',
      'couldNotGetClearLook': 'Couldn\'t get a clear look. Try better lighting or wipe your lens.',
      'retakePhoto': 'Retake Photo',
      'lowConfidenceMatch': 'Low Confidence Match',
      'noPlantMatchFound': 'No Plant Match Found',
      'notConfidentEnough': 'We\'re not confident enough to confirm this as a match. Please retake a clearer photo or browse the catalog manually.',
      'dontRecognizePlant': 'We don\'t recognize this plant. Ensure it\'s a clear single leaf.',
      'bestGuess': 'Best guess: {name}  ·  {pct}%',
      'lookAlikePlants': 'Look-alike Plants',
      'uncertainMatches': 'These are possible but uncertain matches',
      'gotIt': 'Got it',
      // Plant Result Screen
      'notIdentified': 'Not identified',
      'pctMatch': '{pct}% Match',
      'openPlantProfile': 'Open Plant Profile',
      'viewHabitatMap': 'View Habitat Map',
      'dohVerified': 'DOH Verified',
      'scientificallyDocumented': 'Scientifically Documented',
      'dohVerifiedPlant': 'DOH Verified Plant',
      'scientificallyDocumentedPlant': 'Scientifically Documented Plant',
      'dohVerifiedBody': 'This plant is officially endorsed by the Philippine Department of Health under Administrative Order No. 12, series of 1997, and is included in the list of clinically validated herbal medicines (Republic Act No. 8423 — TAMA).',
      'scientificallyDocumentedBody': 'This plant is not on the DOH approved list but is included in HerbaScan based on peer-reviewed literature and Philippine Herbal Pharmacopeia (PITAHC) references.',
      'source': 'Source: Dept. of Health Admin. Order No. 12, s. 1997 · Republic Act No. 8423 (TAMA, 1997) · Philippine Herbal Pharmacopeia (PITAHC)',
      'didWeGetThisRight': 'Did we get this right? Help our research.',
      'thankYou': 'Thank You!',
      'plantNotRecognized': 'Plant Not Recognized',
      'uncertainMatchBody': 'The plant in your photo doesn\'t strongly match any in our database.',
      'whyCantAppIdentify': 'Why can\'t the app identify it?',
      'alternativeMatches': 'Alternative Matches',
      'alternativeMatchesBody': 'If the top result seems wrong, these are the next possibilities.',
      'scanResults': 'Scan Results',
      'noPredictionsAvailable': 'No predictions available',
      'unableToIdentifyPlant': 'Unable to identify the plant in the image',
      'tryAgain': 'Try Again',
      'saveScan': 'Save Scan',
      'saveToDevice': 'Save to device',
      'saveToCloud': 'Save to cloud',
      'saveToCameraRoll': 'Save to Camera Roll',
      'share': 'Share',
      'shareAsInfoCard': 'Share as Info Card',
      'shareAsInfoCardSub': 'Branded card with plant details',
      'shareAsText': 'Share as Text',
      'shareAsTextSub': 'Plain text for WhatsApp, SMS, etc.',
      'matchConfidence': 'Match Confidence',
      'medicinalUses': 'Medicinal Uses',
      'scannedWithHerbaScan': 'Scanned with HerbaScan 🌱',
      'discoverMedicinalPlants': 'Discover Philippine medicinal plants',
      'imageNotFound': 'Image not found',
      'yes': 'Yes',
      'notListed': 'Not listed',
      'milestoneFeedbackTitle': 'Enjoying HerbaScan?',
      'milestoneFeedbackBody': 'You\'ve made a few scans! How is your experience so far?',
      'maybeLater': 'Maybe Later',
      'rateExperience': 'Rate Experience',
      
      // Plant Detail Screen
      'taxonomy': 'Taxonomy',
      'ecology': 'Ecology',
      'medicinal': 'Medicinal',
      'safety': 'Safety',
      'scientificClassification': 'Scientific Classification',
      'morphology': 'Morphology',
      'kingdom': 'Kingdom',
      'plantae': 'Plantae',
      'family': 'Family',
      'genus': 'Genus',
      'species': 'Species',
      'habitat': 'Habitat',
      'preparationMethods': 'Preparation Methods',
      'dosage': 'Dosage',
      'duration': 'Duration',
      'forCondition': 'For {condition}',
      'startGuide': 'Start Guide',
      'dataSources': 'Data Sources',
      'dataSourcesSub': 'Where this information comes from',
      'departmentOfHealth': 'Department of Health',
      'pitahc': 'PITAHC',
      'aiTrainingDataset': 'AI Training Dataset',
      'informationNotAvailable': 'Information not yet available.',

      // Preparation Instructions Screen
      'progressReset': 'Progress reset',
      'calendarCouldNotBeOpened': 'Calendar could not be opened. Check that a calendar app is installed and try again.',
      'couldNotOpenCalendar': 'Could not open calendar: {e}',
      'resetProgressTitle': 'Reset Progress?',
      'resetProgressBody': 'This will clear all completed steps and stop any running timer.',
      'cancel': 'Cancel',
      'reset': 'Reset',
      'medicalDisclaimer': 'HerbaScan is an educational tool. Always consult a licensed physician before using any herbal remedy.',
      'importantWarnings': 'Important Warnings',
      'generalSafetyInfo': 'General Safety Information',
      'steps': 'Steps',
      'regimen': 'Regimen',
      'frequency': 'Frequency',
      'stepN': 'Step {n}',

      // Preparation Focus Mode Screen
      'noStepsAvailable': 'No steps available',
      'tapToResume': 'Tap to resume • Long press to reset',
      'tapToPause': 'Tap to pause • Long press to reset',
      'tapToStartTimer': 'Tap to start timer',
      'stepDone': 'Step Done ✓',
      'allDone': 'All Done ✓',
      'completeAndContinue': 'Complete & Continue',
      'completePreparation': 'Complete Preparation',
      'preparationComplete': 'Preparation Complete!',
      'completedAllSteps': 'You\'ve completed all the preparation steps.',
      'returnToGuide': 'Return to Guide',

      // Settings Screen
      'accountLabel': 'Account',
      'appPreferencesLabel': 'App Preferences',
      'scanningRecognitionLabel': 'Scanning & Recognition',
      'supportLegalAboutLabel': 'Support, Legal & About',
      'developerOptionsLabel': 'Developer Options',
      
      'personalHerbarium': 'Personal Herbarium',
      'signInToBackUp': 'Sign in to back up your scans to the cloud',
      'administrator': 'Administrator',
      'standardUser': 'Standard User',
      'updatePasswordSubtitle': 'Update your account password',
      'updateEmailSubtitle': 'Update your account email',
      'adminConsole': 'Admin Console',
      'adminConsoleSubtitle': 'Access administrative tools and settings',
      'deleteAccountSubtitle': 'Permanently delete your account and cloud data',
      'requestDataDeletion': 'Request Data Deletion',
      'requestDataDeletionSubtitle': 'Submit a request to delete your personal data',
      
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'themeSubtitle': 'Toggle between dark and light themes',
      'english': 'English',
      'filipino': 'Filipino',
      'autoSaveScans': 'Auto-save Scans',
      'autoSaveScansSubtitle': 'Automatically save scan results',
      
      'showConfidenceScores': 'Show Prediction Confidence',
      'showAlternativeMatches': 'Show Alternative Matches',
      
      'helpTutorialSubtitle': 'Learn how to get the best scanning results',
      'sendFeedback': 'Send Feedback',
      'sendFeedbackSubtitle': 'Share your thoughts or report an issue',
      'termsOfService': 'Terms of Service',
      'eula': 'End-User License Agreement',
      'privacyPolicy': 'Privacy Policy',
      'appVersion': 'App Version',
      'modelVersion': 'Model Version',
      
      'refreshOfflineData': 'Refresh Offline Data',
      'refreshOfflineDataSubtitle': 'Reload stats from local database and sync status',
      'offlineStorageInfo': 'Offline Storage Info',
      'clearOfflineData': 'Clear Offline Data',
      'clearOfflineDataSubtitle': 'Remove all scan history and pending sync from this device',
      'systemDiagnostics': 'System Diagnostics',
      'systemDiagnosticsSubtitle': 'View models, database, and connection status',
      'offlineModeSubtitle': 'Force offline: use AI and local database only, no cloud sync',
      'changePassword': 'Change Password',
      'emailAddress': 'Email Address',
      'deleteAccount': 'Delete Account',

      // History Screen
      'confirmDelete': 'Confirm Delete',
      'deleteAll': 'Delete All',
      'deleteAllHistoryConfirmation': 'Are you sure you want to delete all scan history?',
      'allScansDeleted': 'All scans deleted',
      'deleteAllCloudConfirmation': 'Are you sure you want to delete all scans from the cloud?',
      'itemsSelected': '{count} selected',
      'deselectAll': 'Deselect all',
      'selectAll': 'Select all',
      'device': 'Device',
      'cloud': 'Cloud',
      'historyStats': '{count} Scans saved • {avgMatch}% Avg Match',
      'uploadSelected': 'Upload Selected Images',
      'downloadSelected': 'Download Selected Images',
      'signInForCloudBackup': 'Sign in to view your cloud backup',
      'signIn': 'Sign in',
      'noInternetConnection': 'No internet connection',
      'cloudScansOfflineMessage': 'Cloud scans will appear when you\'re back online.',
      'noCloudScansYet': 'No cloud scans yet',
      'cloudScansBackupMessage': 'Scans are backed up here when you\'re signed in',
      'unknownPlant': 'Unknown plant',
      'deleteFromCloud': 'Delete from cloud?',
      'saveToCloud': 'Save to Cloud',
      'saveToDevice': 'Save to Device',
      'signInToSaveCloud': 'Sign in to save to cloud',
      'imageFileNotFound': 'Image file not found',
      'savedToCloud': 'Saved to cloud',
      'failedToSaveCloud': 'Failed to save to cloud',
      'scanDeleted': 'Scan deleted',
      'sort': 'SORT',
      'mostRecent': 'Most Recent',
      'oldestFirst': 'Oldest First',
      'highestConfidence': 'Highest Confidence',
      'selectItems': 'Select Items',
      'deleteConfirmation': 'Are you sure you want to delete this scan?',
      'noScansYet': 'No scans yet',
      'startScanning': 'Start scanning to build your herbarium',
      'scanPlant': 'Scan Plant',

      // Feedback Screen
      'feedbackHelpText': 'Help us improve HerbaScan by sharing your experience',
      'feedbackPrivacyNotice': 'Your feedback is stored locally and used for thesis research purposes only.',
      'pleaseSelectCategory': 'Please select a feedback category',
      'commentMinLength': 'Please provide at least 10 characters in your comment',
      'shareThoughtsHint': 'Share your thoughts about HerbaScan...',
      'suggestFeaturesHint': 'Suggest new features or improvements...',
      'submitAnonymously': 'Submit Anonymously',
      'submitAnonymouslySubtitle': 'Your identity will not be attached to this feedback.',
      'errorOccurred': 'Error: {error}',

      // Home Screen
      'home': 'Home',
      'accuracy': 'Accuracy',
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
      'plantReferences': 'Mga Sanggunian ng Halaman',
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
      'useWithStrictCaution': 'Gamitin nang may mahigpit na pag-iingat',
      'useWithStrictCautionBody': 'Dapat sundin ang paraan ng paghahanda at dosis. Huwag gamitin nang walang gabay ng propesyonal.',
      'generallySafeForConsumption': 'Sa pangkalahatan ay ligtas para sa normal na pagkonsumo.',
      'safetyDisclaimerEducational':
          'Ang app na ito ay para lamang sa edukasyonal na layunin. Hindi ito kapalit ng propesyonal na payo medikal. Laging kumonsulta sa propesyonal sa kalusugan bago gumamit ng halamang gamot, lalo na kung ikaw ay buntis, nagpapasuso, umiinom ng gamot, o may umiiral na kondisyong medikal.',
      'noStructuredSafetyData': 'Walang istrukturang data ng kaligtasan para sa halamang ito.',
      'safetyInformationUnavailable': 'Hindi Available ang Impormasyon sa Kaligtasan',
      'safetyInformationUnavailableBody':
          'Masyadong mababa ang kumpiyansa ng pagkakakilala. Huwag gamitin ang resultang ito para sa mga desisyon sa kalusugan.',
      'plantNotRecognized': 'Hindi Makilala ang Halaman',
      'uncertainMatchBody':
          'Para sa iyong kaligtasan, huwag gamitin o kainin ang halamang ito batay sa resultang ito.',
      'whyCantAppIdentify': 'Bakit hindi makilala ng app ang halamang ito?',
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
      'nextPart': 'Susunod na bahagi',
      'previousPart': 'Nakaraang bahagi',
      'adminAnatomyEmpty':
          'Walang bahagi ng halaman. Magdagdag ng bahagi para ipakita ang interactive silhouette sa Plant Detail.',
      'adminAnatomyAddPart': 'Magdagdag ng bahagi ng halaman',
      'restoreToDefault': 'Ibalik sa default',
      'edit': 'I-edit',
      'adminAnatomyDeleteConfirm': 'Tanggalin ang bahaging ito ng halaman',
      'savedToCatalog': 'Nai-save sa catalog',
      'saveFailed': 'Hindi nai-save',
      'deleted': 'Natanggal',
      'restoredToDefault': 'Naibalik sa default',
      'language': 'Wika / Language',
      'offlineMode': 'Offline Mode',
      'showConfidenceScores': 'Ipakita ang Confidence Scores',
      'showGradCAM': 'Show AI Reasoning Heatmap',
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
      'searchHistory': 'Kasaysayan ng Paghahanap',
      'scanHistory': 'Kasaysayan ng Scan',
      'noScansYet': 'Wala pang scan',
      'startScanning': 'Magsimula sa pag-scan ng iyong unang halaman!',
      'deleteAll': 'Tanggalin Lahat',
      'confirmDelete': 'Kumpirmahin ang Pagtanggal',
      'deleteConfirmation':
          'Sigurado ka bang gusto mong tanggalin ang scan na ito?',
      'confidence': 'Confidence',
      'saveToCloud': 'I-save sa Cloud',
      'saveToDevice': 'I-save sa Device',
      'makeAdmin': 'Gawing admin',
      'removeAdmin': 'Alisin ang admin',
      'userNowAdmin': 'Ang user ay administrator na.',
      'adminRemoved': 'Naalis na ang admin role.',
      'forceVerifyEmail': 'Pilitin i-activate ang email',
      'emailVerified': 'Na-verify na ang email. Maaari nang mag-sign in ang user nang walang OTP.',
      'forceVerifyNotAvailable':
          'Hindi available ang force verify. I-deploy ang force-verify-user Edge Function.',
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
      'browseCatalog': 'Mag-browse ng Katalogo',
      'toxicPlantDetected': 'Nadetect ang lason na halaman',
      'toxicPlantBody':
          'Ang halamang ito ay maaaring %s. Huwag gamitin para sa pagkain o gamot. Kung nalunok o na-expose, humingi ng medikal na atensyon.',
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
      'didWeGetThisRight':
          'Tama ba ang resulta? Tulungan ang aming pananaliksik.',
      'milestoneFeedbackTitle': 'Nag-explore ka na ng HerbaScan!',
      'milestoneFeedbackBody':
          'Pwede mo bang gugulin ng 30 segundo para i-rate ang iyong karanasan para sa aming pananaliksik?',
      'rateExperience': 'I-rate ang karanasan',
      'maybeLater': 'Mamaya na',
      'appPerformance': 'Pagganap ng App',
      'viewPerformanceData': 'Tingnan ang data at istatistika ng pagganap',
      'unauthorizedAccess': 'Hindi pinahihintulutang pag-access.',
      'whatPlant': 'Anong halaman ang iyong kinikilala?',
      'tapCameraToStart': 'Pindutin ang camera button sa ibaba para magsimula.',
      'scansCount': 'Scans',
      'seeAll': 'Tingnan Lahat',
      'unknownPlant': 'Hindi Kilalang Halaman',
      'dohApprovedPlants': 'Mga Halamang Aprubado ng DOH',
      'noDohPlantsLoaded': 'Walang nai-load na halamang aprubado ng DOH.',
      'searchPlantsCount': 'Maghanap sa {count} Halaman',
      'showingPlants': 'Ipinapakita ang {count} Halaman',
      'medical': 'Medikal',
      'listView': 'Tingnan bilang Listahan',
      'gridView': 'Tingnan bilang Grid',
      'emailOrPasswordMismatch': 'Hindi tugma ang email o password.',
      'signInFailed': 'Bigo ang pag-sign in. Pakisubukan muli.',
      'tooManyAttempts': 'Masyadong maraming nabigong pagsubok. Maghintay ng {seconds} segundo.',
      'signInTitle': 'Mag-sign In',
      'backToApp': 'Bumalik sa app',
      'emailLabel': 'Email',
      'emailHint': 'ikaw@example.com',
      'enterEmail': 'Ilagay ang iyong email',
      'validEmailRequired': 'Maglagay ng wastong email',
      'passwordLabel': 'Password',
      'enterPassword': 'Ilagay ang iyong password',
      'forgotPasswordLabel': 'Nakalimutan ang password?',
      'waitSeconds': 'Maghintay ng {seconds}s',
      'newToHerbaScan': 'Bago sa HerbaScan?',
      'createAccountBtn': 'Gumawa ng Account',
      'personalHerbarium': 'Personal na Herbarium',
      'loginSubtitle': 'Mag-sign in para i-sync ang kasaysayan at mga larawan sa cloud.',
      'tooManyEmailsSent': 'Masyadong maraming signup email ang naipadala. Subukan muli pagkatapos ng isang oras.',
      'emailAlreadyRegistered': 'Nakarehistro na ang email na ito. Subukang mag-sign in.',
      'createAccountTitle': 'Gumawa ng Account',
      'signupSubtitle': 'Gumawa ng account para i-back up ang iyong mga scan sa cloud.',
      'passwordHint': 'Maglagay ng malakas na password',
      'useAtLeast8Chars': 'Gumamit ng hindi bababa sa 8 character',
      'includeCapitalLetter': 'Maglakip ng kahit isang malaking letra',
      'includeLowercaseLetter': 'Maglakip ng kahit isang maliit na letra',
      'includeNumber': 'Maglakip ng kahit isang numero',
      'includeSpecialChar': 'Maglakip ng kahit isang espesyal na character (!@#\$%^&* etc.)',
      'confirmPasswordLabel': 'Kumpirmahin ang Password',
      'confirmPasswordHint': 'Ilagay muli ang iyong password',
      'passwordsDoNotMatch': 'Hindi tugma ang mga password',
      'confirmYourPassword': 'Kumpirmahin ang iyong password',
      'alreadyHaveCode': 'May verification code na?',
      'enterValidEmailForCode': 'Pakilagay ang iyong wastong email sa itaas para i-verify ang code.',
      'resetPasswordTitle': 'I-reset ang Password',
      'resetPasswordSubtitle': 'Ilagay ang iyong email at magpapadala kami ng 6-digit code para i-reset ang iyong password.',
      'sendCodeBtn': 'Ipadala ang Code',
      'backToSignIn': 'Bumalik sa Pag-sign In',
      'createNewPasswordTitle': 'Gumawa ng Bagong Password',
      'remainSignedIn': 'Mananatili kang naka-sign in sa device na ito.',
      'currentPasswordLabel': 'Kasalukuyang password',
      'enterCurrentPassword': 'Ilagay ang iyong kasalukuyang password',
      'newPasswordLabel': 'Bagong password',
      'confirmNewPassword': 'Kumpirmahin ang bagong password',
      'updatePasswordBtn': 'I-update ang Password',
      'passwordUpdated': 'Matagumpay na na-update ang password',
      'incorrectCurrentPassword': 'Mali ang inilagay mong kasalukuyang password.',
      'emailUpdatedMsg': 'Na-update ang email. Suriin ang iyong bagong inbox para kumpirmahin.',
      'emailAddressTitle': 'Email Address',
      'updateEmailSubtitle': 'I-update ang email address na nakaugnay sa iyong account.',
      'newEmailAddressLabel': 'Bagong email address',
      'enterNewEmail': 'Ilagay ang bagong email',
      'newEmailMustBeDifferent': 'Dapat na bago ang email na inilagay',
      'confirmationLinkMsg': 'Magpapadala kami ng confirmation link sa iyong bagong email. Magkakabisa ang pagbabago kapag na-verify na.',
      'updateEmailBtn': 'I-update ang Email',
      'codeExpired': 'Expired na ang code. I-tap ang "Resend" para kumuha ng bago.',
      'invalidCode': 'Mali ang code. Subukan muli.',
      'newCodeSent': 'Naipadala na ang bagong code sa iyong email.',
      'failedToResend': 'Bigo ang pagpapadala muli. Pakisubukan muli.',
      'checkYourInbox': 'Suriin ang iyong inbox',
      'sent6DigitCode': 'Nagpadala kami ng 6-digit code sa\n{email}',
      'tooManyAttemptsWait': 'Masyadong maraming pagsubok.\nSubukan muli pagkatapos ng {lockedUntil}.',
      'attemptsLeft': 'Mga natitirang pagsubok: {attemptsLeft}',
      'activateAccountBtn': 'I-activate ang Account',
      'waitResend': 'Maghintay ng {seconds}s para ipadala muli',
      'didntReceiveEmail': 'Hindi natanggap ang email? Ipadala muli',
      'continueBtn': 'Magpatuloy',
      'accountSuspendedTitle': 'Suspindido ang Account',
      'accountSuspendedSubtitle': 'Ang iyong HerbaScan account ay pansamantalang nasuspinde at hindi ma-access sa ngayon.',
      'reasonLabel': 'Dahilan',
      'contactSupportBtn': 'Kontakin ang Suporta',
      'couldNotOpenEmail': 'Hindi mabuksan ang email client.',
      'supportMistakeMsg': 'Kung naniniwala kang nagkamali ito, mangyaring kontakin ang aming support team.',
      'accountVerifiedTitle': 'Na-verify na ang Account!',
      'accountCreatedAs': 'Nagawa na ang iyong account bilang\n{email}',
      'nowSignedInWelcome': 'Naka-sign in ka na. Maligayang pagdating sa iyong Personal na Herbarium.',
      'redirectingSettings': 'Pumupunta sa mga setting sa {countdown}...',
      'goToSettingsBtn': 'Pumunta sa Settings',
      'authenticating': 'Nagsa-sign in...',
      'authenticationTitle': 'Pagpapatotoo',
      'authErrorTitle': 'Error sa Pagpapatotoo',
      'authStatusTitle': 'Katayuan',
      'goToDashboardBtn': 'Pumunta sa Dashboard',
      // Admin Web Screen
      'overview': 'Pangkalahatang-tingin',
      'plantCatalog': 'Katalogo ng Halaman',
      'healthConditions': 'Mga Kondisyong Pangkalusugan',
      'userDirectory': 'Direktoryo ng Gumagamit',
      'systemHealth': 'Kalusugan ng Sistema',
      'feedbackMenu': 'Feedback',
      'submissions': 'Mga Isinumite',
      'appConfig': 'Kumpigurasyon ng App',
      'adminConsole': 'Admin Console',
      'elevatedPrivilegesActive': 'Aktibong Pribilehiyo ng Admin',
      'adminRole': 'Admin',
      'signOut': 'Mag-sign Out',
      'exitAdminConsole': 'Lumabas sa Admin Console',
      'selectAModule': 'Pumili ng module mula sa sidebar para magsimula.',
      // Admin User Management
      'makeAdminPrompt': 'Gawing Admin',
      'removeAdminPrompt': 'Alisin ang Admin',
      'makeAdminDesc': 'Bibigyan ba ng pribilehiyong admin ang gumagamit na ito?',
      'removeAdminDesc': 'Aalisin ba ang pribilehiyong admin ng gumagamit na ito?',
      'deleteUserDataPrompt': 'Burahin ang Data ng Gumagamit',
      'deleteUserDataDesc': 'Permanenteng mabubura ang lahat ng data ng gumagamit na ito. Hindi na ito mababawi.',
      'typeDeleteToConfirm': 'I-type ang DELETE para kumpirmahin',
      'deleteUserDataBtn': 'Burahin ang Data ng Gumagamit',
      'deletingAccount': 'Binubura ang account...',
      'removingAccountData': 'Iniaalis ang data ng account...',
      'refresh': 'I-refresh',
      'searchByEmail': 'Maghanap ayon sa email...',
      'noUsersMatch': 'Walang gumagamit na tumutugma sa iyong paghahanap.',
      'noUsersFound': 'Walang nahanap na gumagamit.',
      'verified': 'Na-verify',
      'unverified': 'Hindi Na-verify',
      'joined': 'Sumali',
      'scanCount': 'Mga Scan',
      'adminLabel': 'Admin',
      'userLabel': 'Gumagamit',
      'suspendAccount': 'Suspindihin ang Account',
      'reactivateAccount': 'Muling I-activate ang Account',
      // Admin System Health
      'successRate': 'Antas ng Tagumpay',
      'avgResponse': 'Avg na Tugon',
      'errorLogs': 'Mga Log ng Error',
      'filterAll': 'Lahat',
      'filterCamera': 'Camera',
      'filterAI': 'AI',
      'filterDatabase': 'Database',
      'filterNetwork': 'Network',
      'systemStable0Errors': 'Matatag ang sistema — 0 error',
      'noErrorsInLog': 'Walang error sa log.',
      'showLess': 'Ipakita ang Mas Kaunti',
      'showAllErrors': 'Ipakita ang Lahat ng Error',
      'stackTrace': 'Stack Trace',
      'errorContext': 'Konteksto ng Error',
      'noAdditionalDetails': 'Walang karagdagang detalye.',
      'export': 'I-export',
      'exportStatsErrors': 'I-export ang Stats at Mga Error',
      'exportAll': 'I-export ang Lahat',
      'exportErrorLogs': 'I-export ang Mga Log ng Error',
      'clearAll': 'Burahin ang Lahat',
      'exportAllData': 'I-export ang Lahat ng Data',
      'errorLogEntries': 'mga entry ng log ng error',
      'performanceUsageErrorLogs': 'Performance, Paggamit at Mga Log ng Error',
      'format': 'Format',
      // Admin Feedback Screen
      'markReviewed': 'Markahan bilang Nasuri',
      'markResolved': 'Markahan bilang Nalutas',
      'markPending': 'Markahan bilang Nakabinbin',
      'deleteBtn': 'Burahin',
      'showMore': 'Ipakita pa',
      'suggestion': 'Mungkahi',
      // Admin System Health (extra)
      'mobilenetV2MedicinalPlants': 'MobileNetV2 – Mga Halamang Gamot',
      'webLiveModelCloud': 'Web: Live na Model (Cloud)',
      'liveModelSupabase': 'Live na Model (Supabase)',
      'bundledAssetModel': 'Bundled Asset Model',
      'webAdminRunsLiveCloud': 'Palaging ginagamit ng Web/Admin ang live cloud model.',
      'versionLabel': 'v',
      'noOtaModelDownloaded': 'Walang na-download na OTA model',
      'otaModelUpdatesWebCloud': 'Ang mga OTA model update ay para sa web/cloud lamang.',
      'checkingForModelUpdate': 'Sinisuri ang model update...',
      'checkNow': 'Suriin Ngayon',
      'localDeviceAnalytics': 'Lokal na Analytics ng Device',
      'totalScans': 'Kabuuang Scan',
      'successful': 'Matagumpay',
      // Admin User Management (extra)
      'suspend': 'Suspindihin',
      'suspendWarning': 'Mapipigilan ang gumagamit na mag-sign in.',
      'reasonOptional': 'Dahilan (opsyonal)',
      'reasonHint': 'hal. Paglabag sa mga alituntunin ng komunidad',
      // Admin Dashboard
      'approve': 'Aprubahan',
      'reject': 'Tanggihan',
      'trainingEligible': 'Karapat-dapat sa Training',
      // Admin Feedback (extra)
      'failedToLoadFeedback': 'Nabigo ang pag-load ng feedback.',
      'anonymous': 'Hindi Kilala',
      'userText': 'Gumagamit',
      'couldNotLoadFeedback': 'Hindi ma-load ang feedback.',
      'userFeedback': 'Feedback ng Gumagamit',
      'searchFeedbackOrUser': 'Maghanap ng feedback o gumagamit...',
      'allStatuses': 'Lahat ng Katayuan',
      'pending': 'Nakabinbin',
      'reviewed': 'Nasuri',
      'resolved': 'Nalutas',
      'statusLabel': 'Katayuan',
      'allCategories': 'Lahat ng Kategorya',
      'categoryLabel': 'Kategorya',
      'noFeedbackInSupabase': 'Walang feedback sa Supabase.',
      'noFeedbackMatchesFilters': 'Walang feedback na tumutugma sa iyong mga filter.',
      'deleteFeedbackPrompt': 'Burahin ang Feedback',
      'deleteFeedbackDesc': 'Sigurado ka bang gusto mong permanenteng burahin ang feedback na ito?',
      'feedbackRemoved': 'Naalis ang feedback.',
      'couldNotDeleteFeedback': 'Hindi mabura ang feedback.',
      'statusUpdated': 'Na-update ang katayuan.',
      'failedToUpdateStatus': 'Nabigo ang pag-update ng katayuan.',
      // Admin App Config
      'helpTutorialContent': 'Nilalaman ng Tulong at Tutorial',
      'tips': 'Mga Tip',
      'issues': 'Mga Isyu',
      'features': 'Mga Feature',
      'oodExplanation': 'Paliwanag ng OOD',
      'saving': 'Nino-save...',
      'saveConfiguration': 'I-save ang Kumpigurasyon',
      'add': 'Idagdag',
      'noItemsAdded': 'Walang mga item na idinagdag.',
      // Admin Dashboard (extra)
      'fullResolutionPinchToZoom': 'Buong Resolusyon (Pinch para Mag-zoom)',
      'deleteSubmission': 'Burahin ang Isinumite',
      'deleteSubmissionBody': 'Sigurado ka bang gusto mong burahin ang isinumiteng ito?',
      'deleteRequest': 'Burahin ang Kahilingan',
      'deleteRequestBody': 'Sigurado ka bang gusto mong burahin ang kahilingang ito?',
      'imageAddedToTraining': 'Naidagdag ang larawan sa training set.',
      'storageCopyFailed': 'Nabigo ang pagkopya sa storage.',
      'accessDeniedAdminOnly': 'Hindi pinahintulutan. Para sa mga admin lamang.',
      'dataDeletionRequests': 'Mga Kahilingang Burahin ang Data',
      'submissionTriage': 'Pag-uri-uriin ng Isinumite',
      'backToSubmissions': 'Bumalik sa mga Isinumite',
      'inboxZero': 'Walang laman ang inbox!',
      'noDeletionRequests': 'Walang mga kahilingang burahin.',
      'unknown': 'Hindi Kilala',
      'remove': 'Alisin',
      // Admin App Config (extra)
      'configSavedSuccess': 'Na-save ang kumpigurasyon.',
      'failedToSave': 'Nabigo ang pag-save.',
      'appConfiguration': 'Kumpigurasyon ng App',
      'appConfigDesc': 'Pamahalaan ang mga setting ng app at kumpigurasyon ng nilalaman.',
      'reloadFromServer': 'I-reload mula sa Server',
      'failedToLoadConfig': 'Nabigo ang pag-load ng kumpigurasyon.',
      'appVersionLabel': 'Bersyon ng App',
      'appVersionDesc': 'Ang kasalukuyang bersyon ng HerbaScan na ipinapakita sa mga gumagamit.',
      'modelVersionLabel': 'Bersyon ng Model',
      'modelVersionDesc': 'Ang aktibong bersyon ng AI model na ginagamit para makilala ang mga halaman.',
      // Onboarding & Disclaimer
      'skipBtn': 'Laktawan',
      'getStartedBtn': 'Magsimula',
      'nextBtn': 'Susunod',
      'onboardingTitle1': 'Pagkilala sa Halaman gamit ang AI',
      'onboardingDesc1': 'Agad na kilalanin ang mga halamang gamot sa Pilipinas nang may mataas na katumpakan gamit ang isang larawan.',
      'onboardingTitle2': 'Gumagana Kahit Walang Internet',
      'onboardingDesc2': 'I-scan at alamin ang mga herbal na lunas kahit saan. Hindi na kailangan ng internet.',
      'onboardingTitle3': 'Mga Halamang Aprubado ng DOH',
      'onboardingDesc3': 'Tuklasin ang mga herbal na gamot na kinikilala at aprubado ng Department of Health.',
      'onboardingTitle4': 'Malinaw na AI',
      'onboardingDesc4': 'Tingnan nang eksakto kung aling bahagi ng dahon ang ginamit ng AI sa pagtukoy, upang makasiguro ka sa resulta.',
      'termsConditionsStep': 'Mga Tuntunin at Kundisyon ({step}/3)',
      'errorLoadingDocs': 'Nagkaroon ng error sa pag-load ng mga dokumento. Pakisubukan muli mamaya.',
      'scrollToBottomToUnlock': 'Pakiscroll hanggang ibaba para ma-unlock ang kasunduan.',
      'agreeMedicalDisclaimer': 'Nabasá ko at sumasang-ayon ako sa Medical Disclaimer',
      'agreeTermsOfService': 'Nabasá ko at sumasang-ayon ako sa Terms of Service',
      'agreeEULA': 'Nabasá ko at sumasang-ayon ako sa End-User License Agreement (EULA)',
      // Scan & Results Screens
      'selectAPlantImageToIdentify': 'Pumili ng larawan ng halaman na kikilalanin',
      'cameraNotAvailableWindows': 'Hindi available ang camera sa Windows desktop',
      'analyzing': 'Sinisuri...',
      'chooseDifferentImage': 'Pumili ng Ibang Larawan',
      'browseImage': 'Mag-browse ng Larawan',
      'initializingCamera': 'Sinisimulan ang camera...',
      'cameraError': 'May Error sa Camera',
      'unknownError': 'Hindi kilalang error',
      'noPlantDetected': 'Walang nadetect na halaman.',
      'failedToIdentifyPlant': 'Nabigong makilala ang halaman.',
      'imageTooUnclear': 'Masyadong Malabo ang Larawan',
      'couldNotGetClearLook': 'Hindi makuha nang malinaw. Subukan ang mas magandang ilaw o punasan ang lens.',
      'retakePhoto': 'Kumuha Muli ng Larawan',
      'lowConfidenceMatch': 'Mababang Kumpiyansa sa Tugma',
      'noPlantMatchFound': 'Walang Nakitang Tugmang Halaman',
      'notConfidentEnough': 'Hindi kami sapat na kumpyansa para kumpirmahin itong tugma. Kumuha muli ng mas malinaw na larawan o mag-browse sa katalogo nang manu-mano.',
      'dontRecognizePlant': 'Hindi namin makilala ang halamang ito. Siguraduhing ito ay malinaw at iisang dahon lamang.',
      'bestGuess': 'Pinakamahusay na hula: {name}  ·  {pct}%',
      'lookAlikePlants': 'Mga Halamang Kamukha',
      'uncertainMatches': 'Ito ay mga posible ngunit hindi tiyak na tugma',
      'gotIt': 'Naiintindihan ko',
      // Plant Result Screen
      'notIdentified': 'Hindi nakilala',
      'pctMatch': '{pct}% Tugma',
      'openPlantProfile': 'Buksan ang Profile ng Halaman',
      'viewHabitatMap': 'Tingnan ang Habitat Map',
      'dohVerified': 'Na-verify ng DOH',
      'scientificallyDocumented': 'Dokumentado ng Siyensya',
      'dohVerifiedPlant': 'Halamang Na-verify ng DOH',
      'scientificallyDocumentedPlant': 'Halamang Dokumentado ng Siyensya',
      'dohVerifiedBody': 'Ang halamang ito ay opisyal na ineendorso ng Department of Health ng Pilipinas sa ilalim ng Administrative Order No. 12, serye ng 1997, at kasama sa listahan ng mga klinikal na balidong halamang gamot (Republic Act No. 8423 — TAMA).',
      'scientificallyDocumentedBody': 'Ang halamang ito ay wala sa aprubadong listahan ng DOH ngunit isinama sa HerbaScan batay sa peer-reviewed literature at mga sanggunian ng Philippine Herbal Pharmacopeia (PITAHC).',
      'source': 'Pinagmulan: Dept. of Health Admin. Order No. 12, s. 1997 · Republic Act No. 8423 (TAMA, 1997) · Philippine Herbal Pharmacopeia (PITAHC)',
      'didWeGetThisRight': 'Tama ba ito? Tulungan ang aming pananaliksik.',
      'thankYou': 'Salamat!',
      'plantNotRecognized': 'Hindi Nakilala ang Halaman',
      'uncertainMatchBody': 'Ang halaman sa iyong larawan ay hindi lubos na tumutugma sa anumang nasa aming database.',
      'whyCantAppIdentify': 'Bakit hindi makilala ng app?',
      'alternativeMatches': 'Mga Alternatibong Tugma',
      'alternativeMatchesBody': 'Kung mukhang mali ang nangungunang resulta, ito ang mga susunod na posibilidad.',
      'scanResults': 'Mga Resulta ng Scan',
      'noPredictionsAvailable': 'Walang magagamit na hula',
      'unableToIdentifyPlant': 'Hindi makilala ang halaman sa larawan',
      'tryAgain': 'Subukan Muli',
      'saveScan': 'I-save ang Scan',
      'saveToDevice': 'I-save sa device',
      'saveToCloud': 'I-save sa cloud',
      'saveToCameraRoll': 'I-save sa Camera Roll',
      'share': 'Ibahagi',
      'shareAsInfoCard': 'Ibahagi bilang Info Card',
      'shareAsInfoCardSub': 'Branded na card na may detalye ng halaman',
      'shareAsText': 'Ibahagi bilang Text',
      'shareAsTextSub': 'Plain text para sa WhatsApp, SMS, atbp.',
      'matchConfidence': 'Kumpiyansa sa Tugma',
      'medicinalUses': 'Mga Gamit Medikal',
      'scannedWithHerbaScan': 'Na-scan gamit ang HerbaScan 🌱',
      'discoverMedicinalPlants': 'Tuklasin ang mga halamang gamot ng Pilipinas',
      'imageNotFound': 'Hindi nahanap ang larawan',
      'yes': 'Oo',
      'notListed': 'Hindi nakalista',
      'milestoneFeedbackTitle': 'Nag-eenjoy sa HerbaScan?',
      'milestoneFeedbackBody': 'Nakagawa ka na ng ilang scan! Kamusta ang iyong karanasan hanggang ngayon?',
      'maybeLater': 'Siguro Mamaya',
      'rateExperience': 'I-rate ang Karanasan',

      // Plant Detail Screen
      'taxonomy': 'Taksonomiya',
      'ecology': 'Ekolohiya',
      'medicinal': 'Medikal',
      'safety': 'Kaligtasan',
      'scientificClassification': 'Siyentipikong Klasipikasyon',
      'morphology': 'Morpolohiya',
      'kingdom': 'Kaharian',
      'plantae': 'Plantae',
      'family': 'Pamilya',
      'genus': 'Kaurian',
      'species': 'Uri',
      'habitat': 'Tirahan',
      'preparationMethods': 'Mga Paraan ng Paghahanda',
      'dosage': 'Dosis',
      'duration': 'Tagal',
      'forCondition': 'Para sa {condition}',
      'startGuide': 'Simulan ang Gabay',
      'dataSources': 'Pinagmulan ng Datos',
      'dataSourcesSub': 'Kung saan nagmula ang impormasyong ito',
      'departmentOfHealth': 'Department of Health',
      'pitahc': 'PITAHC',
      'aiTrainingDataset': 'AI Training Dataset',
      'informationNotAvailable': 'Wala pang impormasyon.',

      // Preparation Instructions Screen
      'progressReset': 'Na-reset ang progreso',
      'calendarCouldNotBeOpened': 'Hindi mabuksan ang kalendaryo. Suriin kung may naka-install na calendar app at subukang muli.',
      'couldNotOpenCalendar': 'Hindi mabuksan ang kalendaryo: {e}',
      'resetProgressTitle': 'I-reset ang Progreso?',
      'resetProgressBody': 'Buburahin nito ang lahat ng natapos na hakbang at ititigil ang anumang tumatakbong timer.',
      'cancel': 'Kanselahin',
      'reset': 'I-reset',
      'medicalDisclaimer': 'Ang HerbaScan ay isang edukasyonal na tool. Laging kumunsulta sa isang lisensyadong doktor bago gumamit ng anumang halamang gamot.',
      'importantWarnings': 'Mahalagang Babala',
      'generalSafetyInfo': 'Pangkalahatang Impormasyon sa Kaligtasan',
      'steps': 'Mga Hakbang',
      'regimen': 'Regimen',
      'frequency': 'Dalas',
      'stepN': 'Hakbang {n}',

      // Preparation Focus Mode Screen
      'noStepsAvailable': 'Walang magagamit na mga hakbang',
      'tapToResume': 'I-tap para ituloy • Pindutin nang matagal para i-reset',
      'tapToPause': 'I-tap para i-pause • Pindutin nang matagal para i-reset',
      'tapToStartTimer': 'I-tap para simulan ang timer',
      'stepDone': 'Tapos na ang Hakbang ✓',
      'allDone': 'Tapos na ang Lahat ✓',
      'completeAndContinue': 'Kumpletuhin & Magpatuloy',
      'completePreparation': 'Kumpletuhin ang Paghahanda',
      'preparationComplete': 'Tapos na ang Paghahanda!',
      'completedAllSteps': 'Nakumpleto mo na ang lahat ng hakbang sa paghahanda.',
      'returnToGuide': 'Bumalik sa Gabay',

      // Settings Screen
      'accountLabel': 'Account',
      'appPreferencesLabel': 'Mga Kagustuhan sa App',
      'scanningRecognitionLabel': 'Pag-scan at Pagkilala',
      'supportLegalAboutLabel': 'Suporta, Legal at Tungkol Dito',
      'developerOptionsLabel': 'Mga Opsyon ng Developer',
      
      'personalHerbarium': 'Personal Herbarium',
      'signInToBackUp': 'Mag-sign in para i-back up ang iyong mga scan sa cloud',
      'administrator': 'Administrator',
      'standardUser': 'Karaniwang Gumagamit',
      'updatePasswordSubtitle': 'I-update ang password ng iyong account',
      'updateEmailSubtitle': 'I-update ang email ng iyong account',
      'adminConsole': 'Admin Console',
      'adminConsoleSubtitle': 'I-access ang mga tool at setting ng admin',
      'deleteAccountSubtitle': 'Permanenteng tanggalin ang iyong account at cloud data',
      'requestDataDeletion': 'Humiling ng Pagbura ng Data',
      'requestDataDeletionSubtitle': 'Magsumite ng kahilingan na tanggalin ang iyong personal na data',
      
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'themeSubtitle': 'Magpalipat-lipat sa pagitan ng dark at light na tema',
      'english': 'English',
      'filipino': 'Filipino',
      'autoSaveScans': 'I-auto-save ang mga Scan',
      'autoSaveScansSubtitle': 'Awtomatikong i-save ang mga resulta ng scan',
      
      'showConfidenceScores': 'Ipakita ang Kumpiyansa sa Hula',
      'showAlternativeMatches': 'Ipakita ang Ibang mga Tugma',
      
      'helpTutorialSubtitle': 'Alamin kung paano makuha ang pinakamagandang resulta ng pag-scan',
      'sendFeedback': 'Magpadala ng Feedback',
      'sendFeedbackSubtitle': 'Ibahagi ang iyong mga saloobin o mag-ulat ng isyu',
      'termsOfService': 'Mga Tuntunin ng Serbisyo',
      'eula': 'Kasunduan sa Lisensya ng End-User',
      'privacyPolicy': 'Patakaran sa Privacy',
      'appVersion': 'Bersyon ng App',
      'modelVersion': 'Bersyon ng Modelo',
      
      'refreshOfflineData': 'I-refresh ang Offline na Data',
      'refreshOfflineDataSubtitle': 'I-reload ang mga stat mula sa lokal na database at katayuan sa pag-sync',
      'offlineStorageInfo': 'Impormasyon sa Offline na Storage',
      'clearOfflineData': 'I-clear ang Offline na Data',
      'clearOfflineDataSubtitle': 'Alisin ang lahat ng history ng scan at nakabinbing pag-sync mula sa device na ito',
      'systemDiagnostics': 'System Diagnostics',
      'systemDiagnosticsSubtitle': 'Tingnan ang mga modelo, database, at katayuan ng koneksyon',
      'offlineModeSubtitle': 'Kumilala ng mga halaman nang walang internet connection.',
      'changePassword': 'Baguhin ang Password',
      'emailAddress': 'Email Address',
      'deleteAccount': 'Burahin ang Account',

      // History Screen
      'confirmDelete': 'Kumpirmahin ang Pagbura',
      'deleteAll': 'Burahin Lahat',
      'deleteAllHistoryConfirmation': 'Sigurado ka bang gusto mong burahin ang buong history ng scan?',
      'allScansDeleted': 'Nabura na ang lahat ng scan',
      'deleteAllCloudConfirmation': 'Sigurado ka bang gusto mong burahin ang lahat ng scan mula sa cloud?',
      'itemsSelected': '{count} ang napili',
      'deselectAll': 'Alisin ang pagkakapili sa lahat',
      'selectAll': 'Piliin lahat',
      'device': 'Device',
      'cloud': 'Cloud',
      'historyStats': '{count} Scan na na-save • {avgMatch}% Average Match',
      'uploadSelected': 'I-upload ang Napiling mga Larawan',
      'downloadSelected': 'I-download ang Napiling mga Larawan',
      'signInForCloudBackup': 'Mag-sign in para makita ang iyong cloud backup',
      'signIn': 'Mag-sign in',
      'noInternetConnection': 'Walang koneksyon sa internet',
      'cloudScansOfflineMessage': 'Lilitaw ang mga cloud scan kapag naka-online ka na muli.',
      'noCloudScansYet': 'Wala pang cloud scan',
      'cloudScansBackupMessage': 'Naba-back up ang mga scan dito kapag naka-sign in ka',
      'unknownPlant': 'Hindi kilalang halaman',
      'deleteFromCloud': 'Burahin mula sa cloud?',
      'saveToCloud': 'I-save sa Cloud',
      'saveToDevice': 'I-save sa Device',
      'signInToSaveCloud': 'Mag-sign in para i-save sa cloud',
      'imageFileNotFound': 'Hindi nahanap ang image file',
      'savedToCloud': 'Na-save sa cloud',
      'failedToSaveCloud': 'Nabigong i-save sa cloud',
      'scanDeleted': 'Nabura na ang scan',
      'sort': 'AYUSIN',
      'mostRecent': 'Pinakabago',
      'oldestFirst': 'Pinakaluma Una',
      'highestConfidence': 'Pinakamataas na Kumpiyansa',
      'selectItems': 'Pumili ng mga Item',
      'deleteConfirmation': 'Sigurado ka bang gusto mong burahin ang scan na ito?',
      'noScansYet': 'Wala pang mga scan',
      'startScanning': 'Magsimulang mag-scan para bumuo ng iyong herbarium',
      'scanPlant': 'I-scan ang Halaman',

      // Feedback Screen
      'feedbackHelpText': 'Tulungan kaming pagandahin ang HerbaScan sa pamamagitan ng pagbabahagi ng iyong karanasan',
      'feedbackPrivacyNotice': 'Ang iyong feedback ay naka-save ng lokal at gagamitin lang para sa layuning pananaliksik sa thesis.',
      'pleaseSelectCategory': 'Mangyaring pumili ng kategorya ng feedback',
      'commentMinLength': 'Mangyaring magbigay ng kahit 10 letra sa iyong komento',
      'shareThoughtsHint': 'Ibahagi ang iyong mga iniisip tungkol sa HerbaScan...',
      'suggestFeaturesHint': 'Magmungkahi ng mga bagong feature o mga pagpapabuti...',
      'submitAnonymously': 'Isumite ng Anonymous',
      'submitAnonymouslySubtitle': 'Ang iyong pagkakakilanlan ay hindi isasama sa feedback na ito.',
      'errorOccurred': 'Error: {error}',

      // Home Screen
      'home': 'Home',
      'accuracy': 'Accuracy',
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
