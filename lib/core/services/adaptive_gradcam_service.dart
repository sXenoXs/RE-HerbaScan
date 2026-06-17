// lib/core/services/adaptive_gradcam_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:herbascan/core/services/online_gradcam_service.dart';
import 'package:herbascan/core/services/offline_cam_service.dart';

/// Adaptive service that automatically chooses between online Grad-CAM and offline CAM
/// based on connectivity and service availability
class AdaptiveGradCAMService {
  static final AdaptiveGradCAMService _instance =
      AdaptiveGradCAMService._internal();
  factory AdaptiveGradCAMService() => _instance;
  AdaptiveGradCAMService._internal();

  final Logger _logger = Logger();

  // Dependencies
  final OnlineGradCAMService _onlineService = OnlineGradCAMService();
  final OfflineCAMService _offlineService = OfflineCAMService();
  final Connectivity _connectivity = Connectivity();

  // State
  bool _isInitialized = false;

  /// Initialize the adaptive service
  Future<void> initialize() async {
    print('═══════════════════════════════════════════════════════');
    print('🚀 [AdaptiveGradCAMService] initialize() called');
    print('   Current _isInitialized: $_isInitialized');
    print('   Offline service initialized: ${_offlineService.isInitialized}');
    print('═══════════════════════════════════════════════════════');

    if (_isInitialized) {
      _logger.i('AdaptiveGradCAMService already initialized');
      print('✅ [AdaptiveGradCAMService] Already initialized, skipping');
      return;
    }

    try {
      _logger.i('Initializing AdaptiveGradCAMService...');
      print('🚀 [AdaptiveGradCAMService] Starting initialization...');

      // Initialize offline service (always needed for fallback)
      // Don't fail if offline service fails - we can still use online mode
      try {
        print('   Calling _offlineService.initialize() during app startup...');
        await _offlineService.initialize();
        print('   Initialize() call completed');
        print('   Checking status...');

        // Wait a bit for async operations
        await Future.delayed(const Duration(milliseconds: 100));

        final status = _offlineService.getInitializationStatus();
        print('   Status after initialization: $status');

        // Verify initialization actually succeeded
        if (_offlineService.isInitialized) {
          _logger.i('✅ Offline CAM service initialized');
          print(
              '✅ [AdaptiveGradCAMService] Offline CAM service initialized successfully');
        } else {
          _logger.w('⚠️ Offline CAM service initialization failed silently');
          _logger.w('⚠️ App will use online-only mode until fixed');
          print(
              '⚠️ [AdaptiveGradCAMService] Offline CAM service initialization FAILED');
          print('   Status: $status');
          print('   ⚠️ App will use online-only mode until fixed');
        }
      } catch (e, stackTrace) {
        _logger.w('⚠️ Offline CAM service failed to initialize: $e');
        _logger.w('⚠️ App will use online-only mode until fixed');
        print('═══════════════════════════════════════════════════════');
        print(
            '⚠️ [AdaptiveGradCAMService] EXCEPTION during offline CAM initialization');
        print('   Error: $e');
        print('   Error type: ${e.runtimeType}');
        print('   Stack trace: $stackTrace');
        print('   ⚠️ App will use online-only mode until fixed');
        print('═══════════════════════════════════════════════════════');
        // Continue initialization - online mode still works
      }

      _isInitialized = true;
      _logger.i('✅ AdaptiveGradCAMService initialized successfully');
      print('✅ [AdaptiveGradCAMService] Initialization complete');
      print('   _isInitialized: $_isInitialized');
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize AdaptiveGradCAMService: $e');
      _isInitialized = false;
      print('❌ [AdaptiveGradCAMService] Failed to initialize');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      // Don't rethrow - allow app to start, will fail gracefully when needed
    }
  }

  /// Check if device has internet connectivity
  /// Returns true if network is available (even if backend is not reachable)
  /// This allows us to try online first, and fallback gracefully if backend fails
  Future<bool> _hasConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final hasNetworkConnection = connectivityResults.any(
        (result) => result != ConnectivityResult.none,
      );

      if (!hasNetworkConnection) {
        _logger.d('No network connection detected');
        return false;
      }

