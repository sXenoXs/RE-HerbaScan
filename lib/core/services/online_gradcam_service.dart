// lib/core/services/online_gradcam_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for communicating with the Python Grad-CAM backend API
class OnlineGradCAMService {
  static final OnlineGradCAMService _instance =
      OnlineGradCAMService._internal();
  factory OnlineGradCAMService() => _instance;
  OnlineGradCAMService._internal();

  final Logger _logger = Logger();

  // Railway backend URL (must include scheme for Uri.parse)
  static const String serverUrl = 'https://web-production-011a.up.railway.app';
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
  ///
  /// Returns Map with:
  /// - plant_name: String
  /// - scientific_name: String
  /// - confidence: double (0-1)
  /// - all_predictions: List<Map> (top 3)
  /// - gradcam_image: Uint8List (decoded from base64)
  /// - method: "grad-cam"
  /// - processing_time_ms: double
  ///
  /// Implements retry logic (3 attempts) for network resilience
  Future<Map<String, dynamic>?> identifyPlant(String imagePath) async {
    const int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        _logger.i(
            'Starting online Grad-CAM identification... (attempt ${attempt + 1}/$maxRetries)');

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

        // Attach Supabase JWT when signed in (for Railway backend verification)
        final token = Supabase.instance.client.auth.currentSession?.accessToken;
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }

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
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          // Debug logging
          print('🔍 [OnlineGradCAM] Backend response received:');
          print('   Response keys: ${data.keys.toList()}');
          print('   gradcam_image present: ${data['gradcam_image'] != null}');
          if (data['gradcam_image'] != null) {
            final gradcamBase64 = data['gradcam_image'] as String;
            print('   gradcam_image type: ${gradcamBase64.runtimeType}');
            print('   gradcam_image length: ${gradcamBase64.length} chars');
          }

          // Decode base64 gradcam image (backend returns base64-encoded PNG)
          if (data['gradcam_image'] != null) {
            try {
              final gradcamBase64 = data['gradcam_image'] as String;
              print('   Decoding base64 gradcam image...');
              data['gradcam_image'] = base64Decode(gradcamBase64);
              final decodedBytes = data['gradcam_image'] as Uint8List;
              print('   ✅ Decoded successfully: ${decodedBytes.length} bytes');
            } catch (e) {
              print('   ❌ Error decoding base64: $e');
              _logger.e('Failed to decode base64 gradcam image: $e');
              data['gradcam_image'] = null;
            }
          } else {
            print('   ⚠️ WARNING: gradcam_image is null in backend response!');
            _logger.w('Backend response does not contain gradcam_image');
          }

          _logger.i('Plant identified: ${data['plant_name']} '
              '(confidence: ${data['confidence']})');
          _logger.i('Processing time: ${data['processing_time_ms']}ms');
          _logger.i('Method used: ${data['method']}');

          return data;
        } else {
          // Server error - log but don't retry (server issue, not network)
          _logger.e('Server error: ${response.statusCode} - ${response.body}');
          return null;
        }
      } on SocketException catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          _logger.e(
              'Network error after $maxRetries attempts: No internet connection - $e');
          return null;
        }
        _logger.w('Network error (attempt $attempt/$maxRetries), retrying...');
        await Future.delayed(
            Duration(seconds: attempt * 2)); // Exponential backoff
        continue;
      } on HttpException catch (e) {
        _logger.e('HTTP error: $e');
        return null; // HTTP errors are usually not retryable
      } on FormatException catch (e) {
        _logger.e('JSON parsing error: $e');
        return null; // Parse errors are not retryable
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          _logger.e(
              'Error during online identification after $maxRetries attempts: $e');
          return null;
        }
        _logger
            .w('Unexpected error (attempt $attempt/$maxRetries), retrying...');
        await Future.delayed(Duration(seconds: attempt * 2));
        continue;
      }
    }

    return null;
  }

  /// Alias for identifyPlant - matches the planned method name
  Future<Map<String, dynamic>?> identifyPlantWithGradCAM(
      String imagePath) async {
    return identifyPlant(imagePath);
  }

  /// Get all predictions (top N) from the server
  Future<List<Map<String, dynamic>>?> getAllPredictions(
      String imagePath) async {
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
      final response = await http
          .get(
            Uri.parse('$serverUrl/health'),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
