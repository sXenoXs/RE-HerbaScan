// lib/core/services/offline_data_manager.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:herbascan/core/services/database_service.dart';

class OfflineDataManager {
  static final OfflineDataManager _instance = OfflineDataManager._internal();
  factory OfflineDataManager() => _instance;
  OfflineDataManager._internal();

  final DatabaseService _databaseService = DatabaseService();
  Directory? _offlineDataDir;
  Directory? _imagesDir;
  Directory? _modelsDir;

  /// Initialize offline data directories
  Future<void> initialize() async {
    try {
      print('🔄 Initializing Offline Data Manager...');

      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();

      // Create offline data directory
      _offlineDataDir = Directory('${appDir.path}/offline_data');
      if (!await _offlineDataDir!.exists()) {
        await _offlineDataDir!.create(recursive: true);
        print('📁 Created offline data directory');
      }

      // Create images directory
      _imagesDir = Directory('${_offlineDataDir!.path}/images');
      if (!await _imagesDir!.exists()) {
        await _imagesDir!.create(recursive: true);
        print('📁 Created images directory');
      }

      // Create models directory
      _modelsDir = Directory('${_offlineDataDir!.path}/models');
      if (!await _modelsDir!.exists()) {
        await _modelsDir!.create(recursive: true);
        print('📁 Created models directory');
      }

      print('✅ Offline Data Manager initialized');
    } catch (e) {
      print('❌ Error initializing Offline Data Manager: $e');
      rethrow;
    }
  }

  /// Save image data to offline storage
  Future<String> saveImageOffline(Uint8List imageData, String filename) async {
    try {
      if (_imagesDir == null) {
        throw Exception('Offline data manager not initialized');
      }

      final file = File('${_imagesDir!.path}/$filename');
      await file.writeAsBytes(imageData);

      print('💾 Image saved offline: $filename');
      return file.path;
    } catch (e) {
      print('❌ Error saving image offline: $e');
      rethrow;
    }
  }

  /// Load image from offline storage
  Future<Uint8List?> loadImageOffline(String filename) async {
    try {
      if (_imagesDir == null) {
        throw Exception('Offline data manager not initialized');
      }

      final file = File('${_imagesDir!.path}/$filename');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      print('❌ Error loading image offline: $e');
      return null;
    }
  }

