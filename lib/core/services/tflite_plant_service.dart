import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:herbascan/core/platform_utils_stub.dart' if (dart.library.io) 'package:herbascan/core/platform_utils_io.dart' as platform_utils;
import 'package:herbascan/core/services/ota_model_service.dart';
import 'package:herbascan/core/services/ood_config_service.dart';

class
PlantPrediction {
  final String label;
  final double confidence;
  PlantPrediction({required this.label, required this.confidence});
}

class TflitePlantService {
  Interpreter? _mobilenetv2Interpreter;
  List<String>? _labels;
  String? _lastLoadError;

  // Output indices for multi-output models
  int _mobilenetv2PredictionIndex = 1; // Default: predictions at output 1

  static const String mobilenetv2ModelPath =
      "assets/models/mobilenetv2_multi_output.tflite";
  static const String labelPath = "assets/models/class_indices.json";

  // MATCHING PYTHON: 224x224
  static const int inputSize = 224;

  bool get isModelLoaded => _mobilenetv2Interpreter != null;
  bool get areLabelsLoaded => _labels != null && _labels!.isNotEmpty;
  int get labelCount => _labels?.length ?? 0;
  String? get lastLoadError => _lastLoadError;
  bool get isReady => isModelLoaded && areLabelsLoaded;

  Map<String, dynamic> getModelHealth() {
    return {
      'modelLoaded': isModelLoaded,
      'labelsLoaded': areLabelsLoaded,
      'labelCount': labelCount,
      'modelPath': mobilenetv2ModelPath,
      'labelPath': labelPath,
      'lastLoadError': _lastLoadError,
    };
  }

  Future<void> loadModel() async {
    if (platform_utils.isDesktop()) {
      print(' [TflitePlantService] Skipping TFLite init on desktop platform');
      return;
    }
    try {
      _lastLoadError = null;
      // Load MobileNetV2 multi-output model (ONLY MODEL - HerbaScan deprecated)
      try {
        final otaTflitePath = OtaModelService.instance.tflitePath;
        if (otaTflitePath != null) {
          print(" Loading MobileNetV2 from OTA path: $otaTflitePath");
          _mobilenetv2Interpreter =
              await Interpreter.fromFile(File(otaTflitePath));
        } else {
          _mobilenetv2Interpreter =
              await Interpreter.fromAsset(mobilenetv2ModelPath);
        }
        _mobilenetv2Interpreter!.allocateTensors();
        _mobilenetv2PredictionIndex =
            _determinePredictionOutputIndex(_mobilenetv2Interpreter!);
        print(" MobileNetV2 Multi-Output TFLite Model loaded successfully.");
        print("   Prediction output index: $_mobilenetv2PredictionIndex");
      } catch (e) {
        print(" Error loading MobileNetV2 model: $e");
        throw Exception("Failed to load MobileNetV2 TFLite model: $e");
      }

      // Check if model loaded
      if (_mobilenetv2Interpreter == null) {
        throw Exception("Failed to load MobileNetV2 TFLite model");
      }

      await _loadLabels();
      if (!areLabelsLoaded) {
        throw Exception('Labels were not loaded from $labelPath');
      }
      print(" MobileNetV2 TFLite Model loaded successfully.");
    } catch (e) {
      _lastLoadError = e.toString();
      print(" Error loading model: $e");
      rethrow;
    }
  }

  /// Determine which output index contains predictions (2D tensor)
  /// Multi-output models have: [feature_maps (4D), predictions (2D)]
  int _determinePredictionOutputIndex(Interpreter interpreter) {
    final outputCount = interpreter.getOutputTensors().length;
    if (outputCount < 2) {
      return 0; // Single output model
    }

    // Check output shapes to find predictions (2D tensor)
    for (int i = 0; i < outputCount; i++) {
      final outputTensor = interpreter.getOutputTensor(i);
      final shape = outputTensor.shape;
      if (shape.length == 2) {
        // 2D tensor [batch, classes] = predictions
        return i;
      }
    }

    // Fallback: assume predictions at index 1
    return 1;
  }

