import 'package:herbascan/core/models/catalog_condition.dart';
import 'package:herbascan/core/services/database_service.dart';

/// Exposes conditions and condition–plant links from SQLite (synced from Supabase).
/// When DB has no conditions, returns default list so Condition Search works before seed.
class ConditionService {
  static ConditionService? _instance;
  factory ConditionService() => _instance ??= ConditionService._internal();
  ConditionService._internal();

  final DatabaseService _db = DatabaseService();

  /// Default 15 conditions (same as legacy hardcoded list) for fallback when DB is empty.
  static List<CatalogCondition> get defaultConditions => [
        const CatalogCondition(id: 1, name: 'Cough', iconKey: 'sick', colorHex: '3B82F6', isDefault: true, sortOrder: 0),
        const CatalogCondition(id: 2, name: 'Asthma', iconKey: 'air', colorHex: '8B5CF6', isDefault: true, sortOrder: 1),
        const CatalogCondition(id: 3, name: 'Fever', iconKey: 'thermostat', colorHex: 'EF4444', isDefault: true, sortOrder: 2),
        const CatalogCondition(id: 4, name: 'Pain', iconKey: 'healing', colorHex: 'F59E0B', isDefault: true, sortOrder: 3),
        const CatalogCondition(id: 5, name: 'Diabetes', iconKey: 'water_drop', colorHex: 'EC4899', isDefault: true, sortOrder: 4),
        const CatalogCondition(id: 6, name: 'Hypertension', iconKey: 'favorite', colorHex: 'DC2626', isDefault: true, sortOrder: 5),
        const CatalogCondition(id: 7, name: 'Diarrhea', iconKey: 'local_hospital', colorHex: '8B5CF6', isDefault: true, sortOrder: 6),
        const CatalogCondition(id: 8, name: 'Kidney Stones', iconKey: 'bubble_chart', colorHex: '06B6D4', isDefault: true, sortOrder: 7),
        const CatalogCondition(id: 9, name: 'Wound Healing', iconKey: 'medical_services', colorHex: '10B981', isDefault: true, sortOrder: 8),
        const CatalogCondition(id: 10, name: 'Digestive Issues', iconKey: 'restaurant', colorHex: 'F97316', isDefault: true, sortOrder: 9),
        const CatalogCondition(id: 11, name: 'Skin Conditions', iconKey: 'spa', colorHex: '84CC16', isDefault: true, sortOrder: 10),
        const CatalogCondition(id: 12, name: 'Gout', iconKey: 'accessibility_new', colorHex: '6366F1', isDefault: true, sortOrder: 11),
        const CatalogCondition(id: 13, name: 'Respiratory Issues', iconKey: 'air', colorHex: '14B8A6', isDefault: true, sortOrder: 12),
        const CatalogCondition(id: 14, name: 'Inflammation', iconKey: 'local_fire_department', colorHex: 'EF4444', isDefault: true, sortOrder: 13),
        const CatalogCondition(id: 15, name: 'Fungal Infections', iconKey: 'bug_report', colorHex: 'A855F7', isDefault: true, sortOrder: 14),
      ];

  /// Conditions from SQLite (synced from Supabase). If empty, returns [defaultConditions].
  Future<List<CatalogCondition>> getConditions() async {
    final list = await _db.getConditions();
    if (list.isEmpty) return defaultConditions;
    return list;
  }

  /// Plant IDs linked to this condition (from catalog_condition_plants).
  /// When using default conditions (no sync yet), returns empty so UI can fall back to medicinalUses match.
  Future<List<String>> getPlantIdsForCondition(int conditionId) async {
    return _db.getPlantIdsForCondition(conditionId);
  }
}
