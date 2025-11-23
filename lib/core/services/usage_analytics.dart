import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for tracking app usage and user behavior analytics
class UsageAnalytics {
  static const String _analyticsKey = 'usage_analytics';
  static final UsageAnalytics _instance = UsageAnalytics._internal();

  factory UsageAnalytics() => _instance;
  UsageAnalytics._internal();

  // Counters
  int _totalScans = 0;
  int _successfulScans = 0;
  int _failedScans = 0;
  int _poorQualityScans = 0;
  int _noMatchScans = 0;
  int _plantsViewed = 0;
  int _preparationsViewed = 0;
  int _historyViewed = 0;
  int _browseViewed = 0;
  int _dohScreenViewed = 0;
  int _helpViewed = 0;

  // Plant-specific analytics
  final Map<String, int> _plantScans = {};
  final Map<String, int> _conditionSearches = {};

  DateTime? _firstLaunch;
  DateTime? _lastActive;

  /// Initialize analytics from storage
  Future<void> initialize() async {
    await _loadAnalytics();
  }

  /// Load analytics from persistent storage
  Future<void> _loadAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_analyticsKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;

        _totalScans = data['total_scans'] ?? 0;
        _successfulScans = data['successful_scans'] ?? 0;
        _failedScans = data['failed_scans'] ?? 0;
        _poorQualityScans = data['poor_quality_scans'] ?? 0;
        _noMatchScans = data['no_match_scans'] ?? 0;
        _plantsViewed = data['plants_viewed'] ?? 0;
        _preparationsViewed = data['preparations_viewed'] ?? 0;
        _historyViewed = data['history_viewed'] ?? 0;
        _browseViewed = data['browse_viewed'] ?? 0;
        _dohScreenViewed = data['doh_screen_viewed'] ?? 0;
        _helpViewed = data['help_viewed'] ?? 0;

        _plantScans.clear();
        _plantScans.addAll(Map<String, int>.from(data['plant_scans'] ?? {}));

        _conditionSearches.clear();
        _conditionSearches
            .addAll(Map<String, int>.from(data['condition_searches'] ?? {}));

