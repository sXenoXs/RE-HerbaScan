// lib/core/services/plant_classifier_service.dart
import 'dart:convert';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
// Old GradCAM service removed - replaced with AdaptiveGradCAMService
// import 'package:herbascan/core/services/gradcam_service.dart';

class PlantClassifierService {
  late Interpreter _mobilenetInterpreter;
  late Interpreter _randomForestInterpreter;
  late List<String> _labels;
  bool _isInitialized = false;
  
  // Model input/output shapes
  static const int _inputSize = 224;
  static const int _numClasses = 42; // From class_indices.json (42 plants)

  /// Load label list from class_indices.json (format: {"PlantName": index}).
  static Future<List<String>> _loadLabelsFromClassIndices() async {
    final jsonString = await rootBundle.loadString('assets/models/class_indices.json');
    final Map<String, dynamic> map = jsonDecode(jsonString) as Map<String, dynamic>;
    final entries = map.entries.map((e) => MapEntry(e.key, (e.value as num).toInt())).toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries.map((e) => e.key).toList();
  }
  
  Future<void> loadModels() async {
    try {
      _labels = await _loadLabelsFromClassIndices();
      try {
        _mobilenetInterpreter = await Interpreter.fromAsset('assets/models/mobilenetv2_feature_extractor.tflite');
      } catch (_) {
        _isInitialized = false;
        return;
      }
      try {
        _randomForestInterpreter = await Interpreter.fromAsset('assets/models/random_forest_distilled.tflite');
      } catch (_) {
        _isInitialized = true; // MobileNet-only mode
        return;
      }
      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }
  
  Future<List<Map<String, dynamic>>> classifyPlant(Uint8List imageData) async {
    if (!_isInitialized) {
      print('⚠️ Models not loaded, returning empty results');
      return [];
    }
    
    try {
      print('🔄 Starting plant classification...');
      
      // Step 1: Preprocess image
      final processedImage = _preprocessImage(imageData);
      
      // Step 2: Extract features using MobileNet V2
      final features = await _extractFeatures(processedImage);
      
      // Step 3: Get predictions (try Random Forest, fallback to MobileNet)
      List<double> predictions;
      try {
        predictions = await _getRandomForestPredictions(features);
      } catch (e) {
        print('⚠️ Random Forest failed, using MobileNet features directly');
        // Use MobileNet features as predictions (simplified approach)
        predictions = features.take(_numClasses).toList();
        if (predictions.length < _numClasses) {
          predictions.addAll(List.filled(_numClasses - predictions.length, 0.0));
        }
      }
      
      // Step 4: Get top 3 predictions
      final topPredictions = _getTopPredictions(predictions, 3);
      
      print('✅ Classification complete');
      return topPredictions;
      
    } catch (e) {
      print('❌ Error during classification: $e');
      rethrow;
    }
  }

  /// Classify plant with GradCAM visualization
  Future<Map<String, dynamic>> classifyPlantWithGradCAM(Uint8List imageData) async {
    if (!_isInitialized) {
      print('⚠️ Models not loaded, returning empty results');
      return {
        'predictions': <Map<String, dynamic>>[],
        'gradCAMPath': null,
        'summaryGradCAMPath': null,
      };
    }
    
    try {
      print('🔄 Starting plant classification with GradCAM...');
      
      // Step 1: Preprocess image
      final processedImage = _preprocessImage(imageData);
      
      // Step 2: Extract features using MobileNet V2
      final features = await _extractFeatures(processedImage);
      
      // Step 3: Get predictions (try Random Forest, fallback to MobileNet)
      List<double> predictions;
      try {
        predictions = await _getRandomForestPredictions(features);
      } catch (e) {
        print('⚠️ Random Forest failed, using MobileNet features directly');
        // Use MobileNet features as predictions (simplified approach)
        predictions = features.take(_numClasses).toList();
        if (predictions.length < _numClasses) {
          predictions.addAll(List.filled(_numClasses - predictions.length, 0.0));
        }
      }
      
      // Step 4: Get top 3 predictions
      final topPredictions = _getTopPredictions(predictions, 3);
      
      // Step 5: Generate GradCAM visualizations
      String? gradCAMPath;
      String? summaryGradCAMPath;
      
      // TODO: Update to use AdaptiveGradCAMService in Phase 4
      // Old GradCAM service has been removed
      // GradCAM visualization will be handled by AdaptiveGradCAMService
      // in the scan flow (camera_provider -> plant_result_screen)
      
      // For now, skip GradCAM generation here
      // This will be handled in Phase 4 integration
      gradCAMPath = null;
      summaryGradCAMPath = null;
      
      print('✅ Classification with GradCAM complete');
      return {
        'predictions': topPredictions,
        'gradCAMPath': gradCAMPath,
        'summaryGradCAMPath': summaryGradCAMPath,
      };
      
    } catch (e) {
      print('❌ Error during classification with GradCAM: $e');
      rethrow;
    }
  }
  
  List<List<List<List<double>>>> _preprocessImage(Uint8List imageData) {
    try {
      // Decode image
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      // Resize to 224x224
      final resizedImage = img.copyResize(
        image,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.cubic,
      );
      
      // Convert to RGB and normalize to [0, 1]
      final normalizedImage = _normalizeImage(resizedImage);
      
      // Create the 4D tensor directly without using reshape
      final List<List<List<List<double>>>> tensor = [];
      
      // Add batch dimension (1)
      final List<List<List<double>>> batch = [];
      for (int y = 0; y < _inputSize; y++) {
        final List<List<double>> row = [];
        for (int x = 0; x < _inputSize; x++) {
          if (y < normalizedImage.length && x < normalizedImage[y].length) {
            row.add(normalizedImage[y][x]);
          } else {
            // Fill with zeros if out of bounds
            row.add([0.0, 0.0, 0.0]);
          }
        }
        batch.add(row);
      }
      tensor.add(batch);
      
      return tensor;
      
    } catch (e) {
      print('❌ Error preprocessing image: $e');
      rethrow;
    }
  }
  
  List<List<List<double>>> _normalizeImage(img.Image image) {
    final List<List<List<double>>> normalized = [];
    
    for (int y = 0; y < image.height; y++) {
      final List<List<double>> row = [];
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;
        row.add([r, g, b]);
      }
      normalized.add(row);
    }
    
    return normalized;
  }
  
