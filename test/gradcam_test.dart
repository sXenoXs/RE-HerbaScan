// test/gradcam_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:herbascan/core/services/gradcam_service.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';

void main() {
  group('GradCAM Service Tests', () {
    test('should generate GradCAM heatmap for valid input', () async {
      // Create a test image (224x224 RGB)
      final testImageData = _createTestImageData();
      final predictions = List.generate(41, (index) => index == 5 ? 0.85 : 0.01);
      const targetClassIndex = 5;
      
      final result = await GradCAMService.generateGradCAM(
        imageData: testImageData,
        predictions: predictions,
        targetClassIndex: targetClassIndex,
      );
      
      expect(result, isNotNull);
      expect(result, isA<String>());
      
      // Verify the file was created
      final file = File(result!);
      expect(await file.exists(), isTrue);
      
      // Clean up
      await file.delete();
    });
    
    test('should generate summary GradCAM', () async {
      final testImageData = _createTestImageData();
      final predictions = List.generate(41, (index) => index == 3 ? 0.75 : 0.02);
      
      final result = await GradCAMService.generateSummaryGradCAM(
        imageData: testImageData,
        predictions: predictions,
      );
      
      expect(result, isNotNull);
      expect(result, isA<String>());
      
      // Verify the file was created
      final file = File(result!);
      expect(await file.exists(), isTrue);
      
      // Clean up
      await file.delete();
    });
    
    test('should handle empty predictions gracefully', () async {
      final testImageData = _createTestImageData();
      final predictions = <double>[];
      const targetClassIndex = 0;
      
      final result = await GradCAMService.generateGradCAM(
        imageData: testImageData,
        predictions: predictions,
        targetClassIndex: targetClassIndex,
      );
      
      // Should still work with empty predictions
      expect(result, isNotNull);
      
      if (result != null) {
        final file = File(result);
        expect(await file.exists(), isTrue);
        await file.delete();
      }
    });
    
    test('should handle invalid image data', () async {
      final invalidImageData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final predictions = List.generate(41, (index) => 0.1);
      const targetClassIndex = 0;
      
      final result = await GradCAMService.generateGradCAM(
        imageData: invalidImageData,
        predictions: predictions,
        targetClassIndex: targetClassIndex,
      );
      
      // Should return null for invalid image data
      expect(result, isNull);
    });
    
    test('should generate multiple GradCAMs for top predictions', () async {
      final testImageData = _createTestImageData();
      final predictions = List.generate(41, (index) {
        if (index == 5) return 0.85;
        if (index == 12) return 0.70;
        if (index == 8) return 0.60;
        return 0.01;
      });
      final topClassIndices = [5, 12, 8];
      
      final results = await GradCAMService.generateMultipleGradCAMs(
        imageData: testImageData,
        predictions: predictions,
        topClassIndices: topClassIndices,
      );
      
      expect(results, isA<List<String>>());
      expect(results.length, equals(3));
      
      // Verify all files were created
      for (final path in results) {
        final file = File(path);
        expect(await file.exists(), isTrue);
        await file.delete();
      }
    });
  });
}

/// Create a test image data (224x224 RGB)
Uint8List _createTestImageData() {
  // Create a proper PNG image using the image package
  final width = 224;
  final height = 224;
  final image = img.Image(width: width, height: height);
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Create a gradient pattern
      final r = (x * 255 / width).round();
      final g = (y * 255 / height).round();
      final b = ((x + y) * 255 / (width + height)).round();
      
      image.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }
  
  return Uint8List.fromList(img.encodePng(image));
}
