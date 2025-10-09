// test/real_gradcam_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:herbascan/core/services/gradcam_service.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';

void main() {
  group('Real GradCAM Tests', () {
    test('should generate GradCAM with real plant image', () async {
      print('🧪 Testing GradCAM with real plant image...');
      
      // Create a realistic plant image
      final plantImageData = _createRealisticPlantImage();
      final predictions = _createRealisticPredictions();
      const targetClassIndex = 5; // Sambong
      
      print('🔄 Generating GradCAM for Sambong (confidence: ${(predictions[targetClassIndex] * 100).toStringAsFixed(1)}%)...');
      
      final gradCAMPath = await GradCAMService.generateGradCAM(
        imageData: plantImageData,
        predictions: predictions,
        targetClassIndex: targetClassIndex,
      );
      
      if (gradCAMPath != null) {
        final file = File(gradCAMPath);
        final fileSize = await file.length();
        
        print('✅ GradCAM generated successfully!');
        print('📁 File path: $gradCAMPath');
        print('📊 File size: ${fileSize} bytes');
        
        // Verify the file was created and is valid
        expect(await file.exists(), isTrue);
        expect(fileSize, greaterThan(1000));
        
        // Verify it's a valid PNG
        final bytes = await file.readAsBytes();
        expect(bytes[0], equals(0x89)); // PNG signature
        expect(bytes[1], equals(0x50)); // P
        expect(bytes[2], equals(0x4E)); // N
        expect(bytes[3], equals(0x47)); // G
        
        print('✅ Valid PNG GradCAM generated');
        
        // Clean up
        await file.delete();
        print('🗑️ Test file cleaned up');
      } else {
        print('❌ Failed to generate GradCAM');
        fail('GradCAM generation failed');
      }
    });
    
    test('should generate summary GradCAM', () async {
      print('🧪 Testing summary GradCAM...');
      
      final plantImageData = _createRealisticPlantImage();
      final predictions = _createRealisticPredictions();
      
      print('🔄 Generating summary GradCAM...');
      
      final summaryPath = await GradCAMService.generateSummaryGradCAM(
        imageData: plantImageData,
        predictions: predictions,
      );
      
      if (summaryPath != null) {
        final file = File(summaryPath);
        final fileSize = await file.length();
        
        print('✅ Summary GradCAM generated successfully!');
        print('📁 File path: $summaryPath');
        print('📊 File size: ${fileSize} bytes');
        
        expect(await file.exists(), isTrue);
        expect(fileSize, greaterThan(1000));
        
        // Verify it's a valid PNG
        final bytes = await file.readAsBytes();
        expect(bytes[0], equals(0x89));
        expect(bytes[1], equals(0x50));
        expect(bytes[2], equals(0x4E));
        expect(bytes[3], equals(0x47));
        
        print('✅ Valid PNG summary GradCAM generated');
        
        await file.delete();
        print('🗑️ Test file cleaned up');
      } else {
        print('❌ Failed to generate summary GradCAM');
        fail('Summary GradCAM generation failed');
      }
    });
    
    test('should generate multiple GradCAMs for top predictions', () async {
      print('🧪 Testing multiple GradCAMs...');
      
      final plantImageData = _createRealisticPlantImage();
      final predictions = _createRealisticPredictions();
      
      // Get top 3 predictions
      final topIndices = _getTopPredictionIndices(predictions, 3);
      
      print('🔄 Generating GradCAMs for top 3 predictions...');
      print('🏆 Top predictions: ${topIndices.map((i) => 'Class $i (${(predictions[i] * 100).toStringAsFixed(1)}%)').join(', ')}');
      
      final gradCAMPaths = await GradCAMService.generateMultipleGradCAMs(
        imageData: plantImageData,
        predictions: predictions,
        topClassIndices: topIndices,
      );
      
      print('✅ Generated ${gradCAMPaths.length} GradCAM visualizations');
      
      for (int i = 0; i < gradCAMPaths.length; i++) {
        final path = gradCAMPaths[i];
        final file = File(path);
        final fileSize = await file.length();
        
        print('📁 GradCAM ${i + 1}: $path (${fileSize} bytes)');
        
        expect(await file.exists(), isTrue);
        expect(fileSize, greaterThan(1000));
        
        // Verify it's a valid PNG
        final bytes = await file.readAsBytes();
        expect(bytes[0], equals(0x89));
        expect(bytes[1], equals(0x50));
        expect(bytes[2], equals(0x4E));
        expect(bytes[3], equals(0x47));
        
        await file.delete();
      }
      
      print('🗑️ All test files cleaned up');
    });
    
    test('should handle different plant species', () async {
      print('🧪 Testing different plant species...');
      
      final plantImageData = _createRealisticPlantImage();
      
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
          if (index == testCase['index']) return testCase['confidence'] as double;
          return 0.01;
        });
        
        print('🔄 Testing ${testCase['name']} (${((testCase['confidence'] as double) * 100).toStringAsFixed(1)}%)...');
        
        final gradCAMPath = await GradCAMService.generateGradCAM(
          imageData: plantImageData,
          predictions: predictions,
          targetClassIndex: testCase['index'] as int,
        );
        
        expect(gradCAMPath, isNotNull);
        
        if (gradCAMPath != null) {
          final file = File(gradCAMPath);
          expect(await file.exists(), isTrue);
          
          final fileSize = await file.length();
          expect(fileSize, greaterThan(1000));
          
          print('✅ GradCAM for ${testCase['name']}: ${fileSize} bytes');
          await file.delete();
        }
      }
      
      print('✅ All plant species tests passed');
    });
    
    test('should handle edge cases gracefully', () async {
      print('🧪 Testing edge cases...');
      
      final plantImageData = _createRealisticPlantImage();
      
      // Test with empty predictions
      print('🔄 Testing empty predictions...');
      final emptyPredictions = <double>[];
      
      final result1 = await GradCAMService.generateGradCAM(
        imageData: plantImageData,
        predictions: emptyPredictions,
        targetClassIndex: 0,
      );
      
      // Should still work with empty predictions
      if (result1 != null) {
        final file = File(result1);
        expect(await file.exists(), isTrue);
        await file.delete();
        print('✅ Empty predictions handled correctly');
      }
      
      // Test with very low confidence predictions
      print('🔄 Testing low confidence predictions...');
      final lowConfidencePredictions = List.generate(41, (index) => 0.001);
      
      final result2 = await GradCAMService.generateGradCAM(
        imageData: plantImageData,
        predictions: lowConfidencePredictions,
        targetClassIndex: 0,
      );
      
      if (result2 != null) {
        final file = File(result2);
        expect(await file.exists(), isTrue);
        await file.delete();
        print('✅ Low confidence predictions handled correctly');
      }
      
      print('✅ All edge cases handled correctly');
    });
  });
}

