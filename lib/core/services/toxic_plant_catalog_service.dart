import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';

/// Fetches and manages the `toxic_plants_catalog` Supabase table.
///
/// Replaces the formerly hardcoded toxic plant list with a database-driven
/// catalog that admins can add, edit, and delete via the Admin Console.
class ToxicPlantCatalogService {
  static ToxicPlantCatalogService? _instance;
  factory ToxicPlantCatalogService() =>
      _instance ??= ToxicPlantCatalogService._internal();
  ToxicPlantCatalogService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get _canRead => isSupabaseConfigured;

  /// Fetch all active toxic plant entries for the public browse screen.
  /// Ordered by display_order, then common_name.
  /// Falls back to empty list when Supabase is not configured or on error.
  Future<List<Map<String, dynamic>>> fetchAllActive() async {
    if (!_canRead) return [];
    try {
      final rows = await _client
          .from('toxic_plants_catalog')
          .select('*')
          .eq('is_active', true)
          .order('display_order')
          .order('common_name') as List<dynamic>;
      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantCatalogService] fetchAllActive: $e');
      return [];
    }
  }

  /// Fetch all entries (including inactive) for the admin editor.
  Future<List<Map<String, dynamic>>> fetchAllAdmin() async {
    if (!_canRead) return [];
    try {
      final rows = await _client
          .from('toxic_plants_catalog')
          .select('*')
          .order('display_order')
          .order('common_name') as List<dynamic>;
      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantCatalogService] fetchAllAdmin: $e');
      return [];
    }
  }

  /// Fetch a single entry by slug.
  Future<Map<String, dynamic>?> fetchBySlug(String slug) async {
    if (!_canRead) return null;
    try {
      final rows = await _client
          .from('toxic_plants_catalog')
          .select('*')
          .eq('slug', slug)
          .limit(1) as List<dynamic>;
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantCatalogService] fetchBySlug: $e');
      return null;
    }
  }

  /// Admin: insert a new toxic plant entry.
  /// Returns true on success.
  Future<bool> insert(Map<String, dynamic> data) async {
    if (!_canRead) return false;
    try {
      await _client.from('toxic_plants_catalog').insert(data);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantCatalogService] insert: $e');
      return false;
    }
  }

  /// Admin: update an existing entry by slug.
  /// Returns true on success.
  Future<bool> update(String slug, Map<String, dynamic> data) async {
    if (!_canRead) return false;
    try {
      await _client
          .from('toxic_plants_catalog')
          .update({...data, 'updated_at': DateTime.now().toIso8601String()})
          .eq('slug', slug);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantCatalogService] update: $e');
      return false;
    }
  }

  /// Admin: delete an entry by slug.
  /// Returns true on success.
  Future<bool> delete(String slug) async {
    if (!_canRead) return false;
    try {
      await _client.from('toxic_plants_catalog').delete().eq('slug', slug);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ToxicPlantCatalogService] delete: $e');
      return false;
    }
  }
}
