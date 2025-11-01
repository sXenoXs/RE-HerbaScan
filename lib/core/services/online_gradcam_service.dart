// lib/core/services/online_gradcam_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Service for communicating with the Python Grad-CAM backend API
class OnlineGradCAMService {
  static final OnlineGradCAMService _instance = OnlineGradCAMService._internal();
  factory OnlineGradCAMService() => _instance;
  OnlineGradCAMService._internal();

  final Logger _logger = Logger();
  
  // Railway backend URL
  static const String serverUrl = 'https://herbascan-backend-production.up.railway.app';
  static const Duration timeout = Duration(seconds: 30);
  
  /// Check if the backend server is healthy and ready
  Future<bool> checkServerHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/health'),
          )
          .timeout(timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isHealthy = data['status'] == 'healthy' && 
                         data['model_loaded'] == true &&
                         data['labels_loaded'] == true;
        
        _logger.i('Server health: $isHealthy');
        return isHealthy;
      }
      
      _logger.w('Server health check failed: ${response.statusCode}');
      return false;
    } catch (e) {
      _logger.e('Error checking server health: $e');
      return false;
    }
  }
  
  /// Identify plant using true Grad-CAM from Python backend
  /// Returns: Map with plant_name, confidence, gradcam_image (Uint8List), etc.
  Future<Map<String, dynamic>?> identifyPlant(String imagePath) async {
    try {
      _logger.i('Starting online Grad-CAM identification...');
      
      // Read image file
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        _logger.e('Image file not found: $imagePath');
        return null;
      }
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/identify'),
      );
      
      // Attach image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
        ),
      );
      
      // Send request with timeout
      _logger.d('Uploading image to server...');
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      // Parse response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Decode base64 gradcam image
        if (data['gradcam_image'] != null) {
          data['gradcam_image'] = base64Decode(data['gradcam_image']);
        }
        
        // Decode base64 colored heatmap if present
        if (data['colored_heatmap'] != null) {
          data['colored_heatmap'] = base64Decode(data['colored_heatmap']);
        }
        
        _logger.i('Plant identified: ${data['plant_name']} '
                  '(confidence: ${data['confidence']})');
        _logger.i('Processing time: ${data['processing_time_ms']}ms');
        
        return data;
      } else {
        _logger.e('Server error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on SocketException {
      _logger.e('Network error: No internet connection');
      return null;
    } on HttpException catch (e) {
      _logger.e('HTTP error: $e');
      return null;
    } on FormatException catch (e) {
      _logger.e('JSON parsing error: $e');
      return null;
    } catch (e) {
      _logger.e('Error during online identification: $e');
      return null;
    }
  }
  
  /// Get all predictions (top N) from the server
  Future<List<Map<String, dynamic>>?> getAllPredictions(String imagePath) async {
    try {
      final result = await identifyPlant(imagePath);
      if (result != null && result['all_predictions'] != null) {
        return List<Map<String, dynamic>>.from(result['all_predictions']);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting predictions: $e');
      return null;
    }
  }
  
  /// Get the URL of the backend server
  String getServerUrl() => serverUrl;
  
  /// Check if we have internet connectivity
  Future<bool> hasConnectivity() async {
    try {
      // Quick ping to check connectivity
      final response = await http.get(
        Uri.parse('$serverUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

