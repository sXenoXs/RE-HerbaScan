// lib/core/services/ood_config_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';

/// Singleton that loads and caches `assets/data/ood_safety_config.json`.
///
/// All services that need OOD / quality thresholds read from this single
/// source of truth instead of using hard-coded values.  Falls back to safe
/// hard-coded defaults if the file is missing or malformed — matching the
/// Python backend defaults in `validation_pipeline.py`.
class OodConfigService {
  static final OodConfigService _instance = OodConfigService._internal();
  factory OodConfigService() => _instance;
  OodConfigService._internal();

  bool _loaded = false;

  // ── Defaults match Python backend (validation_pipeline.py) ──────────────
  /// Variance-of-Laplacian threshold; images below this are "too blurry".
  double blurThreshold = 100.0;

  /// Raw mean grayscale pixel value [0-255]; images below this are "too dark".
  double darknessThreshold = 40.0;

  /// Minimum confidence to accept a prediction as a known plant.
  double confidenceThresholdOod = 0.4;

  /// Minimum confidence to show as a confident top-1 result.
  double confidenceThresholdAccept = 0.55;

  /// Class index of a dedicated "not_plant" output class, or -1 if disabled.
  int notPlantClassIndex = -1;

  /// Display names of plants that should always route to the warning screen.
  List<String> toxicBlacklist = ['Adelfa', 'IpilIpil', 'TubaTuba'];

  // ────────────────────────────────────────────────────────────────────────

  /// Load config from the asset bundle.  Safe to call multiple times — the
  /// file is read only once per process lifetime (singleton cache).
  Future<void> load() async {
    if (_loaded) return;

    try {
      final jsonString = await rootBundle
          .loadString('assets/data/ood_safety_config.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      blurThreshold =
          (data['ood_blur_threshold'] as num?)?.toDouble() ?? blurThreshold;
      darknessThreshold =
          (data['ood_darkness_threshold'] as num?)?.toDouble() ??
              darknessThreshold;
      confidenceThresholdOod =
          (data['confidence_threshold_ood'] as num?)?.toDouble() ??
              confidenceThresholdOod;
      confidenceThresholdAccept =
          (data['confidence_threshold_accept'] as num?)?.toDouble() ??
              confidenceThresholdAccept;

      final notPlantIdx = data['not_plant_class_index'];
      notPlantClassIndex =
          (notPlantIdx != null && notPlantIdx is int) ? notPlantIdx : -1;

      final blacklist = data['toxic_blacklist'];
      if (blacklist != null) {
        toxicBlacklist = List<String>.from(blacklist as List);
      }

      _loaded = true;
      print('✅ [OodConfigService] Config loaded — '
          'blur≥$blurThreshold  dark≥$darknessThreshold  '
          'ood≥$confidenceThresholdOod  accept≥$confidenceThresholdAccept  '
          'notPlantIdx=$notPlantClassIndex');
    } catch (e) {
      // Use hard-coded defaults; mark as loaded so we don't retry every call.
      _loaded = true;
      print('⚠️ [OodConfigService] Could not load ood_safety_config.json: $e'
          '\n   Using built-in defaults.');
    }
  }
}
