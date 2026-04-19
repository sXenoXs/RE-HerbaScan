import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/plant_anatomy_part.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/services/plant_service.dart';
import 'package:herbascan/core/services/database_service.dart';
import 'package:herbascan/core/services/database_init_service.dart';
import 'package:herbascan/core/services/catalog_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';

class PlantProvider extends ChangeNotifier {
  final PlantService _plantService = PlantService();
  final DatabaseService _databaseService = DatabaseService();
  late final DatabaseInitService _databaseInitService;

  /// Supabase Realtime channel that listens for admin edits to catalog_plants.
  RealtimeChannel? _catalogChannel;

  List<Plant> _plants = [];
  List<ScanResult> _scanHistory = [];
  List<Plant> _dohApprovedPlants = [];
  List<Plant> _filteredPlants = [];
  Plant? _selectedPlant;
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedCondition = 'all';

  // Getters
  List<Plant> get plants => _plants;
  List<ScanResult> get scanHistory => _scanHistory;
  List<Plant> get dohApprovedPlants => _dohApprovedPlants;
  List<Plant> get filteredPlants => _filteredPlants;
  Plant? get selectedPlant => _selectedPlant;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedCondition => _selectedCondition;

  PlantProvider() {
    _databaseInitService = DatabaseInitService(_databaseService);
    _initializeData();
  }

  // Initialize data
  Future<void> _initializeData() async {
    // Initialize database with plant data on first run
    // This will also check for and add any missing plants
    try {
      await _databaseInitService.initializeDatabase();
      print('✅ Database initialized successfully');
    } catch (e) {
      print('❌ Error initializing database: $e');
    }

    // When online, sync catalog from Supabase (admin-editable master)
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final online = connectivity.any((c) =>
          c == ConnectivityResult.mobile || c == ConnectivityResult.wifi);
      if (online) {
        final synced = await CatalogSyncService().syncFromSupabase();
        if (synced) print('✅ Catalog synced from Supabase');
      }
    } catch (e) {
      print('ℹ️ Catalog sync skipped or failed: $e');
    }

    await loadPlants();
    await loadScanHistory();
    await loadDOHApprovedPlants();

