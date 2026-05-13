import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'plant_service.dart';
import '../models/plant.dart';

/// Model for plant explanation data
/// Standardized structure with four required sections:
/// 1. Taxonomy (Family, Genus, Species)
/// 2. Ecology (Habitat, Growth Patterns)
/// 3. Medicinal Use & Preparation (Traditional uses, preparation steps)
/// 4. Safety & Look-alikes (Toxicity warnings, look-alike distinction)
class PlantExplanation {
  final String identification;
  final String? taxonomy; // Family, Genus, Species
  final String? ecology; // Habitat, Growth Patterns
  final String?
      medicinalPreparation; // Traditional uses, preparation steps (renamed from medicinalUses)
  final String? safety; // Toxicity warnings, look-alike distinction
  final String? heatmapGuidance; // Guidance for interpreting heatmap offline
  final String
      usability; // Usability assessment (kept for backward compatibility)

  PlantExplanation({
    required this.identification,
    this.taxonomy,
    this.ecology,
    String? medicinalPreparation,
    this.safety,
    this.heatmapGuidance,
    required this.usability,
    // Backward compatibility: support old medicinalUses field
    String? medicinalUses,
  }) : medicinalPreparation = medicinalPreparation ?? medicinalUses ?? '';

  String get formattedExplanation {
    final buffer = StringBuffer();

    buffer.writeln('**Plant Identification Summary**');
    buffer.writeln();
    buffer.writeln(identification);
    buffer.writeln();

    // Section 1: Taxonomy (ensure Family / Genus / Species each on own line in Markdown)
    if (taxonomy != null && taxonomy!.isNotEmpty) {
      buffer.writeln('### Taxonomy');
      buffer.writeln();
      // Markdown treats single \n as space; use "  \n" for hard line breaks so labels appear on separate lines
      final taxonomyWithLineBreaks = taxonomy!.replaceAll('\n', '  \n');
      buffer.writeln(taxonomyWithLineBreaks);
      buffer.writeln();
    }

    // Section 2: Ecology & Habitat
    if (ecology != null && ecology!.isNotEmpty) {
      buffer.writeln('### Ecology & Habitat');
      buffer.writeln();
      buffer.writeln(ecology);
      buffer.writeln();
    }

    // Section 3: Medicinal Uses
    if (medicinalPreparation != null && medicinalPreparation!.isNotEmpty) {
      buffer.writeln('### Medicinal Uses');
      buffer.writeln();
      buffer.writeln(medicinalPreparation);
      buffer.writeln();
    }

    // Section 4: Safety Protocol
    if (safety != null && safety!.isNotEmpty) {
      buffer.writeln('### Safety Protocol');
      buffer.writeln();
      buffer.writeln(safety);
      buffer.writeln();
    }

    // Usability Assessment (kept for backward compatibility)
    buffer.writeln('**Usability Assessment**');
    buffer.writeln();
    buffer.writeln(usability);
    buffer.writeln();

    // Heatmap Guidance (optional)
    if (heatmapGuidance != null && heatmapGuidance!.isNotEmpty) {
      buffer.writeln('**Heatmap Guidance**');
      buffer.writeln();
      buffer.writeln(heatmapGuidance);
    }

    return buffer.toString();
  }
}

class XAIExplanationService {
  static final XAIExplanationService _instance =
      XAIExplanationService._internal();
  factory XAIExplanationService() => _instance;
  XAIExplanationService._internal();

  final Logger _logger = Logger();
  final PlantService _plantService = PlantService();

  // Cache for offline explanations (asset JSON)
  Map<String, PlantExplanation>? _offlineExplanationsCache;

  // Cache for online API responses (JSON file)
  Map<String, Map<String, dynamic>>? _explanationFileCache;

  // Source tracking
  String? _lastExplanationSource; // "cache", "offline", "fallback"

  /// Get the last explanation source
  String? getLastExplanationSource() => _lastExplanationSource;

