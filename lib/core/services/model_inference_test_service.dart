import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Model classes — deserialised from POST /admin/test-inference JSON response
// ─────────────────────────────────────────────────────────────────────────────

class ModelInfo {
  final String path;
  final double temperature;
  final int numClasses;

  const ModelInfo({
    required this.path,
    required this.temperature,
    required this.numClasses,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) => ModelInfo(
        path: json['path'] as String? ?? '',
        temperature: (json['temperature'] as num?)?.toDouble() ?? 1.0,
        numClasses: (json['num_classes'] as num?)?.toInt() ?? 0,
      );
}

class AdminImageInfo {
  final String filename;
  final int width;
  final int height;

  const AdminImageInfo({
    required this.filename,
    required this.width,
    required this.height,
  });

  factory AdminImageInfo.fromJson(Map<String, dynamic> json) => AdminImageInfo(
        filename: json['filename'] as String? ?? 'unknown',
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
      );
}

class OodGateResult {
  final bool decoded;
  final double brightness;
  final double brightnessMin;
  final bool brightnessPass;
  final double blur;
  final double blurMin;
  final bool blurPass;
  final double edgeDensity;
  final double edgeDensityMin;
  final bool edgeDensityPass;
  final bool overallPass;
  final String? failReason;

  const OodGateResult({
    required this.decoded,
    required this.brightness,
    required this.brightnessMin,
    required this.brightnessPass,
    required this.blur,
    required this.blurMin,
    required this.blurPass,
    required this.edgeDensity,
    required this.edgeDensityMin,
    required this.edgeDensityPass,
    required this.overallPass,
    this.failReason,
  });

  factory OodGateResult.fromJson(Map<String, dynamic> json) => OodGateResult(
        decoded: json['decoded'] as bool? ?? false,
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
        brightnessMin: (json['brightness_min'] as num?)?.toDouble() ?? 0.0,
        brightnessPass: json['brightness_pass'] as bool? ?? false,
        blur: (json['blur'] as num?)?.toDouble() ?? 0.0,
        blurMin: (json['blur_min'] as num?)?.toDouble() ?? 0.0,
        blurPass: json['blur_pass'] as bool? ?? false,
        edgeDensity: (json['edge_density'] as num?)?.toDouble() ?? 0.0,
        edgeDensityMin: (json['edge_density_min'] as num?)?.toDouble() ?? 0.0,
        edgeDensityPass: json['edge_density_pass'] as bool? ?? false,
        overallPass: json['overall_pass'] as bool? ?? false,
        failReason: json['fail_reason'] as String?,
      );
}

class Top5Prediction {
  final int rank;
  final String label;
  final double confidence;
  final double barFraction;

  const Top5Prediction({
    required this.rank,
    required this.label,
    required this.confidence,
    required this.barFraction,
  });

  factory Top5Prediction.fromJson(Map<String, dynamic> json) => Top5Prediction(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        label: json['label'] as String? ?? '-',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        barFraction: (json['bar_fraction'] as num?)?.toDouble() ?? 0.0,
      );
}

class ConfidenceGateResult {
  final double value;
  final double threshold;
  final bool passed;

  const ConfidenceGateResult({
    required this.value,
    required this.threshold,
    required this.passed,
  });

  factory ConfidenceGateResult.fromJson(Map<String, dynamic> json) =>
      ConfidenceGateResult(
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
        passed: json['passed'] as bool? ?? false,
      );
}

class InferenceResultPlant {
  final String plantName;
  final String scientificName;

  const InferenceResultPlant({
    required this.plantName,
    required this.scientificName,
  });

  factory InferenceResultPlant.fromJson(Map<String, dynamic> json) =>
      InferenceResultPlant(
        plantName: json['plant_name'] as String? ?? 'Unknown',
        scientificName: json['scientific_name'] as String? ?? 'Unknown',
      );
}

class ModelInferenceResult {
  final ModelInfo modelInfo;
  final AdminImageInfo imageInfo;
  final OodGateResult oodGate;
  final List<Top5Prediction> top5;
  final ConfidenceGateResult confidenceGate;
  final InferenceResultPlant? result;
  final bool oodRejected;
  final bool stage1Rejected;

  const ModelInferenceResult({
    required this.modelInfo,
    required this.imageInfo,
    required this.oodGate,
    required this.top5,
    required this.confidenceGate,
    this.result,
    required this.oodRejected,
    required this.stage1Rejected,
  });

