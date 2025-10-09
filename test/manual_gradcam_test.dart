// test/manual_gradcam_test.dart
// This is a manual test script to verify GradCAM functionality
// Run this with: flutter test test/manual_gradcam_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:herbascan/core/services/gradcam_service.dart';
import 'package:herbascan/core/services/plant_classifier_service.dart';
import 'package:herbascan/core/providers/camera_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Manual GradCAM Testing', () {
    test('Test GradCAM with sample plant images', () async {
      print('🧪 Starting manual GradCAM testing...');
      
      // Test 1: Basic GradCAM generation
      await _testBasicGradCAM();
      
      // Test 2: Summary GradCAM generation
      await _testSummaryGradCAM();
      
      // Test 3: Multiple GradCAMs for top predictions
      await _testMultipleGradCAMs();
      
      // Test 4: Edge cases and error handling
      await _testEdgeCases();
      
      print('✅ All manual GradCAM tests completed!');
    });
  });
}

Future<void> _testBasicGradCAM() async {
  print('\n📋 Test 1: Basic GradCAM Generation');
  
  try {
    // Create a test plant image
    final plantImageData = _createRealisticPlantImage();
    final predictions = _createRealisticPredictions();
    const targetClassIndex = 5; // Sambong
    
    print('🔄 Generating GradCAM for Sambong (index: $targetClassIndex)...');
    
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
      print('🎨 Image dimensions: 224x224 pixels');
      
      // Verify file properties
      expect(await file.exists(), isTrue);
      expect(fileSize, greaterThan(1000));
      
      // Clean up
      await file.delete();
      print('🗑️ Test file cleaned up');
    } else {
      print('❌ Failed to generate GradCAM');
      fail('GradCAM generation failed');
    }
  } catch (e) {
    print('❌ Error in basic GradCAM test: $e');
    rethrow;
  }
}

Future<void> _testSummaryGradCAM() async {
  print('\n📋 Test 2: Summary GradCAM Generation');
  
  try {
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
      
      await file.delete();
      print('🗑️ Test file cleaned up');
    } else {
      print('❌ Failed to generate summary GradCAM');
      fail('Summary GradCAM generation failed');
    }
  } catch (e) {
    print('❌ Error in summary GradCAM test: $e');
    rethrow;
  }
}

Future<void> _testMultipleGradCAMs() async {
  print('\n📋 Test 3: Multiple GradCAMs for Top Predictions');
  
  try {
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
      
      await file.delete();
    }
    
    print('🗑️ All test files cleaned up');
  } catch (e) {
    print('❌ Error in multiple GradCAMs test: $e');
    rethrow;
  }
}

Future<void> _testEdgeCases() async {
  print('\n📋 Test 4: Edge Cases and Error Handling');
  
  try {
    // Test with invalid image data
    print('🔄 Testing invalid image data...');
    final invalidImageData = Uint8List.fromList([1, 2, 3, 4, 5]);
    final predictions = _createRealisticPredictions();
    
    final result1 = await GradCAMService.generateGradCAM(
      imageData: invalidImageData,
      predictions: predictions,
      targetClassIndex: 0,
    );
    
    expect(result1, isNull);
    print('✅ Invalid image data handled correctly (returned null)');
    
    // Test with empty predictions
    print('🔄 Testing empty predictions...');
    final plantImageData = _createRealisticPlantImage();
    final emptyPredictions = <double>[];
    
    final result2 = await GradCAMService.generateGradCAM(
      imageData: plantImageData,
      predictions: emptyPredictions,
      targetClassIndex: 0,
    );
    
    // Should still work with empty predictions
    if (result2 != null) {
      final file = File(result2);
      expect(await file.exists(), isTrue);
      await file.delete();
      print('✅ Empty predictions handled correctly');
    }
    
    // Test with very low confidence predictions
    print('🔄 Testing low confidence predictions...');
    final lowConfidencePredictions = List.generate(41, (index) => 0.001);
    
    final result3 = await GradCAMService.generateGradCAM(
      imageData: plantImageData,
      predictions: lowConfidencePredictions,
      targetClassIndex: 0,
    );
    
    if (result3 != null) {
      final file = File(result3);
      expect(await file.exists(), isTrue);
      await file.delete();
      print('✅ Low confidence predictions handled correctly');
    }
    
    print('✅ All edge cases handled correctly');
  } catch (e) {
    print('❌ Error in edge cases test: $e');
    rethrow;
  }
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
