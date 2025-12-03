import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // REQUIRED: To create temp files for TFLite

// --- NEW IMPORT: Your TFLite Service ---
import 'package:herbascan/core/services/tflite_plant_service.dart';

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

  // --- CHANGED: Use TflitePlantService instead of PlantClassifierService ---
  final TflitePlantService _tfliteService = TflitePlantService();

  // Keep this if you still want online capabilities as backup
  final AdaptiveGradCAMService _adaptiveGradCAM = AdaptiveGradCAMService();

  List<Map<String, dynamic>> _lastPredictions = [];
  bool _isClassifying = false;

  final ImagePicker _imagePicker = ImagePicker();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final UsageAnalytics _usageAnalytics = UsageAnalytics();
  final ErrorLogger _errorLogger = ErrorLogger();

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  // Getters
  CameraController? get cameraController => _cameraController;
  List<CameraDescription> get cameras => _cameras;
  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  bool get isProcessing => _isProcessing;
  String? get lastCapturedImagePath => _lastCapturedImagePath;
  Uint8List? get lastCapturedImageData => _lastCapturedImageData;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  List<Map<String, dynamic>> get lastPredictions => _lastPredictions;
  bool get isClassifying => _isClassifying;

  // Replaced getter: TFLite manages its own state, assume initialized after loadModel call
  bool get isClassifierInitialized => true;

  double get currentZoomLevel => _currentZoomLevel;
  double get minZoomLevel => _minZoomLevel;
  double get maxZoomLevel => _maxZoomLevel;

  CameraProvider() {
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _initializeCameraController();
      } else {
        _errorMessage = 'No cameras available';
        await _errorLogger.logError(ErrorType.cameraError, 'No cameras available', context: {'method': '_initializeCamera'});
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to initialize camera: $e';
      await _errorLogger.logError(ErrorType.cameraError, _errorMessage!, stackTrace: stackTrace.toString());
      notifyListeners();
    }
  }

  Future<void> _initializeCameraController() async {
    try {
      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      _minZoomLevel = await _cameraController!.getMinZoomLevel();
      _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;

      try {
        await _cameraController!.setFlashMode(FlashMode.off);
      } catch (e) {
        print('Flash not supported: $e');
      }

      _isInitialized = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to initialize camera controller: $e';
      _isInitialized = false;
      await _errorLogger.logError(ErrorType.cameraError, _errorMessage!, stackTrace: stackTrace.toString());
      notifyListeners();
    }
  }

  // --- CHANGED: Initialize TFLite Model ---
  Future<void> initializeClassifier() async {
    try {
      print("🚀 Loading TFLite Model...");
      await _tfliteService.loadModel();

      _errorMessage = null;

      // Initialize AdaptiveGradCAMService asynchronously (optional)
      _adaptiveGradCAM.initialize().catchError((e) {
        print('⚠️ Warning: Failed to initialize Online Service (that is okay, using Offline TFLite): $e');
      });

      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to load AI models: $e';
      await _errorLogger.logError(ErrorType.aiInferenceError, _errorMessage!, stackTrace: stackTrace.toString());
      notifyListeners();
    }
  }

  Future<XFile?> captureImage() async {
    if (!_isInitialized || _cameraController == null) {
      _errorMessage = 'Camera not initialized';
      notifyListeners();
      return null;
    }

    _isCapturing = true;
    notifyListeners();
    _performanceMonitor.startTimer(PerformanceOperation.imageCapture);

    try {
      final XFile image = await _cameraController!.takePicture();
      _lastCapturedImagePath = image.path;
      final File imageFile = File(image.path);
      _lastCapturedImageData = await imageFile.readAsBytes();

      await _performanceMonitor.stopTimer(PerformanceOperation.imageCapture);

      _isCapturing = false;
      _errorMessage = null;
      notifyListeners();

      return image;
    } catch (e, stackTrace) {
      _isCapturing = false;
      _errorMessage = 'Failed to capture image: $e';
      await _errorLogger.logError(ErrorType.cameraError, _errorMessage!, stackTrace: stackTrace.toString());
      notifyListeners();
      return null;
    }
  }

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
      _errorMessage = 'Failed to pick image: $e';
      await _errorLogger.logError(ErrorType.imageProcessingError, _errorMessage!, stackTrace: stackTrace.toString());
      notifyListeners();
      return null;
    }
  }

  // Helper to convert Uint8List to File (Needed for TFLite)
  Future<File> _getImageFileForTflite(Uint8List imageData) async {
    if (_lastCapturedImagePath != null) {
      return File(_lastCapturedImagePath!);
    }
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(imageData);
    return tempFile;
  }

  // --- CHANGED: Unified AI Processing Logic using TFLite ---
  Future<List<Map<String, dynamic>>> processImageForAI(Uint8List imageData) async {
    _isClassifying = true;
    notifyListeners();
    _performanceMonitor.startTimer(PerformanceOperation.aiInference);

    try {
      final imageFile = await _getImageFileForTflite(imageData);

      // CALL YOUR TFLITE SERVICE
      final prediction = await _tfliteService.predict(imageFile);

      List<Map<String, dynamic>> resultList = [];
      if (prediction != null) {
        resultList.add({
          'label': prediction.label,
          'plantName': prediction.label,
          'scientificName': prediction.label,
          'confidence': prediction.confidence,
          'index': 0,
          'isDOHApproved': false, // Add lookup logic later if needed
        });
      }

      _lastPredictions = resultList;
      await _performanceMonitor.stopTimer(PerformanceOperation.aiInference);

      _isClassifying = false;
      notifyListeners();
      return resultList;

    } catch (e, stackTrace) {
      _isClassifying = false;
      _errorMessage = 'Classification failed: $e';
      await _errorLogger.logError(ErrorType.aiInferenceError, _errorMessage!, stackTrace: stackTrace.toString());
      notifyListeners();
      return [];
    }
  }

  // --- CHANGED: Main method called by UI ---
  // Replaces the complex GradCAM logic with a direct TFLite call
  Future<Map<String, dynamic>> processPlantIdentificationWithGradCAM(
      Uint8List imageData, {
        OfflineProvider? offlineProvider,
      }) async {
    _isClassifying = true;
    _errorMessage = null;
    notifyListeners();
    _performanceMonitor.startTimer(PerformanceOperation.aiInference);

    try {
      print('🌿 Processing with TFLite (Offline)...');

      // 1. Get File
      final imageFile = await _getImageFileForTflite(imageData);

      // 2. Predict
      final tfliteResult = await _tfliteService.predict(imageFile);

      if (tfliteResult == null) {
        throw Exception("Model could not identify image.");
      }

      print('✅ TFLite Result: ${tfliteResult.label} (${(tfliteResult.confidence * 100).toStringAsFixed(1)}%)');

      // 3. Map Result
      final predictions = [{
        'label': tfliteResult.label,
        'plantName': tfliteResult.label,
        'scientificName': tfliteResult.label,
        'confidence': tfliteResult.confidence,
        'index': 0,
        'isDOHApproved': false,
      }];

      _lastPredictions = predictions;

      await _performanceMonitor.stopTimer(PerformanceOperation.aiInference);

      if (tfliteResult.confidence > 0.5) {
        await _usageAnalytics.trackSuccessfulScan(tfliteResult.label);
      } else {
        await _usageAnalytics.trackFailedScan();
      }

      _isClassifying = false;
      notifyListeners();

      // 4. Return formatted response
      // Note: TFLite doesn't generate heatmaps (gradcam_image is null)
      return {
        'predictions': predictions,
        'gradcam_image': null,
        'method': 'tflite_offline', // Tells UI this was an offline scan
        'fallback_used': true,
        'processing_time_ms': 0.0,
        'gradCAMPath': null,
        'summaryGradCAMPath': null,
      };

    } catch (e, stackTrace) {
      _isClassifying = false;
      _errorMessage = 'Error processing: $e';
      await _errorLogger.logError(ErrorType.aiInferenceError, _errorMessage!, stackTrace: stackTrace.toString());
      notifyListeners();
      rethrow;
    }
  }

  // Wrapper for consistency
  Future<List<Map<String, dynamic>>> processPlantIdentification(
      Uint8List imageData, {
        OfflineProvider? offlineProvider,
      }) async {
    return processImageForAI(imageData);
  }

  // --- Existing Utility Methods ---
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

  Future<void> setFlashMode(FlashMode mode) async {
    if (_cameraController != null && _isInitialized) {
      try {
        await _cameraController!.setFlashMode(mode);
        notifyListeners();
      } catch (e) { print(e); }
    }
  }

  FlashMode get currentFlashMode {
    if (_cameraController != null && _isInitialized) {
      return _cameraController!.value.flashMode;
    }
    return FlashMode.auto;
  }

  bool get isFlashAvailable => true;

  Size get cameraResolution {
    if (_cameraController != null && _isInitialized) {
      return Size(
        _cameraController!.value.previewSize!.height,
        _cameraController!.value.previewSize!.width,
      );
    }
    return const Size(0, 0);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearLastCapturedImage() {
    _lastCapturedImagePath = null;
    _lastCapturedImageData = null;
    notifyListeners();
  }

  bool isOfflineProcessingAvailable(OfflineProvider? offlineProvider) {
    return true; // Always true now!
  }

  String getProcessingStatusMessage(OfflineProvider? offlineProvider) {
    if (_isClassifying) return 'Analyzing plant...';
    return 'Ready to scan';
  }

  Future<void> setZoomLevel(double zoom) async {
    if (_cameraController != null && _isInitialized) {
      final clampedZoom = zoom.clamp(_minZoomLevel, _maxZoomLevel);
      await _cameraController!.setZoomLevel(clampedZoom);
      _currentZoomLevel = clampedZoom;
      notifyListeners();
    }
  }

  Future<void> setFocusPoint(Offset point) async {
    if (_cameraController != null && _isInitialized) {
      try {
        await _cameraController!.setFocusPoint(point);
        await _cameraController!.setExposurePoint(point);
      } catch (e) { print(e); }
    }
  }

  void clearPredictions() {
    _lastPredictions = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tfliteService.close(); // IMPORTANT: Close TFLite
    super.dispose();
  }
}