import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Default (bundled) plant anatomy data for "Restore to Default" and default-entry protection.
/// Key in JSON: "plant_id|part_name". Value: { svg_path, title, description, conditions }.
class DefaultAnatomyService {
  static Map<String, Map<String, dynamic>>? _cache;

  static const String _assetPath = 'assets/data/default_plant_anatomy.json';

  static Future<Map<String, Map<String, dynamic>>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final str = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(str) as Map<String, dynamic>?;
      _cache = decoded?.map((k, v) => MapEntry(k, (v as Map<String, dynamic>))) ?? {};
      return _cache!;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DefaultAnatomyService] load: $e');
        debugPrint(st.toString());
      }
      _cache = {};
      return _cache!;
    }
  }

  /// Returns true if (plantId, partName) has a default entry in the bundled JSON.
  static Future<bool> isDefault(String plantId, String partName) async {
    final map = await _load();
    return map.containsKey('$plantId|$partName');
  }

  /// Returns default data for (plantId, partName), or null if not a default part.
  /// Map keys: svg_path, title, description, conditions (list of strings).
  static Future<Map<String, dynamic>?> getDefaultData(String plantId, String partName) async {
    final map = await _load();
    final raw = map['$plantId|$partName'];
    if (raw == null) return null;
    final out = <String, dynamic>{
      'svg_path': raw['svg_path'] as String? ?? '',
      'title': raw['title'] as String? ?? '',
      'description': raw['description'] as String? ?? '',
      'conditions': raw['conditions'] is List
          ? List<String>.from((raw['conditions'] as List).map((e) => e.toString()))
          : <String>[],
    };
    return out;
  }
}
