// test/working_gradcam_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';

void main() {
  group('Working GradCAM Tests', () {
    test('should create and save heatmap image', () async {
      print('🧪 Testing basic heatmap creation...');
      
      // Create a test image
      final testImage = _createTestImage();
      
      // Create a simple heatmap
      final heatmap = _createSimpleHeatmap();
      
      // Overlay heatmap on image
      final resultImage = _overlayHeatmap(testImage, heatmap);
      
      // Save the result
      final directory = await Directory.systemTemp.create();
      final file = File('${directory.path}/test_gradcam.png');
      await file.writeAsBytes(img.encodePng(resultImage));
      
      print('✅ Heatmap image created: ${file.path}');
      print('📊 File size: ${await file.length()} bytes');
      
      // Verify the file was created
      expect(await file.exists(), isTrue);
      final fileSize = await file.length();
      expect(fileSize, greaterThan(1000));
      
      // Verify it's a valid PNG
      final bytes = await file.readAsBytes();
      expect(bytes[0], equals(0x89)); // PNG signature
      expect(bytes[1], equals(0x50)); // P
      expect(bytes[2], equals(0x4E)); // N
      expect(bytes[3], equals(0x47)); // G
      
      print('✅ Valid PNG heatmap generated');
      
      // Clean up
      await file.delete();
      print('🗑️ Test file cleaned up');
    });
    
    test('should create realistic plant heatmap', () async {
      print('🧪 Testing realistic plant heatmap...');
      
      // Create a plant-like image
      final plantImage = _createPlantImage();
      
      // Create a realistic heatmap
      final heatmap = _createRealisticHeatmap();
      
      // Overlay heatmap on image
      final resultImage = _overlayHeatmap(plantImage, heatmap);
      
      // Save the result
      final directory = await Directory.systemTemp.create();
      final file = File('${directory.path}/plant_gradcam.png');
      await file.writeAsBytes(img.encodePng(resultImage));
      
      print('✅ Plant GradCAM created: ${file.path}');
      print('📊 File size: ${await file.length()} bytes');
      
      // Verify the file was created
      expect(await file.exists(), isTrue);
      final fileSize = await file.length();
      expect(fileSize, greaterThan(1000));
      
      print('✅ Plant GradCAM generated successfully');
      
      // Clean up
      await file.delete();
      print('🗑️ Test file cleaned up');
    });
    
    test('should handle different attention patterns', () async {
      print('🧪 Testing different attention patterns...');
      
      final plantImage = _createPlantImage();
      
      // Test different attention patterns
      final patterns = [
        {'name': 'High Attention Center', 'pattern': _createCenterAttentionPattern()},
        {'name': 'High Attention Edges', 'pattern': _createEdgeAttentionPattern()},
        {'name': 'Random Attention', 'pattern': _createRandomAttentionPattern()},
      ];
      
      for (final pattern in patterns) {
        print('🔄 Testing ${pattern['name']}...');
        
        final resultImage = _overlayHeatmap(plantImage, pattern['pattern'] as List<List<double>>);
        
        // Save the result
        final directory = await Directory.systemTemp.create();
        final fileName = '${pattern['name'].toString().toLowerCase().replaceAll(' ', '_')}_gradcam.png';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(img.encodePng(resultImage));
        
        print('✅ ${pattern['name']} GradCAM created: ${file.path}');
        
        // Verify the file was created
        expect(await file.exists(), isTrue);
        final fileSize = await file.length();
        expect(fileSize, greaterThan(1000));
        
        await file.delete();
      }
      
      print('✅ All attention patterns tested successfully');
    });
  });
}

/// Create a test image
img.Image _createTestImage() {
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
  
  return image;
}

/// Create a plant-like image
img.Image _createPlantImage() {
  final width = 224;
  final height = 224;
  final image = img.Image(width: width, height: height);
  
  // Create a leaf-like pattern
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final centerX = width / 2;
      final centerY = height / 2;
      final distance = sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
      final maxDistance = sqrt((width / 2) * (width / 2) + (height / 2) * (height / 2));
      
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
  
  return image;
}