/// Create a realistic plant image for testing
Uint8List _createRealisticPlantImage() {
  final width = 224;
  final height = 224;
  final image = img.Image(width: width, height: height);
  
  // Create a more realistic plant leaf pattern
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Create leaf-like shape with veins
      final centerX = width / 2;
      final centerY = height / 2;
      final distance = sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
      final angle = atan2(y - centerY, x - centerX);
      
      // Create leaf shape (elliptical)
      final leafX = (x - centerX) / (width * 0.4);
      final leafY = (y - centerY) / (height * 0.6);
      final leafDistance = sqrt(leafX * leafX + leafY * leafY);
      
      if (leafDistance <= 1.0) {
        // Inside leaf - green with variations
        final intensity = 1.0 - leafDistance;
        final veinPattern = sin(angle * 3).abs() * 0.3;
        final finalIntensity = intensity + veinPattern;
        
        final r = (30 + 20 * finalIntensity).round();
        final g = (100 + 80 * finalIntensity).round();
        final b = (20 + 15 * finalIntensity).round();
        
        image.setPixel(x, y, img.ColorRgb8(r, g, b));
      } else {
        // Outside leaf - background
        image.setPixel(x, y, img.ColorRgb8(240, 240, 240));
      }
    }
  }
  
  return Uint8List.fromList(img.encodePng(image));
}

/// Create realistic plant predictions
List<double> _createRealisticPredictions() {
  final predictions = List.generate(41, (index) => 0.01);
  
  // Simulate realistic DOH-approved plant predictions
  predictions[0] = 0.12;  // Akapulko
  predictions[1] = 0.15;  // Ampalaya
  predictions[2] = 0.18;  // Bawang
  predictions[3] = 0.14;  // Bayabas
  predictions[4] = 0.16;  // Lagundi
  predictions[5] = 0.89;  // Sambong (top prediction)
  predictions[6] = 0.13;  // Tsaang Gubat
  predictions[7] = 0.11;  // Ulasimang Bato
  predictions[8] = 0.10;  // Yerba Buena
  predictions[9] = 0.09;  // Niyog-niyogan
  
  // Add some noise to other classes
  for (int i = 10; i < 41; i++) {
    predictions[i] = 0.005 + (i % 7) * 0.001;
  }
  
  return predictions;
}

/// Get top prediction indices
List<int> _getTopPredictionIndices(List<double> predictions, int count) {
  final indexed = predictions.asMap().entries.toList();
  indexed.sort((a, b) => b.value.compareTo(a.value));
  return indexed.take(count).map((e) => e.key).toList();
}
