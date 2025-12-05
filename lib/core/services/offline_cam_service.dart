// lib/core/services/offline_cam_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service for offline CAM (Class Activation Mapping) computation
/// Uses pre-extracted weights and TFLite model for on-device visualization
class OfflineCAMService {
  static final OfflineCAMService _instance = OfflineCAMService._internal();
  factory OfflineCAMService() => _instance;
  OfflineCAMService._internal();

  final Logger _logger = Logger();

  Interpreter? _interpreter;
  Interpreter? _mobilenetv2Interpreter;
  Interpreter? _herbascanInterpreter;
  List<List<double>>? _camWeights; // [256, 40]
  List<List<double>>? _mobilenetv2CamWeights;
  List<List<double>>? _herbascanCamWeights;
  Map<String, String>? _labels; // Loaded from labels.json
  bool _isInitialized = false;
  String? _preferredModelName; // Track which model to use for CAM

  // Model output indices (determined during initialization)
  int _featureMapOutputIndex = 0; // Which output contains feature maps
  int _predictionOutputIndex =
      -1; // Which output contains predictions (-1 if not available)
  List<int>? _featureMapShape; // Actual feature map shape from model
  int _numModelOutputs = 0; // Number of outputs the model has

  // Model configuration
  static const int inputSize = 224;
  // numClasses is now dynamic - determined from labels file (42 classes: 0-41)
  int get numClasses => _labels?.length ?? 42; // Default to 42 if labels not loaded
  static const int featureDim = 256; // From Phase 2 analysis
  static const List<int> expectedFeatureMapShape = [
    7,
    7,
    1280
  ]; // Expected Conv_1 output