  Future<void> _loadLabels() async {
    print("   📋 Loading labels from: $labelPath");
    try {
      final otaClassIndicesPath = OtaModelService.instance.classIndicesPath;
      final String labelData = otaClassIndicesPath != null
          ? await File(otaClassIndicesPath).readAsString()
          : await rootBundle.loadString(labelPath);
      print("   📋 Label data loaded: ${labelData.length} characters");
      final Map<String, dynamic> jsonMap = json.decode(labelData);
      print("   📋 Parsed ${jsonMap.length} labels");
      _labels = List<String>.filled(jsonMap.length, 'Unknown');
      jsonMap.forEach((name, index) {
        if (index is int && index < _labels!.length) {
          _labels![index] = name;
        }
      });
      print("    Labels loaded: ${_labels!.length} labels");
      print("    First 5 labels: ${_labels!.take(5).toList()}");
    } catch (e, stackTrace) {
      _lastLoadError = 'Failed to load labels: $e';
      print(" Error loading labels: $e");
      print("Stack trace: $stackTrace");
    }
  }

  Future<PlantPrediction?> predict(File imageFile) async {
    print(" [TflitePlantService] predict() called");
    print("   Image file: ${imageFile.path}");

    if (_mobilenetv2Interpreter == null) {
      print(" Model not loaded, loading now...");
      await loadModel();
    }

    print(
        "   MobileNetV2 interpreter: ${_mobilenetv2Interpreter != null ? "✅" : "❌"}");
    print(
        "   Labels loaded: ${_labels != null && _labels!.isNotEmpty ? "✅ (${_labels!.length} labels)" : "❌"}");

    if (_labels == null || _labels!.isEmpty) {
      print("    ERROR: Labels not loaded!");
      return null;
    }

    if (_mobilenetv2Interpreter == null) {
      print("   ERROR: MobileNetV2 model not loaded!");
      return null;
    }

    // 1. Decode Image
    print("    Decoding image...");
    final imageBytes = await imageFile.readAsBytes();
    print("    Image bytes: ${imageBytes.length} bytes");
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      print("    ERROR: Failed to decode image!");
      return null;
    }
    print(
        "    Image decoded: ${originalImage.width}x${originalImage.height}");
    // 2. Fix Rotation
    img.Image orientedImage = img.bakeOrientation(originalImage);

    // 3. Resize
    img.Image resizedImage = img.copyResize(orientedImage,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear);

