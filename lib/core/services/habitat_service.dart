import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_habitat.dart';
import 'package:herbascan/core/services/error_logger.dart';

/// Single source of truth for static habitat data (Static Habitat Heatmap).
/// Loads from assets/data/plant_habitats.json; no third-party location API.
class HabitatService {
  static final HabitatService _instance = HabitatService._internal();
  factory HabitatService() => _instance;
  HabitatService._internal();

  Map<String, PlantHabitat>? _byPlantId;

  Future<void> _ensureLoaded() async {
    if (_byPlantId != null) return;
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/plant_habitats.json');
      final Map<String, dynamic> data =
          jsonDecode(jsonString) as Map<String, dynamic>;
      _byPlantId = {};
      for (final entry in data.entries) {
        final value = entry.value as Map<String, dynamic>;
        value['plant_id'] ??= entry.key.toString();
        final habitat = PlantHabitat.fromJson(value);
        _byPlantId![habitat.plantId] = habitat;
      }
      if (kDebugMode) {
        debugPrint(
            '[HabitatService] Loaded ${_byPlantId!.length} plant habitats. Keys: ${_byPlantId!.keys.take(5).join(", ")}${_byPlantId!.length > 5 ? "..." : ""}');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[HabitatService] Failed to load plant_habitats.json: $e');
      }
      await ErrorLogger().logError(
        ErrorType.unknownError,
        'HabitatService: failed to load plant_habitats.json',
        stackTrace: stack.toString(),
        context: {'error': e.toString()},
      );
      _byPlantId = {};
    }
  }

  /// Get habitat data by Plant (uses plant.id).
  Future<PlantHabitat?> getHabitat(Plant plant) async {
    return getHabitatByPlantId(plant.id);
  }

  /// Get habitat data by plant id (e.g. lagundi-001).
  Future<PlantHabitat?> getHabitatByPlantId(String plantId) async {
    if (plantId.isEmpty) {
      if (kDebugMode) debugPrint('[HabitatService] getHabitatByPlantId: plantId is empty');
      return null;
    }
    await _ensureLoaded();
    final habitat = _byPlantId?[plantId];
    if (kDebugMode) {
      if (habitat == null) {
        debugPrint(
            '[HabitatService] No habitat for plantId="$plantId". Available keys (sample): ${_byPlantId?.keys.take(10).join(", ") ?? "none"}');
      } else {
        debugPrint(
            '[HabitatService] Found habitat for "$plantId": coords=${habitat.knownCoordinates.length}, regions=${habitat.regionNames.length}, climateNotes=${habitat.climateNotes.isEmpty ? "empty" : "${habitat.climateNotes.length} chars"}');
      }
    }
    return habitat;
  }

  /// Returns true if the plant has at least one coordinate (so we can show "View habitat map").
  Future<bool> hasHabitatData(String plantId) async {
    final habitat = await getHabitatByPlantId(plantId);
    return habitat != null && habitat.hasCoordinates;
  }
}