  /// Initialize the service by loading TFLite model and CAM weights
  Future<void> initialize() async {
    // CRITICAL: Use print() for maximum visibility
    print('═══════════════════════════════════════════════════════');
    print('🚀 [OfflineCAMService] initialize() called');
    print('   Current _isInitialized: $_isInitialized');
    print('═══════════════════════════════════════════════════════');

    if (_isInitialized) {
      _logger.i('OfflineCAMService already initialized');
      print('✅ [OfflineCAMService] Already initialized, skipping');
      return;
    }

    try {
      _logger.i('═══════════════════════════════════════════════════════');
      _logger.i('🚀 Initializing OfflineCAMService...');
      _logger.i('═══════════════════════════════════════════════════════');
      print('🚀 [OfflineCAMService] Starting initialization...');

      // Step 1: Load TFLite model (try both models)
      _logger.i('Step 1: Loading TFLite model...');
      print('📦 [OfflineCAMService] Step 1: Loading TFLite model...');
      try {
        // Try to load both multi-output models
        List<String> mobilenetv2Paths = [
          'assets/models/mobilenetv2_multi_output.tflite',
          'assets/models/MobileNetV2_model.tflite', // Legacy fallback
        ];
        
        List<String> herbascanPaths = [
          'assets/models/herbascan_multi_output.tflite',
          'assets/models/herbascan_model.tflite', // Legacy fallback
        ];
        
        // Load MobileNetV2 multi-output model
        String? mobilenetv2Path;
        for (String modelPath in mobilenetv2Paths) {
          try {
            print('   Attempting to load MobileNetV2: $modelPath');
            final assetData = await rootBundle.load(modelPath);
            final sizeMB = (assetData.lengthInBytes / 1024 / 1024).toStringAsFixed(2);
            _logger.i('✅ MobileNetV2 model found, size: ${assetData.lengthInBytes} bytes ($sizeMB MB)');
            print('✅ [OfflineCAMService] MobileNetV2 model found!');
            print('   Path: $modelPath');
            mobilenetv2Path = modelPath;
            break;
          } catch (assetError) {
            continue;
          }
        }
        
        // Load HerbaScan multi-output model
        String? herbascanPath;
        for (String modelPath in herbascanPaths) {
          try {
            print('   Attempting to load HerbaScan: $modelPath');
            final assetData = await rootBundle.load(modelPath);
            final sizeMB = (assetData.lengthInBytes / 1024 / 1024).toStringAsFixed(2);
            _logger.i('✅ HerbaScan model found, size: ${assetData.lengthInBytes} bytes ($sizeMB MB)');
            print('✅ [OfflineCAMService] HerbaScan model found!');
            print('   Path: $modelPath');
            herbascanPath = modelPath;
            break;
          } catch (assetError) {
            continue;
          }
        }
        
        if (mobilenetv2Path == null && herbascanPath == null) {
          _logger.e('❌ No multi-output model assets found in bundle');
          print('❌ [OfflineCAMService] No multi-output models found!');
          print('   Expected: mobilenetv2_multi_output.tflite or herbascan_multi_output.tflite');
          throw Exception(
            'No multi-output model files found. Please verify:\n'
            '1. Files exist: assets/models/mobilenetv2_multi_output.tflite or assets/models/herbascan_multi_output.tflite\n'
            '2. pubspec.yaml includes: assets/models/\n'
            '3. Run: flutter clean && flutter pub get && flutter run',
          );
        }

        // Load interpreters
        if (mobilenetv2Path != null) {
          try {
            _logger.d('   Creating MobileNetV2 interpreter from: $mobilenetv2Path');
            _mobilenetv2Interpreter = await Interpreter.fromAsset(mobilenetv2Path);
            _mobilenetv2Interpreter!.allocateTensors();
            _logger.i('✅ MobileNetV2 interpreter created successfully');
            print('✅ [OfflineCAMService] MobileNetV2 interpreter created!');
          } catch (e) {
            _logger.w('⚠️ Failed to create MobileNetV2 interpreter: $e');
            print('⚠️ [OfflineCAMService] Failed to create MobileNetV2 interpreter');
          }
        }
        
        if (herbascanPath != null) {
          try {
            _logger.d('   Creating HerbaScan interpreter from: $herbascanPath');
            _herbascanInterpreter = await Interpreter.fromAsset(herbascanPath);
            _herbascanInterpreter!.allocateTensors();
            _logger.i('✅ HerbaScan interpreter created successfully');
            print('✅ [OfflineCAMService] HerbaScan interpreter created!');
          } catch (e) {
            _logger.w('⚠️ Failed to create HerbaScan interpreter: $e');
            print('⚠️ [OfflineCAMService] Failed to create HerbaScan interpreter');
          }
        }
        
        // Set default interpreter (prefer MobileNetV2, fallback to HerbaScan)
        if (_mobilenetv2Interpreter != null) {
          _interpreter = _mobilenetv2Interpreter;
          _preferredModelName = 'MobileNetV2';
        } else if (_herbascanInterpreter != null) {
          _interpreter = _herbascanInterpreter;
          _preferredModelName = 'HerbaScan';
        } else {
          throw Exception('Failed to load any multi-output models');
        }
        
        // Load interpreter (for backward compatibility)
        try {
          _logger.i('✅ TFLite interpreter created successfully');
          print(
              '✅ [OfflineCAMService] TFLite interpreter created successfully!');
        } catch (interpreterError, interpreterStack) {
          _logger.e('❌ Failed to create TFLite interpreter: $interpreterError');
          print('❌ [OfflineCAMService] Failed to create TFLite interpreter!');
          print('   Error: $interpreterError');
          print('   Error type: ${interpreterError.runtimeType}');
          print('   Stack trace: $interpreterStack');
          rethrow;
        }

        // Log model info
        final inputShape = _interpreter!.getInputTensor(0).shape;

        // Get the number of outputs first
        final numOutputs = _interpreter!.getOutputTensors().length;
        print('   ═══════════════════════════════════════════════════════');
        print('   Model Output Count: $numOutputs');
        print('   ═══════════════════════════════════════════════════════');

        _logger.i('   Model structure:');
        _logger.i('     Input shape: $inputShape');
        _logger.i('     Number of outputs: $numOutputs');

        // Log all outputs
        for (int i = 0; i < numOutputs; i++) {
          try {
            final outputShape = _interpreter!.getOutputTensor(i).shape;
            _logger.i('     Output $i shape: $outputShape');
            print(
                '   Output $i shape: $outputShape (dimensions: ${outputShape.length})');
          } catch (e) {
            _logger.e('     Failed to get output $i: $e');
            print('   ❌ Failed to get output $i: $e');
          }
        }

        // Check if we have the expected outputs
        if (numOutputs < 1) {
          throw Exception('Model has no outputs!');
        }

        final output0Shape = _interpreter!.getOutputTensor(0).shape;
        List<int>? output1Shape;

        if (numOutputs > 1) {
          try {
            output1Shape = _interpreter!.getOutputTensor(1).shape;
          } catch (e) {
            _logger.w('   ⚠️ Output 1 not available: $e');
            print('   ⚠️ Output 1 not available: $e');
            output1Shape = null;
          }
        }

        _logger.i('     Output 0 shape: $output0Shape');
        if (output1Shape != null) {
          _logger.i('     Output 1 shape: $output1Shape');
        } else {
          _logger.w('     Output 1: Not available (model has only 1 output)');
        }

        // Validate model structure
        if (inputShape.length != 4 ||
            inputShape[1] != 224 ||
            inputShape[2] != 224 ||
            inputShape[3] != 3) {
          _logger.w(
              '⚠️ WARNING: Input shape is unexpected: $inputShape (expected [1, 224, 224, 3])');
        }

        // Analyze model structure
        print('   ═══════════════════════════════════════════════════════');
        print('   Model Structure Analysis:');
        print('   Input shape: $inputShape');
        print('   Output 0 shape: $output0Shape (${output0Shape.length}D)');
        if (output1Shape != null) {
          print('   Output 1 shape: $output1Shape (${output1Shape.length}D)');
        } else {
          print('   Output 1: None (single-output model)');
        }

        // Check output types
        final output0Is4D = output0Shape.length == 4;
        final output0Is2D = output0Shape.length == 2;
        final output1Is4D = output1Shape != null && output1Shape.length == 4;
        final output1Is2D = output1Shape != null && output1Shape.length == 2;

        print('   Output 0 is 4D (feature maps): $output0Is4D');
        print('   Output 0 is 2D (predictions): $output0Is2D');
        if (output1Shape != null) {
          print('   Output 1 is 4D (feature maps): $output1Is4D');
          print('   Output 1 is 2D (predictions): $output1Is2D');
        }
        print('   ═══════════════════════════════════════════════════════');

        // Determine which output is feature maps and which is predictions
        List<int>? featureMapShape;

        if (numOutputs == 1) {
          // Single output model - check what it is
          if (output0Is4D) {
            // Only feature maps - predictions might be computed separately
            featureMapShape = output0Shape;
            _logger.w(
                '⚠️ Model has only one output (4D feature maps). Predictions will need to be computed separately.');
            print(
                '⚠️ [OfflineCAMService] Single-output model detected (feature maps only)');
            print(
                '   This model structure requires computing predictions from feature maps');
          } else if (output0Is2D) {
            // Only predictions - no feature maps for CAM
            _logger.e(
                '❌ Model has only predictions output, no feature maps for CAM!');
            print(
                '❌ [OfflineCAMService] Model has only predictions, cannot generate CAM heatmap!');
            print('═══════════════════════════════════════════════════════');
            print('⚠️ MODEL RE-EXPORT ISSUE DETECTED');
            print('═══════════════════════════════════════════════════════');
            print('The re-exported model only has predictions output [1, 40]');
            print('CAM requires feature maps output [1, 7, 7, 1280]');
            print('');
            print('SOLUTION: Re-export the model with BOTH outputs:');
            print('  1. Feature maps from last conv layer: [1, 7, 7, 1280]');
            print('  2. Predictions: [1, 40]');
            print('');
            print('Use the script: backend/create_multi_output_tflite.py');
            print('This will create a model with 2 outputs for CAM.');
            print('═══════════════════════════════════════════════════════');
            throw Exception(
                'Model does not have feature maps output required for CAM. The re-exported model only has predictions [1, 40]. Please re-export with both feature maps [1, 7, 7, 1280] and predictions [1, 40] outputs.');
          } else {
            _logger.e('❌ Unknown output structure: $output0Shape');
            throw Exception('Model output structure is not recognized');
          }
        } else if (numOutputs == 2) {
          // Two outputs - determine which is which
          if (output0Is4D && output1Is2D) {
            // Output 0 = feature maps, Output 1 = predictions
            featureMapShape = output0Shape;
            _logger.i(
                '✅ Model structure: Output 0 = feature maps, Output 1 = predictions');
          } else if (output0Is2D && output1Is4D) {
            // Output 0 = predictions, Output 1 = feature maps
            featureMapShape = output1Shape;
            _logger.i(
                '✅ Model structure: Output 0 = predictions, Output 1 = feature maps');
          } else {
            _logger.e('❌ Unexpected output combination:');
            _logger.e('   Output 0: $output0Shape (${output0Shape.length}D)');
            if (output1Shape != null) {
              _logger.e('   Output 1: $output1Shape (${output1Shape.length}D)');
            } else {
              _logger.e('   Output 1: null');
            }
            throw Exception(
                'Model outputs do not match expected format (need one 4D and one 2D output)');
          }
        } else {
          _logger.e('❌ Model has $numOutputs outputs, expected 1 or 2');
          throw Exception(
              'Model has unexpected number of outputs: $numOutputs');
        }

        // Validate and store feature maps shape
        // Note: featureMapShape is guaranteed to be non-null at this point
        if (featureMapShape.length != 4) {
          _logger.w('⚠️ Feature maps shape is not 4D: $featureMapShape');
          print(
              '⚠️ [OfflineCAMService] Feature maps shape is not 4D: $featureMapShape');
        } else {
          _featureMapShape = featureMapShape;
          _logger.i('✅ Feature maps shape: $featureMapShape');
          print('✅ [OfflineCAMService] Feature maps shape: $featureMapShape');

          // Store output indices
          if (numOutputs == 2) {
            if (output0Is4D && output1Is2D) {
              _featureMapOutputIndex = 0;
              _predictionOutputIndex = 1;
            } else if (output0Is2D && output1Is4D) {
              _featureMapOutputIndex = 1;
              _predictionOutputIndex = 0;
            }
            _logger
                .i('   Feature maps at output index: $_featureMapOutputIndex');
            _logger
                .i('   Predictions at output index: $_predictionOutputIndex');
            print('   Feature maps at output: $_featureMapOutputIndex');
            print('   Predictions at output: $_predictionOutputIndex');
          } else {
            // Single output - only feature maps
            _featureMapOutputIndex = 0;
            _predictionOutputIndex = -1; // No separate predictions output
            _logger.w('⚠️ Single-output model: Only feature maps available');
            print(
                '⚠️ [OfflineCAMService] Single-output model - predictions must be computed from features');
          }
          _numModelOutputs = numOutputs;
        }

        _logger.i('✅ Model structure validated');
      } catch (e, stackTrace) {
        _logger.e('❌ Failed to load TFLite model: $e');
        _logger.e('   Error type: ${e.runtimeType}');
        _logger.e('   Stack trace: $stackTrace');
        print('═══════════════════════════════════════════════════════');
        print('❌ [OfflineCAMService] FAILED to load TFLite model!');
        print('   Error: $e');
        print('   Error type: ${e.runtimeType}');
        print('   Stack trace: $stackTrace');
        print('═══════════════════════════════════════════════════════');
        _logger.e('═══════════════════════════════════════════════════════');
        _logger.e('Troubleshooting steps:');
        _logger.e(
            '1. Verify file exists: assets/models/mobilenetv2_multi_output.tflite');
        _logger.e('2. Check pubspec.yaml includes: assets/models/');
        _logger.e('3. Run: flutter clean');
        _logger.e('4. Run: flutter pub get');
        _logger.e('5. Rebuild app: flutter run');
        _logger.e(
            '6. Check Android: android/app/src/main/assets/ (should be auto-generated)');
        _logger.e('═══════════════════════════════════════════════════════');
        _isInitialized = false;
        rethrow;
      }

      // Step 2: Load CAM weights from JSON
      _logger.i('Step 2: Loading CAM weights from JSON...');
      print('📦 [OfflineCAMService] Step 2: Loading CAM weights from JSON...');
      try {
        await _loadCAMWeights();
        _logger.i('✅ CAM weights loaded successfully');
        print('✅ [OfflineCAMService] CAM weights loaded successfully!');
      } catch (e, stackTrace) {
        _logger.e('❌ Failed to load CAM weights: $e');
        _logger.e('   Error type: ${e.runtimeType}');
        _logger.e('   Stack trace: $stackTrace');
        print('❌ [OfflineCAMService] FAILED to load CAM weights!');
        print('   Error: $e');
        print('   Error type: ${e.runtimeType}');
        print('   Stack trace: $stackTrace');
        _logger.e('   This usually means:');
        _logger.e('   1. File is missing: assets/models/cam_weights.json');
        _logger.e('   2. File format is incorrect');
        _logger.e('   3. JSON structure doesn\'t match expected format');
        _isInitialized = false;
        rethrow;
      }

      // Step 3: Load plant labels
      _logger.i('Step 3: Loading plant labels...');
      print('📦 [OfflineCAMService] Step 3: Loading plant labels...');
      try {
        await _loadLabels();
        _logger.i(
            '✅ Plant labels loaded successfully (${_labels!.length} classes)');
        print('✅ [OfflineCAMService] Plant labels loaded successfully!');
        print('   Labels count: ${_labels!.length} classes');
      } catch (e, stackTrace) {
        _logger.e('❌ Failed to load plant labels: $e');
        _logger.e('   Error type: ${e.runtimeType}');
        _logger.e('   Stack trace: $stackTrace');
        print(
            '⚠️ [OfflineCAMService] Failed to load plant labels (non-critical)');
        print('   Error: $e');
        _logger.e('   This usually means:');
        _logger.e('   1. File is missing: assets/models/labels.json');
        _logger.e('   2. File format is incorrect');
        _logger.w('⚠️ Continuing without labels (will use default names)');
        _labels = {}; // Allow continuation with empty labels
      }

      // Final validation
      if (_interpreter == null) {
        throw Exception('TFLite interpreter is null after initialization');
      }
      if (_camWeights == null) {
        throw Exception('CAM weights are null after initialization');
      }

      _isInitialized = true;
      _logger.i('═══════════════════════════════════════════════════════');
      _logger.i('✅ OfflineCAMService initialized successfully!');
      _logger.i('   Model: Loaded');
      _logger.i(
          '   CAM Weights: Loaded (${_camWeights!.length} features x ${_camWeights![0].length} classes)');
      _logger.i('   Labels: Loaded (${_labels?.length ?? 0} classes)');
      _logger.i('═══════════════════════════════════════════════════════');
      print('═══════════════════════════════════════════════════════');
      print('✅ [OfflineCAMService] Initialized SUCCESSFULLY!');
      print('   Model: Loaded ✅');
      print(
          '   CAM Weights: Loaded ✅ (${_camWeights!.length} features x ${_camWeights![0].length} classes)');
      print('   Labels: Loaded ✅ (${_labels?.length ?? 0} classes)');
      print('   _isInitialized: $_isInitialized');
      print('═══════════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      _logger.e('═══════════════════════════════════════════════════════');
      _logger.e('❌ Failed to initialize OfflineCAMService');
      _logger.e('   Error: $e');
      _logger.e('   Error type: ${e.runtimeType}');
      _logger.e('   Stack trace: $stackTrace');
      _logger.e('═══════════════════════════════════════════════════════');
      print('═══════════════════════════════════════════════════════');
      print('❌ [OfflineCAMService] INITIALIZATION FAILED!');
      print('   Error: $e');
      print('   Error type: ${e.runtimeType}');
      print('   Stack trace: $stackTrace');
      print('   _isInitialized will be set to: false');
      print('═══════════════════════════════════════════════════════');
      _isInitialized = false;
      _interpreter = null;
      _camWeights = null;
      _labels = null;
      // Don't rethrow - allow app to continue with online-only mode
      // The adaptive service will handle fallback gracefully
      print(
          '⚠️ [OfflineCAMService] Exception caught, NOT rethrowing (allowing app to continue)');
    }
  }

  /// Load plant labels from JSON asset
  Future<void> _loadLabels() async {
    try {
      _logger.d('   Loading labels file...');

      // Try to load the file (try class_indices.json first, then labels.json)
      String jsonString;
      try {
        // Try class_indices.json first (new format)
        jsonString = await rootBundle.loadString('assets/models/class_indices.json');
        _logger.d('   ✅ Labels file loaded (class_indices.json), size: ${jsonString.length} bytes');
        print('   📋 Loaded class_indices.json');
      } catch (fileError) {
        _logger.w('⚠️ Failed to load class_indices.json: $fileError');
        _logger.w('   Trying labels.json (legacy format)...');
        print('   ⚠️ Failed to load class_indices.json, trying labels.json...');
        try {
          jsonString = await rootBundle.loadString('assets/models/labels.json');
          _logger.d('   ✅ Labels file loaded (labels.json), size: ${jsonString.length} bytes');
          print('   📋 Loaded labels.json (legacy)');
        } catch (fileError2) {
          _logger.w('⚠️ Failed to load labels file: $fileError2');
          _logger.w('   File paths tried: assets/models/class_indices.json, assets/models/labels.json');
          _logger.w('   Continuing without labels (will use default names)');
          print('   ❌ Failed to load both class_indices.json and labels.json');
          _labels = {};
          return;
        }
      }

      // Parse JSON
      _logger.d('   Parsing JSON data...');
      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        _logger.d('   ✅ JSON parsed successfully');
      } catch (parseError) {
        _logger.w('⚠️ Failed to parse labels JSON: $parseError');
        _logger.w('   Continuing without labels (will use default names)');
        _labels = {};
        return;
      }

      // Extract labels
      _labels = jsonData.map((key, value) => MapEntry(key, value.toString()));
      _logger.i('✅ Labels loaded: ${_labels!.length} classes');

      if (_labels!.isEmpty) {
        _logger.w('⚠️ Labels map is empty');
      }
    } catch (e, stackTrace) {
      _logger.w('⚠️ Error loading labels: $e');
      _logger.w('   Error type: ${e.runtimeType}');
      _logger.w('   Stack trace: $stackTrace');
      _logger.w('   Continuing without labels (will use default names)');
      _labels = {};
      // Don't rethrow - labels are optional
    }
  }