    // Start listening for admin edits after the initial load is done.
    _subscribeToRealtimeUpdates();
  }

  // ---------------------------------------------------------------------------
  // Realtime catalog synchronization
  // ---------------------------------------------------------------------------

  /// Opens a Supabase Realtime channel that reacts to changes on catalog_plants
  /// and all related tables. Any admin edit — medicinal uses, preparation
  /// methods, safety, habitat, anatomy, conditions — triggers an immediate
  /// in-app update with no restart required.
  void _subscribeToRealtimeUpdates() {
    if (!isSupabaseConfigured) return;
    _catalogChannel?.unsubscribe();

    // Tables that carry a plant_id and require a single-plant re-sync.
    const plantRelatedTables = [
      'catalog_medicinal_uses',
      'catalog_preparation_methods',
      'catalog_safety',
      'catalog_habitat',
      'catalog_plant_anatomy',
      'catalog_condition_plants',
    ];

    var channel = Supabase.instance.client
        .channel('catalog_all_changes')
        // catalog_plants INSERT / UPDATE / DELETE
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'catalog_plants',
          callback: (payload) => _onCatalogPlantChanged(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'catalog_plants',
          callback: (payload) => _onCatalogPlantChanged(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'catalog_plants',
          callback: (payload) => _onCatalogPlantDeleted(payload.oldRecord),
        );

    // Related plant tables — re-sync the affected plant on any change.
    for (final table in plantRelatedTables) {
      channel = channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: table,
            callback: (payload) => _onRelatedTableChanged(payload.newRecord),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: table,
            callback: (payload) => _onRelatedTableChanged(payload.newRecord),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: table,
            callback: (payload) => _onRelatedTableChanged(payload.oldRecord),
          );
    }

    // catalog_conditions has no plant_id — sync the whole conditions table.
    channel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'catalog_conditions',
          callback: (_) => _onConditionsChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'catalog_conditions',
          callback: (_) => _onConditionsChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'catalog_conditions',
          callback: (_) => _onConditionsChanged(),
        );

    _catalogChannel = channel.subscribe((status, [error]) {
      if (kDebugMode) {
        debugPrint('[PlantProvider] Realtime status: $status'
            '${error != null ? " — $error" : ""}');
      }
    });
  }

  /// Called whenever Supabase pushes a catalog_plants INSERT or UPDATE.
  Future<void> _onCatalogPlantChanged(Map<String, dynamic> record) async {
    final plantId = record['id'] as String?;
    if (plantId == null || plantId.isEmpty) return;

    if (kDebugMode) debugPrint('[PlantProvider] Realtime update for plant: $plantId');

    final updated = await CatalogSyncService().syncSinglePlant(plantId);
    if (updated == null) return;

    final idx = _plants.indexWhere((p) => p.id == plantId);
    if (idx != -1) {
      _plants[idx] = updated;
    } else {
      _plants.add(updated);
    }

    final dohIdx = _dohApprovedPlants.indexWhere((p) => p.id == plantId);
    if (updated.isDOHApproved) {
      if (dohIdx != -1) {
        _dohApprovedPlants[dohIdx] = updated;
      } else {
        _dohApprovedPlants.add(updated);
      }
    } else if (dohIdx != -1) {
      _dohApprovedPlants.removeAt(dohIdx);
    }

    if (_selectedPlant?.id == plantId) _selectedPlant = updated;

    _applyFilters();
    notifyListeners();
  }

  /// Called when a related table row changes — extracts plant_id and re-syncs
  /// that single plant so all its details are refreshed.
  Future<void> _onRelatedTableChanged(Map<String, dynamic> record) async {
    final plantId = record['plant_id'] as String?;
    if (plantId == null || plantId.isEmpty) return;
    if (kDebugMode) debugPrint('[PlantProvider] Related table change for plant: $plantId');
    await _onCatalogPlantChanged({'id': plantId});
  }

  /// Called when a catalog_plants row is deleted — removes it from memory.
  void _onCatalogPlantDeleted(Map<String, dynamic> record) {
    final plantId = record['id'] as String?;
    if (plantId == null || plantId.isEmpty) return;
    if (kDebugMode) debugPrint('[PlantProvider] Plant deleted: $plantId');
    _plants.removeWhere((p) => p.id == plantId);
    _dohApprovedPlants.removeWhere((p) => p.id == plantId);
    if (_selectedPlant?.id == plantId) _selectedPlant = null;
    _applyFilters();
    notifyListeners();
  }

  /// Called when catalog_conditions changes — re-syncs the conditions table.
  Future<void> _onConditionsChanged() async {
    if (kDebugMode) debugPrint('[PlantProvider] catalog_conditions changed, re-syncing...');
    try {
      await CatalogSyncService().syncConditionsOnly();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[PlantProvider] Conditions re-sync failed: $e');
    }
  }

  @override
  void dispose() {
    _catalogChannel?.unsubscribe();
    super.dispose();
  }

  // Refresh plants and check for database updates
  Future<void> refreshPlants() async {
    try {
      print('🔄 Refreshing plants...');
      // Check for and add any missing plants
      await _databaseInitService.updateDatabaseWithMissingPlants();
      print('✅ Database update check completed');
      // Reload plants from database
      await loadPlants();
      await loadDOHApprovedPlants();
      print(
          '✅ Plants reloaded: ${_plants.length} total, ${_dohApprovedPlants.length} DOH');
    } catch (e) {
      print('❌ Error refreshing plants: $e');
      rethrow;
    }
  }

  // Force reinitialize database (clears and repopulates)
  Future<void> forceReinitializeDatabase() async {
    try {
      print('🔄 Force reinitializing database...');
      await _databaseInitService.repopulateDatabase();
      print('✅ Database reinitialized');
      // Reload plants from database
      await loadPlants();
      await loadDOHApprovedPlants();
      print(
          '✅ Plants reloaded: ${_plants.length} total, ${_dohApprovedPlants.length} DOH');
    } catch (e) {
      print('❌ Error force reinitializing database: $e');
      rethrow;
    }
  }

  // Load all plants
  Future<void> loadPlants() async {
    _isLoading = true;
    notifyListeners();

    try {
      _plants = await _plantService.getAllPlants();
      _applyFilters();
    } catch (e) {
      // Handle error
      _plants = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load DOH approved plants
  Future<void> loadDOHApprovedPlants() async {
    try {
      _dohApprovedPlants = await _plantService.getDOHApprovedPlants();
    } catch (e) {
      _dohApprovedPlants = [];
    }
    notifyListeners();
  }

  // Load scan history
  Future<void> loadScanHistory() async {
    try {
      print('🔄 Loading scan history from database...');
      _scanHistory = await _databaseService.getScanHistory();
      print('✅ Scan history loaded: ${_scanHistory.length} scans');
      if (_scanHistory.isNotEmpty) {
        print(
            '   First scan: ${_scanHistory.first.plant?.commonName ?? _scanHistory.first.topPrediction?.plantName ?? "Unknown"} (${_scanHistory.first.confidenceScore})');
      }
    } catch (e) {
      print('❌ Error loading scan history: $e');
      _scanHistory = [];
    }
    notifyListeners();
  }

  // Search plants
  void searchPlants(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  // Filter by category
  void filterByCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  // Filter by condition
  void filterByCondition(String condition) {
    _selectedCondition = condition;
    _applyFilters();
    notifyListeners();
  }

  // Apply filters
  void _applyFilters() {
    _filteredPlants = _plants.where((plant) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch = plant.commonName.toLowerCase().contains(query) ||
            plant.scientificName.toLowerCase().contains(query) ||
            plant.localName.toLowerCase().contains(query);
        if (!matchesSearch) return false;
      }

      // Category filter
      if (_selectedCategory != 'all') {
        if (_selectedCategory == 'doh' && !plant.isDOHApproved) {
          return false;
        }
      }

      // Condition filter
      if (_selectedCondition != 'all') {
        final matchesCondition = plant.medicinalUses.any((use) => use.condition
            .toLowerCase()
            .contains(_selectedCondition.toLowerCase()));
        if (!matchesCondition) return false;
      }

      return true;
    }).toList();
  }

  // Get plant by ID
  Plant? getPlantById(String id) {
    try {
      return _plants.firstWhere((plant) => plant.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Returns anatomy parts for the plant (from local DB, synced from Supabase). Ordered by z_index.
  /// Returns empty list if the anatomy table is missing (e.g. old DB before migration) or on error.
  Future<List<PlantAnatomyPart>> getPlantAnatomy(String plantId) async {
    try {
      final rows = await _databaseService.getAnatomyForPlant(plantId);
      return rows.map((row) => PlantAnatomyPart.fromMap(row)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns true if the plant has at least one anatomy part in the DB.
  Future<bool> hasAnatomyData(String plantId) async {
    final list = await getPlantAnatomy(plantId);
    return list.isNotEmpty;
  }

  // Get plants by condition
  List<Plant> getPlantsByCondition(String condition) {
    return _plants.where((plant) {
      return plant.medicinalUses.any((use) =>
          use.condition.toLowerCase().contains(condition.toLowerCase()));
    }).toList();
  }

  // Select plant
  void selectPlant(Plant plant) {
    _selectedPlant = plant;
    notifyListeners();
  }

  // Clear selection
  void clearSelection() {
    _selectedPlant = null;
    notifyListeners();
  }

  // Add scan result
  Future<void> addScanResult(ScanResult result) async {
    try {
      print('💾 Saving scan result to database...');
      print('   ID: ${result.id}');
      print(
          '   Plant: ${result.plant?.commonName ?? result.topPrediction?.plantName ?? "Unknown"}');
      print('   Confidence: ${result.confidenceScore}');
      print('   Predictions: ${result.predictions.length}');
      print('   Metadata: ${result.metadata}');

      await _databaseService.saveScanResult(result);
      _scanHistory.insert(0, result);
      notifyListeners();

      print(
          '✅ Scan result saved successfully. Total scans: ${_scanHistory.length}');
    } catch (e) {
      print('❌ Error saving scan result: $e');
      rethrow;
    }
  }

  // Delete scan result
  Future<void> deleteScanResult(String resultId) async {
    try {
      await _databaseService.deleteScanResult(resultId);
      _scanHistory.removeWhere((result) => result.id == resultId);
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  // Clear scan history
  Future<void> clearScanHistory() async {
    try {
      await _databaseService.clearScanHistory();
      _scanHistory.clear();
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    final totalScans = _scanHistory.length;
    final dohScans = _scanHistory
        .where((result) => result.plant?.isDOHApproved == true)
        .length;
    final highConfidenceScans =
        _scanHistory.where((result) => result.confidenceScore >= 0.8).length;

    final averageConfidence = totalScans > 0
        ? _scanHistory
                .map((result) => result.confidenceScore)
                .reduce((a, b) => a + b) /
            totalScans
        : 0.0;

    return {
      'totalScans': totalScans,
      'dohScans': dohScans,
      'highConfidenceScans': highConfidenceScans,
      'averageConfidence': averageConfidence,
      'totalPlants': _plants.length,
      'dohApprovedPlants': _dohApprovedPlants.length,
    };
  }
}
