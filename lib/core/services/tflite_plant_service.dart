import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class PlantPrediction {
  final String label;
  final double confidence;
  PlantPrediction({required this.label, required this.confidence});
}

class TflitePlantService {
  Interpreter? _interpreter;
  List<String>? _labels;

  static const String modelPath = "assets/models/MobileNetV2_model.tflite";
  static const String labelPath = "assets/models/class_indices.json";

  // MATCHING PYTHON: 224x224
  static const int inputSize = 224;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      await _loadLabels();
      print("✅ TFLite Model loaded successfully.");
    } catch (e) {
      print("❌ Error loading model: $e");
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString(labelPath);
      final Map<String, dynamic> jsonMap = json.decode(labelData);
      _labels = List<String>.filled(jsonMap.length, 'Unknown');
      jsonMap.forEach((name, index) {
        if (index is int && index < _labels!.length) {
          _labels![index] = name;
        }
      });
    } catch (e) {
      print("Error loading labels: $e");
    }
  }

  Future<PlantPrediction?> predict(File imageFile) async {
    if (_interpreter == null) await loadModel();
    if (_labels == null || _labels!.isEmpty) return null;

    // 1. Decode Image
    final imageBytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) return null;

    // 2. Fix Rotation
    img.Image orientedImage = img.bakeOrientation(originalImage);

    // 3. Resize
    img.Image resizedImage = img.copyResize(
        orientedImage,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear
    );

    // 4. Preprocess (Get flat list)
    var flatInput = _imageToByteListFloat32(resizedImage, inputSize);

    // --- CRITICAL FIX START ---
    // Reshape the flat list [150528] into a 4D tensor [1, 224, 224, 3]
    var input = flatInput.reshape([1, inputSize, inputSize, 3]);
    // --- CRITICAL FIX END ---

    // Output Buffer
    var output = List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);

    // 5. Run Inference
    _interpreter!.run(input, output);

    // 6. Parse Results
    List<double> outputList = List<double>.from(output[0]);
    double maxScore = -1.0;
    int maxIndex = -1;

    for (int i = 0; i < outputList.length; i++) {
      if (outputList[i] > maxScore) {
        maxScore = outputList[i];
        maxIndex = i;
      }
    }

    if (maxIndex != -1) {
      print("🧠 RESULT: ${_labels![maxIndex]} (${(maxScore * 100).toStringAsFixed(2)}%)");

      // Temporary: Lower threshold to ensure you see results
      if (maxScore > 0.1) {
        return PlantPrediction(label: _labels![maxIndex], confidence: maxScore);
      }
    }

    return null;
  }

  Float32List _imageToByteListFloat32(img.Image image, int size) {
    var convertedBytes = Float32List(1 * size * size * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < size; i++) {
      for (var j = 0; j < size; j++) {
        final pixel = image.getPixel(j, i);

        // EXPLICIT RGB EXTRACTION
        // We explicitly cast to double then divide.
        // This ensures compatibility with different versions of the 'image' package
        double r = pixel.r.toDouble() / 255.0;
        double g = pixel.g.toDouble() / 255.0;
        double b = pixel.b.toDouble() / 255.0;

        buffer[pixelIndex++] = r;
        buffer[pixelIndex++] = g;
        buffer[pixelIndex++] = b;
      }
    }

    // 🔍 DATA DEBUGGER
    // This prints the exact math of the first pixel.
    // If these numbers are > 1.0, the math is wrong.
    // If these numbers are around 0.5, the math is correct.
    print("------------------------------------------------");
    print("🔍 INPUT CHECK (First Pixel):");
    print("   R: ${buffer[0]}");
    print("   G: ${buffer[1]}");
    print("   B: ${buffer[2]}");
    print("------------------------------------------------");

    return convertedBytes;
  }

  void close() {
    _interpreter?.close();
  }
}