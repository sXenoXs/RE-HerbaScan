import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:herbascan/core/services/plant_classifier_service.dart';
import 'package:herbascan/core/providers/offline_provider.dart';

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
  List<Map<String, dynamic>> _lastPredictions = [];
  bool _isClassifying = false;
  
  // Image picker for gallery selection
  final ImagePicker _imagePicker = ImagePicker();
  
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
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize camera: ${e.toString()}';
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
    } catch (e) {
      _errorMessage = 'Failed to initialize camera controller: ${e.toString()}';
      _isInitialized = false;
      notifyListeners();
    }
  }
  
  // New method: Initialize classifier
  Future<void> initializeClassifier() async {
    try {
      await _classifierService.loadModels();
      if (!_classifierService.isInitialized) {
        _errorMessage = 'AI models not loaded';
      } else {
        _errorMessage = null;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load AI models: ${e.toString()}';
      notifyListeners();
    }
  }

  // Capture image
  Future<XFile?> captureImage() async {
    if (!_isInitialized || _cameraController == null) {
      _errorMessage = 'Camera not initialized';
      notifyListeners();
      return null;
    }

    _isCapturing = true;
    notifyListeners();

    try {
      final XFile image = await _cameraController!.takePicture();
      _lastCapturedImagePath = image.path;

      // Read image data
      final File imageFile = File(image.path);
      _lastCapturedImageData = await imageFile.readAsBytes();

      _isCapturing = false;
      _errorMessage = null;
      notifyListeners();

      return image;
    } catch (e) {
      _isCapturing = false;
      _errorMessage = 'Failed to capture image: ${e.toString()}';
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
    } catch (e) {
      _errorMessage = 'Failed to pick image: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  // Updated method: Process image for AI inference with plant classification
  Future<List<Map<String, dynamic>>> processImageForAI(Uint8List imageData) async {
    if (!_classifierService.isInitialized) {
      _errorMessage = 'AI models not loaded';
      notifyListeners();
      return [];
    }
    
    _isClassifying = true;
    notifyListeners();
    
    try {
      final predictions = await _classifierService.classifyPlant(imageData);
      _lastPredictions = predictions;
      _isClassifying = false;
      notifyListeners();
      
      return predictions;
    } catch (e) {
      _isClassifying = false;
      _errorMessage = 'Failed to classify plant: ${e.toString()}';
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
    try {
      _isClassifying = true;
      _errorMessage = null;
      notifyListeners();

      List<Map<String, dynamic>> predictions;

      // Use offline processing if available
      if (offlineProvider != null && offlineProvider.isFeatureAvailableOffline('plant_identification')) {
        print('🌿 Processing plant identification offline...');
        predictions = await offlineProvider.processPlantOffline(imageData);
      } else {
        // Fallback to direct classifier service
        print('🌿 Processing plant identification with classifier service...');
        predictions = await _classifierService.classifyPlant(imageData);
      }

      _lastPredictions = predictions;
      _isClassifying = false;
      notifyListeners();

      return predictions;
    } catch (e) {
      _isClassifying = false;
      _errorMessage = 'Error processing plant identification: $e';
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
    try {
      _isClassifying = true;
      _errorMessage = null;
      notifyListeners();

      Map<String, dynamic> result;

      // Always use classifier service with GradCAM for now
      // Offline processing can be added later with GradCAM support
      print('🌿 Processing plant identification with GradCAM...');
      result = await _classifierService.classifyPlantWithGradCAM(imageData);

      _lastPredictions = result['predictions'] as List<Map<String, dynamic>>;
      _isClassifying = false;
      notifyListeners();

      return result;
    } catch (e) {
      _isClassifying = false;
      _errorMessage = 'Error processing plant identification with GradCAM: $e';
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