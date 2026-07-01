// lib/core/services/ota_model_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles OTA version checking and downloading of ML model files.
///
/// Resolution order (first source that returns data wins):
///   1. `model_versions` Supabase table — versioned admin-controlled releases.
///      Columns: version, tflite_url, class_indices_url, cam_weights_url, is_active.
///   2. `live-models` Supabase Storage bucket — direct upload fallback.
///      Files: mobilenetv2_multi_output.tflite, class_indices.json,
///             mobilenetv2_cam_weights.json.
///      Version is derived from the tflite file's updatedAt timestamp, so
///      re-uploading to the bucket automatically triggers a re-download.
///
/// Always falls back silently to bundled APK assets if both sources fail.
class OtaModelService {
  static final OtaModelService instance = OtaModelService._internal();
  OtaModelService._internal();

  static const String _prefKey = 'ota_model_version';

  static const String _tfliteFileName = 'mobilenetv2_multi_output.tflite';
  static const String _classIndicesFileName = 'class_indices.json';
  static const String _camWeightsFileName = 'mobilenetv2_cam_weights.json';

  // The Supabase Storage bucket that holds the live model files.
  static const String _liveModelsBucket = 'live-models';

  Directory? _modelsDir;
  bool _otaAvailable = false;

  // ── Public API ────────────────────────────────────────────────────────────

  bool get isOtaAvailable => _otaAvailable;

  String? get tflitePath =>
      _otaAvailable ? '${_modelsDir!.path}/$_tfliteFileName' : null;

  String? get classIndicesPath =>
      _otaAvailable ? '${_modelsDir!.path}/$_classIndicesFileName' : null;