  factory ModelInferenceResult.fromJson(Map<String, dynamic> json) =>
      ModelInferenceResult(
        modelInfo: ModelInfo.fromJson(
            json['model_info'] as Map<String, dynamic>? ?? {}),
        imageInfo: AdminImageInfo.fromJson(
            json['image_info'] as Map<String, dynamic>? ?? {}),
        oodGate: OodGateResult.fromJson(
            json['ood_gate'] as Map<String, dynamic>? ?? {}),
        top5: (json['top_5'] as List<dynamic>?)
                ?.map((e) =>
                    Top5Prediction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        confidenceGate: ConfidenceGateResult.fromJson(
            json['confidence_gate'] as Map<String, dynamic>? ?? {}),
        result: json['result'] != null
            ? InferenceResultPlant.fromJson(
                json['result'] as Map<String, dynamic>)
            : null,
        oodRejected: json['ood_rejected'] as bool? ?? false,
        stage1Rejected: json['stage1_rejected'] as bool? ?? false,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service — calls POST /admin/test-inference on the Railway backend
// ─────────────────────────────────────────────────────────────────────────────

class ModelInferenceTestService {
  ModelInferenceTestService._();
  static final ModelInferenceTestService instance =
      ModelInferenceTestService._();

  /// Railway backend URL injected at build time via:
  ///   --dart-define=RAILWAY_BACKEND_URL=https://re-herbascan-production.up.railway.app
  static const String _railwayBackendUrl = String.fromEnvironment(
    'RAILWAY_BACKEND_URL',
    defaultValue: '',
  );

  /// Admin secret injected at build time via:
  ///   --dart-define=ADMIN_SECRET=<your_secret>
  static const String _adminSecret = String.fromEnvironment(
    'ADMIN_SECRET',
    defaultValue: '',
  );

  /// Returns true if required build-time configuration is present.
  bool get isConfigured =>
      _railwayBackendUrl.isNotEmpty && _adminSecret.isNotEmpty;

  /// Sends an image to the Railway backend for inference testing.
  ///
  /// [imageBytes] — raw JPEG/PNG image data.
  /// [filename] — original filename (shown in the UI).
  /// [temperature] — temperature scaling factor (0.1–5.0, default 1.0).
  ///
  /// Returns a parsed [ModelInferenceResult] on success.
  /// Throws [ModelInferenceTestException] on any error (network, auth, server).
  Future<ModelInferenceResult> testInference({
    required Uint8List imageBytes,
    required String filename,
    double temperature = 1.0,
  }) async {
    if (!isConfigured) {
      throw ModelInferenceTestException(
        'Backend URL or admin secret not configured.\n'
        'Build with --dart-define=RAILWAY_BACKEND_URL=... '
        'and --dart-define=ADMIN_SECRET=...',
        code: _ErrorCode.notConfigured,
      );
    }

    final uri = Uri.parse(
      '$_railwayBackendUrl/admin/test-inference?temperature=$temperature',
    );

    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers['x-admin-secret'] = _adminSecret
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: filename,
          ),
        );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on ModelInferenceTestException {
      rethrow;
    } on http.ClientException catch (e) {
      throw ModelInferenceTestException(
        'Network error: $e\nCheck Railway deployment status.',
        code: _ErrorCode.networkError,
      );
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw ModelInferenceTestException(
          'Request timed out. Check Railway deployment status.',
          code: _ErrorCode.timeout,
        );
      }
      throw ModelInferenceTestException(
        'Request failed: $e',
        code: _ErrorCode.unknown,
      );
    }
  }

  ModelInferenceResult _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    switch (response.statusCode) {
      case 200:
        return ModelInferenceResult.fromJson(body);
      case 401:
        throw ModelInferenceTestException(
          'Admin secret is incorrect. Check --dart-define=ADMIN_SECRET.',
          code: _ErrorCode.unauthorized,
        );
      case 429:
        throw ModelInferenceTestException(
          'Rate limit hit. Wait 1 minute before testing again.',
          code: _ErrorCode.rateLimited,
        );
      case 503:
        throw ModelInferenceTestException(
          'Railway model not loaded. Try /admin/reload-model first.',
          code: _ErrorCode.modelNotLoaded,
        );
      default:
        final detail = body['detail'] as String? ?? response.body;
        throw ModelInferenceTestException(
          'Server error (${response.statusCode}): $detail',
          code: _ErrorCode.serverError,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typed exception for the inference test flow
// ─────────────────────────────────────────────────────────────────────────────

class ModelInferenceTestException implements Exception {
  final String message;
  final String code;

  const ModelInferenceTestException(this.message, {required this.code});

  @override
  String toString() => 'ModelInferenceTestException($code): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal error codes (not exposed publicly, used for UI branching)
// ─────────────────────────────────────────────────────────────────────────────

abstract class _ErrorCode {
  static const String notConfigured = 'not_configured';
  static const String networkError = 'network_error';
  static const String timeout = 'timeout';
  static const String unauthorized = 'unauthorized';
  static const String rateLimited = 'rate_limited';
  static const String modelNotLoaded = 'model_not_loaded';
  static const String serverError = 'server_error';
  static const String unknown = 'unknown';
}
