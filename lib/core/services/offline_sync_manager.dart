// lib/core/services/offline_sync_manager.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/models/plant.dart';

class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  // Sync configuration
  static const String _syncEndpoint = 'https://api.herbascan.com/sync'; // Placeholder
  static const Duration _syncInterval = Duration(minutes: 5);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 30);

  // State management
  bool _isSyncing = false;
  bool _isOnline = true;
  Timer? _syncTimer;
  int _retryCount = 0;
  String? _lastSyncError;

  // Stream controllers
  final StreamController<bool> _syncStatusController = StreamController<bool>.broadcast();
  final StreamController<String> _syncProgressController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _syncStatsController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  String? get lastSyncError => _lastSyncError;
  Stream<bool> get syncStatusStream => _syncStatusController.stream;
  Stream<String> get syncProgressStream => _syncProgressController.stream;
  Stream<Map<String, dynamic>> get syncStatsStream => _syncStatsController.stream;

  /// Initialize sync manager
  Future<void> initialize() async {
    try {
      print('🔄 Initializing Offline Sync Manager...');
      
      // Load sync preferences
      await _loadSyncPreferences();
      
      // Start periodic sync if online
      if (_isOnline) {
        _startPeriodicSync();
      }
      
      print('✅ Offline Sync Manager initialized');
    } catch (e) {
      print('❌ Error initializing Offline Sync Manager: $e');
    }
  }

  /// Load sync preferences from SharedPreferences
  Future<void> _loadSyncPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnline = prefs.getBool('isOnline') ?? true;
    } catch (e) {
      print('❌ Error loading sync preferences: $e');
      _isOnline = true;
    }
  }

  /// Save sync preferences to SharedPreferences
  Future<void> _saveSyncPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isOnline', _isOnline);
    } catch (e) {
      print('❌ Error saving sync preferences: $e');
    }
  }

  /// Start periodic sync
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_isOnline && !_isSyncing) {
        _performSync();
      }
    });
  }

  /// Stop periodic sync
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Set online status
  void setOnlineStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _saveSyncPreferences();
      
      if (_isOnline) {
        _startPeriodicSync();
        _performSync(); // Immediate sync when coming online
      } else {
        _stopPeriodicSync();
      }
    }
  }

  /// Perform sync operation
  Future<void> _performSync() async {
    if (_isSyncing || !_isOnline) return;

    try {
      _isSyncing = true;
      _lastSyncError = null;
      _syncStatusController.add(true);
      _syncProgressController.add('Starting sync...');

      print('🔄 Starting sync operation...');

      // Get pending sync data
      final pendingData = await _getPendingSyncData();
      
      if (pendingData.isEmpty) {
        _syncProgressController.add('No data to sync');
        _completeSync();
        return;
      }

      _syncProgressController.add('Syncing ${pendingData.length} items...');

      // Attempt to sync data
      final success = await _syncDataToServer(pendingData);
      
      if (success) {
        await _markDataAsSynced(pendingData);
        _retryCount = 0;
        _syncProgressController.add('Sync completed successfully');
        print('✅ Sync completed successfully');
      } else {
        throw Exception('Sync failed');
      }

      _completeSync();
    } catch (e) {
      _lastSyncError = e.toString();
      _retryCount++;
      _syncProgressController.add('Sync failed: $e');
      print('❌ Sync failed: $e');

      // Schedule retry if under max retries
      if (_retryCount < _maxRetries) {
        _scheduleRetry();
      } else {
        _completeSync();
      }
    }
  }

  /// Complete sync operation
  void _completeSync() {
    _isSyncing = false;
    _syncStatusController.add(false);
    _updateSyncStats();
  }

  /// Schedule retry
  void _scheduleRetry() {
    Timer(_retryDelay, () {
      if (_isOnline && !_isSyncing) {
        _performSync();
      }
    });
  }

  /// Get pending sync data
  Future<List<Map<String, dynamic>>> _getPendingSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getStringList('pendingSyncData') ?? [];
      
      return pendingData
          .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('❌ Error getting pending sync data: $e');
      return [];
    }
  }

  /// Save pending sync data
  Future<void> _savePendingSyncData(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = data
          .map((item) => jsonEncode(item))
          .toList();
      
      await prefs.setStringList('pendingSyncData', jsonData);
    } catch (e) {
      print('❌ Error saving pending sync data: $e');
    }
  }

  /// Add data to pending sync
  Future<void> addToPendingSync(Map<String, dynamic> data) async {
    try {
      final pendingData = await _getPendingSyncData();
      pendingData.add(data);
      await _savePendingSyncData(pendingData);
      
      // Trigger immediate sync if online
      if (_isOnline && !_isSyncing) {
        _performSync();
      }
    } catch (e) {
      print('❌ Error adding to pending sync: $e');
    }
  }

  /// Sync data to server
  Future<bool> _syncDataToServer(List<Map<String, dynamic>> data) async {
    try {
      // This is a placeholder implementation
      // In a real app, you would send data to your server
      
      print('📤 Syncing ${data.length} items to server...');
      
      // Simulate network request
      await Future.delayed(const Duration(seconds: 2));
      
      // For demo purposes, always succeed
      // In real implementation, you would:
      // 1. Send HTTP POST request to sync endpoint
      // 2. Handle server response
      // 3. Process any server-side validation errors
      // 4. Return success/failure status
      
      return true;
    } catch (e) {
      print('❌ Error syncing data to server: $e');
      return false;
    }
  }

  /// Mark data as synced
  Future<void> _markDataAsSynced(List<Map<String, dynamic>> syncedData) async {
    try {
      // Remove synced data from pending list
      final pendingData = await _getPendingSyncData();
      final syncedIds = syncedData.map((item) => item['id']).toSet();
      
      final remainingData = pendingData
          .where((item) => !syncedIds.contains(item['id']))
          .toList();
      
      await _savePendingSyncData(remainingData);
      
      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSyncTime', DateTime.now().toIso8601String());
      
      print('✅ Marked ${syncedData.length} items as synced');
    } catch (e) {
      print('❌ Error marking data as synced: $e');
    }
  }

  /// Update sync statistics
  void _updateSyncStats() {
    try {
      final stats = {
        'isOnline': _isOnline,
        'isSyncing': _isSyncing,
        'retryCount': _retryCount,
        'lastError': _lastSyncError,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
      
      _syncStatsController.add(stats);
    } catch (e) {
      print('❌ Error updating sync stats: $e');
    }
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = await _getPendingSyncData();
      final lastSyncTime = prefs.getString('lastSyncTime');
      
      return {
        'isOnline': _isOnline,
        'isSyncing': _isSyncing,
        'pendingCount': pendingData.length,
        'retryCount': _retryCount,
        'lastSyncTime': lastSyncTime,
        'lastError': _lastSyncError,
        'nextSyncIn': _getNextSyncTime(),
      };
    } catch (e) {
      print('❌ Error getting sync stats: $e');
      return {
        'isOnline': false,
        'isSyncing': false,
        'pendingCount': 0,
        'retryCount': 0,
        'lastSyncTime': null,
        'lastError': e.toString(),
        'nextSyncIn': null,
      };
    }
  }

  /// Get next sync time
  String? _getNextSyncTime() {
    if (_syncTimer == null || !_isOnline) return null;
    
    // This is a simplified calculation
    // In a real implementation, you'd track the actual next sync time
    return 'In ${_syncInterval.inMinutes} minutes';
  }

  /// Force sync
  Future<void> forceSync() async {
    if (_isSyncing) return;
    
    _retryCount = 0;
    await _performSync();
  }

  /// Clear sync data
  Future<void> clearSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pendingSyncData');
      await prefs.remove('lastSyncTime');
      
      _retryCount = 0;
      _lastSyncError = null;
      
      print('🗑️ Sync data cleared');
    } catch (e) {
      print('❌ Error clearing sync data: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
    _syncProgressController.close();
    _syncStatsController.close();
  }
}
