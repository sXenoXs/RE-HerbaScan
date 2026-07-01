import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:herbascan/core/models/catalog_condition.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_habitat.dart';
import 'package:herbascan/core/models/safety_profile.dart';
import 'package:herbascan/core/models/scan_result.dart';

/// Local SQLite DB for plants and scan history. Catalog rule: plant catalog is 1-to-1
/// with ML model classes; do not add or delete plants dynamically (admin may only edit text).
class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'herbascan.db';
  static const int _databaseVersion = 9;

  // Table names
  static const String _plantsTable = 'plants';
  static const String _scanHistoryTable = 'scan_history';
  static const String _medicinalUsesTable = 'medicinal_uses';
  static const String _preparationMethodsTable = 'preparation_methods';
  static const String _safetyProfilesTable = 'safety_profiles';
  static const String _plantHabitatsTable = 'plant_habitats';
  static const String _conditionsTable = 'catalog_conditions';
  static const String _conditionPlantsTable = 'catalog_condition_plants';
  static const String _anatomyTable = 'catalog_plant_anatomy';

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
      onOpen: _ensureCatalogTablesExist,
    );
  }

  /// Ensures catalog_conditions, catalog_condition_plants, and catalog_plant_anatomy exist.
  /// Runs on every open so DBs created before these tables were added get them without a version bump.
  Future<void> _ensureCatalogTablesExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_conditionsTable (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL DEFAULT 'healing',
        color_hex TEXT NOT NULL DEFAULT 'FF6366F1',
        is_default INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_conditionPlantsTable (
        condition_id INTEGER NOT NULL,
        plant_id TEXT NOT NULL,
        PRIMARY KEY (condition_id, plant_id),
        FOREIGN KEY (plant_id) REFERENCES $_plantsTable (id)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_condition_plants_plant ON $_conditionPlantsTable (plant_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_anatomyTable (
        id TEXT PRIMARY KEY,
        plant_id TEXT NOT NULL,
        part_name TEXT NOT NULL DEFAULT '',
        svg_path TEXT NOT NULL DEFAULT '',
        color_hex TEXT NOT NULL DEFAULT '4CAF50',
        z_index INTEGER NOT NULL DEFAULT 0,
        is_interactive INTEGER NOT NULL DEFAULT 1,
        title TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        conditions TEXT NOT NULL DEFAULT '[]'
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_catalog_plant_anatomy_plant_id ON $_anatomyTable (plant_id)');
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
        "references" TEXT NOT NULL DEFAULT '[]',
        image_path TEXT NOT NULL,
        image_url TEXT,
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

    // Create safety_profiles table (synced from catalog_safety)
    await db.execute('''
      CREATE TABLE $_safetyProfilesTable (
        plant_id TEXT PRIMARY KEY,
        is_generally_safe INTEGER NOT NULL DEFAULT 1,
        pregnancy_warning INTEGER NOT NULL DEFAULT 0,
        known_side_effects TEXT NOT NULL DEFAULT '[]',
        drug_interactions TEXT NOT NULL DEFAULT '[]',
        strict_contraindications TEXT NOT NULL DEFAULT '[]',
        needs_strict_contraindications INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_safety_profiles_plant ON $_safetyProfilesTable (plant_id)');

    // Create plant_habitats table (synced from catalog_habitat)
    await db.execute('''
      CREATE TABLE $_plantHabitatsTable (
        plant_id TEXT PRIMARY KEY,
        known_coordinates TEXT NOT NULL DEFAULT '[]',
        region_names TEXT NOT NULL DEFAULT '[]',
        climate_notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_plant_habitats_plant ON $_plantHabitatsTable (plant_id)');

    // Create indexes
    await db.execute(
        'CREATE INDEX idx_plants_doh ON $_plantsTable (is_doh_approved)');
    await db.execute(
        'CREATE INDEX idx_scan_history_date ON $_scanHistoryTable (scan_date)');
    await db.execute(
        'CREATE INDEX idx_medicinal_uses_plant ON $_medicinalUsesTable (plant_id)');
    await db.execute(
        'CREATE INDEX idx_preparation_methods_plant ON $_preparationMethodsTable (plant_id)');

    // catalog_conditions and catalog_condition_plants (v6)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_conditionsTable (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL DEFAULT 'healing',
        color_hex TEXT NOT NULL DEFAULT 'FF6366F1',
        is_default INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_conditionPlantsTable (
        condition_id INTEGER NOT NULL,
        plant_id TEXT NOT NULL,
        PRIMARY KEY (condition_id, plant_id),
        FOREIGN KEY (plant_id) REFERENCES $_plantsTable (id)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_condition_plants_plant ON $_conditionPlantsTable (plant_id)');

    // catalog_plant_anatomy (v7)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_anatomyTable (
        id TEXT PRIMARY KEY,
        plant_id TEXT NOT NULL,
        part_name TEXT NOT NULL DEFAULT '',
        svg_path TEXT NOT NULL DEFAULT '',
        color_hex TEXT NOT NULL DEFAULT '4CAF50',
        z_index INTEGER NOT NULL DEFAULT 0,
        is_interactive INTEGER NOT NULL DEFAULT 1,
        title TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        conditions TEXT NOT NULL DEFAULT '[]'
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_catalog_plant_anatomy_plant_id ON $_anatomyTable (plant_id)');
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
        print(
            '✅ Added step_details_json and schedule_json to preparation_methods');
      } catch (e) {
        print('ℹ️ preparation_methods columns may already exist: $e');
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE $_plantsTable ADD COLUMN image_url TEXT');
        print('✅ Added image_url to plants table');
      } catch (e) {
        print('ℹ️ image_url column may already exist: $e');
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_safetyProfilesTable (
            plant_id TEXT PRIMARY KEY,
            is_generally_safe INTEGER NOT NULL DEFAULT 1,
            pregnancy_warning INTEGER NOT NULL DEFAULT 0,
            known_side_effects TEXT NOT NULL DEFAULT '[]',
            drug_interactions TEXT NOT NULL DEFAULT '[]',
            strict_contraindications TEXT NOT NULL DEFAULT '[]',
            needs_strict_contraindications INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_safety_profiles_plant ON $_safetyProfilesTable (plant_id)');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_plantHabitatsTable (
            plant_id TEXT PRIMARY KEY,
            known_coordinates TEXT NOT NULL DEFAULT '[]',
            region_names TEXT NOT NULL DEFAULT '[]',
            climate_notes TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_plant_habitats_plant ON $_plantHabitatsTable (plant_id)');
        print('✅ Added safety_profiles and plant_habitats tables');
      } catch (e) {
        print('ℹ️ safety_profiles/plant_habitats may already exist: $e');
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_conditionsTable (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            icon_key TEXT NOT NULL DEFAULT 'healing',
            color_hex TEXT NOT NULL DEFAULT 'FF6366F1',
            is_default INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_conditionPlantsTable (
            condition_id INTEGER NOT NULL,
            plant_id TEXT NOT NULL,
            PRIMARY KEY (condition_id, plant_id),
            FOREIGN KEY (plant_id) REFERENCES $_plantsTable (id)
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_condition_plants_plant ON $_conditionPlantsTable (plant_id)');
        print('✅ Added catalog_conditions and catalog_condition_plants tables');
      } catch (e) {
        print('ℹ️ catalog_conditions/condition_plants may already exist: $e');
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_anatomyTable (
            id TEXT PRIMARY KEY,
            plant_id TEXT NOT NULL,
            part_name TEXT NOT NULL DEFAULT '',
            svg_path TEXT NOT NULL DEFAULT '',
            color_hex TEXT NOT NULL DEFAULT '4CAF50',
            z_index INTEGER NOT NULL DEFAULT 0,
            is_interactive INTEGER NOT NULL DEFAULT 1,
            title TEXT NOT NULL DEFAULT '',
            description TEXT NOT NULL DEFAULT '',
            conditions TEXT NOT NULL DEFAULT '[]'
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_catalog_plant_anatomy_plant_id ON $_anatomyTable (plant_id)');
        print('✅ Added catalog_plant_anatomy table');
      } catch (e) {
        print('ℹ️ catalog_plant_anatomy may already exist: $e');
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute(
            'ALTER TABLE $_safetyProfilesTable ADD COLUMN needs_strict_contraindications INTEGER NOT NULL DEFAULT 0');
        print('✅ Added needs_strict_contraindications to safety_profiles');
      } catch (e) {
        print('ℹ️ needs_strict_contraindications may already exist: $e');
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
            'ALTER TABLE $_plantsTable ADD COLUMN "references" TEXT NOT NULL DEFAULT "[]"');
        print('✅ Added references to plants');
      } catch (e) {
        print('ℹ️ references may already exist: $e');
      }
    }
  }

  // Plant operations
  Future<void> insertPlant(Plant plant) async {
    final db = await database;
    await db.insert(_plantsTable, _plantToRow(plant));
  }

  /// Converts Plant to a row map with snake_case keys for DB.
  Map<String, dynamic> _plantToRow(Plant plant) {
    return {
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
      'references': jsonEncode(plant.references),
      'image_path': plant.imagePath,
      'image_url': plant.imageUrl,
      'created_at': plant.createdAt.toIso8601String(),
      'updated_at': plant.updatedAt.toIso8601String(),
    };
  }

  Future<void> deleteMedicinalUsesForPlant(String plantId) async {
    final db = await database;
    await db.delete(
      _medicinalUsesTable,
      where: 'plant_id = ?',
      whereArgs: [plantId],
    );
  }

  Future<void> deletePreparationMethodsForPlant(String plantId) async {
    final db = await database;
    await db.delete(
      _preparationMethodsTable,
      where: 'plant_id = ?',
      whereArgs: [plantId],
    );
  }

  /// Replaces a plant and its relations (for sync from Supabase).
  Future<void> replacePlantFromSync(Plant plant) async {
    final db = await database;
    await db.transaction((txn) async {
      final row = _plantToRow(plant);
      final count = await txn.update(
        _plantsTable,
        row,
        where: 'id = ?',
        whereArgs: [plant.id],
      );
      if (count == 0) {
        await txn.insert(_plantsTable, row);
      }
      await txn.delete(
        _medicinalUsesTable,
        where: 'plant_id = ?',
        whereArgs: [plant.id],
      );
      await txn.delete(
        _preparationMethodsTable,
        where: 'plant_id = ?',
        whereArgs: [plant.id],
      );
      for (var use in plant.medicinalUses) {
        await txn.insert(_medicinalUsesTable, {
          'plant_id': plant.id,
          'condition': use.condition,
          'description': use.description,
          'effectiveness': use.effectiveness,
          'active_compounds': use.activeCompounds.join(','),
          'dosage': use.dosage,
          'duration': use.duration,
        });
      }
      for (var method in plant.preparationMethods) {
        final map = <String, dynamic>{
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
        };
        if (method.stepDetails != null && method.stepDetails!.isNotEmpty) {
          map['step_details_json'] =
              jsonEncode(method.stepDetails!.map((s) => s.toJson()).toList());
        }
        if (method.schedule != null) {
          map['schedule_json'] = jsonEncode(method.schedule!.toJson());
        }
        await txn.insert(_preparationMethodsTable, map);
      }
    });
  }

  /// Replaces safety profile for a plant (for sync from catalog_safety).
  Future<void> replaceSafetyFromSync(SafetyProfile profile) async {
    final db = await database;
    final row = {
      'plant_id': profile.plantId,
      'is_generally_safe': profile.isGenerallySafe ? 1 : 0,
      'pregnancy_warning': profile.pregnancyWarning ? 1 : 0,
      'known_side_effects': jsonEncode(profile.knownSideEffects),
      'drug_interactions': jsonEncode(profile.drugInteractions),
      'strict_contraindications': jsonEncode(profile.strictContraindications),
      'needs_strict_contraindications': profile.needsStrictContraindications ? 1 : 0,
    };
    await db.insert(
      _safetyProfilesTable,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Replaces habitat for a plant (for sync from catalog_habitat).
  Future<void> replaceHabitatFromSync(PlantHabitat habitat) async {
    final db = await database;
    final row = {
      'plant_id': habitat.plantId,
      'known_coordinates':
          jsonEncode(habitat.knownCoordinates.map((e) => e.toJson()).toList()),
      'region_names': jsonEncode(habitat.regionNames),
      'climate_notes': habitat.climateNotes,
    };
    await db.insert(
      _plantHabitatsTable,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns safety profile from local DB (synced from Supabase), or null if not present.
  Future<SafetyProfile?> getSafetyProfile(String plantId) async {
    final db = await database;
    final maps = await db.query(
      _safetyProfilesTable,
      where: 'plant_id = ?',
      whereArgs: [plantId],
    );
    if (maps.isEmpty) return null;
    return _rowToSafetyProfile(maps.first);
  }

  /// Returns plant habitat from local DB (synced from Supabase), or null if not present.
  Future<PlantHabitat?> getPlantHabitat(String plantId) async {
    final db = await database;
    final maps = await db.query(
      _plantHabitatsTable,
      where: 'plant_id = ?',
      whereArgs: [plantId],
    );
    if (maps.isEmpty) return null;
    return _rowToPlantHabitat(maps.first);
  }

  /// Replaces all conditions (for sync from catalog_conditions).
  Future<void> replaceConditionsFromSync(
      List<CatalogCondition> conditions) async {
    final db = await database;
    await db.delete(_conditionsTable);
    for (var c in conditions) {
      await db.insert(_conditionsTable, {
        'id': c.id,
        'name': c.name,
        'icon_key': c.iconKey,
        'color_hex': c.colorHex,
        'is_default': c.isDefault ? 1 : 0,
        'sort_order': c.sortOrder,
      });
    }
  }

  /// Replaces all condition–plant links (for sync from catalog_condition_plants).
  Future<void> replaceConditionPlantsFromSync(
      List<MapEntry<int, String>> pairs) async {
    final db = await database;
    await db.delete(_conditionPlantsTable);
    for (var e in pairs) {
      await db.insert(_conditionPlantsTable, {
        'condition_id': e.key,
        'plant_id': e.value,
      });
    }
  }

  /// Returns all conditions from local DB (synced from Supabase), ordered by sort_order.
  Future<List<CatalogCondition>> getConditions() async {
    final db = await database;
    final maps =
        await db.query(_conditionsTable, orderBy: 'sort_order ASC, id ASC');
    return maps.map((row) => CatalogCondition.fromRow(row)).toList();
  }

  /// Returns plant_ids linked to a condition (from catalog_condition_plants).
  Future<List<String>> getPlantIdsForCondition(int conditionId) async {
    final db = await database;
    final maps = await db.query(
      _conditionPlantsTable,
      where: 'condition_id = ?',
      whereArgs: [conditionId],
      columns: ['plant_id'],
    );
    return maps.map((m) => m['plant_id'] as String).toList();
  }

  /// Replaces all plant anatomy rows (for sync from catalog_plant_anatomy). Full replace.
  Future<void> replaceAnatomyFromSync(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_anatomyTable);
      for (var row in rows) {
        await txn.insert(_anatomyTable, _anatomyRowToInsert(row));
      }
    });
  }

  /// Replaces anatomy rows for a single plant (for admin instant sync after edit). Deletes existing for plant_id then inserts.
  Future<void> replaceAnatomyForPlantFromSync(String plantId, List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_anatomyTable, where: 'plant_id = ?', whereArgs: [plantId]);
      for (var row in rows) {
        final insertRow = Map<String, dynamic>.from(_anatomyRowToInsert(row));
        insertRow['plant_id'] = plantId;
        await txn.insert(_anatomyTable, insertRow);
      }
    });
  }

  static Map<String, dynamic> _anatomyRowToInsert(Map<String, dynamic> row) {
    return {
      'id': row['id'] as String? ?? '',
      'plant_id': row['plant_id'] as String? ?? '',
      'part_name': row['part_name'] as String? ?? '',
      'svg_path': row['svg_path'] as String? ?? '',
      'color_hex': row['color_hex'] as String? ?? '4CAF50',
      'z_index': row['z_index'] is int
          ? row['z_index'] as int
          : int.tryParse(row['z_index'].toString()) ?? 0,
      'is_interactive':
          row['is_interactive'] == true || row['is_interactive'] == 1
              ? 1
              : 0,
      'title': row['title'] as String? ?? '',
      'description': row['description'] as String? ?? '',
      'conditions': row['conditions'] is String
          ? row['conditions'] as String
          : jsonEncode(row['conditions'] ?? []),
    };
  }

  /// Returns anatomy parts for a plant from local DB (synced from Supabase), ordered by z_index.
  Future<List<Map<String, dynamic>>> getAnatomyForPlant(String plantId) async {
    final db = await database;
    return db.query(
      _anatomyTable,
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'z_index ASC',
    );
  }

  static SafetyProfile _rowToSafetyProfile(Map<String, dynamic> row) {
    List<String> list(String s) {
      if (s.isEmpty || s == '[]') return <String>[];
      try {
        final decoded = jsonDecode(s) as List<dynamic>?;
        return decoded?.map((e) => e.toString()).toList() ?? [];
      } catch (_) {
        return <String>[];
      }
    }

    final strictRaw = row['needs_strict_contraindications'];
    final needsStrict = strictRaw == 1 ||
        strictRaw == true ||
        (strictRaw is String && strictRaw == '1');
    return SafetyProfile(
      plantId: row['plant_id'] as String? ?? '',
      name: '',
      isGenerallySafe: (row['is_generally_safe'] as int?) == 1,
      pregnancyWarning: (row['pregnancy_warning'] as int?) == 1,
      knownSideEffects: list(row['known_side_effects'] as String? ?? '[]'),
      drugInteractions: list(row['drug_interactions'] as String? ?? '[]'),
      strictContraindications:
          list(row['strict_contraindications'] as String? ?? '[]'),
      needsStrictContraindications: needsStrict,
    );
  }

  static PlantHabitat _rowToPlantHabitat(Map<String, dynamic> row) {
    List<HabitatPoint> coords = [];
    try {
      final s = row['known_coordinates'] as String? ?? '[]';
      if (s.isNotEmpty && s != '[]') {
        final decoded = jsonDecode(s) as List<dynamic>?;
        if (decoded != null) {
          coords = decoded
              .map((e) => HabitatPoint.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    List<String> regions = [];
    try {
      final s = row['region_names'] as String? ?? '[]';
      if (s.isNotEmpty && s != '[]') {
        final decoded = jsonDecode(s) as List<dynamic>?;
        regions = decoded?.map((e) => e.toString()).toList() ?? [];
      }
    } catch (_) {}
    return PlantHabitat(
      plantId: row['plant_id'] as String? ?? '',
      knownCoordinates: coords,
      regionNames: regions,
      climateNotes: row['climate_notes'] as String? ?? '',
    );
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

    final preparationMethods = preparationMethodsMaps.map((methodMap) {
      List<PreparationStepDetail>? stepDetails;
      final stepDetailsJson = methodMap['step_details_json'] as String?;
      if (stepDetailsJson != null && stepDetailsJson.isNotEmpty) {
        try {
          final list = jsonDecode(stepDetailsJson) as List<dynamic>?;
          if (list != null) {
            stepDetails = list
                .map((e) =>
                    PreparationStepDetail.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        } catch (_) {}
      }
      PreparationSchedule? schedule;
      final scheduleJson = methodMap['schedule_json'] as String?;
      if (scheduleJson != null && scheduleJson.isNotEmpty) {
        try {
          schedule = PreparationSchedule.fromJson(
              jsonDecode(scheduleJson) as Map<String, dynamic>);
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
    }).toList();

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
      safetyWarnings: [], // TODO: synced from Supabase or safety table
      references: (map['references'] != null && map['references'].toString().isNotEmpty)
          ? List<String>.from(jsonDecode(map['references']))
          : [],
      imagePath: map['image_path'],
      imageUrl: map['image_url'] as String?,
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

  /// Remove a plant and all its related rows from local SQLite.
  Future<void> deletePlantFromLocal(String plantId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_conditionPlantsTable, where: 'plant_id = ?', whereArgs: [plantId]);
      await txn.delete(_anatomyTable, where: 'plant_id = ?', whereArgs: [plantId]);
      await txn.delete(_safetyProfilesTable, where: 'plant_id = ?', whereArgs: [plantId]);
      await txn.delete(_plantHabitatsTable, where: 'plant_id = ?', whereArgs: [plantId]);
      await txn.delete(_medicinalUsesTable, where: 'plant_id = ?', whereArgs: [plantId]);
      await txn.delete(_preparationMethodsTable, where: 'plant_id = ?', whereArgs: [plantId]);
      await txn.delete(_plantsTable, where: 'id = ?', whereArgs: [plantId]);
    });
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