        if (data['first_launch'] != null) {
          _firstLaunch = DateTime.parse(data['first_launch']);
        }
        if (data['last_active'] != null) {
          _lastActive = DateTime.parse(data['last_active']);
        }
      }
    } catch (e) {
      print('Error loading analytics: $e');
    }
  }

  /// Save analytics to persistent storage
  Future<void> _saveAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = {
        'total_scans': _totalScans,
        'successful_scans': _successfulScans,
        'failed_scans': _failedScans,
        'poor_quality_scans': _poorQualityScans,
        'no_match_scans': _noMatchScans,
        'plants_viewed': _plantsViewed,
        'preparations_viewed': _preparationsViewed,
        'history_viewed': _historyViewed,
        'browse_viewed': _browseViewed,
        'doh_screen_viewed': _dohScreenViewed,
        'help_viewed': _helpViewed,
        'plant_scans': _plantScans,
        'condition_searches': _conditionSearches,
        'first_launch': _firstLaunch?.toIso8601String(),
        'last_active': _lastActive?.toIso8601String(),
      };

      await prefs.setString(_analyticsKey, jsonEncode(data));
    } catch (e) {
      print('Error saving analytics: $e');
    }
  }

  // Event tracking methods

  Future<void> trackScanAttempt() async {
    _totalScans++;
    await _saveAnalytics();
  }

  Future<void> trackSuccessfulScan(String plantName) async {
    _successfulScans++;
    _plantScans[plantName] = (_plantScans[plantName] ?? 0) + 1;
    await _saveAnalytics();
  }

  Future<void> trackFailedScan() async {
    _failedScans++;
    await _saveAnalytics();
  }

  Future<void> trackPoorQualityScan() async {
    _poorQualityScans++;
    await _saveAnalytics();
  }

  Future<void> trackNoMatchScan() async {
    _noMatchScans++;
    await _saveAnalytics();
  }

  Future<void> trackPlantViewed() async {
    _plantsViewed++;
    await _saveAnalytics();
  }

  Future<void> trackPreparationViewed() async {
    _preparationsViewed++;
    await _saveAnalytics();
  }

  Future<void> trackHistoryViewed() async {
    _historyViewed++;
    await _saveAnalytics();
  }

  Future<void> trackBrowseViewed() async {
    _browseViewed++;
    await _saveAnalytics();
  }

  Future<void> trackDOHScreenViewed() async {
    _dohScreenViewed++;
    await _saveAnalytics();
  }

  Future<void> trackHelpViewed() async {
    _helpViewed++;
    await _saveAnalytics();
  }

  Future<void> trackConditionSearch(String condition) async {
    _conditionSearches[condition] = (_conditionSearches[condition] ?? 0) + 1;
    await _saveAnalytics();
  }

  Future<void> trackAppLaunch() async {
    _firstLaunch ??= DateTime.now();
    _lastActive = DateTime.now();
    await _saveAnalytics();
  }

  // Analytics getters

  int get totalScans => _totalScans;
  int get successfulScans => _successfulScans;
  int get failedScans => _failedScans;
  int get poorQualityScans => _poorQualityScans;
  int get noMatchScans => _noMatchScans;
  int get plantsViewed => _plantsViewed;
  int get preparationsViewed => _preparationsViewed;
  int get historyViewed => _historyViewed;
  int get browseViewed => _browseViewed;
  int get dohScreenViewed => _dohScreenViewed;
  int get helpViewed => _helpViewed;

  DateTime? get firstLaunch => _firstLaunch;
  DateTime? get lastActive => _lastActive;

  double get scanSuccessRate {
    if (_totalScans == 0) return 0.0;
    return (_successfulScans / _totalScans) * 100;
  }

  /// Get statistics summary
  Map<String, dynamic> getStatistics() {
    return {
      'total_scans': _totalScans,
      'successful_scans': _successfulScans,
      'failed_scans': _failedScans,
      'poor_quality_scans': _poorQualityScans,
      'no_match_scans': _noMatchScans,
      'success_rate': '${scanSuccessRate.toStringAsFixed(1)}%',
      'plants_viewed': _plantsViewed,
      'preparations_viewed': _preparationsViewed,
      'history_viewed': _historyViewed,
      'browse_viewed': _browseViewed,
      'doh_screen_viewed': _dohScreenViewed,
      'help_viewed': _helpViewed,
      'first_launch': _firstLaunch?.toIso8601String(),
      'last_active': _lastActive?.toIso8601String(),
      'days_since_install': _firstLaunch != null
          ? DateTime.now().difference(_firstLaunch!).inDays
          : 0,
    };
  }

  /// Get most scanned plants
  List<MapEntry<String, int>> getMostScannedPlants({int limit = 5}) {
    final entries = _plantScans.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Get most searched conditions
  List<MapEntry<String, int>> getMostSearchedConditions({int limit = 5}) {
    final entries = _conditionSearches.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Export analytics for thesis data collection
  Future<String> exportAnalyticsAsJson() async {
    final stats = getStatistics();
    final mostScanned = getMostScannedPlants(limit: 10);
    final mostSearched = getMostSearchedConditions(limit: 10);

    final export = {
      'export_date': DateTime.now().toIso8601String(),
      'summary': stats,
      'most_scanned_plants': Map.fromEntries(mostScanned),
      'most_searched_conditions': Map.fromEntries(mostSearched),
      'raw_plant_scans': _plantScans,
      'raw_condition_searches': _conditionSearches,
    };

    return jsonEncode(export);
  }

  /// Clear all analytics (for testing)
  Future<void> clearAnalytics() async {
    _totalScans = 0;
    _successfulScans = 0;
    _failedScans = 0;
    _poorQualityScans = 0;
    _noMatchScans = 0;
    _plantsViewed = 0;
    _preparationsViewed = 0;
    _historyViewed = 0;
    _browseViewed = 0;
    _dohScreenViewed = 0;
    _helpViewed = 0;
    _plantScans.clear();
    _conditionSearches.clear();
    _firstLaunch = null;
    _lastActive = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_analyticsKey);
  }
}
