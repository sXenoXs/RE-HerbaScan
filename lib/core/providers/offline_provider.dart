// lib/core/providers/offline_provider.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:herbascan/core/services/offline_service.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/models/plant.dart';

class OfflineProvider extends ChangeNotifier {
  final OfflineService _offlineService = OfflineService();
  
  // State
  bool _isInitialized = false;
  bool _isOfflineMode = false;
  bool _isOnline = true;
  List<ScanResult> _pendingSyncResults = [];
  Map<String, dynamic> _offlineStats = {};
  String _lastError = '';

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOfflineMode => _isOfflineMode;
  bool get isOnline => _isOnline;
  List<ScanResult> get pendingSyncResults => List.from(_pendingSyncResults);
  Map<String, dynamic> get offlineStats => Map.from(_offlineStats);
  String get lastError => _lastError;
  bool get hasPendingSync => _pendingSyncResults.isNotEmpty;
  bool get isFullyOffline => _isOfflineMode || !_isOnline;

  OfflineProvider() {
    _initialize();
  }

  /// Initialize the offline provider
  Future<void> _initialize() async {
    try {
      _lastError = '';
      
      // Initialize offline service
      await _offlineService.initialize();
      
      // Set up listeners
      _offlineService.connectivityStream.listen(_onConnectivityChanged);
      _offlineService.pendingSyncStream.listen(_onPendingSyncChanged);
      
      // Load initial state
      await _loadInitialState();
      
      _isInitialized = true;
      notifyListeners();
      
      print('✅ Offline Provider initialized');
    } catch (e) {
      _lastError = 'Failed to initialize offline service: $e';
      print('❌ Error initializing Offline Provider: $e');
      notifyListeners();
    }
  }