      // We have network - try online first
      // Don't check backend health here - let the actual request fail gracefully
      // This allows us to attempt online GradCAM even if backend is temporarily down
      _logger.d('Network connection detected, will attempt online GradCAM');
      return true;
    } catch (e) {
      _logger.w('Error checking connectivity: $e');
      return false;
    }
  }

  /// Identify plant with adaptive Grad-CAM/CAM
  ///
  /// Automatically chooses:
  /// - Online (Grad-CAM) if connectivity is available and backend is healthy
  /// - Offline (CAM) if no connectivity or online service fails
  ///
  /// Parameters:
  /// - [imagePath]: Path to image file (for online service)
  /// - [imageBytes]: Image bytes (for offline service, or if imagePath fails)
  /// - [modelName]: Optional: Always uses "MobileNetV2" (HerbaScan deprecated)
  ///
  /// Returns Map with:
  /// - plant_name: String
  /// - scientific_name: String
  /// - confidence: double (0-1)
  /// - all_predictions: List<Map> (top 3)
  /// - gradcam_image: Uint8List (heatmap overlay as PNG)
  /// - method: "grad-cam" or "cam"
  /// - processing_time_ms: double
  /// - fallback_used: bool (true if offline was used as fallback)
  Future<Map<String, dynamic>?> identifyPlant({
    String? imagePath,
    Uint8List? imageBytes,
    String?
        modelName, // Optional: Always uses "MobileNetV2" (HerbaScan deprecated)
  }) async {
    // CRITICAL: Use print() for visibility in logs
    print('═══════════════════════════════════════════════════════');
    print('🌿 [AdaptiveGradCAM] identifyPlant() called');
    print('   Image path: ${imagePath != null ? "provided" : "null"}');
    print(
        '   Image bytes: ${imageBytes != null ? "${imageBytes.length} bytes" : "null"}');
    print('   Service initialized: $_isInitialized');
    print('   Offline service initialized: ${_offlineService.isInitialized}');
    print('═══════════════════════════════════════════════════════');

    if (!_isInitialized) {
      _logger.w('Service not initialized, initializing now...');
      print('⚠️ [AdaptiveGradCAM] Service not initialized, initializing...');
      await initialize();
      print('✅ [AdaptiveGradCAM] Service initialization complete');
      print('   Service initialized: $_isInitialized');
      print('   Offline service initialized: ${_offlineService.isInitialized}');
    }

    // Validate inputs
    if (imagePath == null && imageBytes == null) {
      _logger.e('Both imagePath and imageBytes cannot be null');
      return null;
    }

    // Ensure we have imageBytes for offline service
    if (imageBytes == null && imagePath != null) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          imageBytes = await file.readAsBytes();
        }
      } catch (e) {
        _logger.w('Could not read image from path: $e');
      }
    }

    if (imageBytes == null) {
      _logger.e('No valid image data available');
      return null;
    }

    try {
      // Step 1: Check connectivity
      print('📡 [AdaptiveGradCAM] Checking connectivity...');
      final hasConnection = await _hasConnectivity();
      print('   Connectivity result: $hasConnection');

      if (hasConnection) {
        _logger.i('🌐 Online mode available, attempting Grad-CAM...');
        print(
            '🌐 [AdaptiveGradCAM] Online mode available, attempting Grad-CAM...');

        // Try online first
        if (imagePath != null) {
          final onlineResult = await _tryOnline(imagePath);

          if (onlineResult != null) {
            _logger.i('✅ Online Grad-CAM succeeded');

            // Debug logging for gradcam_image
            print('🔍 [AdaptiveGradCAM] Online result received:');
            print('   Result keys: ${onlineResult.keys.toList()}');
            print(
                '   gradcam_image present: ${onlineResult['gradcam_image'] != null}');
            if (onlineResult['gradcam_image'] != null) {
              final img = onlineResult['gradcam_image'];
              print('   gradcam_image type: ${img.runtimeType}');
              if (img is Uint8List) {
                print('   gradcam_image size: ${img.length} bytes');
              }
            } else {
              print('   ⚠️ WARNING: gradcam_image is null in online result!');
            }

            return {
              ...onlineResult,
              'fallback_used': false,
            };
          }

          _logger
              .w('⚠️ Online Grad-CAM failed, falling back to offline CAM...');
        }
      } else {
        _logger.i('📴 No connectivity, using offline CAM mode...');
        print(
            '📴 [AdaptiveGradCAM] No connectivity, using offline CAM mode...');
      }

      // Step 2: Fallback to offline CAM
      // Try to initialize offline service if not already initialized
      print('🔍 [AdaptiveGradCAM] Checking offline CAM service status...');
      print('   Offline service initialized: ${_offlineService.isInitialized}');

      if (!_offlineService.isInitialized) {
        _logger.w(
            '⚠️ Offline CAM service not initialized, attempting initialization...');
        print(
            '⚠️ [AdaptiveGradCAM] Offline CAM service not initialized, attempting initialization...');
        try {
          print('   ═══════════════════════════════════════════════════════');
          print('   Calling _offlineService.initialize()...');
          print('   ═══════════════════════════════════════════════════════');

          // IMPORTANT: The initialize() method might throw an exception
          // but it catches it internally and doesn't rethrow
          // So we need to check the status after the call
          await _offlineService.initialize();

          print('   ═══════════════════════════════════════════════════════');
          print('   Initialize() call completed (no exception thrown)');
          print('   ═══════════════════════════════════════════════════════');

          // Wait a tiny bit to ensure async operations complete
          await Future.delayed(const Duration(milliseconds: 100));

          print('   Checking initialization status...');
          print(
              '   isInitialized after call: ${_offlineService.isInitialized}');

          // Get detailed status
          final status = _offlineService.getInitializationStatus();
          print('   ═══════════════════════════════════════════════════════');
          print('   Detailed status: $status');
          print('   ═══════════════════════════════════════════════════════');

          // Verify initialization actually succeeded
          if (!_offlineService.isInitialized) {
            _logger.e(
                '❌ Offline CAM service initialization failed - isInitialized is still false');
            _logger
                .e('❌ Cannot use offline CAM - service initialization failed');
            print('❌ [AdaptiveGradCAM] Offline CAM initialization FAILED');
            print('   Status: $status');
            print(
                '   ⚠️ This means initialize() completed but _isInitialized is still false');
            print(
                '   ⚠️ Check the logs above for the specific error during initialization');
            // Return error structure instead of null
            // CRITICAL FIX: Set method to 'cam' even on error so UI shows AI Explanation tab
            return {
              'error': true,
              'error_type': 'offline_failed',
              'error_message':
                  'Offline CAM model failed to load. TFLite version incompatibility detected. Please enable internet connection or update the app.',
              'predictions': <Map<String, dynamic>>[],
              'gradcam_image': null,
              'method': 'cam', // Set to 'cam' so UI shows AI Explanation tab
              'fallback_used':
                  true, // Mark as fallback since offline was attempted
              'processing_time_ms': 0.0,
            };
          }
          _logger.i(
              '✅ Offline CAM service initialized successfully during fallback');
        } catch (e, stackTrace) {
          _logger.e('❌ Failed to initialize offline CAM service: $e');
          _logger.e('Stack trace: $stackTrace');
          // Verify initialization status
          if (!_offlineService.isInitialized) {
            _logger
                .e('❌ Cannot use offline CAM - service initialization failed');
            // Return error structure instead of null
            // CRITICAL FIX: Set method to 'cam' even on error so UI shows AI Explanation tab
            return {
              'error': true,
              'error_type': 'offline_failed',
              'error_message':
                  'Offline CAM model failed to load. TFLite version incompatibility detected. Please enable internet connection or update the app.',
              'predictions': <Map<String, dynamic>>[],
              'gradcam_image': null,
              'method': 'cam', // Set to 'cam' so UI shows AI Explanation tab
              'fallback_used':
                  true, // Mark as fallback since offline was attempted
              'processing_time_ms': 0.0,
            };
          }
        }
      }

      // Now try offline CAM
      _logger.i('📴 Attempting offline CAM computation...');
      print('📴 [AdaptiveGradCAM] Attempting offline CAM computation...');
      print('   Image bytes: ${imageBytes.length} bytes');
      final offlineResult = await _tryOffline(imageBytes, modelName: modelName);
      print(
          '   Offline CAM result: ${offlineResult != null ? "SUCCESS" : "NULL"}');

      if (offlineResult != null) {
        // Enhanced logging for debugging
        print('🔍 [AdaptiveGradCAM] Offline CAM result received:');
        print('   Result keys: ${offlineResult.keys.toList()}');
        print(
            '   gradcam_image present: ${offlineResult['gradcam_image'] != null}');
        if (offlineResult['gradcam_image'] != null) {
          final img = offlineResult['gradcam_image'];
          print('   gradcam_image type: ${img.runtimeType}');
          if (img is Uint8List) {
            print('   gradcam_image size: ${img.length} bytes');
          } else {
            print(
                '   ⚠️ WARNING: gradcam_image is not Uint8List! Type: ${img.runtimeType}');
          }
        } else {
          print('   ⚠️ WARNING: gradcam_image is null in offline CAM result!');
        }

        final hasHeatmap = offlineResult['gradcam_image'] != null;
        _logger.i('✅ Offline CAM succeeded');
        _logger.i('   Method: ${offlineResult['method']}');
        _logger.i('   Plant name: ${offlineResult['plant_name']}');
        _logger.i('   Confidence: ${offlineResult['confidence']}');
        _logger.i('   Heatmap present: $hasHeatmap');
        if (hasHeatmap) {
          final heatmapBytes = offlineResult['gradcam_image'] as Uint8List?;
          _logger.i('   Heatmap size: ${heatmapBytes?.length ?? 0} bytes');
        } else {
          _logger.w(
              '   ⚠️ WARNING: Offline CAM succeeded but gradcam_image is null!');
          _logger.w(
              '   ⚠️ This will cause the AI Explanation section to not display properly');
          _logger.w(
              '   ⚠️ Check OfflineCAMService.identifyPlantWithCAM() implementation');
        }

        // CRITICAL FIX: Ensure method is ALWAYS set
        // If method is null, set it to 'cam' (offline CAM was used)
        if (offlineResult['method'] == null || offlineResult['method'] == '') {
          offlineResult['method'] = 'cam';
          _logger.w('   ⚠️ Method was null or empty, setting to "cam"');
        }

        // CRITICAL FIX: Ensure fallback_used is properly set
        final fallbackUsed = !hasConnection ||
            (hasConnection && offlineResult['fallback_used'] == true);

        // CRITICAL: Ensure gradcam_image is preserved in the return
        // Also ensure 'predictions' key exists (convert from 'all_predictions' if needed)
        final predictions = offlineResult['predictions'] ??
            offlineResult['all_predictions'] ??
            [];

        final result = {
          ...offlineResult,
          'predictions': predictions, // Ensure 'predictions' key exists for UI
          'method':
              offlineResult['method'] ?? 'cam', // Ensure method is always set
          'fallback_used':
              fallbackUsed, // Mark as fallback if offline or if explicitly marked
        };

        // Debug: Verify gradcam_image is in the result
        print('🔍 [AdaptiveGradCAM] Returning offline CAM result:');
        print('   Result keys: ${result.keys.toList()}');
        print('   gradcam_image present: ${result['gradcam_image'] != null}');
        if (result['gradcam_image'] != null) {
          final img = result['gradcam_image'];
          print('   gradcam_image type: ${img.runtimeType}');
          if (img is Uint8List) {
            print('   gradcam_image size: ${img.length} bytes');
          }
        } else {
          print('   ⚠️ WARNING: gradcam_image is null in return result!');
        }

        return result;
      } else {
        _logger.e('❌ Offline CAM computation returned null');
        _logger.e('   This means identifyPlantWithCAM() returned null');
        _logger.e('   Check if offline service is properly initialized');
        _logger.e('   Check if image processing is working correctly');
      }

      // Both methods failed - return error information
      _logger.e('❌ Both online and offline methods failed');

      // Check why offline failed
      String offlineErrorReason = 'Unknown error';
      if (!_offlineService.isInitialized) {
        offlineErrorReason =
            'Offline CAM model failed to load. TFLite version incompatibility detected.';
      } else {
        offlineErrorReason = 'Offline CAM computation failed';
      }

      // Return error structure instead of null for better error handling
      // CRITICAL FIX: Even on error, set method to indicate what was attempted
      final errorMethod =
          hasConnection ? null : 'cam'; // If offline, we attempted CAM
      return {
        'error': true,
        'error_type': hasConnection ? 'online_failed' : 'offline_failed',
        'error_message': hasConnection
            ? 'Online service unavailable. Offline mode not ready.'
            : offlineErrorReason,
        'predictions': <Map<String, dynamic>>[],
        'gradcam_image': null,
        'method': errorMethod, // Set to 'cam' if offline, null if online failed
        'fallback_used': !hasConnection, // Mark as fallback if we were offline
        'processing_time_ms': 0.0,
      };
    } catch (e, stackTrace) {
      _logger.e('Error in adaptive identification: $e');
      _logger.e('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Try online Grad-CAM identification
  Future<Map<String, dynamic>?> _tryOnline(String imagePath) async {
    try {
      final result = await _onlineService.identifyPlant(imagePath);
      return result;
    } catch (e) {
      _logger.w('Online service error: $e');
      return null;
    }
  }

  /// Try offline CAM identification
  /// [modelName] - Optional: Always uses "MobileNetV2" (HerbaScan deprecated)
  Future<Map<String, dynamic>?> _tryOffline(Uint8List imageBytes,
      {String? modelName}) async {
    try {
      print('═══════════════════════════════════════════════════════');
      print('📴 [AdaptiveGradCAM] _tryOffline() called');
      print('   Image bytes: ${imageBytes.length} bytes');
      print('   Offline service initialized: ${_offlineService.isInitialized}');
      if (modelName != null) {
        print('   Using model: $modelName');
      }
      print('═══════════════════════════════════════════════════════');

      if (!_offlineService.isInitialized) {
        _logger.e('❌ Offline CAM service not initialized, cannot proceed');
        _logger.e(
            '   Service initialization status: ${_offlineService.isInitialized}');
        print('❌ [AdaptiveGradCAM] Offline CAM service not initialized!');
        final status = _offlineService.getInitializationStatus();
        print('   Status: $status');
        return null;
      }

      _logger.d('📴 Starting offline CAM computation...');
      _logger.d('   Image bytes: ${imageBytes.length} bytes');
      if (modelName != null) {
        _logger.d('   Using model: $modelName');
      }
      print(
          '✅ [AdaptiveGradCAM] Offline CAM service is initialized, proceeding...');

      final stopwatch = Stopwatch()..start();
      final result = await _offlineService.identifyPlantWithCAM(imageBytes,
          modelName: modelName);
      stopwatch.stop();

      if (result == null) {
        _logger.e('❌ Offline CAM service returned null result');
        _logger.e('   Computation time: ${stopwatch.elapsedMilliseconds}ms');
        _logger.e('   This could indicate:');
        _logger.e('   1. Image preprocessing failed');
        _logger.e('   2. Model inference failed');
        _logger.e('   3. CAM computation failed');
        _logger.e('   4. Heatmap generation failed');
      } else {
        _logger.d('✅ Offline CAM computation completed successfully');
        _logger.d('   Computation time: ${stopwatch.elapsedMilliseconds}ms');
        _logger.d('   Result keys: ${result.keys.toList()}');
        _logger.d('   Method: ${result['method']}');
        _logger.d('   Plant name: ${result['plant_name']}');
        _logger.d('   Confidence: ${result['confidence']}');
        _logger.d('   Heatmap present: ${result['gradcam_image'] != null}');

        // Verify critical fields
        print('🔍 [AdaptiveGradCAM] Offline CAM result details:');
        print('   Result keys: ${result.keys.toList()}');
        print('   gradcam_image present: ${result['gradcam_image'] != null}');
        if (result['gradcam_image'] != null) {
          final img = result['gradcam_image'];
          print('   gradcam_image type: ${img.runtimeType}');
          if (img is Uint8List) {
            print('   gradcam_image size: ${img.length} bytes');
          }
        } else {
          print('   ⚠️ WARNING: gradcam_image is null in offline CAM result!');
          _logger.w('   ⚠️ WARNING: gradcam_image is null in result!');
          _logger
              .w('   ⚠️ The AI Explanation section may not display correctly');
        }
        if (result['method'] == null) {
          _logger.w('   ⚠️ WARNING: method is null in result!');
          result['method'] = 'cam'; // Set default method
        }
        if (result['all_predictions'] == null) {
          _logger.w('   ⚠️ WARNING: all_predictions is null in result!');
        }
      }

      return result;
    } catch (e, stackTrace) {
      _logger.e('❌ Offline service error: $e');
      _logger.e('   Error type: ${e.runtimeType}');
      _logger.e('   Stack trace: $stackTrace');
      return null;
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get current connectivity status
  Future<bool> getConnectivityStatus() async {
    return await _hasConnectivity();
  }

  /// Manually force offline mode (for testing or user preference)
  Future<Map<String, dynamic>?> identifyPlantOffline(
    Uint8List imageBytes,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    _logger.i('📴 Forced offline mode - using CAM...');
    return await _tryOffline(imageBytes);
  }

  /// Manually force online mode (for testing or user preference)
  Future<Map<String, dynamic>?> identifyPlantOnline(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    _logger.i('🌐 Forced online mode - using Grad-CAM...');
    final result = await _tryOnline(imagePath);

    if (result == null) {
      _logger.w('⚠️ Forced online mode failed');
    }

    return result;
  }

  /// Get statistics about service usage
  Future<Map<String, dynamic>> getServiceStats() async {
    final isConnected = await _hasConnectivity();
    final onlineHealth = await _onlineService.checkServerHealth();
    final offlineInitialized = _offlineService.isInitialized;

    return {
      'is_online': isConnected,
      'online_service_healthy': onlineHealth,
      'offline_service_ready': offlineInitialized,
      'adaptive_mode_available': true,
    };
  }

  /// Dispose resources
  void dispose() {
    _offlineService.dispose();
    _isInitialized = false;
  }
}
