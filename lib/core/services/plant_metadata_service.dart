import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/models/plant_metadata_override.dart';

/// Admin-only: CRUD for plant_metadata overrides (description, safety_warnings, preparation_steps_json).
/// Catalog is fixed; no add/delete plant.
class PlantMetadataService {
  static PlantMetadataService? _instance;
  factory PlantMetadataService() =>
      _instance ??= PlantMetadataService._internal();
  PlantMetadataService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get isAvailable =>
      isSupabaseConfigured && _client.auth.currentUser != null;

  /// Fetch all overrides (admin RLS). Returns map by plant_id.
  Future<Map<String, PlantMetadataOverride>> getOverrides() async {
    if (!isAvailable) return {};
    try {
      final res = await _client.from('plant_metadata').select();
      final list = (res as List).cast<Map<String, dynamic>>();
      return {
        for (final e in list)
          (e['plant_id'] as String): PlantMetadataOverride.fromJson(e)
      };
    } catch (_) {
      return {};
    }
  }

  /// Get one override or null.
  Future<PlantMetadataOverride?> get(String plantId) async {
    if (!isAvailable) return null;
    try {
      final res = await _client
          .from('plant_metadata')
          .select()
          .eq('plant_id', plantId)
          .maybeSingle();
      if (res == null) return null;
      return PlantMetadataOverride.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  /// Upsert override for plant_id (admin only).
  Future<bool> save({
    required String plantId,
    String? description,
    String? safetyWarnings,
    String? preparationStepsJson,
    String? aiVisionSummary,
  }) async {
    if (!isAvailable) return false;
    try {
      await _client.from('plant_metadata').upsert({
        'plant_id': plantId,
        'description': description ?? '',
        'safety_warnings': safetyWarnings ?? '',
        'preparation_steps_json': preparationStepsJson ?? '',
        'ai_vision_summary': aiVisionSummary,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'plant_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove override (Factory Reset) so app falls back to default data.
  Future<bool> factoryReset(String plantId) async {
    if (!isAvailable) return false;
    try {
      await _client.from('plant_metadata').delete().eq('plant_id', plantId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
