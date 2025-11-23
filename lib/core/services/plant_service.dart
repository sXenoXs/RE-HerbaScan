import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/services/database_service.dart';

class PlantService {
  final DatabaseService _databaseService = DatabaseService();

  // Load all plants from database
  Future<List<Plant>> getAllPlants() async {
    return await _databaseService.getAllPlants();
  }

  // Load DOH-approved plants from database
  Future<List<Plant>> getDOHApprovedPlants() async {
    return await _databaseService.getDOHApprovedPlants();
  }

  // Get plant by ID from database
  Future<Plant?> getPlantById(String id) async {
    return await _databaseService.getPlantById(id);
  }

  // Search plants by query
  Future<List<Plant>> searchPlants(String query) async {
    final plants = await getAllPlants();
    return plants.where((plant) {
      final lowerQuery = query.toLowerCase();
      return plant.commonName.toLowerCase().contains(lowerQuery) ||
          plant.scientificName.toLowerCase().contains(lowerQuery) ||
          plant.localName.toLowerCase().contains(lowerQuery) ||
          plant.medicinalUses.any((use) => use.condition.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Get plants by condition
  Future<List<Plant>> getPlantsByCondition(String condition) async {
    final plants = await getAllPlants();
    return plants.where((plant) => plant.treatsCondition(condition)).toList();
  }
}