  String? get camWeightsPath =>
      _otaAvailable ? '${_modelsDir!.path}/$_camWeightsFileName' : null;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Call this in `main()` before `runApp()`. Never throws.
  Future<void> initialize() async {
    try {
      if (kIsWeb) return; // Web does not support dart:io
      
      final appDir = await getApplicationDocumentsDirectory();
      _modelsDir = Directory('${appDir.path}/ota_models');
      
      // Check if we already have files locally first
      if (await _allFilesExist()) {
        _otaAvailable = true;
      }
      
      // Then check for remote updates
      await _checkAndUpdate();

      // Final validation
      if (await _allFilesExist()) {
        _otaAvailable = true;
      } else {
        _otaAvailable = false;
        await _cleanupTempFiles();
      }
    } catch (e) {
      debugPrint('⚠️ [OtaModelService] Initialization error: $e');
      _otaAvailable = false;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _checkAndUpdate() async {
    // Only use model_versions table (versioned releases with accuracy validation).
    final Map<String, dynamic>? remote = await _fetchFromVersionsTable();

    if (remote == null) {
      debugPrint('ℹ️ [OtaModelService] No remote model source found.');
      return;
    }

    final String remoteVersion = remote['version'] as String;

    final prefs = await SharedPreferences.getInstance();
    final String localVersion = prefs.getString(_prefKey) ?? '';

    if (!_isNewer(remoteVersion, localVersion)) {
      debugPrint(
          '✅ [OtaModelService] Model is up to date (version: $localVersion).');
      return;
    }

    debugPrint('⬇️  [OtaModelService] Newer model found: $remoteVersion '
        '(local: ${localVersion.isEmpty ? "none" : localVersion})');

    final bool success = await _downloadAll(
      tfliteUrl: remote['tflite_url'] as String,
      classIndicesUrl: remote['class_indices_url'] as String,
      camWeightsUrl: remote['cam_weights_url'] as String,
    );

    if (success) {
      await prefs.setString(_prefKey, remoteVersion);
      _otaAvailable = true;
      debugPrint(
          '✅ [OtaModelService] Model updated to version $remoteVersion.');
    }
  }

  // ── Source 1: model_versions table ───────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchFromVersionsTable() async {
    try {
      final response = await Supabase.instance.client
          .from('model_versions')
          .select('version, tflite_url, class_indices_url, cam_weights_url, val_accuracy')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      
      // Reject incomplete or garbage models
      final valAccuracy = (response['val_accuracy'] as num?)?.toDouble();
      if (valAccuracy == null || valAccuracy < 0.50) {
        debugPrint('⚠️ [OtaModelService] Model version ${response['version']} rejected due to low/null accuracy: $valAccuracy');
        await clearOtaModels();
        return null;
      }

      debugPrint('📋 [OtaModelService] Found valid model_versions row '
          '(version: ${response['version']}, accuracy: $valAccuracy)');
      return response;
    } catch (e) {
      debugPrint(
          '⚠️ [OtaModelService] model_versions table not available: $e');
      return null;
    }
  }

  // ── Source 2: live-models bucket ─────────────────────────────────────────

  /// Reads public URLs directly from the `live-models` Storage bucket.
  /// Uses the tflite file's `updatedAt` timestamp as the version string so
  /// re-uploading a new model to the bucket triggers an automatic re-download.
  Future<Map<String, dynamic>?> _fetchFromLiveModelsBucket() async {
    try {
      final storage = Supabase.instance.client.storage;

      // List the bucket to get file metadata (updatedAt timestamp).
      final files = await storage.from(_liveModelsBucket).list();

      // Find the tflite file entry to use its timestamp as version.
      final tfliteEntry = files
          .where((f) => f.name == _tfliteFileName)
          .firstOrNull;

      if (tfliteEntry == null) {
        debugPrint(
            '⚠️ [OtaModelService] $_tfliteFileName not found in '
            '$_liveModelsBucket bucket.');
        return null;
      }

      // Use updatedAt as version — changes whenever the file is re-uploaded.
      final version = tfliteEntry.updatedAt ?? tfliteEntry.createdAt ?? 'live';

      final tfliteUrl =
          storage.from(_liveModelsBucket).getPublicUrl(_tfliteFileName);
      final classIndicesUrl =
          storage.from(_liveModelsBucket).getPublicUrl(_classIndicesFileName);
      final camWeightsUrl =
          storage.from(_liveModelsBucket).getPublicUrl(_camWeightsFileName);

      debugPrint('📦 [OtaModelService] Using live-models bucket '
          '(version: $version)');
      return {
        'version': version,
        'tflite_url': tfliteUrl,
        'class_indices_url': classIndicesUrl,
        'cam_weights_url': camWeightsUrl,
      };
    } catch (e) {
      debugPrint(
          '⚠️ [OtaModelService] Could not access live-models bucket: $e');
      return null;
    }
  }

  // ── Version comparison ────────────────────────────────────────────────────

  bool _isNewer(String remote, String local) {
    if (local.isEmpty) return true;
    if (remote == local) return false;

    // Try ISO 8601 datetime comparison (used by bucket updatedAt timestamps).
    try {
      final r = DateTime.parse(remote);
      final l = DateTime.parse(local);
      return r.isAfter(l);
    } catch (_) {}

    // Try semver / integer comparison.
    try {
      final r = _parseSemver(remote);
      final l = _parseSemver(local);
      for (int i = 0; i < r.length && i < l.length; i++) {
        if (r[i] > l[i]) return true;
        if (r[i] < l[i]) return false;
      }
      return r.length > l.length;
    } catch (_) {
      return true; // Unknown format — assume remote is newer.
    }
  }

  List<int> _parseSemver(String v) => v
      .replaceAll(RegExp(r'[^0-9.]'), '')
      .split('.')
      .where((s) => s.isNotEmpty)
      .map(int.parse)
      .toList();

  // ── Download helpers ──────────────────────────────────────────────────────

  Future<bool> _downloadAll({
    required String tfliteUrl,
    required String classIndicesUrl,
    required String camWeightsUrl,
  }) async {
    try {
      await _modelsDir!.create(recursive: true);

      await _downloadFile(tfliteUrl, _tfliteFileName);
      await _downloadFile(classIndicesUrl, _classIndicesFileName);
      await _downloadFile(camWeightsUrl, _camWeightsFileName);

      return true;
    } catch (e) {
      debugPrint('⚠️ [OtaModelService] Download failed: $e');
      await _cleanupTempFiles();
      return false;
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    final dest = File('${_modelsDir!.path}/$fileName');
    final tmp = File('${_modelsDir!.path}/$fileName.tmp');

    debugPrint('⬇️  [OtaModelService] Downloading $fileName …');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(
          'HTTP ${response.statusCode} downloading $fileName from $url');
    }

    await tmp.writeAsBytes(response.bodyBytes, flush: true);

    if (await dest.exists()) await dest.delete();
    await tmp.rename(dest.path);

    debugPrint('✅ [OtaModelService] $fileName saved '
        '(${(response.bodyBytes.length / 1024).toStringAsFixed(1)} KB)');
  }

  Future<bool> _allFilesExist() async {
    if (_modelsDir == null) return false;
    return await File('${_modelsDir!.path}/$_tfliteFileName').exists() &&
        await File('${_modelsDir!.path}/$_classIndicesFileName').exists() &&
        await File('${_modelsDir!.path}/$_camWeightsFileName').exists();
  }

  /// Manually clears all OTA models and reverts to base models
  Future<void> clearOtaModels() async {
    debugPrint('🗑️ [OtaModelService] Clearing all OTA models...');
    if (_modelsDir != null && await _modelsDir!.exists()) {
      await _modelsDir!.delete(recursive: true);
      await _modelsDir!.create(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    _otaAvailable = false;
    debugPrint('🗑️ [OtaModelService] OTA models cleared successfully.');
  }

  Future<void> _cleanupTempFiles() async {
    if (_modelsDir == null) return;
    for (final name in [
      _tfliteFileName,
      _classIndicesFileName,
      _camWeightsFileName,
    ]) {
      try {
        final tmp = File('${_modelsDir!.path}/$name.tmp');
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }
}