/// Create a simple heatmap
List<List<double>> _createSimpleHeatmap() {
  final size = 14;
  final heatmap = List.generate(size, (i) => List.generate(size, (j) => 0.0));
  
  // Create a simple pattern
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final centerX = size / 2;
      final centerY = size / 2;
      final distance = sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
      final maxDistance = sqrt((size / 2) * (size / 2) + (size / 2) * (size / 2));
      
      heatmap[y][x] = 1.0 - (distance / maxDistance);
    }
  }
  
  return heatmap;
}

/// Create a realistic heatmap
List<List<double>> _createRealisticHeatmap() {
  final size = 14;
  final heatmap = List.generate(size, (i) => List.generate(size, (j) => 0.0));
  
  // Create a more realistic attention pattern
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      // Create multiple attention regions
      final centerX = size / 2;
      final centerY = size / 2;
      final distance = sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
      final maxDistance = sqrt((size / 2) * (size / 2) + (size / 2) * (size / 2));
      
      // Main attention region
      final mainAttention = 1.0 - (distance / maxDistance);
      
      // Add some noise and variations
      final noise = (sin(x * 0.5) * cos(y * 0.5) * 0.2);
      final variation = sin(x * 0.3) * cos(y * 0.3) * 0.1;
      
      heatmap[y][x] = (mainAttention + noise + variation).clamp(0.0, 1.0);
    }
  }
  
  return heatmap;
}

/// Create center attention pattern
List<List<double>> _createCenterAttentionPattern() {
  final size = 14;
  final heatmap = List.generate(size, (i) => List.generate(size, (j) => 0.0));
  
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final centerX = size / 2;
      final centerY = size / 2;
      final distance = sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
      final maxDistance = sqrt((size / 2) * (size / 2) + (size / 2) * (size / 2));
      
      heatmap[y][x] = 1.0 - (distance / maxDistance);
    }
  }
  
  return heatmap;
}

/// Create edge attention pattern
List<List<double>> _createEdgeAttentionPattern() {
  final size = 14;
  final heatmap = List.generate(size, (i) => List.generate(size, (j) => 0.0));
  
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final centerX = size / 2;
      final centerY = size / 2;
      final distance = sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
      final maxDistance = sqrt((size / 2) * (size / 2) + (size / 2) * (size / 2));
      
      // Invert the pattern for edge attention
      heatmap[y][x] = distance / maxDistance;
    }
  }
  
  return heatmap;
}

/// Create random attention pattern
List<List<double>> _createRandomAttentionPattern() {
  final size = 14;
  final heatmap = List.generate(size, (i) => List.generate(size, (j) => 0.0));
  final random = Random();
  
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      heatmap[y][x] = random.nextDouble();
    }
  }
  
  return heatmap;
}

/// Overlay heatmap on image
img.Image _overlayHeatmap(img.Image image, List<List<double>> heatmap) {
  final result = img.Image.from(image);
  final heatmapSize = heatmap.length;
  
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      // Map image coordinates to heatmap coordinates
      final heatmapX = (x * heatmapSize / image.width).floor();
      final heatmapY = (y * heatmapSize / image.height).floor();
      
      if (heatmapY < heatmap.length && heatmapX < heatmap[heatmapY].length) {
        final attentionValue = heatmap[heatmapY][heatmapX];
        
        // Get original pixel
        final originalPixel = image.getPixel(x, y);
        
        // Create heatmap color based on attention value
        int r, g, b;
        if (attentionValue < 0.5) {
          // Blue to green
          final intensity = (attentionValue * 2).clamp(0.0, 1.0);
          r = (intensity * 0).round();
          g = (intensity * 255).round();
          b = 255;
        } else {
          // Green to red
          final intensity = ((attentionValue - 0.5) * 2).clamp(0.0, 1.0);
          r = 255;
          g = ((1 - intensity) * 255).round();
          b = 0;
        }
        
        // Blend with original pixel
        final alpha = 0.6;
        final blendedR = (originalPixel.r * (1 - alpha) + r * alpha).round();
        final blendedG = (originalPixel.g * (1 - alpha) + g * alpha).round();
        final blendedB = (originalPixel.b * (1 - alpha) + b * alpha).round();
        
        result.setPixel(x, y, img.ColorRgb8(blendedR, blendedG, blendedB));
      }
    }
  }
  
  return result;
}
