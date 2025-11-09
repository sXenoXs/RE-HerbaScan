import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:herbascan/core/services/plant_classifier_service.dart';
import 'package:herbascan/core/providers/offline_provider.dart';
import 'package:herbascan/core/services/performance_monitor.dart';
import 'package:herbascan/core/services/usage_analytics.dart';
import 'package:herbascan/core/services/error_logger.dart';
import 'package:herbascan/core/services/adaptive_gradcam_service.dart';

class CameraProvider extends ChangeNotifier {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  final bool _isProcessing = false;
  String? _lastCapturedImagePath;
  Uint8List? _lastCapturedImageData;
  String? _errorMessage;

  // New properties for plant classification
  final PlantClassifierService _classifierService = PlantClassifierService();
  final AdaptiveGradCAMService _adaptiveGradCAM = AdaptiveGradCAMService();
  List<Map<String, dynamic>> _lastPredictions = [];
  bool _isClassifying = false;

  // Image picker for gallery selection
  final ImagePicker _imagePicker = ImagePicker();

  // Performance monitoring and analytics services
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final UsageAnalytics _usageAnalytics = UsageAnalytics();
  final ErrorLogger _errorLogger = ErrorLogger();

  // Zoom and focus properties
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  // Existing getters
  CameraController? get cameraController => _cameraController;
  List<CameraDescription> get cameras => _cameras;
  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  bool get isProcessing => _isProcessing;
  String? get lastCapturedImagePath => _lastCapturedImagePath;
  Uint8List? get lastCapturedImageData => _lastCapturedImageData;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  // New getters for plant classification
  List<Map<String, dynamic>> get lastPredictions => _lastPredictions;
  bool get isClassifying => _isClassifying;
  PlantClassifierService get classifierService => _classifierService;
  bool get isClassifierInitialized => _classifierService.isInitialized;

  // Zoom and focus getters
  double get currentZoomLevel => _currentZoomLevel;
  double get minZoomLevel => _minZoomLevel;
  double get maxZoomLevel => _maxZoomLevel;

  CameraProvider() {
    _initializeCamera();
  }