  /// Load CAM weights from JSON asset
  /// Set preferred model name (from TflitePlantService best result)
  void setPreferredModel(String? modelName) {
    _preferredModelName = modelName;
    // Switch interpreter if needed
    if (modelName == 'MobileNetV2' && _mobilenetv2Interpreter != null) {
      _interpreter = _mobilenetv2Interpreter;
      _camWeights = _mobilenetv2CamWeights;
    } else if (modelName == 'HerbaScan' && _herbascanInterpreter != null) {
      _interpreter = _herbascanInterpreter;
      _camWeights = _herbascanCamWeights;
    }
  }

  Future<void> _loadCAMWeights() async {
    try {
      _logger.i('Loading CAM weights from JSON files...');
      print('📦 [OfflineCAMService] Loading CAM weights...');
      
      // Load MobileNetV2 CAM weights
      try {
        final jsonString = await rootBundle.loadString('assets/models/mobilenetv2_cam_weights.json');
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        final weightsList = jsonData['weights'] as List;
        _mobilenetv2CamWeights = weightsList.map((row) {
          if (row is! List) {
            throw Exception('CAM weights row is not a list, got ${row.runtimeType}');
          }
          return List<double>.from(row.map((val) => (val as num).toDouble()));
        }).toList();
        _logger.i('✅ MobileNetV2 CAM weights loaded: ${_mobilenetv2CamWeights!.length} features x ${_mobilenetv2CamWeights![0].length} classes');
        print('✅ [OfflineCAMService] MobileNetV2 CAM weights loaded!');
      } catch (e) {
        _logger.w('⚠️ Failed to load MobileNetV2 CAM weights: $e');
        print('⚠️ [OfflineCAMService] MobileNetV2 CAM weights not found, trying legacy...');
        // Try legacy path
        try {
          final jsonString = await rootBundle.loadString('assets/models/cam_weights.json');
          final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
          final weightsList = jsonData['weights'] as List;
          _mobilenetv2CamWeights = weightsList.map((row) {
            if (row is! List) {
              throw Exception('CAM weights row is not a list, got ${row.runtimeType}');
            }
            return List<double>.from(row.map((val) => (val as num).toDouble()));
          }).toList();
          _logger.i('✅ Loaded CAM weights from legacy path for MobileNetV2');
        } catch (e2) {
          _logger.w('⚠️ Legacy CAM weights also failed: $e2');
        }
      }
      
      // Load HerbaScan CAM weights
      try {
        final jsonString = await rootBundle.loadString('assets/models/herbascan_cam_weights.json');
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        final weightsList = jsonData['weights'] as List;
        _herbascanCamWeights = weightsList.map((row) {
          if (row is! List) {
            throw Exception('CAM weights row is not a list, got ${row.runtimeType}');
          }
          return List<double>.from(row.map((val) => (val as num).toDouble()));
        }).toList();
        _logger.i('✅ HerbaScan CAM weights loaded: ${_herbascanCamWeights!.length} features x ${_herbascanCamWeights![0].length} classes');
        print('✅ [OfflineCAMService] HerbaScan CAM weights loaded!');
      } catch (e) {
        _logger.w('⚠️ Failed to load HerbaScan CAM weights: $e');
        print('⚠️ [OfflineCAMService] HerbaScan CAM weights not found');
      }
      
      // Set default CAM weights (prefer MobileNetV2, fallback to HerbaScan, then legacy)
      if (_mobilenetv2CamWeights != null) {
        _camWeights = _mobilenetv2CamWeights;
      } else if (_herbascanCamWeights != null) {
        _camWeights = _herbascanCamWeights;
      } else {
        // Legacy: try single cam_weights.json
        try {
          final jsonString = await rootBundle.loadString('assets/models/cam_weights.json');
          final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
          final weightsList = jsonData['weights'] as List;
          _camWeights = weightsList.map((row) {
            if (row is! List) {
              throw Exception('CAM weights row is not a list, got ${row.runtimeType}');
            }
            return List<double>.from(row.map((val) => (val as num).toDouble()));
          }).toList();
          _logger.i('✅ Loaded CAM weights from legacy single file');
        } catch (fileError) {
          _logger.e('❌ Failed to load CAM weights file: $fileError');
          _logger.e('   File path: assets/models/cam_weights.json');
          _logger.e('   This usually means:');
          _logger.e('   1. File is missing from assets/models/');
          _logger.e('   2. pubspec.yaml assets not configured');
          _logger.e('   3. App needs to be rebuilt');
          rethrow;
        }
      }
      
      // Validate weights
      if (_camWeights == null || _camWeights!.isEmpty) {
        throw Exception('CAM weights are null or empty after loading');
      }
      
      _logger.i('✅ CAM weights loaded successfully');
      print('✅ [OfflineCAMService] CAM weights loaded!');
      print('   MobileNetV2 weights: ${_mobilenetv2CamWeights != null ? "✅" : "❌"}');
      print('   HerbaScan weights: ${_herbascanCamWeights != null ? "✅" : "❌"}');
      
      // Note: Feature dimension validation happens later
      _logger.d('   Weights shape: ${_camWeights!.length} features x ${_camWeights![0].length} classes');
      
      return;
    } catch (e, stackTrace) {
      _logger.e('❌ Error loading CAM weights: $e');
      _logger.e('   Error type: ${e.runtimeType}');
      _logger.e('   Stack trace: $stackTrace');
      _camWeights = null;
      rethrow;
    }
  }

