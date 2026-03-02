import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/models/catalog_condition.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_habitat.dart';
import 'package:herbascan/core/models/safety_profile.dart';
import 'package:herbascan/core/services/database_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';

const String _keyLastSynced = 'catalog_last_synced_timestamp';

/// Syncs plant catalog from Supabase (catalog_plants + related) to local SQLite.
/// Run when online; app continues to read from SQLite at runtime.
class CatalogSyncService {
  static final CatalogSyncService _instance = CatalogSyncService._internal();
  factory CatalogSyncService() => _instance;
  CatalogSyncService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  final DatabaseService _db = DatabaseService();

  /// Last sync time (ISO8601) or null if never synced.
  Future<String?> getLastSyncedTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastSynced);
  }

  /// Perform sync: fetch catalog from Supabase, overwrite local SQLite.
  /// Returns true if sync ran and at least one plant was processed.
  Future<bool> syncFromSupabase() async {
    if (!isSupabaseConfigured) return false;
    try {
      final plantsRes = await _client.from('catalog_plants').select();
      final plantsList = (plantsRes as List).cast<Map<String, dynamic>>();
      if (plantsList.isEmpty) {
        if (kDebugMode) debugPrint('[CatalogSync] No catalog_plants rows; skip overwrite.');
        return false;
      }

      final defaults = PlantDataService.getAllMedicinalPlantsData();
      final defaultById = {for (var p in defaults) p.id: p};

      for (var row in plantsList) {
        final plantId = row['id'] as String? ?? '';
        if (plantId.isEmpty) continue;

        final defaultPlant = defaultById[plantId];
        final imagePath = defaultPlant?.imagePath ?? 'assets/images/placeholder_plant.jpg';

        final medicinalRes = await _client
            .from('catalog_medicinal_uses')
            .select()
            .eq('plant_id', plantId);
        final medicinalList = (medicinalRes as List).cast<Map<String, dynamic>>();

        final prepRes = await _client
            .from('catalog_preparation_methods')
            .select()
            .eq('plant_id', plantId);
        final prepList = (prepRes as List).cast<Map<String, dynamic>>();

        final medicinalUses = medicinalList.map((m) {
          final ac = m['active_compounds'];
          return MedicinalUse(
            condition: m['condition'] as String? ?? '',
            description: m['description'] as String? ?? '',
            effectiveness: m['effectiveness'] as String? ?? '',
            activeCompounds: ac is String
                ? (ac.isEmpty ? [] : ac.split(',').map((e) => e.trim()).toList())
                : (ac is List ? ac.map((e) => e.toString()).toList() : []),
            dosage: m['dosage'] as String? ?? '',
            duration: m['duration'] as String? ?? '',
          );
        }).toList();

        final preparationMethods = prepList.map((m) {
          List<PreparationStepDetail>? stepDetails;
          final sd = m['step_details_json'];
          if (sd != null && sd is String && sd.isNotEmpty) {
            try {
              final list = jsonDecode(sd) as List<dynamic>?;
              if (list != null) {
                stepDetails = list
                    .map((e) => PreparationStepDetail.fromJson(e as Map<String, dynamic>))
                    .toList();
              }
            } catch (_) {}
          }
          PreparationSchedule? schedule;
          final sj = m['schedule_json'];
          if (sj != null && sj is String && sj.isNotEmpty) {
            try {
              schedule = PreparationSchedule.fromJson(jsonDecode(sj) as Map<String, dynamic>);
            } catch (_) {}
          }
          final stepsStr = m['steps'] as String? ?? '';
          final steps = stepsStr.isEmpty ? <String>[] : stepsStr.split('|');
          final warningsStr = m['warnings'] as String? ?? '';
          final warnings = warningsStr.isEmpty ? <String>[] : warningsStr.split('|');
          return PreparationMethod(
            id: m['id'] as String? ?? plantId,
            condition: m['condition'] as String? ?? '',
            title: m['title'] as String? ?? '',
            description: m['description'] as String? ?? '',
            steps: steps,
            dosage: m['dosage'] as String? ?? '',
            frequency: m['frequency'] as String? ?? '',
            duration: m['duration'] as String? ?? '',
            warnings: warnings,
            preparationType: m['preparation_type'] as String? ?? '',
            stepDetails: stepDetails,
            schedule: schedule,
          );
        }).toList();

        final lastUpdated = row['last_updated'];
        final updatedAt = lastUpdated != null
            ? DateTime.tryParse(lastUpdated.toString()) ?? DateTime.now()
            : DateTime.now();
        final createdAt = updatedAt;

        final plant = Plant(
          id: plantId,
          commonName: row['common_name'] as String? ?? '',
          scientificName: row['scientific_name'] as String? ?? '',
          localName: row['local_name'] as String? ?? '',
          englishName: row['english_name'] as String? ?? '',
          family: row['family'] as String? ?? '',
          genus: row['genus'] as String? ?? '',
          species: row['species'] as String? ?? '',
          isDOHApproved: (row['is_doh_approved'] as bool?) ?? false,
          morphology: row['morphology'] as String? ?? '',
          ecology: row['ecology'] as String? ?? '',
          habitat: row['habitat'] as String? ?? '',
          medicinalUses: medicinalUses,
          preparationMethods: preparationMethods,
          safetyWarnings: [],
          imagePath: imagePath,
          imageUrl: row['image_url'] as String?,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        await _db.replacePlantFromSync(plant);
      }

      // Sync catalog_safety to local safety_profiles table
      try {
        final safetyRes = await _client.from('catalog_safety').select();
        final safetyList = (safetyRes as List).cast<Map<String, dynamic>>();
        for (var row in safetyList) {
          final plantId = row['plant_id'] as String? ?? '';
          if (plantId.isEmpty) continue;
          final profile = _safetyRowToProfile(plantId, row);
          await _db.replaceSafetyFromSync(profile);
        }
        if (kDebugMode) debugPrint('[CatalogSync] Synced ${safetyList.length} safety profiles.');
      } catch (e) {
        if (kDebugMode) debugPrint('[CatalogSync] catalog_safety sync skipped: $e');
      }

      // Sync catalog_habitat to local plant_habitats table
      try {
        final habitatRes = await _client.from('catalog_habitat').select();
        final habitatList = (habitatRes as List).cast<Map<String, dynamic>>();
        for (var row in habitatList) {
          final habitat = _habitatRowToPlantHabitat(row);
          if (habitat.plantId.isNotEmpty) {
            await _db.replaceHabitatFromSync(habitat);
          }
        }
        if (kDebugMode) debugPrint('[CatalogSync] Synced ${habitatList.length} habitats.');
      } catch (e) {
        if (kDebugMode) debugPrint('[CatalogSync] catalog_habitat sync skipped: $e');
      }

      // Sync catalog_conditions and catalog_condition_plants to local SQLite
      try {
        final condRes = await _client.from('catalog_conditions').select().order('sort_order');
        final condList = (condRes as List).cast<Map<String, dynamic>>();
        final conditions = condList.map((row) => _conditionRowToCatalogCondition(row)).toList();
        if (conditions.isNotEmpty) {
          await _db.replaceConditionsFromSync(conditions);
          if (kDebugMode) debugPrint('[CatalogSync] Synced ${conditions.length} conditions.');
        }
        final cpRes = await _client.from('catalog_condition_plants').select();
        final cpList = (cpRes as List).cast<Map<String, dynamic>>();
        final pairs = <MapEntry<int, String>>[];
        for (var row in cpList) {
          final cid = row['condition_id'];
          final pid = row['plant_id'] as String? ?? '';
          if (cid != null && pid.isNotEmpty) {
            final id = cid is int ? cid : int.tryParse(cid.toString());
            if (id != null) pairs.add(MapEntry(id, pid));
          }
        }
        if (pairs.isNotEmpty) {
          await _db.replaceConditionPlantsFromSync(pairs);
          if (kDebugMode) debugPrint('[CatalogSync] Synced ${pairs.length} condition–plant links.');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[CatalogSync] catalog_conditions sync skipped: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSynced, DateTime.now().toUtc().toIso8601String());
      if (kDebugMode) debugPrint('[CatalogSync] Synced ${plantsList.length} plants.');
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogSync] Error: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }

  /// Parse a catalog_safety row (Supabase JSONB may be List or String).
  static SafetyProfile _safetyRowToProfile(String plantId, Map<String, dynamic> row) {
    List<String> listFrom(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty && v != '[]') {
        try {
          final decoded = jsonDecode(v) as List<dynamic>?;
          return decoded?.map((e) => e.toString()).toList() ?? [];
        } catch (_) {}
      }
      return [];
    }
    return SafetyProfile(
      plantId: plantId,
      name: '',
      isGenerallySafe: (row['is_generally_safe'] as bool?) ?? true,
      pregnancyWarning: (row['pregnancy_warning'] as bool?) ?? false,
      knownSideEffects: listFrom(row['known_side_effects']),
      drugInteractions: listFrom(row['drug_interactions']),
      strictContraindications: listFrom(row['strict_contraindications']),
    );
  }

  /// Parse a catalog_conditions row from Supabase.
  static CatalogCondition _conditionRowToCatalogCondition(Map<String, dynamic> row) {
    final id = row['id'];
    final idInt = id is int ? id : int.tryParse(id.toString()) ?? 0;
    return CatalogCondition(
      id: idInt,
      name: row['name'] as String? ?? '',
      iconKey: row['icon_key'] as String? ?? 'healing',
      colorHex: row['color_hex'] as String? ?? 'FF6366F1',
      isDefault: (row['is_default'] as bool?) ?? false,
      sortOrder: row['sort_order'] is int ? row['sort_order'] as int : int.tryParse(row['sort_order'].toString()) ?? 0,
    );
  }

  /// Parse a catalog_habitat row (Supabase JSONB may be List/Map or String).
  static PlantHabitat _habitatRowToPlantHabitat(Map<String, dynamic> row) {
    final plantId = row['plant_id'] as String? ?? '';
    List<HabitatPoint> coords = [];
    final coordsRaw = row['known_coordinates'];
    if (coordsRaw is List) {
      for (var e in coordsRaw) {
        if (e is Map<String, dynamic>) {
          coords.add(HabitatPoint.fromJson(e));
        }
      }
    } else if (coordsRaw is String && coordsRaw.isNotEmpty && coordsRaw != '[]') {
      try {
        final decoded = jsonDecode(coordsRaw) as List<dynamic>?;
        if (decoded != null) {
          coords = decoded
              .map((e) => HabitatPoint.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }
    List<String> regions = [];
    final regionsRaw = row['region_names'];
    if (regionsRaw is List) {
      regions = regionsRaw.map((e) => e.toString()).toList();
    } else if (regionsRaw is String && regionsRaw.isNotEmpty && regionsRaw != '[]') {
      try {
        final decoded = jsonDecode(regionsRaw) as List<dynamic>?;
        regions = decoded?.map((e) => e.toString()).toList() ?? [];
      } catch (_) {}
    }
    return PlantHabitat(
      plantId: plantId,
      knownCoordinates: coords,
      regionNames: regions,
      climateNotes: row['climate_notes'] as String? ?? '',
    );
  }
}
