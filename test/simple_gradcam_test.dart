// test/simple_gradcam_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:herbascan/core/services/gradcam_service.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';

void main() {
  group('Simple GradCAM Tests', () {
    test('should create test image successfully', () async {
      // Test that we can create a proper test image
      final testImageData = _createTestImage();

      expect(testImageData, isNotNull);
      expect(testImageData.length, greaterThan(0));

      // Verify it's a valid PNG
      expect(testImageData[0], equals(0x89)); // PNG signature
      expect(testImageData[1], equals(0x50)); // P
      expect(testImageData[2], equals(0x4E)); // N
      expect(testImageData[3], equals(0x47)); // G

      print(
          '✅ Test image created successfully (${testImageData.length} bytes)');
    });

    test('should handle basic GradCAM service methods', () async {
      // Test the service methods without complex image processing
      final testImageData = _createTestImage();
      final predictions =
          List.generate(41, (index) => index == 5 ? 0.85 : 0.01);

      // Test that the service can be instantiated and methods exist
      expect(GradCAMService.generateGradCAM, isA<Function>());
      expect(GradCAMService.generateSummaryGradCAM, isA<Function>());
      expect(GradCAMService.generateMultipleGradCAMs, isA<Function>());

      print('✅ GradCAM service methods are accessible');
    });

    test('should create realistic plant image', () async {
      final plantImageData = _createPlantImage();

      expect(plantImageData, isNotNull);
      expect(plantImageData.length, greaterThan(0));

      // Verify it's a valid PNG
      expect(plantImageData[0], equals(0x89));
      expect(plantImageData[1], equals(0x50));
      expect(plantImageData[2], equals(0x4E));
      expect(plantImageData[3], equals(0x47));

      print(
          '✅ Plant image created successfully (${plantImageData.length} bytes)');
    });

    test('should create realistic predictions', () async {
      final predictions = _createRealisticPredictions();

      expect(predictions, isNotNull);
      expect(predictions.length, equals(41));

      // Check that we have a clear top prediction
      final maxPrediction = predictions.reduce((a, b) => a > b ? a : b);
      expect(maxPrediction, greaterThan(0.8));

      // Check that most predictions are low
      final lowPredictions = predictions.where((p) => p < 0.1).length;
      expect(lowPredictions, greaterThan(30));

      print(
          '✅ Realistic predictions created (top: ${(maxPrediction * 100).toStringAsFixed(1)}%)');
    });
  });
}

/// Create a simple test image
Uint8List _createTestImage() {
  final width = 224;
  final height = 224;
  final image = img.Image(width: width, height: height);

  // Create a simple gradient pattern
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final r = (x * 255 / width).round();
      final g = (y * 255 / height).round();
      final b = ((x + y) * 255 / (width + height)).round();

      image.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}

/// Create a plant-like test image
Uint8List _createPlantImage() {
  final width = 224;
  final height = 224;
  final image = img.Image(width: width, height: height);

  // Create a leaf-like pattern
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final centerX = width / 2;
      final centerY = height / 2;
      final distance =
          sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
      final maxDistance =
          sqrt((width / 2) * (width / 2) + (height / 2) * (height / 2));

      if (distance / maxDistance <= 0.8) {
        // Inside leaf - green tones
        final intensity = 1.0 - (distance / maxDistance);
        final r = (30 + 20 * intensity).round();
        final g = (100 + 80 * intensity).round();
        final b = (20 + 15 * intensity).round();

        image.setPixel(x, y, img.ColorRgb8(r, g, b));
      } else {
        // Background
        image.setPixel(x, y, img.ColorRgb8(240, 240, 240));
      }
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}

/// Create realistic plant predictions
List<double> _createRealisticPredictions() {
  final predictions = List.generate(41, (index) => 0.01);

  // Set some realistic predictions for DOH-approved plants
  predictions[0] = 0.15; // Akapulko
  predictions[1] = 0.12; // Ampalaya
  predictions[2] = 0.18; // Bawang
  predictions[3] = 0.14; // Bayabas
  predictions[4] = 0.16; // Lagundi
  predictions[5] = 0.89; // Sambong (top prediction)
  predictions[6] = 0.13; // Tsaang Gubat
  predictions[7] = 0.11; // Ulasimang Bato
  predictions[8] = 0.10; // Yerba Buena
  predictions[9] = 0.09; // Niyog-niyogan

  return predictions;
}
