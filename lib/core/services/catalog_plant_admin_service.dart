import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/models/catalog_condition.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_habitat.dart';
import 'package:herbascan/core/models/safety_profile.dart';
import 'package:herbascan/core/services/condition_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';

/// Admin-only: read/write plant catalog in Supabase (catalog_plants + relations)
/// and upload plant images to Storage.
class CatalogPlantAdminService {
  static CatalogPlantAdminService? _instance;
  factory CatalogPlantAdminService() =>
      _instance ??= CatalogPlantAdminService._internal();
  CatalogPlantAdminService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get isAvailable =>
      isSupabaseConfigured && _client.auth.currentUser != null;

  static const String _bucket = 'herbarium-images';
  static const String _plantCatalogPath = 'plant-catalog';

  /// Fetch one plant from Supabase catalog (or null if not present).
  Future<Plant?> getCatalogPlant(String plantId, {required String defaultImagePath}) async {
    if (!isAvailable) return null;
    try {
      final row = await _client
          .from('catalog_plants')
          .select()
          .eq('id', plantId)
          .maybeSingle();
      if (row == null) return null;

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

      final updatedAt = row['last_updated'] != null
          ? DateTime.tryParse(row['last_updated'].toString()) ?? DateTime.now()
          : DateTime.now();

      return Plant(
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
        imagePath: defaultImagePath,
        imageUrl: row['image_url'] as String?,
        createdAt: updatedAt,
        updatedAt: updatedAt,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] getCatalogPlant: $e');
        debugPrint(st.toString());
      }
      return null;
    }
  }

  /// Save plant to Supabase (upsert catalog_plants, replace medicinal_uses and preparation_methods).
  Future<bool> saveCatalogPlant(Plant plant, {String? climateNotes}) async {
    if (!isAvailable) return false;
    try {
      await _client.from('catalog_plants').upsert({
        'id': plant.id,
        'common_name': plant.commonName,
        'scientific_name': plant.scientificName,
        'local_name': plant.localName,
        'english_name': plant.englishName,
        'family': plant.family,
        'genus': plant.genus,
        'species': plant.species,
        'morphology': plant.morphology,
        'ecology': plant.ecology,
        'habitat': plant.habitat,
        'climate_notes': climateNotes ?? '',
        'image_url': plant.imageUrl,
        'is_doh_approved': plant.isDOHApproved,
        'last_updated': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');

      await _client
          .from('catalog_medicinal_uses')
          .delete()
          .eq('plant_id', plant.id);

      for (var use in plant.medicinalUses) {
        await _client.from('catalog_medicinal_uses').insert({
          'plant_id': plant.id,
          'condition': use.condition,
          'description': use.description,
          'effectiveness': use.effectiveness,
          'active_compounds': use.activeCompounds.join(','),
          'dosage': use.dosage,
          'duration': use.duration,
        });
      }

      await _client
          .from('catalog_preparation_methods')
          .delete()
          .eq('plant_id', plant.id);

      for (var method in plant.preparationMethods) {
        await _client.from('catalog_preparation_methods').insert({
          'id': method.id,
          'plant_id': plant.id,
          'condition': method.condition,
          'title': method.title,
          'description': method.description,
          'preparation_type': method.preparationType,
          'steps': method.steps.join('|'),
          'step_details_json': method.stepDetails != null && method.stepDetails!.isNotEmpty
              ? jsonEncode(method.stepDetails!.map((s) => s.toJson()).toList())
              : null,
          'schedule_json': method.schedule != null ? jsonEncode(method.schedule!.toJson()) : null,
          'dosage': method.dosage,
          'frequency': method.frequency,
          'duration': method.duration,
          'warnings': method.warnings.join('|'),
        });
      }

      if (kDebugMode) debugPrint('[CatalogPlantAdminService] Saved plant ${plant.id}');
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] saveCatalogPlant: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }

  /// Fetch safety profile from catalog_safety for a plant (or null if not present).
  Future<SafetyProfile?> getCatalogSafety(String plantId) async {
    if (!isAvailable) return null;
    try {
      final row = await _client
          .from('catalog_safety')
          .select()
          .eq('plant_id', plantId)
          .maybeSingle();
      if (row == null) return null;
      final map = Map<String, dynamic>.from(row);
      map['name'] ??= '';
      return SafetyProfile.fromJson(map);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] getCatalogSafety: $e');
        debugPrint(st.toString());
      }
      return null;
    }
  }

  /// Save safety profile to catalog_safety (upsert by plant_id).
  Future<bool> saveCatalogSafety(String plantId, SafetyProfile profile) async {
    if (!isAvailable) return false;
    try {
      await _client.from('catalog_safety').upsert({
        'plant_id': plantId,
        'is_generally_safe': profile.isGenerallySafe,
        'pregnancy_warning': profile.pregnancyWarning,
        'known_side_effects': profile.knownSideEffects,
        'drug_interactions': profile.drugInteractions,
        'strict_contraindications': profile.strictContraindications,
        'needs_strict_contraindications': profile.needsStrictContraindications,
      }, onConflict: 'plant_id');
      if (kDebugMode) debugPrint('[CatalogPlantAdminService] Saved safety for $plantId');
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] saveCatalogSafety: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }

  /// Fetch habitat from catalog_habitat for a plant (or null if not present).
  Future<PlantHabitat?> getCatalogHabitat(String plantId) async {
    if (!isAvailable) return null;
    try {
      final row = await _client
          .from('catalog_habitat')
          .select()
          .eq('plant_id', plantId)
          .maybeSingle();
      if (row == null) return null;
      final map = Map<String, dynamic>.from(row);
      map['plant_id'] ??= plantId;
      return PlantHabitat.fromJson(map);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] getCatalogHabitat: $e');
        debugPrint(st.toString());
      }
      return null;
    }
  }

  /// Save habitat to catalog_habitat (upsert by plant_id).
  Future<bool> saveCatalogHabitat(String plantId, PlantHabitat habitat) async {
    if (!isAvailable) return false;
    try {
      await _client.from('catalog_habitat').upsert({
        'plant_id': plantId,
        'known_coordinates': habitat.knownCoordinates.map((e) => e.toJson()).toList(),
        'region_names': habitat.regionNames,
        'climate_notes': habitat.climateNotes,
      }, onConflict: 'plant_id');
      if (kDebugMode) debugPrint('[CatalogPlantAdminService] Saved habitat for $plantId');
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] saveCatalogHabitat: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }

  /// Upload plant image to Storage; returns public URL or null.
  Future<String?> uploadPlantImage(String plantId, File imageFile) async {
    if (!isAvailable) return null;
    try {
      final ext = imageFile.path.split('.').last.toLowerCase();
      if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') return null;
      final path = '$_plantCatalogPath/$plantId.$ext';
      await _client.storage.from(_bucket).upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = _client.storage.from(_bucket).getPublicUrl(path);
      if (kDebugMode) debugPrint('[CatalogPlantAdminService] Uploaded image: $url');
      return url;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] uploadPlantImage: $e');
        debugPrint(st.toString());
      }
      return null;
    }
  }

  /// Factory Reset: restore entire Supabase catalog (and optionally Storage) to bundled defaults.
  /// Calls [seedCatalogFromDefaults] then optionally removes all objects under plant-catalog/ so
  /// custom uploaded images are cleared. Next app sync will pull the reset data.
  /// Returns true if seed succeeded; storage clear is best-effort.
  Future<bool> factoryResetCatalog({bool clearPlantCatalogStorage = true}) async {
    if (!isAvailable) return false;
    final ok = await seedCatalogFromDefaults();
    if (!ok) return false;
    if (clearPlantCatalogStorage) {
      try {
        final files = await _client.storage.from(_bucket).list(path: _plantCatalogPath);
        if (files.isNotEmpty) {
          final names = files.map((f) => '$_plantCatalogPath/${f.name}').toList();
          await _client.storage.from(_bucket).remove(names);
          if (kDebugMode) debugPrint('[CatalogPlantAdminService] Cleared ${names.length} plant-catalog images.');
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[CatalogPlantAdminService] factoryResetCatalog clearStorage: $e');
          debugPrint(st.toString());
        }
      }
    }
    return true;
  }

  /// Seed Supabase catalog from bundled defaults (42 plants). Call once or for Factory Reset.
  /// Also seeds catalog_safety, catalog_habitat, and catalog_conditions from assets/defaults.
  Future<bool> seedCatalogFromDefaults() async {
    if (!isAvailable) return false;
    try {
      final plants = PlantDataService.getAllMedicinalPlantsData();
      for (var plant in plants) {
        await saveCatalogPlant(plant);
      }
      if (kDebugMode) debugPrint('[CatalogPlantAdminService] Seeded ${plants.length} plants.');
      await seedCatalogSafetyAndHabitatFromAssets();
      await seedCatalogConditionsFromDefaults();
      await seedCatalogAnatomyFromDefaults();
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] seedCatalogFromDefaults: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }

  /// Seed catalog_safety and catalog_habitat in Supabase from assets/data JSONs.
  /// Called by seedCatalogFromDefaults; can also be used standalone (e.g. "Seed safety/habitat").
  Future<void> seedCatalogSafetyAndHabitatFromAssets() async {
    if (!isAvailable) return;
    try {
      final safetyJson =
          await rootBundle.loadString('assets/data/safety_profiles.json');
      final safetyData = jsonDecode(safetyJson) as Map<String, dynamic>;
      for (final entry in safetyData.entries) {
        final value = entry.value as Map<String, dynamic>;
        value['plant_id'] ??= '${entry.key.toLowerCase().replaceAll(RegExp(r'[\s\-/]+'), '-')}-001';
        value['name'] ??= entry.key;
        final profile = SafetyProfile.fromJson(value);
        if (profile.plantId.isEmpty) continue;
        await _client.from('catalog_safety').upsert({
          'plant_id': profile.plantId,
          'is_generally_safe': profile.isGenerallySafe,
          'pregnancy_warning': profile.pregnancyWarning,
          'known_side_effects': profile.knownSideEffects,
          'drug_interactions': profile.drugInteractions,
          'strict_contraindications': profile.strictContraindications,
          'needs_strict_contraindications': profile.needsStrictContraindications,
        }, onConflict: 'plant_id');
      }
      if (kDebugMode) debugPrint('[CatalogPlantAdminService] Seeded ${safetyData.length} safety profiles.');

      final habitatJson =
          await rootBundle.loadString('assets/data/plant_habitats.json');
      final habitatData = habitatJson.isNotEmpty
          ? (jsonDecode(habitatJson) as Map<String, dynamic>)
          : <String, dynamic>{};
      for (final entry in habitatData.entries) {
        final value = entry.value as Map<String, dynamic>;
        value['plant_id'] ??= entry.key;
        final habitat = PlantHabitat.fromJson(value);
        if (habitat.plantId.isEmpty) continue;
        await _client.from('catalog_habitat').upsert({
          'plant_id': habitat.plantId,
          'known_coordinates': habitat.knownCoordinates.map((e) => e.toJson()).toList(),
          'region_names': habitat.regionNames,
          'climate_notes': habitat.climateNotes,
        }, onConflict: 'plant_id');
      }
      if (kDebugMode) debugPrint('[CatalogPlantAdminService] Seeded ${habitatData.length} habitats.');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] seedCatalogSafetyAndHabitatFromAssets: $e');
        debugPrint(st.toString());
      }
    }
  }

  /// Seed catalog_conditions with 15 default conditions and catalog_condition_plants from plant medicinal uses.
  /// Called by seedCatalogFromDefaults; can also be used standalone (e.g. "Seed conditions" in admin).
  Future<void> seedCatalogConditionsFromDefaults() async {
    if (!isAvailable) return;
    try {
      final defaults = ConditionService.defaultConditions;
      for (var c in defaults) {
        await _client.from('catalog_conditions').upsert({
          'name': c.name,
          'icon_key': c.iconKey,
          'color_hex': c.colorHex,
          'is_default': c.isDefault,
          'sort_order': c.sortOrder,
        }, onConflict: 'name');
      }
      final condRes = await _client.from('catalog_conditions').select('id, name');
      final condList = (condRes as List).cast<Map<String, dynamic>>();
      final nameToId = <String, int>{};
      for (var row in condList) {
        final name = row['name'] as String? ?? '';
        final id = row['id'] is int ? row['id'] as int : int.tryParse(row['id'].toString());
        if (name.isNotEmpty && id != null) nameToId[name.toLowerCase().trim()] = id;
      }
      final plants = PlantDataService.getAllMedicinalPlantsData();
      final Set<String> inserted = {};
      for (var plant in plants) {
        for (var use in plant.medicinalUses) {
          final conditionName = use.condition.trim();
          if (conditionName.isEmpty) continue;
          final id = nameToId[conditionName.toLowerCase()];
          if (id == null) continue;
          final key = '$id-${plant.id}';
          if (inserted.contains(key)) continue;
          inserted.add(key);
          await _client.from('catalog_condition_plants').upsert({
            'condition_id': id,
            'plant_id': plant.id,
          }, onConflict: 'condition_id,plant_id');
        }
      }
      if (kDebugMode) debugPrint('[CatalogPlantAdminService] Seeded ${defaults.length} conditions and ${inserted.length} condition–plant links.');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] seedCatalogConditionsFromDefaults: $e');
        debugPrint(st.toString());
      }
    }
  }

  /// Seed catalog_plant_anatomy from assets/data/default_plant_anatomy.json.
  /// Additive: only inserts missing (plant_id, part_name) pairs; does not delete existing rows.
  /// Called by seedCatalogFromDefaults; ensures all 39 non-toxic plants have at least one anatomy part.
  Future<void> seedCatalogAnatomyFromDefaults() async {
    if (!isAvailable) return;
    try {
      final existingRes = await _client.from('catalog_plant_anatomy').select('plant_id, part_name');
      final existingList = (existingRes as List).cast<Map<String, dynamic>>();
      final existingKeys = <String>{};
      for (var row in existingList) {
        final pid = row['plant_id'] as String? ?? '';
        final pn = row['part_name'] as String? ?? '';
        if (pid.isNotEmpty) existingKeys.add('$pid|$pn');
      }

      final jsonStr = await rootBundle.loadString('assets/data/default_plant_anatomy.json');
      final defaultData = jsonDecode(jsonStr) as Map<String, dynamic>? ?? {};
      int inserted = 0;
      for (final entry in defaultData.entries) {
        final key = entry.key;
        if (!key.contains('|')) continue;
        if (existingKeys.contains(key)) continue;
        final value = entry.value as Map<String, dynamic>? ?? {};
        final plantId = key.split('|').first;
        final partName = key.split('|').skip(1).join('|');
        final svgPath = value['svg_path'] as String? ?? 'M 20 20 L 180 20 L 180 160 L 20 160 Z';
        final title = value['title'] as String? ?? partName;
        final description = value['description'] as String? ?? '';
        final conditionsRaw = value['conditions'];
        final conditions = conditionsRaw is List
            ? conditionsRaw.map((e) => e.toString()).toList()
            : <String>[];

        final row = <String, dynamic>{
          'plant_id': plantId,
          'part_name': partName,
          'svg_path': svgPath,
          'color_hex': '4CAF50',
          'z_index': 0,
          'is_interactive': true,
          'title': title,
          'description': description,
          'conditions': conditions,
        };
        final id = await insertCatalogAnatomy(row);
        if (id != null) {
          existingKeys.add(key);
          inserted++;
        }
      }
      if (kDebugMode) debugPrint('[CatalogPlantAdminService] Seeded $inserted anatomy rows from defaults.');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] seedCatalogAnatomyFromDefaults: $e');
        debugPrint(st.toString());
      }
    }
  }

  // --- Condition Search management (admin CRUD) ---

  /// List all conditions from Supabase catalog_conditions.
  Future<List<CatalogCondition>> listCatalogConditions() async {
    if (!isAvailable) return [];
    try {
      final res = await _client.from('catalog_conditions').select().order('sort_order');
      final list = (res as List).cast<Map<String, dynamic>>();
      return list.map((row) => CatalogCondition.fromRow(row)).toList();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] listCatalogConditions: $e');
        debugPrint(st.toString());
      }
      return [];
    }
  }

  /// Add a custom condition. Returns new id or null.
  Future<int?> addCatalogCondition({
    required String name,
    required String iconKey,
    required String colorHex,
    int sortOrder = 999,
  }) async {
    if (!isAvailable) return null;
    try {
      final res = await _client.from('catalog_conditions').insert({
        'name': name.trim(),
        'icon_key': iconKey,
        'color_hex': colorHex,
        'is_default': false,
        'sort_order': sortOrder,
      }).select('id');
      final list = res as List;
      final row = list.isNotEmpty ? list.first : null;
      final id = row?['id'];
      return id is int ? id : int.tryParse(id?.toString() ?? '');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] addCatalogCondition: $e');
        debugPrint(st.toString());
      }
      return null;
    }
  }

  /// Update a condition (name, icon_key, color_hex, sort_order).
  Future<bool> updateCatalogCondition(int id, {
    required String name,
    required String iconKey,
    required String colorHex,
    required int sortOrder,
  }) async {
    if (!isAvailable) return false;
    try {
      await _client.from('catalog_conditions').update({
        'name': name.trim(),
        'icon_key': iconKey,
        'color_hex': colorHex,
        'sort_order': sortOrder,
      }).eq('id', id);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] updateCatalogCondition: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }

  /// Delete a condition. Only allowed for custom (is_default=false).
  Future<bool> deleteCatalogCondition(int id) async {
    if (!isAvailable) return false;
    try {
      final row = await _client.from('catalog_conditions').select('is_default').eq('id', id).maybeSingle();
      if (row == null) return false;
      final isDefault = (row['is_default'] as bool?) ?? false;
      if (isDefault) return false;
      await _client.from('catalog_condition_plants').delete().eq('condition_id', id);
      await _client.from('catalog_conditions').delete().eq('id', id);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] deleteCatalogCondition: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }

  /// Get plant IDs linked to a condition from Supabase.
  Future<List<String>> getPlantIdsForCatalogCondition(int conditionId) async {
    if (!isAvailable) return [];
    try {
      final res = await _client.from('catalog_condition_plants').select('plant_id').eq('condition_id', conditionId);
      final list = (res as List).cast<Map<String, dynamic>>();
      return list.map((r) => r['plant_id'] as String? ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] getPlantIdsForCatalogCondition: $e');
        debugPrint(st.toString());
      }
      return [];
    }
  }

  /// Replace plant links for a condition.
  Future<bool> saveConditionPlants(int conditionId, List<String> plantIds) async {
    if (!isAvailable) return false;
    try {
      await _client.from('catalog_condition_plants').delete().eq('condition_id', conditionId);
      for (var pid in plantIds) {
        if (pid.isEmpty) continue;
        await _client.from('catalog_condition_plants').insert({
          'condition_id': conditionId,
          'plant_id': pid,
        });
      }
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] saveConditionPlants: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }

  // --- Anatomy (catalog_plant_anatomy) CRUD ---

  /// List anatomy rows for a plant from Supabase, ordered by z_index.
  Future<List<Map<String, dynamic>>> getCatalogAnatomyForPlant(String plantId) async {
    if (!isAvailable) return [];
    try {
      final res = await _client
          .from('catalog_plant_anatomy')
          .select()
          .eq('plant_id', plantId)
          .order('z_index');
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] getCatalogAnatomyForPlant: $e');
        debugPrint(st.toString());
      }
      return [];
    }
  }

  /// Insert one anatomy row. Returns the new id (UUID string) or null.
  Future<String?> insertCatalogAnatomy(Map<String, dynamic> row) async {
    if (!isAvailable) return null;
    try {
      final payload = <String, dynamic>{
        'plant_id': row['plant_id'] as String? ?? '',
        'part_name': row['part_name'] as String? ?? '',
        'svg_path': row['svg_path'] as String? ?? '',
        'color_hex': row['color_hex'] as String? ?? '4CAF50',
        'z_index': row['z_index'] is int ? row['z_index'] as int : int.tryParse(row['z_index'].toString()) ?? 0,
        'is_interactive': row['is_interactive'] == true || row['is_interactive'] == 1,
        'title': row['title'] as String? ?? '',
        'description': row['description'] as String? ?? '',
        'conditions': row['conditions'],
      };
      if (payload['conditions'] is! List) {
        payload['conditions'] = payload['conditions'] is String
            ? (jsonDecode((payload['conditions'] as String).isEmpty ? '[]' : payload['conditions'] as String) as List<dynamic>)
            : <dynamic>[];
      }
      final res = await _client.from('catalog_plant_anatomy').insert(payload).select('id');
      final list = res as List;
      final id = list.isNotEmpty ? list.first['id'] : null;
      return id?.toString();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] insertCatalogAnatomy: $e');
        debugPrint(st.toString());
      }
      return null;
    }
  }

  /// Update an anatomy row by id. Only provided fields are updated.
  Future<bool> updateCatalogAnatomy(String id, {
    String? svgPath,
    String? description,
    dynamic conditions,
    String? colorHex,
    int? zIndex,
    bool? isInteractive,
    String? title,
    String? partName,
  }) async {
    if (!isAvailable || id.isEmpty) return false;
    try {
      final payload = <String, dynamic>{'updated_at': DateTime.now().toUtc().toIso8601String()};
      if (svgPath != null) payload['svg_path'] = svgPath;
      if (description != null) payload['description'] = description;
      if (conditions != null) payload['conditions'] = conditions is List ? conditions : (conditions is String ? jsonDecode(conditions.isEmpty ? '[]' : conditions) as List<dynamic> : <dynamic>[]);
      if (colorHex != null) payload['color_hex'] = colorHex;
      if (zIndex != null) payload['z_index'] = zIndex;
      if (isInteractive != null) payload['is_interactive'] = isInteractive;
      if (title != null) payload['title'] = title;
      if (partName != null) payload['part_name'] = partName;
      await _client.from('catalog_plant_anatomy').update(payload).eq('id', id);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] updateCatalogAnatomy: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }

  /// Delete an anatomy row by id. Call only for non-default entries (caller enforces).
  Future<bool> deleteCatalogAnatomy(String id) async {
    if (!isAvailable || id.isEmpty) return false;
    try {
      await _client.from('catalog_plant_anatomy').delete().eq('id', id);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CatalogPlantAdminService] deleteCatalogAnatomy: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }
}