  /// Main method to generate explanation (hybrid online/offline)
  /// COMPATIBILITY: Maintains backward compatibility with existing calls
  ///
  /// Logic Flow (Read First Principle):
  /// 1. Check SharedPreferences cache (saved explanations)
  /// 2. Check JSON file cache (learned database)
  /// 3. Check asset JSON (offline database)
  /// 4. Only call online API if forceOnline=true AND no cache exists
  Future<String?> generateExplanation({
    required String plantName,
    required String scientificName,
    required double confidence,
    List<Map<String, dynamic>>? predictions,
    String? imagePath, // Original plant image path
    Uint8List? originalImageBytes, // Optional original image bytes
    String? heatmapImagePath, // Heatmap image path
    Uint8List? heatmapImageBytes, // Optional heatmap image bytes
    bool isOnline = false,
    bool forceOnline = false,
    Plant? plantData, // Optional plant data for enrichment
  }) async {
    try {
      // Reset source tracking
      _lastExplanationSource = null;

      // STEP 1: Check cache, but prioritize online if isOnline=true
      if (isOnline) {
        final cachedText = await _getCachedExplanation(scientificName);
        if (cachedText != null && cachedText.isNotEmpty) {
          final cacheSource = await _getCacheSource(scientificName);
          if (cacheSource == 'online') {
            _logger.d(
                'Using cached online explanation from SharedPreferences for $scientificName');
            _lastExplanationSource = 'online';
            return cachedText;
          } else {
            _logger.d(
                'Cache exists but is from offline source - will try online explanation first');
          }
        }

        final fileCachedText = await _getCachedFromFile(scientificName);
        if (fileCachedText != null && fileCachedText.isNotEmpty) {
          final fileCacheSource = await _getFileCacheSource(scientificName);
          if (fileCacheSource == 'online') {
            _logger.d(
                'Using cached online explanation from JSON file for $scientificName');
            _lastExplanationSource = 'online';
            return fileCachedText;
          }
        }
      } else {
        final cachedText = await _getCachedExplanation(scientificName);
        if (cachedText != null && cachedText.isNotEmpty) {
          _logger.d(
              'Using cached explanation from SharedPreferences for $scientificName');
          // Use cache (source already set by _getCachedExplanation)
          return cachedText;
        }

        // STEP 2: Check JSON file cache (learned database)
        final fileCachedText = await _getCachedFromFile(scientificName);
        if (fileCachedText != null && fileCachedText.isNotEmpty) {
          _logger
              .d('Using cached explanation from JSON file for $scientificName');
          // Use cache (source already set by _getCachedFromFile)
          return fileCachedText;
        }
      }

      // STEP 3: Try offline explanation from asset JSON
      final commonNameExplanation = await getExplanationOffline(
        plantName,
        enrichWithPlantData: true,
      );

      if (commonNameExplanation != null) {
        _lastExplanationSource ??= 'offline';
        _logger.d(
            'Using offline explanation from asset JSON (common name) for $plantName');
        return commonNameExplanation.formattedExplanation;
      }

      final offlineExplanation = await getExplanationOffline(
        scientificName,
        enrichWithPlantData: true,
      );

      if (offlineExplanation != null) {
        _lastExplanationSource ??= 'offline';
        _logger.d(
            'Using offline explanation from asset JSON (scientific name) for $scientificName');
        return offlineExplanation.formattedExplanation;
      }

      // Fallback - generic explanation
      _logger.d('No explanation found, generating fallback...');
      _lastExplanationSource = 'fallback';
      final fallback = await _generateFallbackExplanation(
        plantName: plantName,
        scientificName: scientificName,
        confidence: confidence,
      );
      return fallback.formattedExplanation;
    } catch (e) {
      _logger.e('Error generating explanation: $e');
      _lastExplanationSource = 'fallback';
      return "Could not generate explanation details.";
    }
  }

