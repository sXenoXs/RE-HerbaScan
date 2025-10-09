import 'package:flutter/material.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:herbascan/core/services/plant_service.dart';
import 'package:herbascan/core/services/database_service.dart';

class PlantProvider extends ChangeNotifier {
  final PlantService _plantService = PlantService();
  final DatabaseService _databaseService = DatabaseService();

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
    _initializeData();
  }

  // Initialize data
  Future<void> _initializeData() async {
    await loadPlants();
    await loadScanHistory();
    await loadDOHApprovedPlants();
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
      _scanHistory = await _databaseService.getScanHistory();
    } catch (e) {
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
        final matchesCondition = plant.medicinalUses.any((use) =>
            use.condition.toLowerCase().contains(_selectedCondition.toLowerCase()));
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
      await _databaseService.saveScanResult(result);
      _scanHistory.insert(0, result);
      notifyListeners();
    } catch (e) {
      // Handle error
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
    final dohScans = _scanHistory.where((result) => 
        result.plant?.isDOHApproved == true).length;
    final highConfidenceScans = _scanHistory.where((result) => 
        result.confidenceScore >= 0.8).length;
    
    final averageConfidence = totalScans > 0
        ? _scanHistory.map((result) => result.confidenceScore).reduce((a, b) => a + b) / totalScans
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
