import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';

/// Result returned by [TrainingDatasetService.uploadImages].
class UploadResult {
  final int uploaded;
  final List<String> errors;
  const UploadResult({required this.uploaded, required this.errors});
  bool get hasErrors => errors.isNotEmpty;
}

/// Manages training dataset images in Supabase Storage bucket `training-datasets`.
///
/// Path structure: training-datasets/{plant_slug}/{timestamp}_{index}.{ext}
///
/// NOTE: The `training-datasets` bucket must be created in Supabase Storage with
/// service_role–level write access for admins and public read access for ML pipelines.
class TrainingDatasetService {
  static TrainingDatasetService? _instance;
  factory TrainingDatasetService() =>
      _instance ??= TrainingDatasetService._internal();
  TrainingDatasetService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  static const String _bucket = 'training-datasets';

  bool get isAvailable =>
      isSupabaseConfigured && _client.auth.currentUser != null;

  /// Upload [files] for [plantSlug]. Returns an [UploadResult] with the count
  /// of successfully uploaded images and a list of error strings for failures.
  ///
  /// [onProgress] is called after each attempt with (progress 0–1, uploaded count, total count).
  /// Uses [uploadBinary] so it works on all platforms including web.
  Future<UploadResult> uploadImages(
    String plantSlug,
    List<XFile> files, {
    void Function(double progress, int uploaded, int total)? onProgress,
  }) async {
    if (!isAvailable) {
      return UploadResult(
        uploaded: 0,
        errors: ['Not connected to Supabase. Check your credentials.'],
      );
    }
    if (files.isEmpty || plantSlug.isEmpty) {
      return UploadResult(uploaded: 0, errors: []);
    }

    int uploaded = 0;
    final errors = <String>[];
    final total = files.length;
    final ts = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < total; i++) {
      try {
        final xfile = files[i];
        final rawExt = xfile.name.contains('.')
            ? xfile.name.split('.').last.toLowerCase()
            : 'jpg';
        final safeExt =
            ['jpg', 'jpeg', 'png', 'webp'].contains(rawExt) ? rawExt : 'jpg';
        final fileName = '${ts}_$i.$safeExt';
        final path = '$plantSlug/$fileName';
        final bytes = await xfile.readAsBytes();

        await _client.storage.from(_bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
                contentType: 'image/$safeExt',
              ),
            );
        uploaded++;
        onProgress?.call(uploaded / total, uploaded, total);
      } catch (e) {
        final msg = e.toString();
        errors.add('File ${i + 1}: $msg');
        if (kDebugMode) {
          debugPrint('[TrainingDatasetService] upload[$i] error: $e');
        }
      }
    }
    return UploadResult(uploaded: uploaded, errors: errors);
  }

  /// Lightweight result returned by [uploadImages].
  static UploadResult noOp() => UploadResult(uploaded: 0, errors: []);

  /// Returns the count of training images stored under [plantSlug].
  Future<int> getImageCount(String plantSlug) async {
    if (!isAvailable || plantSlug.isEmpty) return 0;
    try {
      final files =
          await _client.storage.from(_bucket).list(path: plantSlug);
      return files.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TrainingDatasetService] getImageCount: $e');
      }
      return 0;
    }
  }

  /// Returns the total count of training images across all plant slug folders.
  /// Makes one list call per top-level folder — use sparingly (dashboard metrics only).
  Future<int> getTotalImageCount() async {
    if (!isAvailable) return 0;
    try {
      final dirs = await _client.storage.from(_bucket).list();
      int total = 0;
      for (final dir in dirs) {
        try {
          final files =
              await _client.storage.from(_bucket).list(path: dir.name);
          total += files.length;
        } catch (_) {}
      }
      return total;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TrainingDatasetService] getTotalImageCount: $e');
      }
      return 0;
    }
  }

  /// Returns public URLs of all training images for [plantSlug].
  Future<List<String>> listImageUrls(String plantSlug) async {
    if (!isAvailable || plantSlug.isEmpty) return [];
    try {
      final files =
          await _client.storage.from(_bucket).list(path: plantSlug);
      return files
          .map((f) => _client.storage
              .from(_bucket)
              .getPublicUrl('$plantSlug/${f.name}'))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TrainingDatasetService] listImageUrls: $e');
      }
      return [];
    }
  }

  /// Deletes a single training image by [fileName] under [plantSlug].
  Future<bool> deleteImage(String plantSlug, String fileName) async {
    if (!isAvailable || plantSlug.isEmpty || fileName.isEmpty) return false;
    try {
      await _client.storage
          .from(_bucket)
          .remove(['$plantSlug/$fileName']);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TrainingDatasetService] deleteImage: $e');
      }
      return false;
    }
  }
}
