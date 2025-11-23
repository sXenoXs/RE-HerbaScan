import 'package:herbascan/core/services/database_service.dart';
import 'package:herbascan/core/services/plant_data_service.dart';
import 'package:herbascan/core/models/plant.dart';

/// Service to initialize and populate the database with plant data
class DatabaseInitService {
  final DatabaseService _databaseService;

  DatabaseInitService(this._databaseService);

  /// Initialize database with all medicinal plants data
  /// Should be called once during app first run
  /// Also checks for and adds any missing plants
  Future<void> initializeDatabase() async {
    try {
      // Get all expected plants from PlantDataService
      final expectedPlants = PlantDataService.getAllMedicinalPlantsData();
      final expectedPlantIds = expectedPlants.map((p) => p.id).toSet();

      // Check existing plants in database
      final existingPlants = await _databaseService.getAllPlants();
      final existingPlantIds = existingPlants.map((p) => p.id).toSet();

      if (existingPlants.isEmpty) {
        // First time initialization - insert all plants
        print('Initializing database with medicinal plants...');
        for (var plant in expectedPlants) {
          await _insertPlantWithRelations(plant);
        }
        print(
            'Successfully populated database with ${expectedPlants.length} medicinal plants');
      } else {
        // Check for missing plants and add them
        final missingPlantIds = expectedPlantIds.difference(existingPlantIds);
        if (missingPlantIds.isNotEmpty) {
          print(
              'Found ${missingPlantIds.length} missing plants. Adding them to database...');
          for (var plant in expectedPlants) {
            if (missingPlantIds.contains(plant.id)) {
              await _insertPlantWithRelations(plant);
              print('Added missing plant: ${plant.commonName}');
            }
          }
          print('Successfully added ${missingPlantIds.length} missing plants');
        } else {
          print(
              'Database already populated with ${existingPlants.length} plants (all expected plants present)');
        }
      }
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  /// Re-populate database (useful for updates or testing)
  Future<void> repopulateDatabase() async {
    try {
      print('Clearing existing data...');
      await _databaseService.deleteDatabase();

      // Reinitialize database
      await Future.delayed(
          Duration(milliseconds: 500)); // Give time for deletion
      await initializeDatabase();

      print('Database repopulated successfully');
    } catch (e) {
      print('Error repopulating database: $e');
      rethrow;
    }
  }

  /// Insert plant with all its related data (medicinal uses, preparation methods)
  Future<void> _insertPlantWithRelations(Plant plant) async {
    final db = await _databaseService.database;

    // Start transaction to ensure all related data is inserted together
    await db.transaction((txn) async {
      // Insert main plant record
      await txn.insert('plants', {
        'id': plant.id,
        'common_name': plant.commonName,
        'scientific_name': plant.scientificName,
        'local_name': plant.localName,
        'english_name': plant.englishName,
        'family': plant.family,
        'genus': plant.genus,
        'species': plant.species,
        'is_doh_approved': plant.isDOHApproved ? 1 : 0,
        'morphology': plant.morphology,
        'ecology': plant.ecology,
        'habitat': plant.habitat,
        'image_path': plant.imagePath,
        'created_at': plant.createdAt.toIso8601String(),
        'updated_at': plant.updatedAt.toIso8601String(),
      });

      // Insert medicinal uses
      for (var use in plant.medicinalUses) {
        await txn.insert('medicinal_uses', {
          'plant_id': plant.id,
          'condition': use.condition,
          'description': use.description,
          'effectiveness': use.effectiveness,
          'active_compounds': use.activeCompounds.join(','),
          'dosage': use.dosage,
          'duration': use.duration,
        });
      }

      // Insert preparation methods
      for (var method in plant.preparationMethods) {
        await txn.insert('preparation_methods', {
          'id': method.id,
          'plant_id': plant.id,
          'condition': method.condition,
          'title': method.title,
          'description': method.description,
          'steps': method.steps.join('|'),
          'dosage': method.dosage,
          'frequency': method.frequency,
          'duration': method.duration,
          'warnings': method.warnings.join('|'),
          'preparation_type': method.preparationType,
        });
      }
    });

    print('Inserted plant: ${plant.commonName} (${plant.scientificName})');
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final plants = await _databaseService.getAllPlants();
    final dohPlants = await _databaseService.getDOHApprovedPlants();

    int totalMedicinalUses = 0;
    int totalPreparationMethods = 0;

    for (var plant in plants) {
      totalMedicinalUses += plant.medicinalUses.length;
      totalPreparationMethods += plant.preparationMethods.length;
    }

    return {
      'total_plants': plants.length,
      'doh_approved_plants': dohPlants.length,
      'total_medicinal_uses': totalMedicinalUses,
      'total_preparation_methods': totalPreparationMethods,
    };
  }

  /// Check if database needs initialization
  Future<bool> needsInitialization() async {
    try {
      final plants = await _databaseService.getAllPlants();
      return plants.isEmpty;
    } catch (e) {
      return true; // If error, assume needs initialization
    }
  }

  /// Check and update database with any missing plants
  /// Also updates image paths for existing plants
  /// Useful for adding new plants after app updates
  Future<void> updateDatabaseWithMissingPlants() async {
    try {
      print('🔍 Checking for missing plants and updating image paths...');
      // Get all expected plants from PlantDataService
      final expectedPlants = PlantDataService.getAllMedicinalPlantsData();
      final expectedPlantIds = expectedPlants.map((p) => p.id).toSet();
      print('📋 Expected plants: ${expectedPlants.length} (IDs: ${expectedPlantIds.join(", ")})');

      // Check existing plants in database
      final existingPlants = await _databaseService.getAllPlants();
      final existingPlantIds = existingPlants.map((p) => p.id).toSet();
      print('💾 Existing plants in database: ${existingPlants.length} (IDs: ${existingPlantIds.join(", ")})');

      // Find missing plants
      final missingPlantIds = expectedPlantIds.difference(existingPlantIds);
      print('❌ Missing plants: ${missingPlantIds.length} (IDs: ${missingPlantIds.join(", ")})');
      
      // Update image paths and english names for existing plants
      final db = await _databaseService.database;
      int updatedCount = 0;
      for (var expectedPlant in expectedPlants) {
        if (existingPlantIds.contains(expectedPlant.id)) {
          // Check if image path or english name needs updating
          final existingPlant = existingPlants.firstWhere((p) => p.id == expectedPlant.id);
          bool needsUpdate = false;
          Map<String, dynamic> updateData = {};
          
          if (existingPlant.imagePath != expectedPlant.imagePath) {
            updateData['image_path'] = expectedPlant.imagePath;
            needsUpdate = true;
          }
          if (existingPlant.englishName != expectedPlant.englishName) {
            updateData['english_name'] = expectedPlant.englishName;
            needsUpdate = true;
          }
          
          if (needsUpdate) {
            updateData['updated_at'] = DateTime.now().toIso8601String();
            await db.update(
              'plants',
              updateData,
              where: 'id = ?',
              whereArgs: [expectedPlant.id],
            );
            updatedCount++;
            print('🔄 Updated ${expectedPlant.commonName}: ${updateData.keys.join(", ")}');
          }
        }
      }
      if (updatedCount > 0) {
        print('✅ Updated $updatedCount plants');
      }
      
      if (missingPlantIds.isNotEmpty) {
        print(
            '➕ Found ${missingPlantIds.length} missing plants. Adding them to database...');
        for (var plant in expectedPlants) {
          if (missingPlantIds.contains(plant.id)) {
            await _insertPlantWithRelations(plant);
            print('✅ Added missing plant: ${plant.commonName} (${plant.scientificName})');
          }
        }
        print('✅ Successfully added ${missingPlantIds.length} missing plants');
      } else {
        print('✅ All expected plants are already in the database');
      }
    } catch (e) {
      print('❌ Error updating database with missing plants: $e');
      rethrow;
    }
  }
}
