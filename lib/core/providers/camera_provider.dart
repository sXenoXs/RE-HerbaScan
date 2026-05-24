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
class CameraProvider extends ChangeNotifier {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isWindowsDesktop = false;
  bool _isCapturing = false;
  final bool _isProcessing = false;
  String? _lastCapturedImagePath;
  Uint8List? _lastCapturedImageData;
  String? _errorMessage;

  final TflitePlantService _tfliteService = TflitePlantService();

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
  bool get isWindowsDesktop => _isWindowsDesktop;

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
    if (Platform.isWindows) {
      _isWindowsDesktop = true;
      _isInitialized = true;
      notifyListeners();
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _initializeCameraController();
      } else {
        _errorMessage = 'No cameras available';
        await _errorLogger.logError(
            ErrorType.cameraError, 'No cameras available',
            context: {'method': '_initializeCamera'});
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to initialize camera: $e';
      await _errorLogger.logError(ErrorType.cameraError, _errorMessage!,
          stackTrace: stackTrace.toString());
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
      await _errorLogger.logError(ErrorType.cameraError, _errorMessage!,
          stackTrace: stackTrace.toString());
      notifyListeners();
    }
  }

  // --- CHANGED: Initialize TFLite Model ---
  Future<void> initializeClassifier() async {
    try {
      print(" Loading TFLite Model...");
      await _tfliteService.loadModel();

      _errorMessage = null;
      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to load AI models: $e';
      await _errorLogger.logError(ErrorType.aiInferenceError, _errorMessage!,
          stackTrace: stackTrace.toString());
      notifyListeners();
    }
  }

  Future<XFile?> captureImage() async {
    if (_isWindowsDesktop) return pickImageFromGallery();
    if (!_isInitialized || _cameraController == null) {
      _errorMessage = 'Camera not initialized';
      notifyListeners();
      return null;
    }

    _isCapturing = true;
    Future.microtask(notifyListeners);
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
      await _errorLogger.logError(ErrorType.cameraError, _errorMessage!,
          stackTrace: stackTrace.toString());
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
      await _errorLogger.logError(
          ErrorType.imageProcessingError, _errorMessage!,
          stackTrace: stackTrace.toString());
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
    final tempFile = File(
        '${tempDir.path}/temp_scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(imageData);
    return tempFile;
  }

  // --- CHANGED: Unified AI Processing Logic using TFLite ---
  Future<List<Map<String, dynamic>>> processImageForAI(
      Uint8List imageData) async {
    print("🔍 [CameraProvider] processImageForAI() called");
    print("   Image data: ${imageData.length} bytes");
    _isClassifying = true;
    Future.microtask(notifyListeners);
    _performanceMonitor.startTimer(PerformanceOperation.aiInference);

    try {
      final imageFile = await _getImageFileForTflite(imageData);
      print("   📁 Image file: ${imageFile.path}");

      // CALL YOUR TFLITE SERVICE
      print("   🚀 Calling TFLite service predict()...");
      final prediction = await _tfliteService.predict(imageFile);
      print(
          "   📊 Prediction result: ${prediction != null ? "${prediction.label} (${(prediction.confidence * 100).toStringAsFixed(2)}%)" : "null"}");

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
      await _errorLogger.logError(ErrorType.aiInferenceError, _errorMessage!,
          stackTrace: stackTrace.toString());
      notifyListeners();
      return [];
    }
  }

  // Main method called by UI — offline TFLite inference only (no GradCAM)
  Future<Map<String, dynamic>> processPlantIdentificationWithGradCAM(
    Uint8List imageData, {
    OfflineProvider? offlineProvider,
  }) async {
    _isClassifying = true;
    _errorMessage = null;
    Future.microtask(notifyListeners);
    _performanceMonitor.startTimer(PerformanceOperation.aiInference);

    try {
      final imageFile = await _getImageFileForTflite(imageData);

      final topK = await _tfliteService.predictTopK(imageFile, k: 3);
      await _performanceMonitor.stopTimer(PerformanceOperation.aiInference);

      // OOD rejection: top prediction is Not_Plant
      if (topK.isNotEmpty && topK.first.label == 'Not_Plant') {
        _isClassifying = false;
        notifyListeners();
        return {
          'validation_failed': true,
          'failure_reason': 'Validation Failed: Subject unrecognized or not a plant.',
          'stage': 2,
        };
      }

      if (topK.isEmpty) {
        throw Exception('Model could not identify image.');
      }

      final predictions = topK.asMap().entries.map((e) => {
        'label': e.value.label,
        'plantName': e.value.label,
        'scientificName': e.value.label,
        'confidence': e.value.confidence,
        'index': e.key,
        'isDOHApproved': false,
      }).toList();

      _lastPredictions = predictions;

      final confidence = predictions[0]['confidence'] as double;
      final plantName = predictions[0]['plantName'] as String? ?? 'Unknown';
      if (confidence > 0.5) {
        await _usageAnalytics.trackSuccessfulScan(plantName);
      } else {
        await _usageAnalytics.trackFailedScan();
      }

      _isClassifying = false;
      notifyListeners();

      return {
        'predictions': predictions,
        'gradcam_image': null,
        'method': 'classification_only',
        'fallback_used': false,
        'processing_time_ms': 0.0,
        'gradCAMPath': null,
        'summaryGradCAMPath': null,
        'validation_failed': false,
      };
    } catch (e, stackTrace) {
      _isClassifying = false;
      _errorMessage = 'Error processing: $e';
      await _errorLogger.logError(ErrorType.aiInferenceError, _errorMessage!,
          stackTrace: stackTrace.toString());
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
      } catch (e) {
        print(e);
      }
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
      } catch (e) {
        print(e);
      }
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