  Future<PlantExplanation?> getExplanationOffline(
    String keyName, {
    bool enrichWithPlantData = true,
  }) async {
    try {
      // CRITICAL: Check persistent cache FIRST (SharedPreferences and JSON file)
      // This ensures CAM results from history load their previously saved summaries
      // instead of auto-regenerating from assets JSON

      // STEP 1: Check SharedPreferences cache FIRST (try keyName as-is)
      var cachedText = await _getCachedExplanation(keyName);

      // STEP 1b: If cache lookup with keyName failed, try to find scientific name
      // from plant data and use that for cache lookup (cache is stored by scientific name)
      if ((cachedText == null || cachedText.isEmpty) && enrichWithPlantData) {
        try {
          final plants = await _plantService.getAllPlants();
          Plant? matchingPlant;

          // Try to find plant by common name (keyName might be common name)
          try {
            matchingPlant = plants.firstWhere(
              (p) =>
                  p.commonName.trim().toLowerCase() ==
                  keyName.trim().toLowerCase(),
            );
          } catch (e) {
            // No match by common name, try scientific name
            try {
              matchingPlant = plants.firstWhere(
                (p) =>
                    p.scientificName.trim().toLowerCase() ==
                    keyName.trim().toLowerCase(),
              );
            } catch (e2) {
              // No match
            }
          }

          // If we found a plant, try cache lookup with scientific name
          if (matchingPlant != null &&
              matchingPlant.scientificName.isNotEmpty) {
            cachedText =
                await _getCachedExplanation(matchingPlant.scientificName);
            if (cachedText != null && cachedText.isNotEmpty) {
              _logger.d(
                  'Using cached explanation from SharedPreferences for ${matchingPlant.scientificName} (found via plant lookup)');
            }
          }
        } catch (e) {
          // Ignore errors in plant lookup, continue to next step
          _logger.d('Could not find plant for cache lookup: $e');
        }
      }

      if (cachedText != null && cachedText.isNotEmpty) {
        _logger.d(
            'Using cached explanation from SharedPreferences for $keyName (offline lookup)');
        // Convert cached text to PlantExplanation format
        // The cached text is already formatted markdown, so we can use it directly
        // Create a minimal PlantExplanation object for compatibility
        return PlantExplanation(
          identification: cachedText,
          medicinalPreparation: '',
          usability: '',
          heatmapGuidance: null,
        );
      }

      // STEP 2: Check JSON file cache (try keyName as-is)
      var fileCachedText = await _getCachedFromFile(keyName);

      // STEP 2b: If cache lookup with keyName failed, try scientific name lookup
      if ((fileCachedText == null || fileCachedText.isEmpty) &&
          enrichWithPlantData) {
        try {
          final plants = await _plantService.getAllPlants();
          Plant? matchingPlant;

          // Try to find plant by common name
          try {
            matchingPlant = plants.firstWhere(
              (p) =>
                  p.commonName.trim().toLowerCase() ==
                  keyName.trim().toLowerCase(),
            );
          } catch (e) {
            // No match by common name, try scientific name
            try {
              matchingPlant = plants.firstWhere(
                (p) =>
                    p.scientificName.trim().toLowerCase() ==
                    keyName.trim().toLowerCase(),
              );
            } catch (e2) {
              // No match
            }
          }

          // If we found a plant, try cache lookup with scientific name
          if (matchingPlant != null &&
              matchingPlant.scientificName.isNotEmpty) {
            fileCachedText =
                await _getCachedFromFile(matchingPlant.scientificName);
            if (fileCachedText != null && fileCachedText.isNotEmpty) {
              _logger.d(
                  'Using cached explanation from JSON file for ${matchingPlant.scientificName} (found via plant lookup)');
            }
          }
        } catch (e) {
          // Ignore errors in plant lookup, continue to next step
          _logger.d('Could not find plant for file cache lookup: $e');
        }
      }

      if (fileCachedText != null && fileCachedText.isNotEmpty) {
        _logger.d(
            'Using cached explanation from JSON file for $keyName (offline lookup)');
        // Convert cached text to PlantExplanation format
        return PlantExplanation(
          identification: fileCachedText,
          medicinalPreparation: '',
          usability: '',
          heatmapGuidance: null,
        );
      }

      // STEP 3: Only if no cache found, load from asset JSON (static offline database)
      // Load asset JSON (static offline database)
      if (_offlineExplanationsCache == null) {
        await _loadOfflineExplanations();
      }

      // Normalize the search key (lowercase, trim whitespace)
      final normalizedKeyName = _normalizeKey(keyName);
      final assetKeys = _offlineExplanationsCache?.keys.toList() ?? [];

      // Debug logging
      _logger.d(
          'Looking for key: "$normalizedKeyName" (original: "$keyName") in database keys: $assetKeys');

      // STEP 1: Try exact match (normalized)
      var explanation = _offlineExplanationsCache?[keyName];

      // STEP 2: Try normalized key match
      if (explanation == null) {
        final exactKey = _offlineExplanationsCache!.keys.firstWhere(
          (k) => _normalizeKey(k) == normalizedKeyName,
          orElse: () => '',
        );
        if (exactKey.isNotEmpty) {
          explanation = _offlineExplanationsCache![exactKey];
          _logger
              .d('Found explanation using normalized key match: "$exactKey"');
        }
      }

      // STEP 3: Try case-insensitive partial match (fuzzy matching)
      if (explanation == null) {
        final fuzzyKey = _offlineExplanationsCache!.keys.firstWhere(
          (k) {
            final normalizedK = _normalizeKey(k);
            return normalizedK.contains(normalizedKeyName) ||
                normalizedKeyName.contains(normalizedK);
          },
          orElse: () => '',
        );
        if (fuzzyKey.isNotEmpty) {
          explanation = _offlineExplanationsCache![fuzzyKey];
          _logger.d('Found explanation using fuzzy match: "$fuzzyKey"');
        }
      }

      // STEP 4: Try scientific name lookup if keyName might be a scientific name
      if (explanation == null) {
        // Try to find by scientific name in the explanation data
        for (final entry in _offlineExplanationsCache!.entries) {
          final expData = entry.value;
          // Check if the explanation's identification or other fields contain the scientific name
          if (expData.identification
                  .toLowerCase()
                  .contains(normalizedKeyName) ||
              (expData.taxonomy != null &&
                  expData.taxonomy!
                      .toLowerCase()
                      .contains(normalizedKeyName))) {
            explanation = expData;
            _logger.d(
                'Found explanation by scientific name match: "${entry.key}"');
            break;
          }
        }
      }

      if (explanation == null) {
        _logger.w(
            'No explanation found for key: "$keyName" (normalized: "$normalizedKeyName")');
        _lastExplanationSource ??= 'offline';
        return null;
      }

      // Update source if not already set
      _lastExplanationSource ??= 'offline';

      // Enrich with plant data from database
      if (enrichWithPlantData) {
        try {
          final plants = await _plantService.getAllPlants();
          Plant? matchingPlant;

          try {
            matchingPlant = plants.firstWhere(
              (p) => p.scientificName.toLowerCase() == keyName.toLowerCase(),
            );
          } catch (e) {
            // No match
          }

          if (matchingPlant != null) {
            explanation = PlantExplanation(
              identification: explanation.identification,
              medicinalPreparation: explanation.medicinalPreparation,
              usability: explanation.usability,
              taxonomy: explanation.taxonomy ?? _formatTaxonomy(matchingPlant),
              ecology: explanation.ecology ?? _formatEcology(matchingPlant),
              safety: _safetyProtocolPointer,
              heatmapGuidance: explanation.heatmapGuidance,
            );
          }
        } catch (e) {
          // Ignore enrichment errors
        }
      }

      return explanation;
    } catch (e) {
      _logger.e('Error loading offline explanation: $e');
      return null;
    }
  }