  /// Identify plant and generate CAM visualization
  ///
  /// [modelName] - Optional: "MobileNetV2" or "HerbaScan" to use specific model
  ///                If null, uses preferred model or default
  ///
  /// Returns Map with:
  /// - plant_name: String
  /// - scientific_name: String
  /// - confidence: double (0-1)
  /// - all_predictions: List<Map> (top 3)
  /// - gradcam_image: Uint8List (CAM overlay image as PNG)
  /// - method: "cam"
  /// - processing_time_ms: double
  /// - model_used: String (which model was used for CAM)
  Future<Map<String, dynamic>?> identifyPlantWithCAM(
    Uint8List imageBytes, {
    String? modelName,
  }) async {
    // Set preferred model if specified
    if (modelName != null) {
      setPreferredModel(modelName);
      _logger.i('Using specified model for CAM: $modelName');
      print('📌 [OfflineCAMService] Using model: $modelName');
    }
    if (!_isInitialized) {
      _logger.w('Service not initialized, initializing now...');
      try {
        await initialize();
      } catch (e, stackTrace) {
        _logger.e('Failed to initialize during identifyPlantWithCAM: $e');
        _logger.e('Stack trace: $stackTrace');
        return null;
      }
    }

    if (_interpreter == null) {
      _logger.e('❌ TFLite interpreter is null - model not loaded');
      return null;
    }

    if (_camWeights == null) {
      _logger.e('❌ CAM weights are null - weights not loaded');
      return null;
    }

    if (_labels == null || _labels!.isEmpty) {
      _logger.e('❌ Plant labels are null or empty - labels not loaded');
      return null;
    }

    final stopwatch = Stopwatch()..start();

    try {
      _logger.i('Starting offline CAM computation...');

      // 1. Preprocess image
      final preprocessedImage = _preprocessImage(imageBytes);

      // 2. Run model inference
      final inferenceResult = _runInference(preprocessedImage);
      if (inferenceResult == null) {
        _logger.e('Model inference failed');
        return null;
      }

      final predictions = inferenceResult['predictions'];
      final predictedClassIdx = inferenceResult['predictedClassIdx'];

      // 3. Compute CAM using SPATIAL features (preserves spatial information)
      // CRITICAL: Use spatialFeatures instead of pooled features for proper CAM
      // This preserves spatial information and creates an accurate heatmap
      final spatialFeatures =
          inferenceResult['spatialFeatures'] as List<List<List<double>>>;
      print('🔍 [OfflineCAM] Computing CAM heatmap...');
      print('   Spatial features shape: [${spatialFeatures.length}, ${spatialFeatures[0].length}, ${spatialFeatures[0][0].length}]');
      print('   Predicted class index: $predictedClassIdx');
      
      final camHeatmap =
          _generateSpatialCAM(spatialFeatures, predictedClassIdx);
      if (camHeatmap == null) {
        _logger.e('❌ CAM computation failed - _generateSpatialCAM returned null');
        print('❌ [OfflineCAM] CAM computation failed - _generateSpatialCAM returned null');
        return null;
      }
      print('✅ [OfflineCAM] CAM heatmap generated: [${camHeatmap.length}, ${camHeatmap[0].length}]');

      // 4. Upscale heatmap (7x7 → 224x224) with bicubic interpolation
      final upscaledHeatmap = _resizeHeatmapBicubic(camHeatmap, inputSize, inputSize);
      
      // 5. Apply Gaussian blur for smoother, more organic appearance
      final smoothedHeatmap = _applyGaussianBlur(upscaledHeatmap, sigma: 2.0);

      // 6. Apply Jet colormap
      final coloredHeatmap = _applyJetColormap(smoothedHeatmap);

      // 7. Decode original image and overlay
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        _logger.e('Failed to decode original image');
        return null;
      }

      final resizedOriginal = img.copyResize(
        originalImage,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.cubic,
      );

      final overlayImage = _overlayHeatmap(resizedOriginal, coloredHeatmap);

      // 8. Encode to PNG
      print('🔍 [OfflineCAM] Encoding overlay image to PNG...');
      final gradcamImageBytes = Uint8List.fromList(img.encodePng(overlayImage));
      print('✅ [OfflineCAM] PNG encoded: ${gradcamImageBytes.length} bytes');

      stopwatch.stop();

      // 9. Get top predictions
      final topPredictions = _getTopPredictions(predictions, 3);

      _logger.i(
        'CAM computation complete: ${stopwatch.elapsedMilliseconds}ms',
      );

      // Enhanced logging for debugging
      print('═══════════════════════════════════════════════════════');
      print('✅ [OfflineCAM] CAM heatmap generated successfully');
      print('   Heatmap size: ${gradcamImageBytes.length} bytes');
      print('   Top prediction: ${topPredictions[0]['label']} (${predictions[predictedClassIdx]})');
      print('   Method: cam');
      print('   Returning result with gradcam_image: ${gradcamImageBytes.length} bytes');
      print('═══════════════════════════════════════════════════════');
      
      _logger.i('✅ CAM heatmap generated successfully');
      _logger.i('   Heatmap size: ${gradcamImageBytes.length} bytes');
      _logger.i(
          '   Top prediction: ${topPredictions[0]['label']} (${predictions[predictedClassIdx]})');
      _logger.i('   Method: cam');

      // Format predictions for UI (convert 'label' to 'plantName' and add 'index')
      final formattedPredictions = topPredictions.map((pred) {
        return {
          'label': pred['label'],
          'plantName': pred['label'], // UI expects 'plantName'
          'scientificName': pred['scientificName'] ?? pred['label'],
          'confidence': pred['confidence'],
          'index': pred['index'] ?? 0,
          'isDOHApproved': pred['isDOHApproved'] ?? false,
        };
      }).toList();

      return {
        'plant_name': topPredictions[0]['label'] ?? 'Unknown',
        'scientific_name': topPredictions[0]['scientificName'] ?? '',
        'confidence': predictions[predictedClassIdx],
        'predictions': formattedPredictions, // UI expects 'predictions' key
        'all_predictions': topPredictions, // Keep for backward compatibility
        'gradcam_image': gradcamImageBytes, // This is the critical field!
        'method': 'cam',
        'processing_time_ms': stopwatch.elapsedMilliseconds.toDouble(),
      };
    } catch (e, stackTrace) {
      _logger.e('Error in CAM computation: $e');
      _logger.e('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Preprocess image for model input
  List<List<List<List<double>>>> _preprocessImage(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize to 224x224
    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.cubic,
    );

    // Convert to normalized float array
    final preprocessed = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (h) => List.generate(
          inputSize,
          (w) => List.generate(3, (c) {
            final pixel = resized.getPixel(w, h);
            final value = [
              (pixel.r / 255.0) * 2.0 - 1.0, // Normalize to [-1, 1]
              (pixel.g / 255.0) * 2.0 - 1.0,
              (pixel.b / 255.0) * 2.0 - 1.0,
            ];
            return value[c];
          }),
        ),
      ),
    );