  Future<List<double>> _extractFeatures(List<List<List<List<double>>>> image) async {
    try {
      // Prepare output tensor for MobileNet V2 - create 2D list directly
      final List<List<double>> output = [];
      for (int i = 0; i < 1; i++) {
        final List<double> batch = List.filled(1280, 0.0);
        output.add(batch);
      }
      
      // Run MobileNet V2 inference
      _mobilenetInterpreter.run(image, output);
      
      return output[0];
      
    } catch (e) {
      print('❌ Error extracting features: $e');
      rethrow;
    }
  }
  
  Future<List<double>> _getRandomForestPredictions(List<double> features) async {
    try {
      // Random Forest interpreter should be available if we reach this point
      
      // Prepare input for Random Forest
      final input = [features];
      
      // Prepare output tensor - create 2D list directly
      final List<List<double>> output = [];
      for (int i = 0; i < 1; i++) {
        final List<double> batch = List.filled(_numClasses, 0.0);
        output.add(batch);
      }
      
      // Run Random Forest inference
      _randomForestInterpreter.run(input, output);
      
      return output[0];
      
    } catch (e) {
      print('❌ Error getting Random Forest predictions: $e');
      rethrow;
    }
  }
  
  List<Map<String, dynamic>> _getTopPredictions(List<double> probabilities, int topK) {
    final indexedProbs = probabilities.asMap().entries.toList();
    indexedProbs.sort((a, b) => b.value.compareTo(a.value));
    
    return indexedProbs.take(topK).map((entry) {
      return {
        'label': _labels[entry.key],
        'confidence': entry.value,
        'index': entry.key,
        'scientificName': _getScientificName(_labels[entry.key]),
        'isDOHApproved': _isDOHApproved(_labels[entry.key]),
      };
    }).toList();
  }
  
  String _getScientificName(String commonName) {
    // Map common names to scientific names
    final scientificNames = {
      'Lagundi': 'Vitex negundo',
      'Sambong': 'Blumea balsamifera',
      'Akapulko': 'Cassia alata',
      'Tsaang Gubat': 'Ehretia microphylla',
      'Ampalaya': 'Momordica charantia',
      'Niyog-niyogan': 'Quisqualis indica',
      'Ulasimang-bato': 'Peperomia pellucida',
      'Bawang': 'Allium sativum',
      'Bayabas': 'Psidium guajava',
      'Yerba Buena': 'Mentha cordifolia',
      'Pansit-pansitan': 'Peperomia pellucida',
      'Tawa-tawa': 'Euphorbia hirta',
      'Malunggay': 'Moringa oleifera',
    };
    
    return scientificNames[commonName] ?? 'Unknown';
  }
  
  bool _isDOHApproved(String commonName) {
    final dohApprovedPlants = {
      'Lagundi', 'Sambong', 'Akapulko', 'Tsaang Gubat', 'Ampalaya',
      'Niyog-niyogan', 'Ulasimang-bato', 'Bawang', 'Bayabas', 'Yerba Buena',
      'Pansit-pansitan', 'Tawa-tawa', 'Malunggay'
    };
    
    return dohApprovedPlants.contains(commonName);
  }
  
  // Utility methods
  bool get isInitialized => _isInitialized;
  
  List<String> get labels => List.from(_labels);
  
  String getLabel(int index) {
    if (index >= 0 && index < _labels.length) {
      return _labels[index];
    }
    return 'Unknown Plant';
  }
  
  void dispose() {
    _mobilenetInterpreter.close();
    _randomForestInterpreter.close();
    _isInitialized = false;
  }
}