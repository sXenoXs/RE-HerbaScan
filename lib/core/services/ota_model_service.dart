// lib/core/services/ota_model_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles OTA version checking and downloading of ML model files from Supabase.
///
/// Requires a `model_versions` table in Supabase:
///
///   CREATE TABLE model_versions (
///     id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
///     version       text NOT NULL,
///     is_active     boolean NOT NULL DEFAULT true,
///     model_url     text NOT NULL,           -- mobilenetv2_multi_output.tflite
///     class_indices_url text NOT NULL,       -- class_indices.json
///     cam_weights_url   text NOT NULL,       -- mobilenetv2_cam_weights.json
///     created_at    timestamptz NOT NULL DEFAULT now()
///   );
///
/// Usage in consuming services:
///   - [TflitePlantService]: use [tflitePath] / [classIndicesPath] when non-null
///     instead of loading from rootBundle assets.
///   - [OfflineCAMService]: use [tflitePath] / [camWeightsPath] when non-null.
///   - Always fall back to bundled assets when [isOtaAvailable] is false.
class OtaModelService {
  static final OtaModelService instance = OtaModelService._internal();
  OtaModelService._internal();

  // ── SharedPreferences key ────────────────────────────────────────────────
  static const String _prefKey = 'ota_model_version';

  // ── Downloaded file names (must match what existing services expect) ──────
  static const String _tfliteFileName = 'mobilenetv2_multi_output.tflite';
  static const String _classIndicesFileName = 'class_indices.json';
  static const String _camWeightsFileName = 'mobilenetv2_cam_weights.json';

  Directory? _modelsDir;
  bool _otaAvailable = false;

  // ── Public API ────────────────────────────────────────────────────────────

  /// True once all three OTA files are confirmed present on disk.
  bool get isOtaAvailable => _otaAvailable;

  /// Absolute path to the OTA `.tflite` file; null → use bundled asset.
  String? get tflitePath =>
      _otaAvailable ? '${_modelsDir!.path}/$_tfliteFileName' : null;

  /// Absolute path to the OTA `class_indices.json`; null → use bundled asset.
  String? get classIndicesPath =>
      _otaAvailable ? '${_modelsDir!.path}/$_classIndicesFileName' : null;

  /// Absolute path to the OTA `mobilenetv2_cam_weights.json`; null → use bundled asset.
  String? get camWeightsPath =>
      _otaAvailable ? '${_modelsDir!.path}/$_camWeightsFileName' : null;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Call this in `main()` before `runApp()`. Never throws — any failure
  /// silently falls back to the bundled APK assets.
  Future<void> initialize() async {
    if (kIsWeb) return; // OTA model files are not applicable on web.

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      _modelsDir = Directory('${docsDir.path}/models');

      // If all three files already exist from a prior download, mark them
      // available immediately so the rest of the app can use them right away.
      if (await _allFilesExist()) {
        _otaAvailable = true;
        debugPrint('✅ [OtaModelService] Cached OTA model files found.');
      }

      // Check Supabase for a newer version (async — does not block startup).
      await _checkAndUpdate();
    } catch (e) {
      // Non-fatal: bundled assets remain in use.
      debugPrint('⚠️ [OtaModelService] initialize() non-fatal error: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _checkAndUpdate() async {
    final Map<String, dynamic>? remote = await _fetchRemoteVersion();
    if (remote == null) return; // No network or table missing.

    final String remoteVersion = remote['version'] as String;

    final prefs = await SharedPreferences.getInstance();
    final String localVersion = prefs.getString(_prefKey) ?? '';

    if (!_isNewer(remoteVersion, localVersion)) {
      debugPrint(
          '✅ [OtaModelService] Model is up to date (version: $localVersion).');
      return;
    }

    debugPrint(
        '⬇️  [OtaModelService] Newer model found: $remoteVersion '
        '(local: ${localVersion.isEmpty ? "none" : localVersion})');

    final bool success = await _downloadAll(
      tfliteUrl: remote['model_url'] as String,
      classIndicesUrl: remote['class_indices_url'] as String,
      camWeightsUrl: remote['cam_weights_url'] as String,
    );

    if (success) {
      await prefs.setString(_prefKey, remoteVersion);
      _otaAvailable = true;
      debugPrint(
          '✅ [OtaModelService] Model updated to version $remoteVersion.');
    }
    // On failure _otaAvailable stays as it was; bundled assets are the fallback.
  }

  /// Queries `model_versions` for the latest active row.
  /// Returns null on any error (network unavailable, table missing, etc.).
  Future<Map<String, dynamic>?> _fetchRemoteVersion() async {
    try {
      final response = await Supabase.instance.client
          .from('model_versions')
          .select('version, model_url, class_indices_url, cam_weights_url')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint(
          '⚠️ [OtaModelService] Could not reach model_versions table: $e');
      return null;
    }
  }

  /// Returns true if [remote] is strictly newer than [local].
  /// Supports semver (e.g. "1.2.3") and simple integers (e.g. "5").
  /// Unknown formats: any difference is treated as newer.
  bool _isNewer(String remote, String local) {
    if (local.isEmpty) return true;
    if (remote == local) return false;
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

  /// Downloads all three model files atomically (tmp → rename).
  /// Returns false if any download fails; partial files are cleaned up.
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

  /// Downloads [url] and writes it to `<modelsDir>/<fileName>` via a `.tmp`
  /// staging file so a partial write never replaces a good existing file.
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

    // Atomic rename: the destination is only replaced once the write is done.
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