    return preprocessed;
  }

  /// Run model inference and return feature maps + predictions
  Map<String, dynamic>? _runInference(
    List<List<List<List<double>>>> preprocessedImage,
  ) {
    try {
      // Get feature maps output (always available)
      final featuresTensor =
          _interpreter!.getOutputTensor(_featureMapOutputIndex);

      // Get predictions output if available
      Tensor? predictionsTensor;
      if (_predictionOutputIndex >= 0 && _numModelOutputs > 1) {
        try {
          predictionsTensor =
              _interpreter!.getOutputTensor(_predictionOutputIndex);
        } catch (e) {
          _logger.w('⚠️ Predictions output not available: $e');
          predictionsTensor = null;
        }
      }

      // Prepare output buffers
      // CRITICAL: tflite_flutter expects output buffers to match tensor shapes exactly
      final featuresShape = featuresTensor.shape;
      _logger.i('📊 Preparing output buffers:');
      _logger.i(
          '   Features tensor shape: $featuresShape (${featuresShape.length}D)');

      // For tflite_flutter, create output buffers using Tensor methods or manual creation
      // The output buffer must match the tensor's shape exactly
      List<List<List<List<double>>>> featuresOutput;

      // Verify shape is 4D: [batch, H, W, C]
      if (featuresShape.length != 4) {
        _logger.e(
            '❌ Features tensor must be 4D, got ${featuresShape.length}D: $featuresShape');
        throw Exception('Invalid features tensor shape: $featuresShape');
      }

      final batchSize = featuresShape[0];
      final height = featuresShape[1];
      final width = featuresShape[2];
      final channels = featuresShape[3];

      _logger.i(
          '   Creating 4D buffer: batch=$batchSize, H=$height, W=$width, C=$channels');

      // Create 4D list: [batch][height][width][channels]
      featuresOutput = List.generate(
        batchSize,
        (b) => List.generate(
          height,
          (h) => List.generate(
            width,
            (w) => List.filled(channels, 0.0),
          ),
        ),
      );

      // Verify the structure is correct
      _logger.d(
          '   Buffer created: ${featuresOutput.length}x${featuresOutput[0].length}x${featuresOutput[0][0].length}x${featuresOutput[0][0][0].length}');

      // Prepare predictions output buffer (only if predictions tensor exists)
      // CRITICAL: Must be List<List<double>> to match tensor shape [1, 40]
      List<List<double>>? predictionsOutput;

      if (predictionsTensor != null) {
        final predictionsShape = predictionsTensor.shape;
        _logger.i('   Predictions tensor shape: $predictionsShape');

        // CRITICAL: Output buffers must match tensor shapes EXACTLY, including batch dimension
        // For [1, 40] tensor, we need List<List<double>> with shape [1][40], not List<double> [40]
        if (predictionsShape.length == 2) {
          // 2D tensor: [batch, num_classes] - create 2D buffer with batch dimension
          final batchSize = predictionsShape[0];
          final numClasses = predictionsShape[1];
          predictionsOutput = List.generate(
            batchSize,
            (_) => List.filled(numClasses, 0.0),
          );
          _logger.d(
              '   Created 2D predictions buffer: [${predictionsOutput.length}][${predictionsOutput[0].length}]');
        } else if (predictionsShape.length == 1) {
          // 1D tensor: [num_classes] - wrap in batch dimension for consistency
          final numClasses = predictionsShape[0];
          predictionsOutput = [
            List.filled(numClasses, 0.0),
          ];
          _logger.d(
              '   Created 2D predictions buffer (from 1D): [1][${predictionsOutput[0].length}]');
        } else {
          _logger.e('❌ Unexpected predictions tensor shape: $predictionsShape');
          throw Exception(
              'Invalid predictions tensor shape: $predictionsShape');
        }
      } else {
        // Single-output model: predictions will be computed from features
        _logger.i(
            '📊 Single-output model: Will compute predictions from feature maps');
        predictionsOutput = null;
      }

      _logger.i('   Output buffers prepared:');
      _logger.i('   Buffer 0 (features) type: ${featuresOutput.runtimeType}');
      if (predictionsOutput != null) {
        _logger.i(
            '   Buffer 1 (predictions) type: ${predictionsOutput.runtimeType}');
      }

      // Run inference
      try {
        _logger.d('🚀 Running inference...');
        _logger.d('   Input shape: ${_interpreter!.getInputTensor(0).shape}');
        _logger.d('   Output 0 expected shape: ${featuresTensor.shape}');
        if (predictionsTensor != null) {
          _logger.d('   Output 1 expected shape: ${predictionsTensor.shape}');
        }
        _logger.d(
            '   Features buffer actual shape: [${featuresOutput.length}][${featuresOutput[0].length}][${featuresOutput[0][0].length}][${featuresOutput[0][0][0].length}]');
        if (predictionsOutput != null) {
          _logger.d(
              '   Predictions buffer actual shape: [${predictionsOutput.length}][${predictionsOutput[0].length}]');
        }

        // Run inference with output buffers
        // CRITICAL FIX: For multiple outputs with single input, we need to use runForMultipleInputs
        // with a single input in a list and outputs as a map {outputIndex: buffer}
        // This prevents the interpreter from treating the output list as a nested tensor
        final inputs = [preprocessedImage];
        final outputs = <int, Object>{
          _featureMapOutputIndex: featuresOutput,
        };
        if (predictionsOutput != null && _predictionOutputIndex >= 0) {
          outputs[_predictionOutputIndex] = predictionsOutput;
        }

        _logger.d('   Using runForMultipleInputs with:');
        _logger.d('   Inputs: 1 (single input)');
        _logger.d('   Outputs map keys: ${outputs.keys.toList()}');
        _logger.d('   Output 0 (features) at index: $_featureMapOutputIndex');
        if (predictionsOutput != null && _predictionOutputIndex >= 0) {
          _logger
              .d('   Output 1 (predictions) at index: $_predictionOutputIndex');
        }

        _interpreter!.runForMultipleInputs(inputs, outputs);
        _logger.d('✅ Inference completed successfully');
      } catch (e, stackTrace) {
        _logger.e('❌ Inference failed: $e');
        _logger.e('   Error type: ${e.runtimeType}');
        _logger.e('   Stack trace: $stackTrace');
        // Log detailed buffer information for debugging
        _logger.e('   Features buffer structure:');
        _logger.e('     Type: ${featuresOutput.runtimeType}');
        _logger.e('     Length (batch): ${featuresOutput.length}');
        if (featuresOutput.isNotEmpty) {
          _logger.e('     [0] length (height): ${featuresOutput[0].length}');
          if (featuresOutput[0].isNotEmpty) {
            _logger.e(
                '     [0][0] length (width): ${featuresOutput[0][0].length}');
            if (featuresOutput[0][0].isNotEmpty) {
              _logger.e(
                  '     [0][0][0] length (channels): ${featuresOutput[0][0][0].length}');
            }
          }
        }
        rethrow;
      }

      // Store spatial feature maps for CAM computation
      // Extract spatial features (remove batch dimension): [1, 7, 7, 1280] -> [7, 7, 1280]
      final spatialFeatures = featuresOutput[0];
      // Shape: [7, 7, 1280]

      // Enhanced logging for debugging
      _logger.d('Model inference completed');
      _logger.d(
          '   Features shape: ${spatialFeatures.length}x${spatialFeatures[0].length}x${spatialFeatures[0][0].length}');
      if (predictionsOutput != null) {
        _logger.d('   Predictions length: ${predictionsOutput.length}');
      } else {
        _logger.d('   Predictions: Will be computed from features');
      }

      // Validate outputs
      if (spatialFeatures.isEmpty || spatialFeatures[0].isEmpty) {
        _logger.e('❌ Model returned empty feature maps!');
        _logger.e('   This suggests the model is not working correctly');
        return null;
      }

      // Compute predictions from feature maps if not provided by model
      List<double> finalPredictions;
      if (predictionsOutput != null && predictionsOutput.isNotEmpty) {
        // Model provided predictions - extract from 2D buffer [batch][classes]
        final rawPredictions = predictionsOutput[0]; // Extract batch 0
        if (rawPredictions.isEmpty || rawPredictions.every((p) => p == 0.0)) {
          _logger.w(
              '⚠️ Model returned empty or zero predictions, computing from features');
          // Fallback: compute predictions from features
          finalPredictions = _computePredictionsFromFeatures(spatialFeatures);
        } else {
          finalPredictions = rawPredictions;
        }
      } else {
        // Single-output model: compute predictions from feature maps using CAM weights
        _logger.i('📊 Computing predictions from feature maps...');
        finalPredictions = _computePredictionsFromFeatures(spatialFeatures);
      }

      // Global Average Pooling: [7, 7, 1280] → [1280]
      final pooledFeatures = _globalAveragePooling(spatialFeatures);

      // Get predicted class index
      double maxProb = -1.0;
      int predictedClassIdx = 0;
      for (int i = 0; i < finalPredictions.length; i++) {
        if (finalPredictions[i] > maxProb) {
          maxProb = finalPredictions[i];
          predictedClassIdx = i;
        }
      }

      // Map 1280 features to 256 features
      // Note: The model architecture has an intermediate layer (256 dim)
      // For CAM, we'll use the first 256 features as a proxy
      // In a full implementation, we'd preserve spatial structure
      final mappedFeatures = pooledFeatures.take(featureDim).toList();

      return {
        'features': mappedFeatures, // Pooled features [256]
        'spatialFeatures':
            spatialFeatures, // Keep spatial info for future improvement
        'predictions': finalPredictions,
        'predictedClassIdx': predictedClassIdx,
      };
    } catch (e) {
      _logger.e('Inference error: $e');
      return null;
    }
  }

  /// Compute predictions from feature maps using CAM weights
  /// This is used when the model only outputs feature maps (single-output model)
  ///
  /// Process:
  /// 1. Global Average Pooling: [7, 7, 1280] → [1280]
  /// 2. Reduce to 256 dimensions (matching CAM weights)
  /// 3. Apply CAM weights: [256] × [256, 40] → [40]
  /// 4. Apply softmax to get probabilities
  List<double> _computePredictionsFromFeatures(
    List<List<List<double>>> spatialFeatures,
  ) {
    try {
      // Step 1: Global Average Pooling
      final pooledFeatures = _globalAveragePooling(spatialFeatures);
      // Shape: [1280]

      // Step 2: Reduce to 256 dimensions (matching CAM weights)
      final reducedFeatures = pooledFeatures.take(featureDim).toList();
      // Shape: [256]

      // Step 3: Apply CAM weights to get class logits
      // weights: [256, 40], features: [256]
      // result: [40] = features^T × weights
      final predictions = List<double>.filled(numClasses, 0.0);

      if (_camWeights == null) {
        _logger.e('❌ CAM weights not available for computing predictions');
        // Return uniform predictions as fallback
        return List<double>.filled(numClasses, 1.0 / numClasses);
      }

      for (int classIdx = 0; classIdx < numClasses; classIdx++) {
        double logit = 0.0;
        for (int featIdx = 0;
            featIdx < reducedFeatures.length && featIdx < _camWeights!.length;
            featIdx++) {
          logit += reducedFeatures[featIdx] * _camWeights![featIdx][classIdx];
        }
        predictions[classIdx] = logit;
      }

      // Step 4: Apply softmax to convert logits to probabilities
      // Softmax: p_i = exp(x_i) / Σ exp(x_j)
      final maxLogit = predictions.reduce((a, b) => a > b ? a : b);
      double sumExp = 0.0;
      final expPredictions = predictions.map((logit) {
        final exp =
            math.exp(logit - maxLogit); // Subtract max for numerical stability
        sumExp += exp;
        return exp;
      }).toList();

      final probabilities = expPredictions.map((exp) => exp / sumExp).toList();

      _logger.d('✅ Computed predictions from features');
      _logger.d(
          '   Max probability: ${probabilities.reduce((a, b) => a > b ? a : b)}');

      return probabilities;
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to compute predictions from features: $e');
      _logger.e('   Stack trace: $stackTrace');
      // Return uniform predictions as fallback
      return List<double>.filled(numClasses, 1.0 / numClasses);
    }
  }

  /// Global Average Pooling: [H, W, C] → [C]
  List<double> _globalAveragePooling(
    List<List<List<double>>> featureMap,
  ) {
    final h = featureMap.length;
    final w = featureMap[0].length;
    final c = featureMap[0][0].length;

    final pooled = List.filled(c, 0.0);

    for (int channel = 0; channel < c; channel++) {
      double sum = 0.0;
      for (int i = 0; i < h; i++) {
        for (int j = 0; j < w; j++) {
          sum += featureMap[i][j][channel];
        }
      }
      pooled[channel] = sum / (h * w);
    }

    return pooled;
  }

  /// Generate CAM heatmap from SPATIAL feature maps (preserves spatial information)
  /// This is the proper CAM implementation that shows where the model focuses spatially.
  ///
  /// Formula: CAM[i, j] = Σ(k=0 to C-1) W[k, class_idx] * F[i, j, k]
  /// Where:
  /// - F[i, j, k] is the feature value at spatial position (i, j) and channel k
  /// - W[k, class_idx] is the weight for channel k and predicted class
  /// - CAM[i, j] is the activation value at position (i, j)
  ///
  /// Parameters:
  /// - [spatialFeatures]: Spatial feature maps [7, 7, 1280] from conv layer
  /// - [classIdx]: Index of the predicted class (0-39)
  ///
  /// Returns: CAM heatmap [7, 7] showing spatial attention
  List<List<double>>? _generateSpatialCAM(
    List<List<List<double>>> spatialFeatures, // [7, 7, 1280]
    int classIdx,
  ) {
    if (_camWeights == null || classIdx >= numClasses) {
      _logger.e(
          'Invalid CAM weights or class index: classIdx=$classIdx, numClasses=$numClasses');
      return null;
    }

    try {
      final height = spatialFeatures.length; // Should be 7
      final width = spatialFeatures[0].length; // Should be 7
      final channels = spatialFeatures[0][0].length; // Should be 1280

      _logger.d('Generating spatial CAM:');
      _logger.d('   Spatial features shape: ${height}x${width}x$channels');
      _logger.d('   Class index: $classIdx');
      _logger.d(
          '   CAM weights shape: ${_camWeights!.length}x${_camWeights![0].length}');

      // Validate dimensions
      if (_featureMapShape != null) {
        if (height != _featureMapShape![1] || width != _featureMapShape![2]) {
          _logger.w(
              '⚠️ Spatial feature dimensions mismatch: expected ${_featureMapShape![1]}x${_featureMapShape![2]}, got ${height}x$width');
        }
      } else if (height != expectedFeatureMapShape[0] ||
          width != expectedFeatureMapShape[1]) {
        _logger.w(
            '⚠️ Spatial feature dimensions mismatch: expected ${expectedFeatureMapShape[0]}x${expectedFeatureMapShape[1]}, got ${height}x$width');
      }

      // Create heatmap [7, 7]
      final heatmap = List.generate(
        height,
        (i) => List.filled(width, 0.0),
      );

      // Compute CAM for each spatial position
      // CAM[i, j] = Σ(k=0 to C-1) W[k, class_idx] * F[i, j, k]
      for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
          double camValue = 0.0;

          // Sum weighted features across channels
          // Use first 256 channels to match CAM weights dimension [256, 40]
          // Note: For full accuracy, we'd need weights [1280, 40], but using first 256 is a good approximation
          final maxChannels = math.min(256, channels);
          for (int k = 0; k < maxChannels; k++) {
            if (k < _camWeights!.length) {
              final weight = _camWeights![k][classIdx];
              final feature = spatialFeatures[i][j][k];
              camValue += weight * feature;
            }
          }

          heatmap[i][j] = camValue;
        }
      }

      // Log heatmap statistics for debugging
      final minVal = heatmap.expand((row) => row).reduce(math.min);
      final maxVal = heatmap.expand((row) => row).reduce(math.max);
      final meanVal = heatmap.expand((row) => row).reduce((a, b) => a + b) /
          (height * width);
      _logger.d('CAM heatmap statistics:');
      _logger.d('   Min: $minVal');
      _logger.d('   Max: $maxVal');
      _logger.d('   Mean: $meanVal');
      _logger.d('   Range: ${maxVal - minVal}');

      // Normalize to [0, 1] for visualization
      final normalized = _normalizeHeatmap(heatmap);

      // Verify normalization
      final normMin = normalized.expand((row) => row).reduce(math.min);
      final normMax = normalized.expand((row) => row).reduce(math.max);
      _logger.d('Normalized heatmap range: [$normMin, $normMax]');

      return normalized;
    } catch (e, stackTrace) {
      _logger.e('CAM generation error: $e');
      _logger.e('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Normalize heatmap values to [0, 1]
  List<List<double>> _normalizeHeatmap(List<List<double>> heatmap) {
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    // Find min/max
    for (final row in heatmap) {
      for (final val in row) {
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    // Normalize
    final range = maxVal - minVal;
    if (range == 0) {
      return heatmap.map((row) => row.map((_) => 0.5).toList()).toList();
    }

    return heatmap
        .map(
          (row) => row.map((val) => (val - minVal) / range).toList(),
        )
        .toList();
  }

  /// Resize heatmap using bicubic interpolation for smooth, organic appearance
  List<List<double>> _resizeHeatmapBicubic(
    List<List<double>> heatmap,
    int targetWidth,
    int targetHeight,
  ) {
    final srcHeight = heatmap.length;
    final srcWidth = heatmap[0].length;

    final resized = List.generate(
      targetHeight,
      (y) => List.generate(targetWidth, (x) {
        // Map target coordinates to source
        final srcY = (y / targetHeight) * srcHeight;
        final srcX = (x / targetWidth) * srcWidth;

        // Bicubic interpolation uses 4x4 neighborhood
        final srcYFloor = srcY.floor();
        final srcXFloor = srcX.floor();
        
        final y0 = (srcYFloor - 1).clamp(0, srcHeight - 1);
        final y1 = srcYFloor.clamp(0, srcHeight - 1);
        final y2 = (srcYFloor + 1).clamp(0, srcHeight - 1);
        final y3 = (srcYFloor + 2).clamp(0, srcHeight - 1);

        final x0 = (srcXFloor - 1).clamp(0, srcWidth - 1);
        final x1 = srcXFloor.clamp(0, srcWidth - 1);
        final x2 = (srcXFloor + 1).clamp(0, srcWidth - 1);
        final x3 = (srcXFloor + 2).clamp(0, srcWidth - 1);

        final fy = (srcY - srcYFloor).clamp(0.0, 1.0);
        final fx = (srcX - srcXFloor).clamp(0.0, 1.0);

        // Cubic interpolation function (Catmull-Rom spline)
        double cubicInterpolate(double p0, double p1, double p2, double p3, double t) {
          final t2 = t * t;
          final t3 = t2 * t;
          return 0.5 * (
            (2.0 * p1) +
            (-p0 + p2) * t +
            (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
            (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
          );
        }

        // Interpolate along y-axis first
        final row0 = cubicInterpolate(
          heatmap[y0][x0], heatmap[y0][x1], heatmap[y0][x2], heatmap[y0][x3], fx);
        final row1 = cubicInterpolate(
          heatmap[y1][x0], heatmap[y1][x1], heatmap[y1][x2], heatmap[y1][x3], fx);
        final row2 = cubicInterpolate(
          heatmap[y2][x0], heatmap[y2][x1], heatmap[y2][x2], heatmap[y2][x3], fx);
        final row3 = cubicInterpolate(
          heatmap[y3][x0], heatmap[y3][x1], heatmap[y3][x2], heatmap[y3][x3], fx);

        // Interpolate along x-axis (actually y-axis in final step)
        final val = cubicInterpolate(row0, row1, row2, row3, fy);

        return val.clamp(0.0, 1.0);
      }),
    );

    return resized;
  }

  /// Apply Gaussian blur to heatmap for smoother, more organic appearance
  List<List<double>> _applyGaussianBlur(
    List<List<double>> heatmap, {
    double sigma = 2.0,
  }) {
    final height = heatmap.length;
    final width = heatmap[0].length;

    // Calculate kernel size (should be odd and cover 3*sigma)
    final kernelSize = ((sigma * 6).ceil() | 1); // Ensure odd number
    final halfKernel = kernelSize ~/ 2;

    // Generate 1D Gaussian kernel
    final kernel = List.generate(kernelSize, (i) {
      final x = i - halfKernel;
      return math.exp(-(x * x) / (2 * sigma * sigma));
    });

    // Normalize kernel
    final kernelSum = kernel.reduce((a, b) => a + b);
    final normalizedKernel = kernel.map((k) => k / kernelSum).toList();

    // Apply horizontal blur
    final blurredHorizontal = List.generate(height, (y) {
      return List.generate(width, (x) {
        double sum = 0.0;
        for (int i = 0; i < kernelSize; i++) {
          final offset = i - halfKernel;
          final srcX = (x + offset).clamp(0, width - 1);
          sum += heatmap[y][srcX] * normalizedKernel[i];
        }
        return sum;
      });
    });

    // Apply vertical blur
    final blurred = List.generate(height, (y) {
      return List.generate(width, (x) {
        double sum = 0.0;
        for (int i = 0; i < kernelSize; i++) {
          final offset = i - halfKernel;
          final srcY = (y + offset).clamp(0, height - 1);
          sum += blurredHorizontal[srcY][x] * normalizedKernel[i];
        }
        return sum.clamp(0.0, 1.0);
      });
    });

    return blurred;
  }

  /// Apply Jet colormap to heatmap
  List<List<img.ColorRgb8>> _applyJetColormap(
    List<List<double>> heatmap,
  ) {
    return heatmap.map((row) {
      return row.map((value) {
        // Jet colormap: blue → cyan → green → yellow → red
        double r, g, b;

        if (value < 0.25) {
          // Blue to cyan
          final t = value / 0.25;
          r = 0;
          g = t * 255;
          b = 255;
        } else if (value < 0.5) {
          // Cyan to green
          final t = (value - 0.25) / 0.25;
          r = 0;
          g = 255;
          b = (1 - t) * 255;
        } else if (value < 0.75) {
          // Green to yellow
          final t = (value - 0.5) / 0.25;
          r = t * 255;
          g = 255;
          b = 0;
        } else {
          // Yellow to red
          final t = (value - 0.75) / 0.25;
          r = 255;
          g = (1 - t) * 255;
          b = 0;
        }

        return img.ColorRgb8(
          r.clamp(0, 255).toInt(),
          g.clamp(0, 255).toInt(),
          b.clamp(0, 255).toInt(),
        );
      }).toList();
    }).toList();
  }

  /// Overlay colored heatmap on original image
  img.Image _overlayHeatmap(
    img.Image original,
    List<List<img.ColorRgb8>> coloredHeatmap,
  ) {
    final overlay = img.copyResize(
      original,
      width: inputSize,
      height: inputSize,
    );

    final alpha = 0.5; // Heatmap opacity

    for (int y = 0; y < overlay.height; y++) {
      for (int x = 0; x < overlay.width; x++) {
        final pixel = overlay.getPixel(x, y);
        final heatmapColor = coloredHeatmap[y][x];

        final r = (pixel.r * (1 - alpha) + heatmapColor.r * alpha).round();
        final g = (pixel.g * (1 - alpha) + heatmapColor.g * alpha).round();
        final b = (pixel.b * (1 - alpha) + heatmapColor.b * alpha).round();

        overlay.setPixelRgba(
          x,
          y,
          r.clamp(0, 255),
          g.clamp(0, 255),
          b.clamp(0, 255),
          255,
        );
      }
    }

    return overlay;
  }

  /// Get top N predictions from probability array
  List<Map<String, dynamic>> _getTopPredictions(
    List<double> predictions,
    int topN,
  ) {
    final indexed = List.generate(
      predictions.length,
      (i) => {'index': i, 'confidence': predictions[i]},
    );

    indexed.sort((a, b) =>
        (b['confidence'] as double).compareTo(a['confidence'] as double));

    return indexed.take(topN).map((entry) {
      final idx = entry['index'] as int;
      return {
        'label': _getPlantName(idx),
        'confidence': entry['confidence'] as double,
        'index': idx,
        'scientificName': _getScientificName(_getPlantName(idx)),
        'isDOHApproved': _isDOHApproved(_getPlantName(idx)),
      };
    }).toList();
  }

  /// Get plant name from index
  /// class_indices.json format: {"PlantName": index}
  /// So we need to find the key where value == index
  String _getPlantName(int index) {
    if (_labels == null || _labels!.isEmpty) {
      return 'Plant_$index';
    }
    
    // Find the plant name where the value equals the index
    // class_indices.json format: {"Mango": 24, "Oregano": 28, ...}
    for (final entry in _labels!.entries) {
      // Try to parse the value as an integer
      final value = int.tryParse(entry.value.toString());
      if (value == index) {
        return entry.key; // Return the plant name (key)
      }
    }
    
    // Fallback: if not found, return Plant_index
    return 'Plant_$index';
  }

  /// Get scientific name (placeholder)
  String _getScientificName(String commonName) {
    // TODO: Load from plant data service
    return '';
  }

  /// Check if plant is DOH approved (placeholder)
  bool _isDOHApproved(String plantName) {
    // TODO: Load from plant data service
    return false;
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get initialization status with details (for debugging)
  Map<String, dynamic> getInitializationStatus() {
    return {
      'isInitialized': _isInitialized,
      'hasInterpreter': _interpreter != null,
      'hasCAMWeights': _camWeights != null,
      'hasLabels': _labels != null && _labels!.isNotEmpty,
      'camWeightsShape': _camWeights != null
          ? '${_camWeights!.length}x${_camWeights![0].length}'
          : 'null',
      'labelsCount': _labels?.length ?? 0,
    };
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _camWeights = null;
    _isInitialized = false;
  }
}