  Future<void> _loadOfflineExplanations() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/plant_explanations.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      _offlineExplanationsCache = {};

      jsonData.forEach((key, data) {
        final explanationData = data as Map<String, dynamic>;
        _offlineExplanationsCache![key] = PlantExplanation(
          identification: explanationData['identification'] as String? ?? '',
          // Support both new structure (medicinal_preparation) and old structure (medicinal_uses) for backward compatibility
          medicinalPreparation:
              explanationData['medicinal_preparation'] as String? ??
                  explanationData['medicinal_uses'] as String? ??
                  '',
          usability: explanationData['usability'] as String? ?? '',
          taxonomy: explanationData['taxonomy'] as String?,
          ecology: explanationData['ecology'] as String?,
          safety: _safetyProtocolPointer,
          heatmapGuidance: explanationData['heatmap_guidance'] as String?,
        );
      });
    } catch (e) {
      _logger.e('Error loading offline explanations: $e');
      _offlineExplanationsCache = {};
    }
  }

  String _formatTaxonomy(Plant plant) {
    return '''**Kingdom:** Plantae
**Family:** ${plant.family}
**Genus:** ${plant.genus}
**Species:** ${plant.species}''';
  }

  String _formatEcology(Plant plant) {
    final buffer = StringBuffer();
    if (plant.ecology.isNotEmpty) buffer.writeln(plant.ecology);
    if (plant.habitat.isNotEmpty) {
      buffer.writeln('**Habitat:** ${plant.habitat}');
    }
    return buffer.toString().trim();
  }

  /// Short pointer for Safety Protocol; real safety is from ContraindicationEngineWidget (safety_profiles.json).
  static const String _safetyProtocolPointer =
      'See Safety & Contraindications below for verified safety information.';

  Future<PlantExplanation> _generateFallbackExplanation({
    required String plantName,
    required String scientificName,
    required double confidence,
  }) async {
    final confidencePercent = (confidence * 100).toStringAsFixed(1);

    // Try to get plant data for structured fallback
    Plant? plantData;
    try {
      final plants = await _plantService.getAllPlants();
      try {
        plantData = plants.firstWhere(
          (p) =>
              p.scientificName.toLowerCase() == scientificName.toLowerCase() ||
              p.commonName.toLowerCase() == plantName.toLowerCase(),
        );
      } catch (e) {
        // Plant not found in database
      }
    } catch (e) {
      // Ignore errors
    }

    return PlantExplanation(
      identification:
          "Identified as $plantName ($scientificName) with $confidencePercent% confidence.",
      taxonomy: plantData != null ? _formatTaxonomy(plantData) : null,
      ecology: plantData != null ? _formatEcology(plantData) : null,
      medicinalPreparation: plantData != null &&
              plantData.medicinalUses.isNotEmpty
          ? "**Uses:** ${plantData.medicinalUses.map((u) => u.condition).join(", ")}.\n\n**Preparation:** ${plantData.preparationMethods.isNotEmpty ? plantData.preparationMethods.first.title : "Consult traditional preparation methods."}"
          : "Specific medicinal details for this plant are not currently in the offline database.",
      safety: _safetyProtocolPointer,
      usability:
          "**Status: USE WITH CAUTION**\n\nPlease consult a local expert before using this plant.",
      heatmapGuidance: null,
    );
  }

  /// Get cached explanation from SharedPreferences
  /// Returns the cached text and sets the source based on cache metadata
  Future<String?> _getCachedExplanation(String scientificName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'xai_explanation_${_normalizeKey(scientificName)}';
      final cachedText = prefs.getString(key);
      if (cachedText != null && cachedText.isNotEmpty) {
        // Check the source of the cache
        final cacheSource = prefs.getString('${key}_source');
        _lastExplanationSource = 'cache';
        _logger.d(
            'Found cached explanation in SharedPreferences for $scientificName (source: $cacheSource)');
        return cachedText;
      }
    } catch (e) {
      _logger.w('Error reading from SharedPreferences cache: $e');
    }
    return null;
  }

  /// Get cache source from SharedPreferences
  Future<String?> _getCacheSource(String scientificName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'xai_explanation_${_normalizeKey(scientificName)}';
      return prefs.getString('${key}_source');
    } catch (e) {
      return null;
    }
  }

  /// Load cache from JSON file
  Future<void> _loadCacheFromFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/xai_cache');
      if (!await cacheDir.exists()) {
        _explanationFileCache = {};
        return;
      }

      final cacheFile = File('${cacheDir.path}/plant_explanations_cache.json');
      if (!await cacheFile.exists()) {
        _explanationFileCache = {};
        return;
      }

      final jsonString = await cacheFile.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      _explanationFileCache = jsonData.map((key, value) => MapEntry(
            key,
            value as Map<String, dynamic>,
          ));
      _logger.d('Loaded ${_explanationFileCache!.length} cached explanations from file');
    } catch (e) {
      _logger.w('Error loading cache from file: $e');
      _explanationFileCache = {};
    }
  }

  // ignore: unused_element - kept for reference; no longer writing to cache (no live LLM).
  Future<void> _saveToCacheFile(
    String scientificName,
    String text,
    String source,
    String plantName,
  ) async {
    try {
      if (_explanationFileCache == null) {
        await _loadCacheFromFile();
      }

      _explanationFileCache ??= {};
      _explanationFileCache![_normalizeKey(scientificName)] = {
        'text': text,
        'source': source,
        'plantName': plantName,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/xai_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheFile = File('${cacheDir.path}/plant_explanations_cache.json');
      await cacheFile.writeAsString(jsonEncode(_explanationFileCache));
    } catch (e) {
      _logger.w('Error saving to JSON cache file: $e');
    }
  }

  /// Get cached explanation from JSON file
  /// Returns the cached text and sets the source based on cache metadata
  Future<String?> _getCachedFromFile(String scientificName) async {
    try {
      if (_explanationFileCache == null) {
        await _loadCacheFromFile();
      }

      final key = _normalizeKey(scientificName);
      final cached = _explanationFileCache?[key];
      if (cached != null && cached['text'] != null) {
        // Check the source of the cache
        final cacheSource = cached['source'] as String?;
        _lastExplanationSource = 'cache';
        _logger.d(
            'Found cached explanation in JSON file for $scientificName (source: $cacheSource)');
        return cached['text'] as String;
      }
    } catch (e) {
      _logger.w('Error reading from JSON cache file: $e');
    }
    return null;
  }

  /// Get file cache source
  Future<String?> _getFileCacheSource(String scientificName) async {
    try {
      if (_explanationFileCache == null) {
        await _loadCacheFromFile();
      }

      final key = _normalizeKey(scientificName);
      final cached = _explanationFileCache?[key];
      if (cached != null) {
        return cached['source'] as String?;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Normalize key for caching (lowercase, trim)
  String _normalizeKey(String key) {
    return key.trim().toLowerCase();
  }
}
