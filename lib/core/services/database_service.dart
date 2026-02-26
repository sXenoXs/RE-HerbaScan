import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/scan_result.dart';

/// Local SQLite DB for plants and scan history. Catalog rule: plant catalog is 1-to-1
/// with ML model classes; do not add or delete plants dynamically (admin may only edit text).
class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'herbascan.db';
  static const int _databaseVersion = 3;

  // Table names
  static const String _plantsTable = 'plants';
  static const String _scanHistoryTable = 'scan_history';
  static const String _medicinalUsesTable = 'medicinal_uses';
  static const String _preparationMethodsTable = 'preparation_methods';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create plants table
    await db.execute('''
      CREATE TABLE $_plantsTable (
        id TEXT PRIMARY KEY,
        common_name TEXT NOT NULL,
        scientific_name TEXT NOT NULL,
        local_name TEXT NOT NULL,
        english_name TEXT NOT NULL DEFAULT '',
        family TEXT NOT NULL,
        genus TEXT NOT NULL,
        species TEXT NOT NULL,
        is_doh_approved INTEGER NOT NULL DEFAULT 0,
        morphology TEXT NOT NULL,
        ecology TEXT NOT NULL,
        habitat TEXT NOT NULL,
        image_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create medicinal uses table
    await db.execute('''
      CREATE TABLE $_medicinalUsesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id TEXT NOT NULL,
        condition TEXT NOT NULL,
        description TEXT NOT NULL,
        effectiveness TEXT NOT NULL,
        active_compounds TEXT NOT NULL,
        dosage TEXT NOT NULL,
        duration TEXT NOT NULL,
        FOREIGN KEY (plant_id) REFERENCES $_plantsTable (id)
      )
    ''');

    // Create preparation methods table
    await db.execute('''
      CREATE TABLE $_preparationMethodsTable (
        id TEXT PRIMARY KEY,
        plant_id TEXT NOT NULL,
        condition TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        steps TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        duration TEXT NOT NULL,
        warnings TEXT NOT NULL,
        preparation_type TEXT NOT NULL,
        step_details_json TEXT,
        schedule_json TEXT,
        FOREIGN KEY (plant_id) REFERENCES $_plantsTable (id)
      )
    ''');

    // Create scan history table
    await db.execute('''
      CREATE TABLE $_scanHistoryTable (
        id TEXT PRIMARY KEY,
        plant_id TEXT,
        confidence_score REAL NOT NULL,
        predictions TEXT NOT NULL,
        image_path TEXT NOT NULL,
        scan_date TEXT NOT NULL,
        grad_cam_path TEXT,
        metadata TEXT NOT NULL,
        is_offline_scan INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (plant_id) REFERENCES $_plantsTable (id)
      )
    ''');

    // Create indexes
    await db.execute(
        'CREATE INDEX idx_plants_doh ON $_plantsTable (is_doh_approved)');
    await db.execute(
        'CREATE INDEX idx_scan_history_date ON $_scanHistoryTable (scan_date)');
    await db.execute(
        'CREATE INDEX idx_medicinal_uses_plant ON $_medicinalUsesTable (plant_id)');
    await db.execute(
        'CREATE INDEX idx_preparation_methods_plant ON $_preparationMethodsTable (plant_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Add english_name column to plants table
      try {
        await db.execute(
            'ALTER TABLE $_plantsTable ADD COLUMN english_name TEXT NOT NULL DEFAULT ""');
        print('✅ Added english_name column to plants table');
      } catch (e) {
        // Column might already exist
        print('ℹ️ english_name column may already exist: $e');
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
            'ALTER TABLE $_preparationMethodsTable ADD COLUMN step_details_json TEXT');
        await db.execute(
            'ALTER TABLE $_preparationMethodsTable ADD COLUMN schedule_json TEXT');
        print('✅ Added step_details_json and schedule_json to preparation_methods');
      } catch (e) {
        print('ℹ️ preparation_methods columns may already exist: $e');
      }
    }
  }

  // Plant operations
  Future<void> insertPlant(Plant plant) async {
    final db = await database;
    await db.insert(_plantsTable, plant.toJson());
  }

  Future<List<Plant>> getAllPlants() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_plantsTable);

    List<Plant> plants = [];
    for (var map in maps) {
      final plant = await _mapToPlant(map);
      plants.add(plant);
    }

    return plants;
  }

  Future<Plant?> getPlantById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _plantsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return await _mapToPlant(maps.first);
    }
    return null;
  }

  Future<List<Plant>> getDOHApprovedPlants() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _plantsTable,
      where: 'is_doh_approved = ?',
      whereArgs: [1],
    );

    List<Plant> plants = [];
    for (var map in maps) {
      final plant = await _mapToPlant(map);
      plants.add(plant);
    }

    return plants;
  }

  Future<Plant> _mapToPlant(Map<String, dynamic> map) async {
    final db = await database;

    // Get medicinal uses
    final medicinalUsesMaps = await db.query(
      _medicinalUsesTable,
      where: 'plant_id = ?',
      whereArgs: [map['id']],
    );

    final medicinalUses = medicinalUsesMaps
        .map((useMap) => MedicinalUse(
              condition: useMap['condition'] as String,
              description: useMap['description'] as String,
              effectiveness: useMap['effectiveness'] as String,
              activeCompounds:
                  (useMap['active_compounds'] as String).split(','),
              dosage: useMap['dosage'] as String,
              duration: useMap['duration'] as String,
            ))
        .toList();

    // Get preparation methods
    final preparationMethodsMaps = await db.query(
      _preparationMethodsTable,
      where: 'plant_id = ?',
      whereArgs: [map['id']],
    );

    final preparationMethods = preparationMethodsMaps
        .map((methodMap) {
          List<PreparationStepDetail>? stepDetails;
          final stepDetailsJson = methodMap['step_details_json'] as String?;
          if (stepDetailsJson != null && stepDetailsJson.isNotEmpty) {
            try {
              final list = jsonDecode(stepDetailsJson) as List<dynamic>?;
              if (list != null) {
                stepDetails = list
                    .map((e) => PreparationStepDetail.fromJson(e as Map<String, dynamic>))
                    .toList();
              }
            } catch (_) {}
          }
          PreparationSchedule? schedule;
          final scheduleJson = methodMap['schedule_json'] as String?;
          if (scheduleJson != null && scheduleJson.isNotEmpty) {
            try {
              schedule = PreparationSchedule.fromJson(jsonDecode(scheduleJson) as Map<String, dynamic>);
            } catch (_) {}
          }
          return PreparationMethod(
            id: methodMap['id'] as String,
            condition: methodMap['condition'] as String,
            title: methodMap['title'] as String,
            description: methodMap['description'] as String,
            steps: (methodMap['steps'] as String).split('|'),
            dosage: methodMap['dosage'] as String,
            frequency: methodMap['frequency'] as String,
            duration: methodMap['duration'] as String,
            warnings: (methodMap['warnings'] as String).split('|'),
            preparationType: methodMap['preparation_type'] as String,
            stepDetails: stepDetails,
            schedule: schedule,
          );
        })
        .toList();

    return Plant(
      id: map['id'],
      commonName: map['common_name'],
      scientificName: map['scientific_name'],
      localName: map['local_name'],
      englishName: map['english_name'] ?? '',
      family: map['family'],
      genus: map['genus'],
      species: map['species'],
      isDOHApproved: map['is_doh_approved'] == 1,
      morphology: map['morphology'],
      ecology: map['ecology'],
      habitat: map['habitat'],
      medicinalUses: medicinalUses,
      preparationMethods: preparationMethods,
      safetyWarnings: [], // TODO: Add safety warnings table
      imagePath: map['image_path'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  // Scan history operations
  Future<void> saveScanResult(ScanResult result) async {
    final db = await database;

    // Properly serialize predictions and metadata as JSON strings
    final predictionsJson = jsonEncode(
      result.predictions.map((p) => p.toJson()).toList(),
    );
    final metadataJson = jsonEncode(result.metadata);

    await db.insert(_scanHistoryTable, {
      'id': result.id,
      'plant_id': result.plant?.id,
      'confidence_score': result.confidenceScore,
      'predictions': predictionsJson,
      'image_path': result.imagePath,
      'scan_date': result.scanDate.toIso8601String(),
      'grad_cam_path': result.gradCAMPath,
      'metadata': metadataJson,
      'is_offline_scan': result.isOfflineScan ? 1 : 0,
    });
  }

  Future<List<ScanResult>> getScanHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _scanHistoryTable,
      orderBy: 'scan_date DESC',
    );

    List<ScanResult> results = [];
    for (var map in maps) {
      final result = await _mapToScanResult(map);
      results.add(result);
    }

    return results;
  }

  Future<ScanResult> _mapToScanResult(Map<String, dynamic> map) async {
    Plant? plant;
    if (map['plant_id'] != null) {
      plant = await getPlantById(map['plant_id']);
    }

    // Parse predictions from JSON string
    List<Prediction> predictions = [];
    try {
      if (map['predictions'] != null &&
          map['predictions'].toString().isNotEmpty) {
        final predictionsJson = jsonDecode(map['predictions'] as String);
        if (predictionsJson is List) {
          predictions = predictionsJson
              .map((json) => Prediction.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      print('⚠️ Error parsing predictions: $e');
      predictions = [];
    }

    // Parse metadata from JSON string
    Map<String, dynamic> metadata = {};
    try {
      if (map['metadata'] != null && map['metadata'].toString().isNotEmpty) {
        final metadataJson = jsonDecode(map['metadata'] as String);
        if (metadataJson is Map) {
          metadata = Map<String, dynamic>.from(metadataJson);
        }
      }
    } catch (e) {
      print('⚠️ Error parsing metadata: $e');
      metadata = {};
    }

    // summaryGradCAMPath is stored in metadata, so it's already parsed above

    return ScanResult(
      id: map['id'],
      plant: plant,
      confidenceScore: map['confidence_score'] as double,
      predictions: predictions,
      imagePath: map['image_path'] as String,
      scanDate: DateTime.parse(map['scan_date'] as String),
      gradCAMPath: map['grad_cam_path'] as String?,
      metadata: metadata,
      isOfflineScan: (map['is_offline_scan'] as int?) == 1,
    );
  }

  Future<void> deleteScanResult(String resultId) async {
    final db = await database;
    await db.delete(
      _scanHistoryTable,
      where: 'id = ?',
      whereArgs: [resultId],
    );
  }

  Future<void> clearScanHistory() async {
    final db = await database;
    await db.delete(_scanHistoryTable);
  }

  // Utility methods
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
  }
}