    // 4. Preprocess (Convert to 4D list format)
    print("    Preprocessing image...");
    // Create 4D list: [batch][height][width][channels]
    // This matches the format expected by tflite_flutter
    var input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (h) => List.generate(
          inputSize,
          (w) => List.generate(3, (c) {
            final pixel = resizedImage.getPixel(w, h);
            // Normalize to [-1, 1] matching MobileNetV2 training convention.
            final raw = c == 0
                ? pixel.r.toDouble()
                : c == 1
                    ? pixel.g.toDouble()
                    : pixel.b.toDouble();
            return (raw / 255.0) * 2.0 - 1.0;
          }),
        ),
      ),
    );
    print("    Input shape: [1, $inputSize, $inputSize, 3]");
    print(
        "    Input sample (first pixel): R=${input[0][0][0][0]}, G=${input[0][0][0][1]}, B=${input[0][0][0][2]}");

    // 5. Run inference on MobileNetV2 model
    print("    Starting inference with MobileNetV2...");
    PlantPrediction? bestPrediction;
    double bestConfidence = -1.0;

    // Use MobileNetV2 multi-output model (ONLY MODEL)
    if (_mobilenetv2Interpreter != null) {
      try {
        // Multi-output model: extract predictions from the predictions output
        final numOutputs = _mobilenetv2Interpreter!.getOutputTensors().length;
        print(" MobileNetV2 model has $numOutputs outputs");

        final predictionsTensor = _mobilenetv2Interpreter!
            .getOutputTensor(_mobilenetv2PredictionIndex);
        final predictionsShape = predictionsTensor.shape;
        print(" MobileNetV2 predictions shape: $predictionsShape");

        // Create output buffer for predictions [batch, classes]
        var predictionsOutput = List.generate(
          predictionsShape[0],
          (_) => List.filled(predictionsShape[1], 0.0),
        );

        // For multi-output models, use runForMultipleInputs with output map
        // Create buffers for all outputs
        final outputMap = <int, Object>{};
        for (int i = 0; i < numOutputs; i++) {
          if (i == _mobilenetv2PredictionIndex) {
            outputMap[i] = predictionsOutput;
          } else {
            // Create buffer for feature maps output (we don't need it for predictions)
            final featureTensor = _mobilenetv2Interpreter!.getOutputTensor(i);
            final featureShape = featureTensor.shape;
            // Create 4D buffer for feature maps [batch, H, W, C]
            if (featureShape.length == 4) {
              final batch = featureShape[0];
              final height = featureShape[1];
              final width = featureShape[2];
              final channels = featureShape[3];
              final featureBuffer = List.generate(
                batch,
                (_) => List.generate(
                  height,
                  (_) => List.generate(
                    width,
                    (_) => List.filled(channels, 0.0),
                  ),
                ),
              );
              outputMap[i] = featureBuffer;
            } else {
              final featureSize = featureShape.fold(1, (a, b) => a * b);
              outputMap[i] = List.filled(featureSize, 0.0);
            }
          }
        }

        // Run inference using runForMultipleInputs (works better for multi-output)
        final inputs = [input];
        print(
            "    Running MobileNetV2 inference with ${outputMap.length} outputs...");
        _mobilenetv2Interpreter!.runForMultipleInputs(inputs, outputMap);
        print("    MobileNetV2 inference completed");

        // Extract predictions from batch 0
        List<double> outputList = List<double>.from(predictionsOutput[0]);
        print(
            " MobileNetV2 output length: ${outputList.length}, first 5: ${outputList.take(5).toList()}");

        double maxScore = -1.0;
        int maxIndex = -1;

        for (int i = 0; i < outputList.length; i++) {
          if (outputList[i] > maxScore) {
            maxScore = outputList[i];
            maxIndex = i;
          }
        }

        print(" MobileNetV2 maxIndex: $maxIndex, maxScore: $maxScore");
        if (maxIndex != -1 && maxIndex < _labels!.length) {
          bestConfidence = maxScore;
          bestPrediction =
              PlantPrediction(label: _labels![maxIndex], confidence: maxScore);
          print(
              " MobileNetV2: ${_labels![maxIndex]} (${(maxScore * 100).toStringAsFixed(2)}%)");
        } else {
          print(
              "⚠MobileNetV2: Invalid prediction (maxIndex: $maxIndex, labels length: ${_labels!.length}, score: $maxScore)");
        }
      } catch (e, stackTrace) {
        print(" Error running MobileNetV2 inference: $e");
        print("Stack trace: $stackTrace");
        return null;
      }
    } else {
      print(" ERROR: MobileNetV2 interpreter is null!");
      return null;
    }

    // 6. Return best result
    print("    Inference complete. Best confidence: $bestConfidence");
    if (bestPrediction != null) {
      print(
          "Best result: ${bestPrediction.label} (${(bestPrediction.confidence * 100).toStringAsFixed(2)}%)");

      // Use OodConfigService threshold (0.85 from config) to unify OOD gate.
      await OodConfigService().load();
      final oodThreshold = OodConfigService().confidenceThresholdAccept;
      if (bestPrediction.confidence > oodThreshold) {
        print("    Returning prediction (confidence > $oodThreshold)");
        return bestPrediction;
      } else {
        print(
            "    Prediction confidence too low: ${bestPrediction.confidence} (threshold: $oodThreshold)");
      }
    } else {
      print("    No valid prediction found!");
      print("    Best confidence was: $bestConfidence");
    }

    print("    Returning null - no valid prediction");
    return null;
  }

  /// Run inference and return the top-K predictions sorted by confidence
  /// (highest first). Used as a fallback when GradCAM/offline-CAM cannot
  /// initialize. Returns an empty list on any failure.
  Future<List<PlantPrediction>> predictTopK(File imageFile,
      {int k = 3}) async {
    print(" [TflitePlantService] predictTopK(k=$k) called");
    if (_mobilenetv2Interpreter == null) {
      await loadModel();
    }
    if (_labels == null ||
        _labels!.isEmpty ||
        _mobilenetv2Interpreter == null) {
      print(" predictTopK: model or labels not ready");
      return <PlantPrediction>[];
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return <PlantPrediction>[];
      final img.Image orientedImage = img.bakeOrientation(originalImage);
      final img.Image resizedImage = img.copyResize(orientedImage,
          width: inputSize,
          height: inputSize,
          interpolation: img.Interpolation.linear);

      final input = List.generate(
        1,
        (_) => List.generate(
          inputSize,
          (h) => List.generate(
            inputSize,
            (w) => List.generate(3, (c) {
              final pixel = resizedImage.getPixel(w, h);
              final raw = c == 0
                  ? pixel.r.toDouble()
                  : c == 1
                      ? pixel.g.toDouble()
                      : pixel.b.toDouble();
              return (raw / 255.0) * 2.0 - 1.0;
            }),
          ),
        ),
      );

      final numOutputs = _mobilenetv2Interpreter!.getOutputTensors().length;
      final predictionsTensor = _mobilenetv2Interpreter!
          .getOutputTensor(_mobilenetv2PredictionIndex);
      final predictionsShape = predictionsTensor.shape;
      final predictionsOutput = List.generate(
        predictionsShape[0],
        (_) => List.filled(predictionsShape[1], 0.0),
      );

      final outputMap = <int, Object>{};
      for (int i = 0; i < numOutputs; i++) {
        if (i == _mobilenetv2PredictionIndex) {
          outputMap[i] = predictionsOutput;
        } else {
          final featureTensor = _mobilenetv2Interpreter!.getOutputTensor(i);
          final featureShape = featureTensor.shape;
          if (featureShape.length == 4) {
            outputMap[i] = List.generate(
              featureShape[0],
              (_) => List.generate(
                featureShape[1],
                (_) => List.generate(
                  featureShape[2],
                  (_) => List.filled(featureShape[3], 0.0),
                ),
              ),
            );
          } else {
            final featureSize = featureShape.fold(1, (a, b) => a * b);
            outputMap[i] = List.filled(featureSize, 0.0);
          }
        }
      }

      _mobilenetv2Interpreter!.runForMultipleInputs([input], outputMap);
      final outputList = List<double>.from(predictionsOutput[0]);

      final indexed = List.generate(
          outputList.length, (i) => MapEntry(i, outputList[i]));
      indexed.sort((a, b) => b.value.compareTo(a.value));

      final results = <PlantPrediction>[];
      for (final entry in indexed.take(k)) {
        if (entry.key >= 0 && entry.key < _labels!.length) {
          results.add(PlantPrediction(
              label: _labels![entry.key], confidence: entry.value));
        }
      }
      print(" predictTopK: returning ${results.length} predictions");
      return results;
    } catch (e, st) {
      print(" predictTopK error: $e");
      print(st);
      return <PlantPrediction>[];
    }
  }

  Float32List _imageToByteListFloat32(img.Image image, int size) {
    var convertedBytes = Float32List(1 * size * size * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < size; i++) {
      for (var j = 0; j < size; j++) {
        final pixel = image.getPixel(j, i);

        // Normalize to [-1, 1] matching MobileNetV2 training convention.
        double r = (pixel.r.toDouble() / 255.0) * 2.0 - 1.0;
        double g = (pixel.g.toDouble() / 255.0) * 2.0 - 1.0;
        double b = (pixel.b.toDouble() / 255.0) * 2.0 - 1.0;

        buffer[pixelIndex++] = r;
        buffer[pixelIndex++] = g;
        buffer[pixelIndex++] = b;
      }
    }


    // This prints the exact math of the first pixel.
    // If these numbers are > 1.0, the math is wrong.
    // If these numbers are around 0.5, the math is correct.
    print("------------------------------------------------");
    print(" INPUT CHECK (First Pixel):");
    print("   R: ${buffer[0]}");
    print("   G: ${buffer[1]}");
    print("   B: ${buffer[2]}");
    print("------------------------------------------------");

    return convertedBytes;
  }

  void close() {
    _mobilenetv2Interpreter?.close();
    _mobilenetv2Interpreter = null;
    _labels = null;
    _lastLoadError = null;
  }
}
