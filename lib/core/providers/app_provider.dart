import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  bool _isFirstLaunch = true;
  bool _isOfflineMode = false;
  bool _showConfidenceScores = true;
  bool _showGradCAM = true;
  bool _showTop3Results = true; // Default to true (ON)
  bool _isDarkMode = false;
  final String _appVersion = 'v0.9.3';
  final String _modelVersion = 'CNN v1.0';
  bool _isThemeChanging = false;

  // Getters
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isOfflineMode => _isOfflineMode;
  bool get showConfidenceScores => _showConfidenceScores;
  bool get showGradCAM => _showGradCAM;
  bool get showTop3Results => _showTop3Results;
  bool get isDarkMode => _isDarkMode;
  String get appVersion => _appVersion;
  String get modelVersion => _modelVersion;

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
      _showGradCAM =
          prefs.getBool('show_gradcam') ?? prefs.getBool('showGradCAM') ?? true;
      _showTop3Results = prefs.getBool('show_top3') ??
          prefs.getBool('showTop3Results') ??
          true; // Default to true (ON)
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
        prefs.setBool('showGradCAM', _showGradCAM),
        prefs.setBool('showTop3Results', _showTop3Results),
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

  // Toggle GradCAM visualization
  Future<void> toggleGradCAM() async {
    _showGradCAM = !_showGradCAM;
    await _saveSettings();
    notifyListeners();
  }

  // Toggle top 3 results display
  Future<void> toggleTop3Results() async {
    _showTop3Results = !_showTop3Results;
    await _saveSettings();
    notifyListeners();
  }

  // Toggle dark mode
  Future<void> toggleDarkMode() async {
    if (_isThemeChanging) return; // Prevent rapid toggling

    _isThemeChanging = true;
    _isDarkMode = !_isDarkMode;
    await _saveSettings();

    // Use a post-frame callback to ensure smooth theme transitions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
      _isThemeChanging = false;
    });
  }

  // Get app statistics
  Map<String, dynamic> getAppStats() {
    return {
      'appVersion': _appVersion,
      'modelVersion': _modelVersion,
      'isOfflineMode': _isOfflineMode,
      'features': {
        'confidenceScores': _showConfidenceScores,
        'gradCAM': _showGradCAM,
        'top3Results': _showTop3Results,
      },
    };
  }
}
