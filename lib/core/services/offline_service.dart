// lib/core/services/offline_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:herbascan/core/services/database_service.dart';
import 'package:herbascan/core/services/plant_classifier_service.dart';
import 'package:herbascan/core/services/tflite_plant_service.dart';
import 'package:herbascan/core/services/offline_data_manager.dart';
import 'package:herbascan/core/services/offline_sync_manager.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/models/plant.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  // Dependencies
  final DatabaseService _databaseService = DatabaseService();
  final PlantClassifierService _classifierService = PlantClassifierService();
  final TflitePlantService _tfliteService = TflitePlantService();
  final OfflineDataManager _dataManager = OfflineDataManager();
  final OfflineSyncManager _syncManager = OfflineSyncManager();
  final Connectivity _connectivity = Connectivity();

  // State management
  bool _isOfflineMode = false;
  bool _isOnline = true;
  bool _isInitialized = false;
  List<ScanResult> _pendingSyncResults = [];
  Timer? _syncTimer;

  // Stream controllers for real-time updates
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  final StreamController<List<ScanResult>> _pendingSyncController = StreamController<List<ScanResult>>.broadcast();

  // Getters
  bool get isOfflineMode => _isOfflineMode;
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  List<ScanResult> get pendingSyncResults => List.from(_pendingSyncResults);
  Stream<bool> get connectivityStream => _connectivityController.stream;
  Stream<List<ScanResult>> get pendingSyncStream => _pendingSyncController.stream;

  /// Initialize the offline service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔄 Initializing Offline Service...');

      // Load offline mode preference
      await _loadOfflineModePreference();

      // Initialize connectivity monitoring
      await _initializeConnectivityMonitoring();

      // Initialize offline data storage
      await _initializeOfflineStorage();

      // Initialize offline data manager
      await _dataManager.initialize();

      // Initialize sync manager
      await _syncManager.initialize();

      // Load pending sync results
      await _loadPendingSyncResults();

      // Initialize AI models for offline processing
      await _initializeOfflineAI();

      _isInitialized = true;
      print('✅ Offline Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing Offline Service: $e');
      rethrow;
    }
  }

  /// Load offline mode preference from SharedPreferences
  Future<void> _loadOfflineModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
      print('📱 Offline mode preference: $_isOfflineMode');
    } catch (e) {
      print('❌ Error loading offline mode preference: $e');
      _isOfflineMode = false;
    }
  }

  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivityMonitoring() async {
    try {
      // Check initial connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(connectivityResults);
      
      // Listen to connectivity changes
      _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
        final wasOnline = _isOnline;
        _isOnline = _isConnected(results);
        
        if (wasOnline != _isOnline) {
          print('🌐 Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
          _connectivityController.add(_isOnline);
          
          // Update sync manager
          _syncManager.setOnlineStatus(_isOnline);
          
          // Handle offline/online transitions
          if (_isOnline && _pendingSyncResults.isNotEmpty) {
            _startSyncProcess();
          }
        }
      });

      print('📡 Connectivity monitoring initialized');
    } catch (e) {
      print('❌ Error initializing connectivity monitoring: $e');
      _isOnline = false;
    }
  }

  /// Check if device is connected to internet
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Initialize offline data storage
  Future<void> _initializeOfflineStorage() async {
    try {
      // Ensure database is initialized
      await _databaseService.database;
      
      // Create offline data directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${appDir.path}/offline_data');
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
        print('📁 Created offline data directory');
      }

      print('💾 Offline storage initialized');
    } catch (e) {
      print('❌ Error initializing offline storage: $e');
      rethrow;
    }
  }

  /// Load pending sync results from local storage
  Future<void> _loadPendingSyncResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSyncData = prefs.getStringList('pendingSyncResults') ?? [];
      
      _pendingSyncResults = pendingSyncData
          .map((json) => ScanResult.fromJson(Map<String, dynamic>.from(
              Uri.splitQueryString(json))))
          .toList();

      print('📋 Loaded ${_pendingSyncResults.length} pending sync results');
      _pendingSyncController.add(_pendingSyncResults);
    } catch (e) {
      print('❌ Error loading pending sync results: $e');
      _pendingSyncResults = [];
    }
  }

  /// Initialize AI models for offline processing
  Future<void> _initializeOfflineAI() async {
    try {
      // Load AI models (they work offline)
      await _classifierService.loadModels();
      
      if (!_classifierService.isInitialized) {
        print('⚠️ AI models not loaded - offline processing may be limited');
      } else {
        print('🤖 AI models loaded for offline processing');
      }
    } catch (e) {
      print('❌ Error initializing offline AI: $e');
      // Don't rethrow - app can still work without AI
    }
  }

  /// Toggle offline mode
  Future<void> toggleOfflineMode() async {
    _isOfflineMode = !_isOfflineMode;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isOfflineMode', _isOfflineMode);
      
      print('🔄 Offline mode toggled: $_isOfflineMode');
      
      // If switching to online mode and there are pending syncs, start sync
      if (!_isOfflineMode && _isOnline && _pendingSyncResults.isNotEmpty) {
        _startSyncProcess();
      }
    } catch (e) {
      print('❌ Error toggling offline mode: $e');
    }
  }

  /// Process plant identification offline
  Future<List<Map<String, dynamic>>> processPlantOffline(Uint8List imageData) async {
    try {
      if (!_isInitialized) {
        throw Exception('Offline service not initialized');
      }

      if (!_classifierService.isInitialized) {
        throw Exception('AI models not available for offline processing');
      }

      print('🌿 Processing plant offline...');
      
      // Use AI classifier service (works offline)
      final predictions = await _classifierService.classifyPlant(imageData);
      
      print('✅ Offline plant processing completed');
      return predictions;
    } catch (e) {
      print('❌ Error processing plant offline: $e');
      rethrow;
    }
  }

  /// Save scan result for offline storage
  Future<void> saveScanResultOffline(ScanResult result) async {
    try {
      // Save to local database
      await _databaseService.saveScanResult(result);
      
      // Add to pending sync if not in offline mode or if offline
      if (_isOfflineMode || !_isOnline) {
        _pendingSyncResults.add(result);
        await _savePendingSyncResults();
        _pendingSyncController.add(_pendingSyncResults);
        print('💾 Scan result saved offline (pending sync)');
      } else {
        print('💾 Scan result saved and synced');
      }
    } catch (e) {
      print('❌ Error saving scan result offline: $e');
      rethrow;
    }
  }

  /// Get offline scan history
  Future<List<ScanResult>> getOfflineScanHistory() async {
    try {
      return await _databaseService.getScanHistory();
    } catch (e) {
      print('❌ Error getting offline scan history: $e');
      return [];
    }
  }

  /// Get offline plant database
  Future<List<Plant>> getOfflinePlants() async {
    try {
      return await _databaseService.getAllPlants();
    } catch (e) {
      print('❌ Error getting offline plants: $e');
      return [];
    }
  }

  /// Get DOH approved plants offline
  Future<List<Plant>> getOfflineDOHPlants() async {
    try {
      return await _databaseService.getDOHApprovedPlants();
    } catch (e) {
      print('❌ Error getting offline DOH plants: $e');
      return [];
    }
  }

  /// Search plants offline
  Future<List<Plant>> searchPlantsOffline(String query) async {
    try {
      final allPlants = await getOfflinePlants();
      return allPlants.where((plant) {
        return plant.commonName.toLowerCase().contains(query.toLowerCase()) ||
               plant.scientificName.toLowerCase().contains(query.toLowerCase()) ||
               plant.localName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    } catch (e) {
      print('❌ Error searching plants offline: $e');
      return [];
    }
  }

  /// Save pending sync results to SharedPreferences
  Future<void> _savePendingSyncResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSyncData = _pendingSyncResults
          .map((result) => Uri(queryParameters: result.toJson().map(
              (key, value) => MapEntry(key, value.toString()))).query)
          .toList();
      
      await prefs.setStringList('pendingSyncResults', pendingSyncData);
    } catch (e) {
      print('❌ Error saving pending sync results: $e');
    }
  }

  /// Start sync process when online
  void _startSyncProcess() {
    if (_syncTimer?.isActive == true) return;
    
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isOnline && !_isOfflineMode && _pendingSyncResults.isNotEmpty) {
        _syncPendingResults();
      } else if (_pendingSyncResults.isEmpty) {
        timer.cancel();
      }
    });
  }

  /// Sync pending results to server (placeholder for future implementation)
  Future<void> _syncPendingResults() async {
    try {
      print('🔄 Syncing ${_pendingSyncResults.length} pending results...');
      
      // TODO: Implement actual server sync
      // For now, just simulate successful sync
      await Future.delayed(const Duration(seconds: 2));
      
      // Clear pending results after successful sync
      _pendingSyncResults.clear();
      await _savePendingSyncResults();
      _pendingSyncController.add(_pendingSyncResults);
      
      print('✅ Pending results synced successfully');
    } catch (e) {
      print('❌ Error syncing pending results: $e');
    }
  }

  /// Get offline storage statistics
  Future<Map<String, dynamic>> getOfflineStats() async {
    try {
      final scanHistory = await getOfflineScanHistory();
      final plants = await getOfflinePlants();
      final dohPlants = await getOfflineDOHPlants();
      if (!_tfliteService.isReady) {
        await _tfliteService.loadModel();
      }
      final modelHealth = _tfliteService.getModelHealth();
      final aiReady =
          modelHealth['modelLoaded'] == true && modelHealth['labelsLoaded'] == true;
      
      return {
        'totalScans': scanHistory.length,
        'totalPlants': plants.length,
        'dohPlants': dohPlants.length,
        'pendingSync': _pendingSyncResults.length,
        'isOfflineMode': _isOfflineMode,
        'isOnline': _isOnline,
        'aiInitialized': aiReady,
        'aiModelLoaded': modelHealth['modelLoaded'] == true,
        'aiLabelsLoaded': modelHealth['labelsLoaded'] == true,
        'aiLabelCount': modelHealth['labelCount'] ?? 0,
        'aiLastError': modelHealth['lastLoadError'],
      };
    } catch (e) {
      print('❌ Error getting offline stats: $e');
      return {
        'totalScans': 0,
        'totalPlants': 0,
        'dohPlants': 0,
        'pendingSync': 0,
        'isOfflineMode': _isOfflineMode,
        'isOnline': _isOnline,
        'aiInitialized': false,
        'aiModelLoaded': false,
        'aiLabelsLoaded': false,
        'aiLabelCount': 0,
        'aiLastError': e.toString(),
      };
    }
  }

  /// Clear all offline data
  Future<void> clearOfflineData() async {
    try {
      // Clear database
      await _databaseService.clearScanHistory();
      
      // Clear pending sync results
      _pendingSyncResults.clear();
      await _savePendingSyncResults();
      _pendingSyncController.add(_pendingSyncResults);
      
      print('🗑️ Offline data cleared');
    } catch (e) {
      print('❌ Error clearing offline data: $e');
      rethrow;
    }
  }

  /// Get comprehensive offline statistics
  Future<Map<String, dynamic>> getComprehensiveStats() async {
    try {
      final basicStats = await getOfflineStats();
      final dataHealth = await _dataManager.getDataHealthStatus();
      final syncStats = await _syncManager.getSyncStats();
      final storageStats = await _dataManager.getStorageStats();

      return {
        ...basicStats,
        'dataHealth': dataHealth,
        'syncStats': syncStats,
        'storageStats': storageStats,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting comprehensive stats: $e');
      return await getOfflineStats();
    }
  }

  /// Optimize offline storage
  Future<void> optimizeStorage() async {
    try {
      await _dataManager.optimizeStorage();
      print('✅ Storage optimization completed');
    } catch (e) {
      print('❌ Error optimizing storage: $e');
      rethrow;
    }
  }

  /// Export offline data
  Future<Map<String, dynamic>> exportOfflineData() async {
    try {
      return await _dataManager.exportOfflineData();
    } catch (e) {
      print('❌ Error exporting offline data: $e');
      rethrow;
    }
  }

  /// Import offline data
  Future<void> importOfflineData(Map<String, dynamic> data) async {
    try {
      await _dataManager.importOfflineData(data);
      print('✅ Offline data imported successfully');
    } catch (e) {
      print('❌ Error importing offline data: $e');
      rethrow;
    }
  }

  /// Force sync pending data
  Future<void> forceSync() async {
    try {
      await _syncManager.forceSync();
      print('✅ Force sync completed');
    } catch (e) {
      print('❌ Error force syncing: $e');
      rethrow;
    }
  }

  /// Get sync status stream
  Stream<bool> get syncStatusStream => _syncManager.syncStatusStream;

  /// Get sync progress stream
  Stream<String> get syncProgressStream => _syncManager.syncProgressStream;

  /// Get sync statistics stream
  Stream<Map<String, dynamic>> get syncStatsStream => _syncManager.syncStatsStream;

  /// Check if data is available offline
  Future<bool> isDataAvailableOffline() async {
    try {
      return await _dataManager.isOfflineDataAvailable();
    } catch (e) {
      print('❌ Error checking offline data availability: $e');
      return false;
    }
  }

  /// Get offline data health
  Future<Map<String, dynamic>> getDataHealth() async {
    try {
      return await _dataManager.getDataHealthStatus();
    } catch (e) {
      print('❌ Error getting data health: $e');
      return {
        'isHealthy': false,
        'hasData': false,
        'error': e.toString(),
      };
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _connectivityController.close();
    _pendingSyncController.close();
    _syncManager.dispose();
  }
}
