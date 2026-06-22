import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:herbascan/core/services/app_config_service.dart';

class AppProvider extends ChangeNotifier {
  bool _isFirstLaunch = true;
  bool _isOfflineMode = false;
  bool _showConfidenceScores = true;
  bool _showTop3Results = true; // Default to true (ON)
  bool _autoSaveScans = true; // Default ON: auto-save new scans to device history
  bool _isDarkMode = false;
  String _appVersion = 'v1.0.30';
  String _modelVersion = 'CNN v1.0';
  String _helpContent = '';
  bool _isThemeChanging = false;

  // Getters
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isOfflineMode => _isOfflineMode;
  bool get showConfidenceScores => _showConfidenceScores;
  bool get showTop3Results => _showTop3Results;
  bool get autoSaveScans => _autoSaveScans;
  bool get isDarkMode => _isDarkMode;
  String get appVersion => _appVersion;
  String get modelVersion => _modelVersion;
  String get helpContent => _helpContent;

  AppProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
      _isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
      // Check new keys first, fallback to old keys for backward compatibility
      _showConfidenceScores = prefs.getBool('show_confidence') ??
          prefs.getBool('showConfidenceScores') ??
          true;
      _showTop3Results = prefs.getBool('show_top3') ??
          prefs.getBool('showTop3Results') ??
          true; // Default to true (ON)
      _autoSaveScans = prefs.getBool('auto_save_scans') ?? true;
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;

      // Use a microtask to ensure smooth UI updates
      Future.microtask(() {
        notifyListeners();
      });
    } catch (e) {
      // Handle error silently and use defaults
      print('Error loading settings: $e');
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool('isFirstLaunch', _isFirstLaunch),
        prefs.setBool('isOfflineMode', _isOfflineMode),
        prefs.setBool('showConfidenceScores', _showConfidenceScores),
        prefs.setBool('showTop3Results', _showTop3Results),
        prefs.setBool('auto_save_scans', _autoSaveScans),
        prefs.setBool('isDarkMode', _isDarkMode),
      ]);
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  // Set first launch completed
  Future<void> setFirstLaunchCompleted() async {
    _isFirstLaunch = false;
    await _saveSettings();
    notifyListeners();
  }

  // Toggle offline mode
  Future<void> toggleOfflineMode() async {
    _isOfflineMode = !_isOfflineMode;
    await _saveSettings();
    notifyListeners();
  }

  /// Sync offline mode from SharedPreferences (e.g. after OfflineProvider toggles it).
  /// Keeps AppProvider in sync when OfflineProvider is the source of truth for the toggle.
  Future<void> syncOfflineModeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool('isOfflineMode') ?? false;
      if (_isOfflineMode != stored) {
        _isOfflineMode = stored;
        notifyListeners();
      }
    } catch (e) {
      print('Error syncing offline mode from prefs: $e');
    }
  }

  // Toggle confidence scores display
  Future<void> toggleConfidenceScores() async {
    _showConfidenceScores = !_showConfidenceScores;
    await _saveSettings();
    notifyListeners();
  }

  // Toggle top 3 results display
  Future<void> toggleTop3Results() async {
    _showTop3Results = !_showTop3Results;
    await _saveSettings();
    notifyListeners();
  }

  /// Toggle auto-save scans to device history when result screen opens.
  Future<void> toggleAutoSaveScans() async {
    _autoSaveScans = !_autoSaveScans;
    await _saveSettings();
    notifyListeners();
  }

  // Toggle dark mode — update UI immediately, persist in background to avoid lag
  Future<void> toggleDarkMode() async {
    if (_isThemeChanging) return; // Prevent rapid toggling

    _isThemeChanging = true;
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // Theme updates immediately (no wait for disk)
    _isThemeChanging = false;

    _saveSettings(); // Persist in background (unawaited)
  }

  // Get app statistics
  Map<String, dynamic> getAppStats() {
    return {
      'appVersion': _appVersion,
      'modelVersion': _modelVersion,
      'isOfflineMode': _isOfflineMode,
      'features': {
        'confidenceScores': _showConfidenceScores,
        'top3Results': _showTop3Results,
      },
    };
  }

  /// Load remote configuration from Supabase `app_config` table.
  /// Updates app version, model version, and help content on success.
  /// Falls back to compile-time defaults when Supabase is unreachable.
  Future<void> loadRemoteConfig() async {
    try {
      final config = await AppConfigService().fetchAll();
      if (config.isNotEmpty) {
        _appVersion = config['app_version'] ?? _appVersion;
        _modelVersion = config['model_version'] ?? _modelVersion;
        _helpContent = config['help_content'] ?? _helpContent;
        notifyListeners();
      }
    } catch (e) {
      // Fall back to defaults — remote config is optional
      if (kDebugMode) {
        debugPrint('AppProvider.loadRemoteConfig: $e');
      }
    }
  }
}
