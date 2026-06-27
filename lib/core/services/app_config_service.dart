import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';

/// Fetches app configuration from the Supabase `app_config` table.
///
/// Provides remote-controlled values for app version, model version, and
/// help/tutorial content. Falls back to compile-time defaults when Supabase
/// is unreachable or the table has no data.
class AppConfigService {
  static AppConfigService? _instance;
  factory AppConfigService() => _instance ??= AppConfigService._internal();
  AppConfigService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get _canRead => isSupabaseConfigured;

  /// Fetches all config values as a Map<String, String>.
  /// Returns an empty map when Supabase is not configured or on error.
  Future<Map<String, String>> fetchAll() async {
    if (!_canRead) return {};
    try {
      final rows = await _client.from('app_config').select('key, value') as List<dynamic>;
      final map = <String, String>{};
      for (final row in rows) {
        if (row['key'] != null && row['value'] != null) {
          map[row['key'] as String] = row['value'] as String;
        }
      }
      return map;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppConfigService] fetchAll: $e');
      return {};
    }
  }

  /// Fetches a single config value by key. Returns null if not found.
  Future<String?> fetchValue(String key) async {
    if (!_canRead) return null;
    try {
      final rows = await _client
          .from('app_config')
          .select('value')
          .eq('key', key)
          .limit(1) as List<dynamic>;
      if (rows.isNotEmpty && rows.first['value'] != null) {
        return rows.first['value'] as String;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppConfigService] fetchValue($key): $e');
      return null;
    }
  }

  /// Admin: upsert a config key-value pair.
  /// Returns true on success.
  Future<bool> upsert(String key, String value, {String description = ''}) async {
    if (!_canRead) return false;
    try {
      await _client.from('app_config').upsert({
        'key': key,
        'value': value,
        'description': description,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': _client.auth.currentUser?.id,
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppConfigService] upsert($key): $e');
      return false;
    }
  }

  /// Admin: delete a config key.
  Future<bool> delete(String key) async {
    if (!_canRead) return false;
    try {
      await _client.from('app_config').delete().eq('key', key);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppConfigService] delete($key): $e');
      return false;
    }
  }

  /// Admin: fetch all rows with full metadata for the admin editor.
  Future<List<Map<String, dynamic>>> fetchAllAdmin() async {
    if (!_canRead) return [];
    try {
      final rows = await _client
          .from('app_config')
          .select('key, value, description, updated_at')
          .order('key') as List<dynamic>;
      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AppConfigService] fetchAllAdmin: $e');
      return [];
    }
  }
}
