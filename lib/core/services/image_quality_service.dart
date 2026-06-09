// lib/core/services/image_quality_service.dart
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:herbascan/core/services/ood_config_service.dart';

/// Result of a Stage 1 image quality check.
class ImageQualityResult {
  final bool passed;

  /// Null when [passed] is true; one of the canonical error strings otherwise.
  final String? failureReason;

  const ImageQualityResult({required this.passed, this.failureReason});
}

/// Stage 1 image quality gate (Dart equivalent of the Python OpenCV checks).
///
/// Runs two sequential checks on the raw image bytes:
///   1. **Darkness** — mean grayscale pixel value [0-255] < threshold → reject
///   2. **Blur**     — Variance of Laplacian < threshold → reject
///
/// Error strings match the Python backend exactly so that [AdaptiveGradCAMService]
/// can use the same stage-routing logic regardless of whether the failure
/// originated online or offline.
class ImageQualityService {
  static final ImageQualityService _instance = ImageQualityService._internal();
  factory ImageQualityService() => _instance;
  ImageQualityService._internal();

  final OodConfigService _oodConfig = OodConfigService();

  // Canonical rejection strings — must match Python backend exactly.
  static const String _tooBlurry = 'Validation Failed: Image is too blurry.';
  static const String _tooDark = 'Validation Failed: Image is too dark.';
  static const String _lacksStructure =
      'Validation Failed: Image lacks sufficient structure.';

  /// Check image quality.  Returns [ImageQualityResult.passed] == true when
  /// both the darkness and blur gates pass.
  ///
  /// The image is decoded and resized to 224×224 before checking for
  /// consistent, performant results (same resolution as the ML model input).
  Future<ImageQualityResult> check(Uint8List imageBytes) async {
    await _oodConfig.load();

    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        // Cannot decode → treat as too blurry (same as Python on corrupt input).
        return const ImageQualityResult(passed: false, failureReason: _tooBlurry);
      }

      // Resize to 224×224 for consistent, fast processing.
      final resized = img.copyResize(
        decoded,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );
      final gray = img.grayscale(resized);

      // ── Darkness check ───────────────────────────────────────────────────
      // Mean raw pixel value (0-255).  Dark images have a small mean.
      double pixelSum = 0;
      for (int y = 0; y < gray.height; y++) {
        for (int x = 0; x < gray.width; x++) {
          pixelSum += gray.getPixel(x, y).r.toDouble();
        }
      }
      final mean = pixelSum / (gray.width * gray.height);

      print('🔍 [ImageQualityService] darkness mean=$mean  threshold=${_oodConfig.darknessThreshold}');

      if (mean < _oodConfig.darknessThreshold) {
        print('🚫 [ImageQualityService] DARK — mean $mean < ${_oodConfig.darknessThreshold}');
        return const ImageQualityResult(passed: false, failureReason: _tooDark);
      }

      // ── Blur check (Variance of Laplacian) ──────────────────────────────
      final blurScore = _laplacianVariance(gray);

      print('🔍 [ImageQualityService] blur score=$blurScore  threshold=${_oodConfig.blurThreshold}');

      if (blurScore < _oodConfig.blurThreshold) {
        print('🚫 [ImageQualityService] BLURRY — score $blurScore < ${_oodConfig.blurThreshold}');
        return const ImageQualityResult(passed: false, failureReason: _tooBlurry);
      }

      // ── Edge density check (Sobel magnitude > 50) ────────────────────────
      // Count pixels where the Sobel gradient magnitude exceeds 50.
      // A very low ratio means the image is a blank or featureless surface.
      int edgePixels = 0;
      final interior = (gray.width - 2) * (gray.height - 2);
      for (int y = 1; y < gray.height - 1; y++) {
        for (int x = 1; x < gray.width - 1; x++) {
          final tl = gray.getPixel(x - 1, y - 1).r.toDouble();
          final tm = gray.getPixel(x,     y - 1).r.toDouble();
          final tr = gray.getPixel(x + 1, y - 1).r.toDouble();
          final ml = gray.getPixel(x - 1, y    ).r.toDouble();
          final mr = gray.getPixel(x + 1, y    ).r.toDouble();
          final bl = gray.getPixel(x - 1, y + 1).r.toDouble();
          final bm = gray.getPixel(x,     y + 1).r.toDouble();
          final br = gray.getPixel(x + 1, y + 1).r.toDouble();
          final gx = -tl + tr - 2.0 * ml + 2.0 * mr - bl + br;
          final gy = -tl - 2.0 * tm - tr + bl + 2.0 * bm + br;
          if (sqrt(gx * gx + gy * gy) > 50.0) edgePixels++;
        }
      }
      final edgeDensity = interior > 0 ? edgePixels / interior : 0.0;

      print('🔍 [ImageQualityService] edge density=$edgeDensity  threshold=${_oodConfig.edgeDensityMin}');

      if (edgeDensity < _oodConfig.edgeDensityMin) {
        print('🚫 [ImageQualityService] FEATURELESS — edge density $edgeDensity < ${_oodConfig.edgeDensityMin}');
        return const ImageQualityResult(passed: false, failureReason: _lacksStructure);
      }

      print('✅ [ImageQualityService] PASSED (dark=$mean  blur=$blurScore  edge=$edgeDensity)');
      return const ImageQualityResult(passed: true);
    } catch (e) {
      // Any decode / processing error → fail as blurry so we show tips screen.
      print('⚠️ [ImageQualityService] Exception during check: $e');
      return const ImageQualityResult(passed: false, failureReason: _tooBlurry);
    }
  }

  /// Discrete Laplacian variance on a grayscale [img.Image].
  ///
  /// Kernel: centre pixel × −4, four cardinal neighbours × +1.
  /// Returns the variance of all per-pixel responses across the image.
  /// A low variance indicates a blurry (low-frequency) image.
  double _laplacianVariance(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final responses = <double>[];

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final c  = gray.getPixel(x,     y    ).r.toDouble();
        final n  = gray.getPixel(x,     y - 1).r.toDouble();
        final s  = gray.getPixel(x,     y + 1).r.toDouble();
        final e  = gray.getPixel(x + 1, y    ).r.toDouble();
        final ww = gray.getPixel(x - 1, y    ).r.toDouble();
        responses.add(n + s + e + ww - 4.0 * c);
      }
    }

    if (responses.isEmpty) return 0.0;

    final mean = responses.reduce((a, b) => a + b) / responses.length;
    return responses
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b) /
        responses.length;
  }
}