  /// Load initial state from offline service
  Future<void> _loadInitialState() async {
    try {
      _isOfflineMode = _offlineService.isOfflineMode;
      _isOnline = _offlineService.isOnline;
      _pendingSyncResults = _offlineService.pendingSyncResults;
      _offlineStats = await _offlineService.getOfflineStats();
    } catch (e) {
      print('❌ Error loading initial state: $e');
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(bool isOnline) {
    _isOnline = isOnline;
    notifyListeners();
  }

  /// Handle pending sync changes
  void _onPendingSyncChanged(List<ScanResult> pendingResults) {
    _pendingSyncResults = pendingResults;
    notifyListeners();
  }

  /// Toggle offline mode
  Future<void> toggleOfflineMode() async {
    try {
      _lastError = '';
      await _offlineService.toggleOfflineMode();
      _isOfflineMode = _offlineService.isOfflineMode;
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to toggle offline mode: $e';
      print('❌ Error toggling offline mode: $e');
      notifyListeners();
    }
  }

  /// Process plant identification offline
  Future<List<Map<String, dynamic>>> processPlantOffline(Uint8List imageData) async {
    try {
      _lastError = '';
      final result = await _offlineService.processPlantOffline(imageData);
      return result;
    } catch (e) {
      _lastError = 'Failed to process plant offline: $e';
      print('❌ Error processing plant offline: $e');
      rethrow;
    }
  }

  /// Save scan result offline
  Future<void> saveScanResultOffline(ScanResult result) async {
    try {
      _lastError = '';
      await _offlineService.saveScanResultOffline(result);
      await _refreshOfflineStats();
    } catch (e) {
      _lastError = 'Failed to save scan result offline: $e';
      print('❌ Error saving scan result offline: $e');
      rethrow;
    }
  }

  /// Get offline scan history
  Future<List<ScanResult>> getOfflineScanHistory() async {
    try {
      _lastError = '';
      return await _offlineService.getOfflineScanHistory();
    } catch (e) {
      _lastError = 'Failed to get offline scan history: $e';
      print('❌ Error getting offline scan history: $e');
      return [];
    }
  }

  /// Get offline plants
  Future<List<Plant>> getOfflinePlants() async {
    try {
      _lastError = '';
      return await _offlineService.getOfflinePlants();
    } catch (e) {
      _lastError = 'Failed to get offline plants: $e';
      print('❌ Error getting offline plants: $e');
      return [];
    }
  }

  /// Get DOH approved plants offline
  Future<List<Plant>> getOfflineDOHPlants() async {
    try {
      _lastError = '';
      return await _offlineService.getOfflineDOHPlants();
    } catch (e) {
      _lastError = 'Failed to get offline DOH plants: $e';
      print('❌ Error getting offline DOH plants: $e');
      return [];
    }
  }

  /// Search plants offline
  Future<List<Plant>> searchPlantsOffline(String query) async {
    try {
      _lastError = '';
      return await _offlineService.searchPlantsOffline(query);
    } catch (e) {
      _lastError = 'Failed to search plants offline: $e';
      print('❌ Error searching plants offline: $e');
      return [];
    }
  }

  /// Refresh offline statistics
  Future<void> _refreshOfflineStats() async {
    try {
      _offlineStats = await _offlineService.getOfflineStats();
      notifyListeners();
    } catch (e) {
      print('❌ Error refreshing offline stats: $e');
    }
  }

  /// Refresh all offline data
  Future<void> refreshOfflineData() async {
    try {
      _lastError = '';
      await _loadInitialState();
      await _refreshOfflineStats();
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to refresh offline data: $e';
      print('❌ Error refreshing offline data: $e');
      notifyListeners();
    }
  }

  /// Clear all offline data
  Future<void> clearOfflineData() async {
    try {
      _lastError = '';
      await _offlineService.clearOfflineData();
      await _loadInitialState();
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to clear offline data: $e';
      print('❌ Error clearing offline data: $e');
      rethrow;
    }
  }

  /// Get offline status message
  String getOfflineStatusMessage() {
    if (!_isInitialized) {
      return 'Initializing offline service...';
    }
    
    if (_isOfflineMode) {
      return 'Offline mode enabled - All features work without internet';
    }
    
    if (!_isOnline) {
      return 'No internet connection - Using offline mode automatically';
    }
    
    if (_pendingSyncResults.isNotEmpty) {
      return 'Online - ${_pendingSyncResults.length} results pending sync';
    }
    
    return 'Online - All features available';
  }

  /// Get connectivity status icon
  IconData getConnectivityIcon() {
    if (!_isInitialized) {
      return Icons.sync;
    }
    
    if (_isOfflineMode || !_isOnline) {
      return Icons.offline_bolt;
    }
    
    if (_pendingSyncResults.isNotEmpty) {
      return Icons.sync_problem;
    }
    
    return Icons.wifi;
  }

  /// Get connectivity status color
  Color getConnectivityColor(BuildContext context) {
    if (!_isInitialized) {
      return Theme.of(context).colorScheme.primary;
    }
    
    if (_isOfflineMode || !_isOnline) {
      return Theme.of(context).colorScheme.error;
    }
    
    if (_pendingSyncResults.isNotEmpty) {
      return Theme.of(context).colorScheme.tertiary;
    }
    
    return Theme.of(context).colorScheme.primary;
  }

  /// Check if a specific feature is available offline
  bool isFeatureAvailableOffline(String feature) {
    switch (feature) {
      case 'plant_identification':
        return _isInitialized && _offlineService.isInitialized;
      case 'plant_database':
        return _isInitialized;
      case 'scan_history':
        return _isInitialized;
      case 'doh_plants':
        return _isInitialized;
      case 'search':
        return _isInitialized;
      default:
        return false;
    }
  }

  /// Get offline feature status
  Map<String, bool> getOfflineFeatureStatus() {
    return {
      'plant_identification': isFeatureAvailableOffline('plant_identification'),
      'plant_database': isFeatureAvailableOffline('plant_database'),
      'scan_history': isFeatureAvailableOffline('scan_history'),
      'doh_plants': isFeatureAvailableOffline('doh_plants'),
      'search': isFeatureAvailableOffline('search'),
    };
  }

  @override
  void dispose() {
    _offlineService.dispose();
    super.dispose();
  }
}
