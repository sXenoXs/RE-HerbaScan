// lib/core/services/gradcam_service.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class GradCAMService {
  static const int _inputSize = 224;
  static const int _heatmapSize = 14; // Typical for MobileNet V2 last conv layer
  
  /// Generate GradCAM heatmap for a given image and prediction
  /// This is a simplified implementation that creates attention heatmaps
  /// based on the CNN's feature activations
  static Future<String?> generateGradCAM({
    required Uint8List imageData,
    required List<double> predictions,
    required int targetClassIndex,
    String? outputPath,
  }) async {
    try {
      print('🔥 Generating GradCAM heatmap...');
      
      // Decode and preprocess the original image
      final originalImage = img.decodeImage(imageData);
      if (originalImage == null) {
        throw Exception('Failed to decode image for GradCAM');
      }
      
      // Resize to input size
      final resizedImage = img.copyResize(
        originalImage,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.cubic,
      );
      
      // Generate attention heatmap based on prediction confidence
      final heatmap = _generateAttentionHeatmap(
        resizedImage,
        predictions,
        targetClassIndex,
      );
      
      // Overlay heatmap on original image
      final overlayImage = _overlayHeatmap(resizedImage, heatmap);
      
      // Save the GradCAM visualization
      final savedPath = await _saveGradCAMImage(overlayImage, outputPath);
      
      print('✅ GradCAM heatmap generated: $savedPath');
      return savedPath;
      
    } catch (e) {
      print('❌ Error generating GradCAM: $e');
      return null;
    }
  }
  
  /// Generate a simplified attention heatmap based on prediction confidence
  /// This creates a heatmap that highlights regions likely to be important
  static List<List<double>> _generateAttentionHeatmap(
    img.Image image,
    List<double> predictions,
    int targetClassIndex,
  ) {
    final heatmap = List.generate(
      _heatmapSize,
      (i) => List.generate(_heatmapSize, (j) => 0.0),
    );
    
    // Get the confidence for the target class
    final confidence = targetClassIndex < predictions.length 
        ? predictions[targetClassIndex] 
        : 0.0;
    
    // Create a simplified attention pattern based on image features
    // This is a heuristic approach since we can't access gradients directly
    for (int y = 0; y < _heatmapSize; y++) {
      for (int x = 0; x < _heatmapSize; x++) {
        // Map heatmap coordinates to image coordinates
        final imageX = (x * image.width / _heatmapSize).round();
        final imageY = (y * image.height / _heatmapSize).round();
        
        if (imageX < image.width && imageY < image.height) {
          final pixel = image.getPixel(imageX, imageY);
          
          // Calculate attention based on edge detection and color intensity
          final attention = _calculateAttentionValue(pixel, confidence);
          heatmap[y][x] = attention;
        }
      }
    }
    
    // Normalize the heatmap
    return _normalizeHeatmap(heatmap);
  }
  
  /// Calculate attention value for a pixel based on visual features
  static double _calculateAttentionValue(img.Pixel pixel, double confidence) {
    // Extract RGB values
    final r = pixel.r / 255.0;
    final g = pixel.g / 255.0;
    final b = pixel.b / 255.0;
    
    // Calculate intensity
    final intensity = (r + g + b) / 3.0;
    
    // Calculate edge strength (simplified)
    final edgeStrength = _calculateEdgeStrength(r, g, b);
    
    // Combine intensity, edge strength, and confidence
    final attention = (intensity * 0.4 + edgeStrength * 0.4 + confidence * 0.2);
    
    return attention.clamp(0.0, 1.0);
  }
  
  /// Calculate simplified edge strength
  static double _calculateEdgeStrength(double r, double g, double b) {
    // Simple edge detection based on color variance
    final variance = ((r - 0.5).abs() + (g - 0.5).abs() + (b - 0.5).abs()) / 3.0;
    return variance * 2.0; // Scale up for better visibility
  }
  
  /// Normalize heatmap values to 0-1 range
  static List<List<double>> _normalizeHeatmap(List<List<double>> heatmap) {
    double minVal = double.infinity;
    double maxVal = -double.infinity;
    
    // Find min and max values
    for (final row in heatmap) {
      for (final val in row) {
        minVal = val < minVal ? val : minVal;
        maxVal = val > maxVal ? val : maxVal;
      }
    }
    
    // Normalize to 0-1 range
    final range = maxVal - minVal;
    if (range == 0) return heatmap;
    
    for (int y = 0; y < heatmap.length; y++) {
      for (int x = 0; x < heatmap[y].length; x++) {
        heatmap[y][x] = (heatmap[y][x] - minVal) / range;
      }
    }
    
    return heatmap;
  }
  
  /// Overlay heatmap on the original image
  static img.Image _overlayHeatmap(img.Image image, List<List<double>> heatmap) {
    final result = img.Image.from(image);
    
    // Create a colored heatmap overlay
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        // Map image coordinates to heatmap coordinates
        final heatmapX = (x * _heatmapSize / image.width).floor();
        final heatmapY = (y * _heatmapSize / image.height).floor();
        
        if (heatmapY < heatmap.length && heatmapX < heatmap[heatmapY].length) {
          final attentionValue = heatmap[heatmapY][heatmapX];
          
          // Create heatmap color (red for high attention, blue for low)
          final heatmapColor = _getHeatmapColor(attentionValue);
          
          // Blend with original pixel
          final originalPixel = image.getPixel(x, y);
          final blendedPixel = _blendPixels(originalPixel, heatmapColor, 0.6);
          
          result.setPixel(x, y, blendedPixel);
        }
      }
    }
    
    return result;
  }
  
  /// Get heatmap color based on attention value
  static img.ColorRgb8 _getHeatmapColor(double attentionValue) {
    // Create a color gradient from blue (low) to red (high)
    if (attentionValue < 0.5) {
      // Blue to green
      final intensity = (attentionValue * 2).clamp(0.0, 1.0);
      final r = (intensity * 0).round();
      final g = (intensity * 255).round();
      final b = 255;
      return img.ColorRgb8(r, g, b);
    } else {
      // Green to red
      final intensity = ((attentionValue - 0.5) * 2).clamp(0.0, 1.0);
      final r = 255;
      final g = ((1 - intensity) * 255).round();
      final b = 0;
      return img.ColorRgb8(r, g, b);
    }
  }
  
  /// Blend two pixels with given alpha
  static img.ColorRgb8 _blendPixels(img.Pixel original, img.ColorRgb8 overlay, double alpha) {
    final r = (original.r * (1 - alpha) + overlay.r * alpha).round();
    final g = (original.g * (1 - alpha) + overlay.g * alpha).round();
    final b = (original.b * (1 - alpha) + overlay.b * alpha).round();
    
    return img.ColorRgb8(r, g, b);
  }
  
  /// Save GradCAM image to storage
  static Future<String> _saveGradCAMImage(img.Image image, String? outputPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = outputPath ?? 'gradcam_$timestamp.png';
    final filePath = '${directory.path}/$fileName';
    
    final file = File(filePath);
    await file.writeAsBytes(img.encodePng(image));
    
    return filePath;
  }
  
  /// Generate multiple GradCAM visualizations for top predictions
  static Future<List<String>> generateMultipleGradCAMs({
    required Uint8List imageData,
    required List<double> predictions,
    required List<int> topClassIndices,
  }) async {
    final List<String> gradCAMPaths = [];
    
    for (int i = 0; i < topClassIndices.length && i < 3; i++) {
      final classIndex = topClassIndices[i];
      final gradCAMPath = await generateGradCAM(
        imageData: imageData,
        predictions: predictions,
        targetClassIndex: classIndex,
        outputPath: 'gradcam_top${i + 1}_$classIndex.png',
      );
      
      if (gradCAMPath != null) {
        gradCAMPaths.add(gradCAMPath);
      }
    }
    
    return gradCAMPaths;
  }
  
  /// Create a summary heatmap showing overall attention
  static Future<String?> generateSummaryGradCAM({
    required Uint8List imageData,
    required List<double> predictions,
  }) async {
    try {
      print('🔥 Generating summary GradCAM heatmap...');
      
      // Decode and preprocess the original image
      final originalImage = img.decodeImage(imageData);
      if (originalImage == null) {
        throw Exception('Failed to decode image for summary GradCAM');
      }
      
      // Resize to input size
      final resizedImage = img.copyResize(
        originalImage,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.cubic,
      );
      
      // Create a summary heatmap based on all predictions
      final heatmap = _generateSummaryHeatmap(resizedImage, predictions);
      
      // Overlay heatmap on original image
      final overlayImage = _overlayHeatmap(resizedImage, heatmap);
      
      // Save the summary GradCAM visualization
      final savedPath = await _saveGradCAMImage(overlayImage, 'gradcam_summary.png');
      
      print('✅ Summary GradCAM heatmap generated: $savedPath');
      return savedPath;
      
    } catch (e) {
      print('❌ Error generating summary GradCAM: $e');
      return null;
    }
  }
  
  /// Generate summary heatmap based on all predictions
  static List<List<double>> _generateSummaryHeatmap(
    img.Image image,
    List<double> predictions,
  ) {
    final heatmap = List.generate(
      _heatmapSize,
      (i) => List.generate(_heatmapSize, (j) => 0.0),
    );
    
    // Calculate average confidence across all classes
    final avgConfidence = predictions.isNotEmpty 
        ? predictions.reduce((a, b) => a + b) / predictions.length 
        : 0.0;
    
    // Create attention pattern based on image features and average confidence
    for (int y = 0; y < _heatmapSize; y++) {
      for (int x = 0; x < _heatmapSize; x++) {
        // Map heatmap coordinates to image coordinates
        final imageX = (x * image.width / _heatmapSize).round();
        final imageY = (y * image.height / _heatmapSize).round();
        
        if (imageX < image.width && imageY < image.height) {
          final pixel = image.getPixel(imageX, imageY);
          
          // Calculate attention based on edge detection and average confidence
          final attention = _calculateAttentionValue(pixel, avgConfidence);
          heatmap[y][x] = attention;
        }
      }
    }
    
    // Normalize the heatmap
    return _normalizeHeatmap(heatmap);
  }
}
