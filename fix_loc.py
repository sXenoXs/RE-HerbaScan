import re

def main():
    with open(r'D:\Lenovo2\Code\This_is_IT\RE-HerbaScan\lib\core\localization\app_localizations.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # The getters to insert
    getters = """
  // Admin User Management
  String get makeAdmin => _localizedValues[locale.languageCode]!['makeAdmin']!;
  String get removeAdmin => _localizedValues[locale.languageCode]!['removeAdmin']!;
  String get userNowAdmin => _localizedValues[locale.languageCode]!['userNowAdmin']!;
  String get adminRemoved => _localizedValues[locale.languageCode]!['adminRemoved']!;
  String get forceVerifyEmail => _localizedValues[locale.languageCode]!['forceVerifyEmail']!;
  String get emailVerified => _localizedValues[locale.languageCode]!['emailVerified']!;
  String get forceVerifyNotAvailable => _localizedValues[locale.languageCode]!['forceVerifyNotAvailable']!;

  // Admin Web Screen
  String get adminConsole => _localizedValues[locale.languageCode]!['adminConsole']!;
  String get elevatedPrivilegesActive => _localizedValues[locale.languageCode]!['elevatedPrivilegesActive']!;
  String get adminRole => _localizedValues[locale.languageCode]!['adminRole']!;
  String get signOut => _localizedValues[locale.languageCode]!['signOut']!;
  String get exitAdminConsole => _localizedValues[locale.languageCode]!['exitAdminConsole']!;
  String get overview => _localizedValues[locale.languageCode]!['overview']!;
  String get plantCatalog => _localizedValues[locale.languageCode]!['plantCatalog']!;
  String get healthConditions => _localizedValues[locale.languageCode]!['healthConditions']!;
  String get userDirectory => _localizedValues[locale.languageCode]!['userDirectory']!;
  String get systemHealth => _localizedValues[locale.languageCode]!['systemHealth']!;
  String get feedbackMenu => _localizedValues[locale.languageCode]!['feedbackMenu']!;
  String get submissions => _localizedValues[locale.languageCode]!['submissions']!;
  String get appConfig => _localizedValues[locale.languageCode]!['appConfig']!;
  String get selectAModule => _localizedValues[locale.languageCode]!['selectAModule']!;

  // Admin Dashboard Screen
  String get dataDeletionRequests => _localizedValues[locale.languageCode]!['dataDeletionRequests']!;
  String get submissionTriage => _localizedValues[locale.languageCode]!['submissionTriage']!;
  String get pending => _localizedValues[locale.languageCode]!['pending']!;
  String get inboxZero => _localizedValues[locale.languageCode]!['inboxZero']!;
  String get noDeletionRequests => _localizedValues[locale.languageCode]!['noDeletionRequests']!;
  String get unknown => _localizedValues[locale.languageCode]!['unknown']!;
  String get unknownPlant => _localizedValues[locale.languageCode]!['unknownPlant']!;
  String get trainingEligible => _localizedValues[locale.languageCode]!['trainingEligible']!;
  String get reject => _localizedValues[locale.languageCode]!['reject']!;
  String get approve => _localizedValues[locale.languageCode]!['approve']!;
  String get remove => _localizedValues[locale.languageCode]!['remove']!;
  String get fullResolutionPinchToZoom => _localizedValues[locale.languageCode]!['fullResolutionPinchToZoom']!;
  String get deleteSubmission => _localizedValues[locale.languageCode]!['deleteSubmission']!;
  String get deleteSubmissionBody => _localizedValues[locale.languageCode]!['deleteSubmissionBody']!;
  String get deleteRequest => _localizedValues[locale.languageCode]!['deleteRequest']!;
  String get deleteRequestBody => _localizedValues[locale.languageCode]!['deleteRequestBody']!;
  String get imageAddedToTraining => _localizedValues[locale.languageCode]!['imageAddedToTraining']!;
  String get storageCopyFailed => _localizedValues[locale.languageCode]!['storageCopyFailed']!;
  String get accessDeniedAdminOnly => _localizedValues[locale.languageCode]!['accessDeniedAdminOnly']!;
  String get backToSubmissions => _localizedValues[locale.languageCode]!['backToSubmissions']!;

  // Admin App Config & System Health
  String get refresh => _localizedValues[locale.languageCode]!['refresh']!;
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
  String get appConfiguration => _localizedValues[locale.languageCode]!['appConfiguration']!;
  String get appConfigDesc => _localizedValues[locale.languageCode]!['appConfigDesc']!;
  String get reloadFromServer => _localizedValues[locale.languageCode]!['reloadFromServer']!;
  String get saving => _localizedValues[locale.languageCode]!['saving']!;
  String get failedToLoadConfig => _localizedValues[locale.languageCode]!['failedToLoadConfig']!;
  String get appVersionLabel => _localizedValues[locale.languageCode]!['appVersionLabel']!;
  String get appVersionDesc => _localizedValues[locale.languageCode]!['appVersionDesc']!;
  String get modelVersionLabel => _localizedValues[locale.languageCode]!['modelVersionLabel']!;
  String get modelVersionDesc => _localizedValues[locale.languageCode]!['modelVersionDesc']!;
  String get helpTutorialContent => _localizedValues[locale.languageCode]!['helpTutorialContent']!;
  String get oodExplanation => _localizedValues[locale.languageCode]!['oodExplanation']!;
  String get saveConfiguration => _localizedValues[locale.languageCode]!['saveConfiguration']!;
  String get add => _localizedValues[locale.languageCode]!['add']!;
  String get noItemsAdded => _localizedValues[locale.languageCode]!['noItemsAdded']!;
  String get configSavedSuccess => _localizedValues[locale.languageCode]!['configSavedSuccess']!;
  String get failedToSave => _localizedValues[locale.languageCode]!['failedToSave']!;
  String get tips => _localizedValues[locale.languageCode]!['tips']!;
  String get issues => _localizedValues[locale.languageCode]!['issues']!;
  String get features => _localizedValues[locale.languageCode]!['features']!;
  String get searchByEmail => _localizedValues[locale.languageCode]!['searchByEmail']!;
  String get noUsersMatch => _localizedValues[locale.languageCode]!['noUsersMatch']!;
  String get noUsersFound => _localizedValues[locale.languageCode]!['noUsersFound']!;
  String get verified => _localizedValues[locale.languageCode]!['verified']!;
  String get unverified => _localizedValues[locale.languageCode]!['unverified']!;
  String get joined => _localizedValues[locale.languageCode]!['joined']!;
  String get scanCount => _localizedValues[locale.languageCode]!['scanCount']!;
  String get scansCount => _localizedValues[locale.languageCode]!['scansCount']!;
  String get adminLabel => _localizedValues[locale.languageCode]!['adminLabel']!;
  String get userLabel => _localizedValues[locale.languageCode]!['userLabel']!;
  String get suspendAccount => _localizedValues[locale.languageCode]!['suspendAccount']!;
  String get suspendWarning => _localizedValues[locale.languageCode]!['suspendWarning']!;
  String get reasonOptional => _localizedValues[locale.languageCode]!['reasonOptional']!;
  String get reasonHint => _localizedValues[locale.languageCode]!['reasonHint']!;
  String get suspend => _localizedValues[locale.languageCode]!['suspend']!;
  String get reactivateAccount => _localizedValues[locale.languageCode]!['reactivateAccount']!;
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

  // Admin Feedback Screen
  String get failedToLoadFeedback => _localizedValues[locale.languageCode]!['failedToLoadFeedback']!;
  String get couldNotLoadFeedback => _localizedValues[locale.languageCode]!['couldNotLoadFeedback']!;
  String get userFeedback => _localizedValues[locale.languageCode]!['userFeedback']!;
  String get searchFeedbackOrUser => _localizedValues[locale.languageCode]!['searchFeedbackOrUser']!;
  String get allStatuses => _localizedValues[locale.languageCode]!['allStatuses']!;
  String get reviewed => _localizedValues[locale.languageCode]!['reviewed']!;
  String get resolved => _localizedValues[locale.languageCode]!['resolved']!;
  String get statusLabel => _localizedValues[locale.languageCode]!['statusLabel']!;
  String get allCategories => _localizedValues[locale.languageCode]!['allCategories']!;
  String get categoryLabel => _localizedValues[locale.languageCode]!['categoryLabel']!;
  String get noFeedbackInSupabase => _localizedValues[locale.languageCode]!['noFeedbackInSupabase']!;
  String get noFeedbackMatchesFilters => _localizedValues[locale.languageCode]!['noFeedbackMatchesFilters']!;
  String get deleteFeedbackPrompt => _localizedValues[locale.languageCode]!['deleteFeedbackPrompt']!;
  String get deleteFeedbackDesc => _localizedValues[locale.languageCode]!['deleteFeedbackDesc']!;
  String get deleteBtn => _localizedValues[locale.languageCode]!['deleteBtn']!;
  String get feedbackRemoved => _localizedValues[locale.languageCode]!['feedbackRemoved']!;
  String get couldNotDeleteFeedback => _localizedValues[locale.languageCode]!['couldNotDeleteFeedback']!;
  String get statusUpdated => _localizedValues[locale.languageCode]!['statusUpdated']!;
  String get failedToUpdateStatus => _localizedValues[locale.languageCode]!['failedToUpdateStatus']!;
  String get markReviewed => _localizedValues[locale.languageCode]!['markReviewed']!;
  String get markResolved => _localizedValues[locale.languageCode]!['markResolved']!;
  String get markPending => _localizedValues[locale.languageCode]!['markPending']!;
  String get showMore => _localizedValues[locale.languageCode]!['showMore']!;
  String get suggestion => _localizedValues[locale.languageCode]!['suggestion']!;
  String get anonymous => _localizedValues[locale.languageCode]!['anonymous']!;
  String get userText => _localizedValues[locale.languageCode]!['userText']!;

  // Batch 3
  String get unauthorizedAccess => _localizedValues[locale.languageCode]!['unauthorizedAccess']!;
  String get whatPlant => _localizedValues[locale.languageCode]!['whatPlant']!;
  String get tapCameraToStart => _localizedValues[locale.languageCode]!['tapCameraToStart']!;
  String get seeAll => _localizedValues[locale.languageCode]!['seeAll']!;
  String get noDohPlantsLoaded => _localizedValues[locale.languageCode]!['noDohPlantsLoaded']!;
  String searchPlantsCount(int count) => _localizedValues[locale.languageCode]!['searchPlantsCount']!.replaceAll('{count}', count.toString());
  String showingPlants(int count) => _localizedValues[locale.languageCode]!['showingPlants']!.replaceAll('{count}', count.toString());
  String get medical => _localizedValues[locale.languageCode]!['medical']!;
  String get listView => _localizedValues[locale.languageCode]!['listView']!;
  String get gridView => _localizedValues[locale.languageCode]!['gridView']!;
"""

    # Insert getters before "static final Map<String, Map<String, String>> _localizedValues ="
    content = content.replace("  static final Map<String, Map<String, String>> _localizedValues =", getters + "\n  static final Map<String, Map<String, String>> _localizedValues =")

    # The english keys
    en_keys = """      'makeAdmin': 'Make admin',
      'removeAdmin': 'Remove admin',
      'userNowAdmin': 'User is now an administrator.',
      'adminRemoved': 'Admin role removed.',
      'forceVerifyEmail': 'Force activate email',
      'emailVerified': 'Email verified. User can sign in without OTP.',
      'forceVerifyNotAvailable': 'Force verify is not available. Deploy the force-verify-user Edge Function.',
      'adminConsole': 'Admin Console',
      'elevatedPrivilegesActive': 'Elevated Privileges Active',
      'adminRole': 'Admin',
      'signOut': 'Sign Out',
      'exitAdminConsole': 'Exit Admin Console',
      'overview': 'Overview',
      'plantCatalog': 'Plant Catalog',
      'healthConditions': 'Health Conditions',
      'userDirectory': 'User Directory',
      'systemHealth': 'System Health',
      'feedbackMenu': 'Feedback',
      'submissions': 'Submissions',
      'appConfig': 'App Config',
      'selectAModule': 'Select a module',
      'dataDeletionRequests': 'Data Deletion Requests',
      'submissionTriage': 'Submission Triage',
      'pending': 'Pending',
      'inboxZero': 'Inbox Zero. All submissions reviewed.',
      'noDeletionRequests': 'No deletion requests.',
      'unknown': 'Unknown',
      'unknownPlant': 'Unknown Plant',
      'trainingEligible': 'Training eligible',
      'reject': 'Reject',
      'approve': 'Approve',
      'remove': 'Remove',
      'fullResolutionPinchToZoom': 'Full resolution – pinch to zoom',
      'deleteSubmission': 'Delete submission?',
      'deleteSubmissionBody': 'This will remove the scan from the database and storage. It cannot be undone.',
      'deleteRequest': 'Delete request?',
      'deleteRequestBody': 'Remove this deletion request from the database.',
      'imageAddedToTraining': 'Image added to training dataset for ',
      'storageCopyFailed': 'Storage copy failed — scan approved but not in training-datasets',
      'accessDeniedAdminOnly': 'Access denied. Admin only.',
      'backToSubmissions': 'Back to Submissions',
      'refresh': 'Refresh',
      'mobilenetV2MedicinalPlants': 'MobileNet V2 · Philippine medicinal plants',
      'webLiveModelCloud': 'Web Live Model (Cloud)',
      'liveModelSupabase': 'Live Model (Supabase)',
      'bundledAssetModel': 'Bundled Asset Model',
      'webAdminRunsLiveCloud': 'Web Admin runs on the live cloud model.',
      'versionLabel': 'Version:',
      'noOtaModelDownloaded': 'No OTA model downloaded yet',
      'otaModelUpdatesWebCloud': 'OTA model updates are applied directly to mobile devices. Web Admin runs on the live cloud model.',
      'checkingForModelUpdate': 'Checking for model update…',
      'checkNow': 'Check now',
      'localDeviceAnalytics': 'Local Device Analytics',
      'totalScans': 'Total Scans',
      'successful': 'Successful',
      'successRate': 'Success Rate',
      'avgResponse': 'Avg Response',
      'errorLogs': 'Error Logs',
      'filterAll': 'All',
      'filterCamera': 'Camera',
      'filterAI': 'AI',
      'filterDatabase': 'Database',
      'filterNetwork': 'Network',
      'systemStable0Errors': 'System stable. 0 errors recorded in this timeframe.',
      'noErrorsInLog': 'No errors in the last log entries.',
      'showLess': 'Show less',
      'showAllErrors': 'Show all errors',
      'stackTrace': 'Stack Trace',
      'errorContext': 'Context',
      'noAdditionalDetails': 'No additional details.',
      'export': 'Export',
      'exportStatsErrors': 'Export stats and errors for analysis',
      'exportAll': 'Export All',
      'exportErrorLogs': 'Export Error Logs',
      'clearAll': 'Clear All',
      'exportAllData': 'Export All Data',
      'errorLogEntries': 'error log entries',
      'performanceUsageErrorLogs': 'Performance · Usage · Error logs',
      'format': 'FORMAT',
      'appConfiguration': 'App Configuration',
      'appConfigDesc': 'Edit app version, model version, and help content.',
      'reloadFromServer': 'Reload from server',
      'saving': 'Saving…',
      'failedToLoadConfig': 'Failed to load configuration',
      'appVersionLabel': 'App Version',
      'appVersionDesc': 'Displayed in Settings → Support & About. Update when a new APK is released.',
      'modelVersionLabel': 'Model Version',
      'modelVersionDesc': 'Displayed in Settings → Support & About. Update after each model retraining.',
      'helpTutorialContent': 'Help & Tutorial Content',
      'oodExplanation': 'Out-of-Distribution (OOD) Explanation',
      'saveConfiguration': 'Save Configuration',
      'add': 'Add',
      'noItemsAdded': 'No items added.',
      'configSavedSuccess': 'Configuration saved successfully.',
      'failedToSave': 'Failed to save',
      'tips': 'Tips',
      'issues': 'Issues',
      'features': 'Features',
      'searchByEmail': 'Search by email…',
      'noUsersMatch': 'No users match your search.',
      'noUsersFound': 'No users found.',
      'verified': 'Verified',
      'unverified': 'Unverified',
      'joined': 'Joined',
      'scanCount': 'Scan',
      'scansCount': 'Scans',
      'adminLabel': 'ADMIN',
      'userLabel': 'USER',
      'suspendAccount': 'Suspend Account',
      'suspendWarning': 'They will not be able to sign in.',
      'reasonOptional': 'Reason (optional)',
      'reasonHint': 'e.g. Violated terms of service',
      'suspend': 'Suspend',
      'reactivateAccount': 'Reactivate Account',
      'makeAdminPrompt': 'Make admin?',
      'removeAdminPrompt': 'Remove admin?',
      'makeAdminDesc': 'They will be able to access the admin dashboard and manage users and catalog.',
      'removeAdminDesc': 'They will no longer have admin access.',
      'deleteUserDataPrompt': 'Delete user data?',
      'deleteUserDataDesc': 'This will permanently delete the user and all their cloud scans. It cannot be undone.',
      'typeDeleteToConfirm': 'Type DELETE to confirm:',
      'deleteUserDataBtn': 'Delete User Data',
      'deletingAccount': 'Deleting account…',
      'removingAccountData': 'Removing account and associated data.',
      'failedToLoadFeedback': 'Failed to load feedback',
      'couldNotLoadFeedback': 'Could not load feedback.',
      'userFeedback': 'User Feedback',
      'searchFeedbackOrUser': 'Search feedback or User ID...',
      'allStatuses': 'All Statuses',
      'reviewed': 'Reviewed',
      'resolved': 'Resolved',
      'statusLabel': 'Status',
      'allCategories': 'All Categories',
      'categoryLabel': 'Category',
      'noFeedbackInSupabase': 'No feedback in Supabase yet.',
      'noFeedbackMatchesFilters': 'No feedback matches your filters.',
      'deleteFeedbackPrompt': 'Delete feedback',
      'deleteFeedbackDesc': 'Are you sure you want to remove this feedback? This cannot be undone.',
      'deleteBtn': 'Delete',
      'feedbackRemoved': 'Feedback removed',
      'couldNotDeleteFeedback': 'Could not delete feedback',
      'statusUpdated': 'Status updated to',
      'failedToUpdateStatus': 'Failed to update status',
      'markReviewed': 'Mark Reviewed',
      'markResolved': 'Mark Resolved',
      'markPending': 'Mark Pending',
      'showMore': 'Show more',
      'suggestion': 'Suggestion',
      'anonymous': 'Anonymous',
      'userText': 'User',
      'unauthorizedAccess': 'Unauthorized access.',
      'whatPlant': 'What plant are you identifying?',
      'tapCameraToStart': 'Tap the camera button below to start.',
      'seeAll': 'See All',
      'noDohPlantsLoaded': 'No DOH approved plants loaded.',
      'searchPlantsCount': 'Search {count} Plants',
      'showingPlants': 'Showing {count} Plants',
      'medical': 'Medical',
      'listView': 'List View',
      'gridView': 'Grid View',
"""
    content = content.replace("    'fil': {", en_keys + "    },\n    'fil': {")

    fil_keys = """      'makeAdmin': 'Gawing admin',
      'removeAdmin': 'Alisin ang admin',
      'userNowAdmin': 'Ang user ay administrator na.',
      'adminRemoved': 'Naalis na ang admin role.',
      'forceVerifyEmail': 'Pilitin i-activate ang email',
      'emailVerified': 'Na-verify na ang email. Maaari nang mag-sign in ang user nang walang OTP.',
      'forceVerifyNotAvailable': 'Hindi available ang force verify. I-deploy ang force-verify-user Edge Function.',
      'adminConsole': 'Admin Console',
      'elevatedPrivilegesActive': 'Aktibo ang Matataas na Pribilehiyo',
      'adminRole': 'Admin',
      'signOut': 'Mag-sign Out',
      'exitAdminConsole': 'Lumabas sa Admin Console',
      'overview': 'Pangkalahatang-ideya',
      'plantCatalog': 'Katalogo ng Halaman',
      'healthConditions': 'Mga Kondisyon sa Kalusugan',
      'userDirectory': 'Direktoryo ng User',
      'systemHealth': 'Kalusugan ng Sistema',
      'feedbackMenu': 'Feedback',
      'submissions': 'Mga Pagsusumite',
      'appConfig': 'App Config',
      'selectAModule': 'Pumili ng module',
      'dataDeletionRequests': 'Mga Kahilingan sa Pagtanggal ng Data',
      'submissionTriage': 'Pagsusuri ng mga Pagsusumite',
      'pending': 'Nakabinbin',
      'inboxZero': 'Wala nang Laman. Nasuri na ang lahat ng pagsusumite.',
      'noDeletionRequests': 'Walang kahilingan sa pagtanggal.',
      'unknown': 'Hindi kilala',
      'unknownPlant': 'Hindi Kilalang Halaman',
      'trainingEligible': 'Pwedeng isama sa training',
      'reject': 'Tanggihan',
      'approve': 'Aprubahan',
      'remove': 'Alisin',
      'fullResolutionPinchToZoom': 'Buong resolusyon – kurutin para mag-zoom',
      'deleteSubmission': 'Tanggalin ang pagsusumite?',
      'deleteSubmissionBody': 'Aalisin nito ang scan mula sa database at storage. Hindi na ito mababawi.',
      'deleteRequest': 'Tanggalin ang kahilingan?',
      'deleteRequestBody': 'Alisin ang kahilingang pagtanggal na ito mula sa database.',
      'imageAddedToTraining': 'Idinagdag ang larawan sa training dataset para sa ',
      'storageCopyFailed': 'Nabigo ang storage copy — naaprubahan ang scan ngunit wala sa training-datasets',
      'accessDeniedAdminOnly': 'Access denied. Para sa admin lamang.',
      'backToSubmissions': 'Bumalik sa Mga Pagsusumite',
      'refresh': 'I-refresh',
      'mobilenetV2MedicinalPlants': 'MobileNet V2 · Mga halamang gamot ng Pilipinas',
      'webLiveModelCloud': 'Web Live Model (Cloud)',
      'liveModelSupabase': 'Live Model (Supabase)',
      'bundledAssetModel': 'Bundled Asset Model',
      'webAdminRunsLiveCloud': 'Gumagana ang Web Admin sa live cloud model.',
      'versionLabel': 'Bersyon:',
      'noOtaModelDownloaded': 'Wala pang nai-download na OTA model',
      'otaModelUpdatesWebCloud': 'Ang mga OTA model updates ay ina-apply nang direkta sa mga mobile device. Gumagana ang Web Admin sa live cloud model.',
      'checkingForModelUpdate': 'Sinusuri ang model update…',
      'checkNow': 'Suriin ngayon',
      'localDeviceAnalytics': 'Lokal na Analytics ng Device',
      'totalScans': 'Kabuuan ng Scans',
      'successful': 'Matagumpay',
      'successRate': 'Antas ng Tagumpay',
      'avgResponse': 'Average na Tugon',
      'errorLogs': 'Mga Log ng Error',
      'filterAll': 'Lahat',
      'filterCamera': 'Camera',
      'filterAI': 'AI',
      'filterDatabase': 'Database',
      'filterNetwork': 'Network',
      'systemStable0Errors': 'Matatag ang sistema. 0 error ang naitala sa timeframe na ito.',
      'noErrorsInLog': 'Walang error sa mga huling log entries.',
      'showLess': 'Magpakita ng mas kaunti',
      'showAllErrors': 'Ipakita lahat ng error',
      'stackTrace': 'Stack Trace',
      'errorContext': 'Konteksto',
      'noAdditionalDetails': 'Walang karagdagang detalye.',
      'export': 'I-export',
      'exportStatsErrors': 'I-export ang mga istatistika at error',
      'exportAll': 'I-export Lahat',
      'exportErrorLogs': 'I-export ang Error Logs',
      'clearAll': 'Burahin Lahat',
      'exportAllData': 'I-export ang Lahat ng Data',
      'errorLogEntries': 'mga entry sa error log',
      'performanceUsageErrorLogs': 'Pagganap · Paggamit · Mga log ng error',
      'format': 'PORMAT',
      'appConfiguration': 'App Configuration',
      'appConfigDesc': 'I-edit ang bersyon ng app, bersyon ng model, at tulong.',
      'reloadFromServer': 'I-reload mula sa server',
      'saving': 'Nagse-save…',
      'failedToLoadConfig': 'Nabigong i-load ang configuration',
      'appVersionLabel': 'Bersyon ng App',
      'appVersionDesc': 'Ipinapakita sa Settings → Support & About. I-update kapag may bagong APK.',
      'modelVersionLabel': 'Bersyon ng Model',
      'modelVersionDesc': 'Ipinapakita sa Settings → Support & About. I-update pagkatapos ng bawat retraining.',
      'helpTutorialContent': 'Tulong at Nilalaman ng Tutorial',
      'oodExplanation': 'Paliwanag sa Out-of-Distribution (OOD)',
      'saveConfiguration': 'I-save ang Configuration',
      'add': 'Magdagdag',
      'noItemsAdded': 'Walang naidagdag na item.',
      'configSavedSuccess': 'Matagumpay na nai-save ang configuration.',
      'failedToSave': 'Nabigong i-save',
      'tips': 'Mga Tip',
      'issues': 'Mga Isyu',
      'features': 'Mga Feature',
      'searchByEmail': 'Maghanap ayon sa email…',
      'noUsersMatch': 'Walang mga user na tumutugma sa iyong paghahanap.',
      'noUsersFound': 'Walang nahanap na mga user.',
      'verified': 'Na-verify',
      'unverified': 'Hindi na-verify',
      'joined': 'Sumali',
      'scanCount': 'Scan',
      'scansCount': 'Scans',
      'adminLabel': 'ADMIN',
      'userLabel': 'USER',
      'suspendAccount': 'I-suspend ang Account',
      'suspendWarning': 'Hindi sila makakapag-sign in.',
      'reasonOptional': 'Dahilan (opsyonal)',
      'reasonHint': 'hal. Lumabag sa terms of service',
      'suspend': 'I-suspend',
      'reactivateAccount': 'I-reactivate ang Account',
      'makeAdminPrompt': 'Gawing admin?',
      'removeAdminPrompt': 'Alisin ang admin?',
      'makeAdminDesc': 'Magkakaroon sila ng access sa admin dashboard at pamamahala ng users at catalog.',
      'removeAdminDesc': 'Mawawalan sila ng admin access.',
      'deleteUserDataPrompt': 'Tanggalin ang data ng user?',
      'deleteUserDataDesc': 'Permanenteng tatanggalin nito ang user at ang kanilang cloud scans. Hindi ito mababawi.',
      'typeDeleteToConfirm': 'I-type ang DELETE para kumpirmahin:',
      'deleteUserDataBtn': 'Tanggalin ang Data ng User',
      'deletingAccount': 'Tinatanggal ang account…',
      'removingAccountData': 'Inaalis ang account at kaugnay na data.',
      'failedToLoadFeedback': 'Nabigong i-load ang feedback',
      'couldNotLoadFeedback': 'Hindi ma-load ang feedback.',
      'userFeedback': 'Feedback ng User',
      'searchFeedbackOrUser': 'Maghanap ng feedback o User ID...',
      'allStatuses': 'Lahat ng Status',
      'reviewed': 'Nasuri',
      'resolved': 'Naresolba',
      'statusLabel': 'Status',
      'allCategories': 'Lahat ng Kategorya',
      'categoryLabel': 'Kategorya',
      'noFeedbackInSupabase': 'Wala pang feedback sa Supabase.',
      'noFeedbackMatchesFilters': 'Walang feedback na tumutugma sa iyong mga filter.',
      'deleteFeedbackPrompt': 'Tanggalin ang feedback',
      'deleteFeedbackDesc': 'Sigurado ka bang gusto mong tanggalin ang feedback na ito? Hindi na ito mababawi.',
      'deleteBtn': 'Tanggalin',
      'feedbackRemoved': 'Na-alis ang feedback',
      'couldNotDeleteFeedback': 'Hindi maalis ang feedback',
      'statusUpdated': 'Na-update ang status sa',
      'failedToUpdateStatus': 'Nabigong i-update ang status',
      'markReviewed': 'Markahan bilang Nasuri',
      'markResolved': 'Markahan bilang Naresolba',
      'markPending': 'Markahan bilang Nakabinbin',
      'showMore': 'Magpakita ng higit pa',
      'suggestion': 'Mungkahi',
      'anonymous': 'Hindi Kilala',
      'userText': 'User',
      'unauthorizedAccess': 'Hindi pinahihintulutang pag-access.',
      'whatPlant': 'Anong halaman ang iyong kinikilala?',
      'tapCameraToStart': 'Pindutin ang camera button sa ibaba para magsimula.',
      'seeAll': 'Tingnan Lahat',
      'noDohPlantsLoaded': 'Walang nai-load na halamang aprubado ng DOH.',
      'searchPlantsCount': 'Maghanap sa {count} Halaman',
      'showingPlants': 'Ipinapakita ang {count} Halaman',
      'medical': 'Medikal',
      'listView': 'Tingnan bilang Listahan',
      'gridView': 'Tingnan bilang Grid',
"""
    content = content.replace("  };\n}", fil_keys + "  };\n}")

    with open(r'D:\Lenovo2\Code\This_is_IT\RE-HerbaScan\lib\core\localization\app_localizations.dart', 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