  /// Delete image from offline storage
  Future<bool> deleteImageOffline(String filename) async {
    try {
      if (_imagesDir == null) {
        throw Exception('Offline data manager not initialized');
      }

      final file = File('${_imagesDir!.path}/$filename');
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Image deleted offline: $filename');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting image offline: $e');
      return false;
    }
  }

  /// Get offline storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      if (_offlineDataDir == null) {
        return {
          'totalSize': 0,
          'imageCount': 0,
          'modelCount': 0,
          'availableSpace': 0,
        };
      }

      int totalSize = 0;
      int imageCount = 0;
      int modelCount = 0;

      // Calculate images directory size
      if (_imagesDir != null && await _imagesDir!.exists()) {
        final imageFiles = await _imagesDir!.list().toList();
        for (final file in imageFiles) {
          if (file is File) {
            final stat = await file.stat();
            totalSize += stat.size;
            imageCount++;
          }
        }
      }

      // Calculate models directory size
      if (_modelsDir != null && await _modelsDir!.exists()) {
        final modelFiles = await _modelsDir!.list().toList();
        for (final file in modelFiles) {
          if (file is File) {
            final stat = await file.stat();
            totalSize += stat.size;
            modelCount++;
          }
        }
      }

      // Get available space (simplified)
      final availableSpace = await _getAvailableSpace();

      return {
        'totalSize': totalSize,
        'imageCount': imageCount,
        'modelCount': modelCount,
        'availableSpace': availableSpace,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'availableSpaceMB': (availableSpace / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('❌ Error getting storage stats: $e');
      return {
        'totalSize': 0,
        'imageCount': 0,
        'modelCount': 0,
        'availableSpace': 0,
        'totalSizeMB': '0.00',
        'availableSpaceMB': '0.00',
      };
    }
  }

  /// Get available disk space (simplified implementation)
  Future<int> _getAvailableSpace() async {
    try {
      // This is a simplified implementation
      // In a real app, you might want to use a more sophisticated method
      return 100 * 1024 * 1024; // Assume 100MB available
    } catch (e) {
      return 0;
    }
  }

  /// Clean up old offline data
  Future<void> cleanupOldData({int maxAgeInDays = 30}) async {
    try {
      if (_imagesDir == null) return;

      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeInDays));
      int deletedCount = 0;

      final imageFiles = await _imagesDir!.list().toList();
      for (final file in imageFiles) {
        if (file is File) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      print('🧹 Cleaned up $deletedCount old files');
    } catch (e) {
      print('❌ Error cleaning up old data: $e');
    }
  }

  /// Export offline data for backup
  Future<Map<String, dynamic>> exportOfflineData() async {
    try {
      final stats = await getStorageStats();
      final plants = await _databaseService.getAllPlants();
      final scanHistory = await _databaseService.getScanHistory();

      return {
        'exportDate': DateTime.now().toIso8601String(),
        'stats': stats,
        'plants': plants.map((p) => p.toJson()).toList(),
        'scanHistory': scanHistory.map((s) => s.toJson()).toList(),
        'version': 'v1.0.28',
      };
    } catch (e) {
      print('❌ Error exporting offline data: $e');
      rethrow;
    }
  }

  /// Import offline data from backup
  Future<void> importOfflineData(Map<String, dynamic> data) async {
    try {
      // This would implement data import logic
      // For now, just log the import
      print('📥 Importing offline data...');
      print('Export date: ${data['exportDate']}');
      print('Plants: ${data['plants']?.length ?? 0}');
      print('Scans: ${data['scanHistory']?.length ?? 0}');

      // TODO: Implement actual import logic
    } catch (e) {
      print('❌ Error importing offline data: $e');
      rethrow;
    }
  }

  /// Clear all offline data
  Future<void> clearAllOfflineData() async {
    try {
      if (_offlineDataDir == null) return;

      if (await _offlineDataDir!.exists()) {
        await _offlineDataDir!.delete(recursive: true);
        print('🗑️ All offline data cleared');
      }

      // Recreate directories
      await initialize();
    } catch (e) {
      print('❌ Error clearing offline data: $e');
      rethrow;
    }
  }

  /// Check if offline data is available
  Future<bool> isOfflineDataAvailable() async {
    try {
      if (_offlineDataDir == null) return false;

      final plants = await _databaseService.getAllPlants();
      return plants.isNotEmpty;
    } catch (e) {
      print('❌ Error checking offline data availability: $e');
      return false;
    }
  }

  /// Get offline data health status
  Future<Map<String, dynamic>> getDataHealthStatus() async {
    try {
      final stats = await getStorageStats();
      final plants = await _databaseService.getAllPlants();
      final scanHistory = await _databaseService.getScanHistory();
      final isDataAvailable = await isOfflineDataAvailable();

      return {
        'isHealthy': isDataAvailable && plants.isNotEmpty,
        'hasData': isDataAvailable,
        'plantCount': plants.length,
        'scanCount': scanHistory.length,
        'storageStats': stats,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting data health status: $e');
      return {
        'isHealthy': false,
        'hasData': false,
        'plantCount': 0,
        'scanCount': 0,
        'storageStats': {},
        'lastUpdated': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }

  /// Optimize offline storage
  Future<void> optimizeStorage() async {
    try {
      print('🔧 Optimizing offline storage...');

      // Clean up old data
      await cleanupOldData();

      // Rebuild database indexes (if needed)
      await _databaseService.database;

      print('✅ Storage optimization completed');
    } catch (e) {
      print('❌ Error optimizing storage: $e');
    }
  }

  /// Get directory paths
  String? get imagesDirectory => _imagesDir?.path;
  String? get modelsDirectory => _modelsDir?.path;
  String? get offlineDataDirectory => _offlineDataDir?.path;
}
