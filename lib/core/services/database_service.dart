import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/scan_result.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'herbascan.db';
  static const int _databaseVersion = 1;

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
    await db.execute('CREATE INDEX idx_plants_doh ON $_plantsTable (is_doh_approved)');
    await db.execute('CREATE INDEX idx_scan_history_date ON $_scanHistoryTable (scan_date)');
    await db.execute('CREATE INDEX idx_medicinal_uses_plant ON $_medicinalUsesTable (plant_id)');
    await db.execute('CREATE INDEX idx_preparation_methods_plant ON $_preparationMethodsTable (plant_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Example: Add new columns or tables
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
    
    final medicinalUses = medicinalUsesMaps.map((useMap) => MedicinalUse(
      condition: useMap['condition'] as String,
      description: useMap['description'] as String,
      effectiveness: useMap['effectiveness'] as String,
      activeCompounds: (useMap['active_compounds'] as String).split(','),
      dosage: useMap['dosage'] as String,
      duration: useMap['duration'] as String,
    )).toList();

    // Get preparation methods
    final preparationMethodsMaps = await db.query(
      _preparationMethodsTable,
      where: 'plant_id = ?',
      whereArgs: [map['id']],
    );
    
    final preparationMethods = preparationMethodsMaps.map((methodMap) => PreparationMethod(
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
    )).toList();

    return Plant(
      id: map['id'],
      commonName: map['common_name'],
      scientificName: map['scientific_name'],
      localName: map['local_name'],
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
    await db.insert(_scanHistoryTable, {
      'id': result.id,
      'plant_id': result.plant?.id,
      'confidence_score': result.confidenceScore,
      'predictions': result.predictions.map((p) => p.toJson()).toList().toString(),
      'image_path': result.imagePath,
      'scan_date': result.scanDate.toIso8601String(),
      'grad_cam_path': result.gradCAMPath,
      'metadata': result.metadata.toString(),
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

    // Parse predictions (simplified for now)
    final predictions = <Prediction>[];

    return ScanResult(
      id: map['id'],
      plant: plant,
      confidenceScore: map['confidence_score'],
      predictions: predictions,
      imagePath: map['image_path'],
      scanDate: DateTime.parse(map['scan_date']),
      gradCAMPath: map['grad_cam_path'],
      metadata: {}, // TODO: Parse metadata
      isOfflineScan: map['is_offline_scan'] == 1,
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
