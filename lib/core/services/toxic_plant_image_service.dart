import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';

/// Manages display images for the informational toxic plants in the Browse screen.
///
/// Images are stored in Supabase Storage at `herbarium-images/toxic-plants/{slug}.{ext}`
/// and their public URLs are persisted in the `toxic_plant_images` table.
/// Reads are public (no auth required); writes require an authenticated session.
class ToxicPlantImageService {
  static ToxicPlantImageService? _instance;
  factory ToxicPlantImageService() =>
      _instance ??= ToxicPlantImageService._internal();
  ToxicPlantImageService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get _canRead => isSupabaseConfigured;
  bool get _canWrite =>
      isSupabaseConfigured && _client.auth.currentUser != null;

  static const String _bucket = 'herbarium-images';
  static const String _folder = 'toxic-plants';
  static const String _table = 'toxic_plant_images';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns a map of slug → imageUrl for all toxic plants that have an image.
  /// Safe to call without authentication (uses public RLS policy).
  Future<Map<String, String>> getImageUrls() async {
    if (!_canRead) return {};
    try {
      final rows = await _client
          .from(_table)
          .select('slug, image_url')
          .not('image_url', 'is', null) as List<dynamic>;
      return {
        for (final row in rows)
          if (row['slug'] != null && row['image_url'] != null)
            row['slug'] as String: row['image_url'] as String,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantImageService] getImageUrls: $e');
      return {};
    }
  }

  /// Returns all rows (slug + commonName + imageUrl) for the admin screen.
  /// Returns empty list when not authenticated.
  Future<List<ToxicPlantImageEntry>> listAll() async {
    if (!_canRead) return [];
    try {
      final rows = await _client
          .from(_table)
          .select('slug, common_name, image_url, updated_at')
          .order('common_name') as List<dynamic>;
      return rows.map(ToxicPlantImageEntry.fromRow).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantImageService] listAll: $e');
      return [];
    }
  }

  /// Uploads [imageFile] to Storage and saves the public URL to the table.
  /// Returns the public URL on success, or null on failure.
  Future<String?> uploadAndSave(
      String slug, String commonName, File imageFile) async {
    if (!_canWrite) return null;
    try {
      final ext = imageFile.path.split('.').last.toLowerCase();
      if (!{'jpg', 'jpeg', 'png'}.contains(ext)) return null;

      final path = '$_folder/$slug.$ext';
      await _client.storage.from(_bucket).upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = _client.storage.from(_bucket).getPublicUrl(path);

      await _client.from(_table).upsert({
        'slug': slug,
        'common_name': commonName,
        'image_url': url,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint('[ToxicPlantImageService] Uploaded $slug → $url');
      }
      return url;
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantImageService] uploadAndSave: $e');
      return null;
    }
  }

  /// Removes the image for [slug] from Storage and clears the URL in the table.
  Future<bool> removeImage(String slug) async {
    if (!_canWrite) return false;
    try {
      for (final ext in ['jpg', 'jpeg', 'png']) {
        try {
          await _client.storage
              .from(_bucket)
              .remove(['$_folder/$slug.$ext']);
        } catch (_) {}
      }
      await _client.from(_table).upsert({
        'slug': slug,
        'image_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantImageService] removeImage: $e');
      return false;
    }
  }
}

class ToxicPlantImageEntry {
  final String slug;
  final String commonName;
  final String? imageUrl;
  final DateTime? updatedAt;

  const ToxicPlantImageEntry({
    required this.slug,
    required this.commonName,
    this.imageUrl,
    this.updatedAt,
  });

  factory ToxicPlantImageEntry.fromRow(dynamic row) {
    return ToxicPlantImageEntry(
      slug: row['slug'] as String? ?? '',
      commonName: row['common_name'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }

  ToxicPlantImageEntry copyWith({String? imageUrl}) {
    return ToxicPlantImageEntry(
      slug: slug,
      commonName: commonName,
      imageUrl: imageUrl ?? this.imageUrl,
      updatedAt: DateTime.now(),
    );
  }
}
