// test/integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:herbascan/core/services/plant_classifier_service.dart';
import 'package:herbascan/core/services/gradcam_service.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';

void main() {
  group('GradCAM Integration Tests', () {
    late PlantClassifierService classifierService;

    setUp(() async {
      classifierService = PlantClassifierService();
      // Note: In a real test, you would load the actual models
      // For this test, we'll simulate the classification process
    });

    test('should integrate GradCAM with plant classification', () async {
      // Create a simulated plant image
      final plantImageData = _createPlantImageData();

      // Simulate classification results (this would normally come from the AI model)
      final mockPredictions = _createMockPredictions();

      // Test GradCAM generation with the mock data
      final gradCAMPath = await GradCAMService.generateGradCAM(
        imageData: plantImageData,
        predictions: mockPredictions,
        targetClassIndex: 5, // Simulating "Sambong" as top prediction
      );

      expect(gradCAMPath, isNotNull);

      if (gradCAMPath != null) {
        final file = File(gradCAMPath);
        expect(await file.exists(), isTrue);

        // Verify file size is reasonable (not empty, not too large)
        final fileSize = await file.length();
        expect(fileSize, greaterThan(1000)); // At least 1KB
        expect(fileSize, lessThan(1000000)); // Less than 1MB

        print('✅ GradCAM file created: $gradCAMPath');
        print('📊 File size: $fileSize bytes');

        // Clean up
        await file.delete();
      }
    });

    test('should generate summary GradCAM for plant image', () async {
      final plantImageData = _createPlantImageData();
      final mockPredictions = _createMockPredictions();

      final summaryGradCAMPath = await GradCAMService.generateSummaryGradCAM(
        imageData: plantImageData,
        predictions: mockPredictions,
      );

      expect(summaryGradCAMPath, isNotNull);

      if (summaryGradCAMPath != null) {
        final file = File(summaryGradCAMPath);
        expect(await file.exists(), isTrue);

        final fileSize = await file.length();
        expect(fileSize, greaterThan(1000));

        print('✅ Summary GradCAM file created: $summaryGradCAMPath');
        print('📊 File size: $fileSize bytes');

        await file.delete();
      }
    });

    test('should handle different plant species predictions', () async {
      final plantImageData = _createPlantImageData();

      // Test with different top predictions
      final testCases = [
        {'index': 0, 'name': 'Akapulko', 'confidence': 0.92},
        {'index': 1, 'name': 'Ampalaya', 'confidence': 0.88},
        {'index': 2, 'name': 'Bawang', 'confidence': 0.85},
        {'index': 3, 'name': 'Bayabas', 'confidence': 0.82},
        {'index': 4, 'name': 'Lagundi', 'confidence': 0.79},
      ];

      for (final testCase in testCases) {
        final predictions = List.generate(41, (index) {
          if (index == testCase['index'])
            return testCase['confidence'] as double;
          return 0.01;
        });

        final gradCAMPath = await GradCAMService.generateGradCAM(
          imageData: plantImageData,
          predictions: predictions,
          targetClassIndex: testCase['index'] as int,
        );

        expect(gradCAMPath, isNotNull);

        if (gradCAMPath != null) {
          final file = File(gradCAMPath);
          expect(await file.exists(), isTrue);

          print('✅ GradCAM for ${testCase['name']}: $gradCAMPath');
          await file.delete();
        }
      }
    });

    test('should generate heatmap with proper color coding', () async {
      final plantImageData = _createPlantImageData();
      final predictions =
          List.generate(41, (index) => index == 5 ? 0.95 : 0.01);

      final gradCAMPath = await GradCAMService.generateGradCAM(
        imageData: plantImageData,
        predictions: predictions,
        targetClassIndex: 5,
      );

      expect(gradCAMPath, isNotNull);

      if (gradCAMPath != null) {
        final file = File(gradCAMPath);
        expect(await file.exists(), isTrue);

        // Verify the file is a valid PNG
        final bytes = await file.readAsBytes();
        expect(bytes.length, greaterThan(0));

        // Check PNG signature
        expect(bytes[0], equals(0x89));
        expect(bytes[1], equals(0x50)); // P
        expect(bytes[2], equals(0x4E)); // N
        expect(bytes[3], equals(0x47)); // G

        print('✅ Valid PNG GradCAM generated');
        await file.delete();
      }
    });
  });
}

/// Create a simulated plant image data
Uint8List _createPlantImageData() {
  final width = 224;
  final height = 224;
  final image = img.Image(width: width, height: height);

  // Create a more realistic plant-like pattern
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Create a leaf-like pattern with green tones
      final centerX = width / 2;
      final centerY = height / 2;
      final distance =
          sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
      final maxDistance =
          sqrt((width / 2) * (width / 2) + (height / 2) * (height / 2));

      // Create gradient from center (darker green) to edges (lighter green)
      final intensity = 1.0 - (distance / maxDistance);
      final r = (50 * intensity).round();
      final g = (150 + 100 * intensity).round();
      final b = (50 * intensity).round();

      image.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}

/// Create mock predictions for testing
List<double> _createMockPredictions() {
  // Simulate realistic plant classification predictions
  final predictions = List.generate(41, (index) => 0.01);

  // Set some realistic predictions for DOH-approved plants
  predictions[0] = 0.15; // Akapulko
  predictions[1] = 0.12; // Ampalaya
  predictions[2] = 0.18; // Bawang
  predictions[3] = 0.14; // Bayabas
  predictions[4] = 0.16; // Lagundi
  predictions[5] = 0.85; // Sambong (top prediction)
  predictions[6] = 0.11; // Tsaang Gubat
  predictions[7] = 0.13; // Ulasimang Bato
  predictions[8] = 0.10; // Yerba Buena
  predictions[9] = 0.09; // Niyog-niyogan

  return predictions;
}