  // Initialize camera
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _initializeCameraController();
      } else {
        _errorMessage = 'No cameras available';
        await _errorLogger.logError(
          ErrorType.cameraError,
          'No cameras available on device',
          context: {'method': '_initializeCamera'},
        );
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to initialize camera: ${e.toString()}';
      await _errorLogger.logError(
        ErrorType.cameraError,
        _errorMessage!,
        stackTrace: stackTrace.toString(),
        context: {'method': '_initializeCamera'},
      );
      notifyListeners();
    }
  }

  // Initialize camera controller
  Future<void> _initializeCameraController() async {
    try {
      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Initialize zoom levels
      _minZoomLevel = await _cameraController!.getMinZoomLevel();
      _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;

      // Set initial flash mode to off for better control
      try {
        await _cameraController!.setFlashMode(FlashMode.off);
      } catch (e) {
        print('Flash not supported on this device: $e');
      }

      _isInitialized = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to initialize camera controller: ${e.toString()}';
      _isInitialized = false;
      await _errorLogger.logError(
        ErrorType.cameraError,
        _errorMessage!,
        stackTrace: stackTrace.toString(),
        context: {'method': '_initializeCameraController'},
      );
      notifyListeners();
    }
  }

  // New method: Initialize classifier
  Future<void> initializeClassifier() async {
    try {
      await _classifierService.loadModels();
      if (!_classifierService.isInitialized) {
        _errorMessage = 'AI models not loaded';
        await _errorLogger.logError(
          ErrorType.aiInferenceError,
          'AI models failed to load',
          context: {'method': 'initializeClassifier'},
        );
      } else {
        _errorMessage = null;
      }

      // Initialize AdaptiveGradCAMService (non-blocking)
      // Initialize asynchronously to not block app startup
      _adaptiveGradCAM.initialize().catchError((e) {
        print('⚠️ Warning: Failed to initialize AdaptiveGradCAMService: $e');
        print('⚠️ App will work in online-only mode if offline fails');
        // Don't fail initialization if GradCAM service fails - it's optional
      });

      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to load AI models: ${e.toString()}';
      await _errorLogger.logError(
        ErrorType.aiInferenceError,
        _errorMessage!,
        stackTrace: stackTrace.toString(),
        context: {'method': 'initializeClassifier'},
      );
      notifyListeners();
    }
  }

  // Capture image
  Future<XFile?> captureImage() async {
    if (!_isInitialized || _cameraController == null) {
      _errorMessage = 'Camera not initialized';
      await _errorLogger.logError(
        ErrorType.cameraError,
        'Attempted to capture image before camera initialization',
        context: {'method': 'captureImage'},
      );
      notifyListeners();
      return null;
    }

    _isCapturing = true;
    notifyListeners();

    // Start performance tracking
    _performanceMonitor.startTimer(PerformanceOperation.imageCapture);

    try {
      final XFile image = await _cameraController!.takePicture();
      _lastCapturedImagePath = image.path;

      // Read image data
      final File imageFile = File(image.path);
      _lastCapturedImageData = await imageFile.readAsBytes();

      // Stop performance tracking
      await _performanceMonitor.stopTimer(PerformanceOperation.imageCapture);

      _isCapturing = false;
      _errorMessage = null;
      notifyListeners();

      return image;
    } catch (e, stackTrace) {
      _isCapturing = false;
      _errorMessage = 'Failed to capture image: ${e.toString()}';
      await _errorLogger.logError(
        ErrorType.cameraError,
        _errorMessage!,
        stackTrace: stackTrace.toString(),
        context: {'method': 'captureImage'},
      );
      notifyListeners();
      return null;
    }
  }

  // Gallery image selection
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        _lastCapturedImagePath = image.path;
        final File imageFile = File(image.path);
        _lastCapturedImageData = await imageFile.readAsBytes();
        notifyListeners();
      }

      return image;
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to pick image: ${e.toString()}';
      await _errorLogger.logError(
        ErrorType.imageProcessingError,
        _errorMessage!,
        stackTrace: stackTrace.toString(),
        context: {'method': 'pickImageFromGallery'},
      );
      notifyListeners();
      return null;
    }
  }

  // Updated method: Process image for AI inference with plant classification
  Future<List<Map<String, dynamic>>> processImageForAI(
      Uint8List imageData) async {
    if (!_classifierService.isInitialized) {
      _errorMessage = 'AI models not loaded';
      await _errorLogger.logError(
        ErrorType.aiInferenceError,
        'Attempted AI inference before models loaded',
        context: {'method': 'processImageForAI'},
      );
      notifyListeners();
      return [];
    }

    _isClassifying = true;
    notifyListeners();

    // Start performance tracking
    _performanceMonitor.startTimer(PerformanceOperation.aiInference);

    try {
      final predictions = await _classifierService.classifyPlant(imageData);
      _lastPredictions = predictions;

      // Stop performance tracking
      await _performanceMonitor.stopTimer(PerformanceOperation.aiInference);

      _isClassifying = false;
      notifyListeners();

      return predictions;
    } catch (e, stackTrace) {
      _isClassifying = false;
      _errorMessage = 'Failed to classify plant: ${e.toString()}';
      await _errorLogger.logError(
        ErrorType.aiInferenceError,
        _errorMessage!,
        stackTrace: stackTrace.toString(),
        context: {'method': 'processImageForAI'},
      );
      notifyListeners();
      return [];
    }
  }

  // Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    final currentIndex = _cameras.indexOf(_cameraController!.description);
    final newIndex = (currentIndex + 1) % _cameras.length;

    await _cameraController!.dispose();
    _cameraController = CameraController(
      _cameras[newIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController!.initialize();
    notifyListeners();
  }

  // Set flash mode
  Future<void> setFlashMode(FlashMode mode) async {
    if (_cameraController != null && _isInitialized) {
      try {
        await _cameraController!.setFlashMode(mode);
        notifyListeners();
      } catch (e) {
        print('Error setting flash mode: $e');
        // Don't throw error, just log it
      }
    }
  }

  // Get current flash mode
  FlashMode get currentFlashMode {
    if (_cameraController != null && _isInitialized) {
      return _cameraController!.value.flashMode;
    }
    return FlashMode.auto;
  }

  // Check if flash is available
  bool get isFlashAvailable {
    if (_cameraController != null && _isInitialized) {
      // Check if flash is available by trying to get the current flash mode
      try {
        _cameraController!.value.flashMode;
        return true; // If we can get the flash mode, flash is available
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  // Get camera resolution
  Size get cameraResolution {
    if (_cameraController != null && _isInitialized) {
      return Size(
        _cameraController!.value.previewSize!.height,
        _cameraController!.value.previewSize!.width,
      );
    }
    return const Size(0, 0);
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear last captured image
  void clearLastCapturedImage() {
    _lastCapturedImagePath = null;
    _lastCapturedImageData = null;
    notifyListeners();
  }

  // Process plant identification with offline support
  Future<List<Map<String, dynamic>>> processPlantIdentification(
    Uint8List imageData, {
    OfflineProvider? offlineProvider,
  }) async {
    // Start performance tracking
    _performanceMonitor.startTimer(PerformanceOperation.aiInference);

    try {
      _isClassifying = true;
      _errorMessage = null;
      notifyListeners();

      List<Map<String, dynamic>> predictions;

      // Use offline processing if available
      if (offlineProvider != null &&
          offlineProvider.isFeatureAvailableOffline('plant_identification')) {
        print('🌿 Processing plant identification offline...');
        predictions = await offlineProvider.processPlantOffline(imageData);
      } else {
        // Fallback to direct classifier service
        print('🌿 Processing plant identification with classifier service...');
        predictions = await _classifierService.classifyPlant(imageData);
      }

      _lastPredictions = predictions;

      // Stop performance tracking
      await _performanceMonitor.stopTimer(PerformanceOperation.aiInference);

      // Track successful scan
      if (predictions.isNotEmpty && predictions.first['confidence'] > 0.5) {
        await _usageAnalytics
            .trackSuccessfulScan(predictions.first['label'] ?? 'Unknown');
      } else {
        await _usageAnalytics.trackFailedScan();
      }

      _isClassifying = false;
      notifyListeners();

      return predictions;
    } catch (e, stackTrace) {
      _isClassifying = false;
      _errorMessage = 'Error processing plant identification: $e';
      await _errorLogger.logError(
        ErrorType.aiInferenceError,
        _errorMessage!,
        stackTrace: stackTrace.toString(),
        context: {'method': 'processPlantIdentification'},
      );
      await _usageAnalytics.trackFailedScan();
      print('❌ Error in plant identification: $e');
      notifyListeners();
      rethrow;
    }
  }

  // Process plant identification with GradCAM visualization
  Future<Map<String, dynamic>> processPlantIdentificationWithGradCAM(
    Uint8List imageData, {
    OfflineProvider? offlineProvider,
  }) async {
    // Start performance tracking for both AI inference and GradCAM
    _performanceMonitor.startTimer(PerformanceOperation.aiInference);
    _performanceMonitor.startTimer(PerformanceOperation.gradcamGeneration);

    try {
      _isClassifying = true;
      _errorMessage = null;
      notifyListeners();

      // Get image path if available (for online mode)
      String? imagePath = _lastCapturedImagePath;

      print('🌿 Processing plant identification with Adaptive Grad-CAM/CAM...');

      // Call AdaptiveGradCAMService
      final adaptiveResult = await _adaptiveGradCAM.identifyPlant(
        imagePath: imagePath,
        imageBytes: imageData,
      );

      if (adaptiveResult == null) {
        throw Exception(
          'Unable to process image. Please check your internet connection or try again later.',
        );
      }

      // Check if service returned an error
      if (adaptiveResult['error'] == true) {
        final errorMessage = adaptiveResult['error_message'] as String?;
        final errorType = adaptiveResult['error_type'] as String?;

        // If offline mode failed and we're offline, try basic classification as fallback
        if (errorType == 'offline_failed' &&
            !_classifierService.isInitialized) {
          // Initialize basic classifier as last resort
          try {
            await _classifierService.loadModels();
          } catch (e) {
            print('⚠️ Basic classifier also failed to initialize: $e');
          }
        }

        // If basic classifier is available, use it as fallback
        if (_classifierService.isInitialized && errorType == 'offline_failed') {
          print(
              '⚠️ Attempting fallback to basic plant classification (without GradCAM)...');
          try {
            final basicPredictions =
                await _classifierService.classifyPlant(imageData);
            if (basicPredictions.isNotEmpty) {
              print('✅ Basic classification succeeded as fallback');
              _lastPredictions = basicPredictions;
              _isClassifying = false;
              notifyListeners();

              await _performanceMonitor
                  .stopTimer(PerformanceOperation.aiInference);

              return {
                'predictions': basicPredictions,
                'gradcam_image': null, // No heatmap available
                'method': 'classification_only', // Indicate no visualization
                'fallback_used': true,
                'processing_time_ms': 0.0,
                'gradCAMPath': null,
                'summaryGradCAMPath': null,
                'note':
                    'Basic classification only. Heatmap visualization unavailable.',
              };
            }
          } catch (e) {
            print('❌ Basic classification fallback also failed: $e');
          }
        }

        // No fallback available, throw error
        throw Exception(
          errorMessage ??
              'Unable to process image. Please enable internet connection or try again later.',
        );
      }

      // Transform response format to match expected structure
      // Safely convert List<dynamic> to List<Map<String, dynamic>>
      List<Map<String, dynamic>> allPredictions = [];
      if (adaptiveResult['all_predictions'] != null) {
        final rawPredictions = adaptiveResult['all_predictions'];
        if (rawPredictions is List) {
          allPredictions = rawPredictions
              .map((item) => item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item))
              .toList()
              .cast<Map<String, dynamic>>();
        }
      }

      // Map predictions to expected format
      final predictions = allPredictions.map((pred) {
        return {
          'label': pred['label'] ?? '',
          'plantName': pred['label'] ?? 'Unknown',
          'confidence': pred['confidence'] ?? 0.0,
          'index': pred['index'] ?? 0,
          'scientificName': pred['scientificName'] ?? '',
          'isDOHApproved': pred['isDOHApproved'] ?? false,
        };
      }).toList();

      _lastPredictions = predictions;

      // Stop performance tracking
      await _performanceMonitor.stopTimer(PerformanceOperation.aiInference);
      await _performanceMonitor
          .stopTimer(PerformanceOperation.gradcamGeneration);

      // Track successful scan
      if (predictions.isNotEmpty && predictions.first['confidence'] > 0.5) {
        await _usageAnalytics
            .trackSuccessfulScan(predictions.first['label'] ?? 'Unknown');
      } else {
        await _usageAnalytics.trackFailedScan();
      }

      _isClassifying = false;
      notifyListeners();

      // Enhanced logging for debugging
      final gradcamImage = adaptiveResult['gradcam_image'];
      var method = adaptiveResult['method'] as String?;
      final fallbackUsed = adaptiveResult['fallback_used'] ?? false;

      // CRITICAL FIX: Ensure method is always set
      // PRIORITY ORDER:
      // 1. If fallback is used, method MUST be 'cam' (offline CAM was attempted)
      // 2. If method is already set and valid, use it
      // 3. Otherwise, infer from heatmap or default
      if (fallbackUsed) {
        // Fallback ALWAYS means offline CAM was attempted
        if (method == null ||
            method.isEmpty ||
            method == 'classification_only') {
          method = 'cam';
          print(
              '🔧 [CameraProvider] FIX: Fallback=true, forcing method to "cam"');
        }
      } else if (method == null || method.isEmpty) {
        // No fallback, determine from heatmap or default
        if (gradcamImage != null) {
          method = 'cam'; // Has heatmap, assume CAM was used
          print(
              '⚠️ [CameraProvider] Method was null but heatmap exists, setting to "cam"');
        } else {
          method = 'classification_only';
          print(
              '⚠️ [CameraProvider] Method was null and no heatmap, setting to "classification_only"');
        }
      }

      print('🔍 [CameraProvider] Final Result from AdaptiveGradCAM:');
      print('   ════════════════════════════════════════════════════════');
      print('   Method: "$method" (final)');
      print('   Fallback used: $fallbackUsed');
      print('   Heatmap present: ${gradcamImage != null}');
      if (gradcamImage != null) {
        print('   Heatmap size: ${(gradcamImage as Uint8List).length} bytes');
      } else {
        print('   ⚠️ WARNING: No heatmap in adaptive result!');
      }
      print('   Predictions count: ${predictions.length}');
      if (predictions.isNotEmpty) {
        final topPred = predictions.first;
        print(
            '   Top prediction: ${topPred['plantName']} (${(topPred['confidence'] * 100).toStringAsFixed(1)}%)');
      }
      print('   ════════════════════════════════════════════════════════');
      // Method is guaranteed to be non-null at this point (set above)
      final willShowByMethod = method != 'classification_only';
      final willShowByFallback = fallbackUsed;
      print('   ✅ Will show AI Explanation (method check): $willShowByMethod');
      print(
          '   ✅ Will show AI Explanation (fallback check): $willShowByFallback');
      print(
          '   ✅ Final decision: ${willShowByMethod || willShowByFallback ? "SHOW TABS" : "NO TABS"}');

      // Return transformed result - ALWAYS include method
      // CRITICAL: Ensure method and fallback are properly set
      return {
        'predictions': predictions,
        'gradcam_image':
            adaptiveResult['gradcam_image'], // Uint8List (may be null)
        'method':
            method, // ALWAYS set: 'grad-cam', 'cam', or 'classification_only'
        'fallback_used': fallbackUsed, // Ensure fallback flag is properly set
        'processing_time_ms': adaptiveResult['processing_time_ms'] ?? 0.0,
        // Keep old format for backward compatibility (deprecated)
        'gradCAMPath': null,
        'summaryGradCAMPath': null,
      };
    } catch (e, stackTrace) {
      _isClassifying = false;
      _errorMessage = 'Error processing plant identification with GradCAM: $e';
      await _errorLogger.logError(
        ErrorType.aiInferenceError,
        _errorMessage!,
        stackTrace: stackTrace.toString(),
        context: {'method': 'processPlantIdentificationWithGradCAM'},
      );
      await _usageAnalytics.trackFailedScan();
      print('❌ Error in plant identification with GradCAM: $e');
      notifyListeners();
      rethrow;
    }
  }

  // Check if offline processing is available
  bool isOfflineProcessingAvailable(OfflineProvider? offlineProvider) {
    if (offlineProvider == null) return false;
    return offlineProvider.isFeatureAvailableOffline('plant_identification');
  }

  // Get processing status message
  String getProcessingStatusMessage(OfflineProvider? offlineProvider) {
    if (_isClassifying) {
      return 'Processing plant identification...';
    }

    if (offlineProvider != null && offlineProvider.isFullyOffline) {
      return 'Offline processing available';
    }

    if (offlineProvider != null && !offlineProvider.isOnline) {
      return 'No internet - using offline mode';
    }

    return 'Ready to identify plants';
  }

  // Zoom control
  Future<void> setZoomLevel(double zoom) async {
    if (_cameraController != null && _isInitialized) {
      final clampedZoom = zoom.clamp(_minZoomLevel, _maxZoomLevel);
      await _cameraController!.setZoomLevel(clampedZoom);
      _currentZoomLevel = clampedZoom;
      notifyListeners();
    }
  }

  // Focus control
  Future<void> setFocusPoint(Offset point) async {
    if (_cameraController != null && _isInitialized) {
      try {
        await _cameraController!.setFocusPoint(point);
        await _cameraController!.setExposurePoint(point);
        notifyListeners();
      } catch (e) {
        print('Focus point error: $e');
      }
    }
  }

  // New method: Clear predictions
  void clearPredictions() {
    _lastPredictions = [];
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
