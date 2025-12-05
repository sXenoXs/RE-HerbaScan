import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'plant_service.dart';
import '../models/plant.dart';
import 'gemini_api_service.dart';
import 'config_service.dart';

/// Model for plant explanation data
class PlantExplanation {
  final String identification;
  final String medicinalUses;
  final String usability;
  final String? taxonomy;
  final String? ecology;
  final String? safety;
  final String? heatmapGuidance; // Guidance for interpreting heatmap offline

  PlantExplanation({
    required this.identification,
    required this.medicinalUses,
    required this.usability,
    this.taxonomy,
    this.ecology,
    this.safety,
    this.heatmapGuidance,
  });

  String get formattedExplanation {
    final buffer = StringBuffer();

    buffer.writeln('**Plant Identification Summary**');
    buffer.writeln();
    buffer.writeln(identification);
    buffer.writeln();

    if (taxonomy != null && taxonomy!.isNotEmpty) {
      buffer.writeln('**Taxonomy**');
      buffer.writeln(taxonomy);
      buffer.writeln();
    }

    if (ecology != null && ecology!.isNotEmpty) {
      buffer.writeln('**Ecology & Habitat**');
      buffer.writeln(ecology);
      buffer.writeln();
    }

    buffer.writeln('**Medicinal Uses Overview**');
    buffer.writeln(medicinalUses);
    buffer.writeln();

    if (safety != null && safety!.isNotEmpty) {
      buffer.writeln('**Safety Information**');
      buffer.writeln(safety);
      buffer.writeln();
    }

    buffer.writeln('**Usability Assessment**');
    buffer.writeln(usability);
    buffer.writeln();

    if (heatmapGuidance != null && heatmapGuidance!.isNotEmpty) {
      buffer.writeln('**Heatmap Guidance**');
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
  final GeminiAPIService _geminiService = GeminiAPIService();

  // Cache for offline explanations (asset JSON)
  Map<String, PlantExplanation>? _offlineExplanationsCache;

  // Cache for Gemini responses (JSON file)
  Map<String, Map<String, dynamic>>? _geminiCache;

  // Source tracking
  String? _lastExplanationSource; // "gemini", "cache", "offline", "fallback"

  // Danger look-alikes for safety checks
  static const Map<String, Map<String, String>> _dangerLookAlikes = {
    'Conium maculatum': {
      // Poison Hemlock
      'marker': 'purple splotches on stem',
      'safeAlternative': 'Wild Carrot',
      'safeMarker': 'hairy stem',
    },
    // Add more dangerous look-alikes as needed
  };

  /// Get the last explanation source
  String? getLastExplanationSource() => _lastExplanationSource;

  /// Main method to generate explanation (hybrid online/offline)
  /// COMPATIBILITY: Maintains backward compatibility with existing calls
  ///
  /// Logic Flow (Read First Principle):
  /// 1. Check SharedPreferences cache (saved explanations)
  /// 2. Check JSON file cache (learned database)
  /// 3. Check asset JSON (offline database)
  /// 4. Only call Gemini if forceOnline=true AND no cache exists
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

      // STEP 1: Check SharedPreferences cache FIRST (Read First Principle)
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

      // STEP 3: Try offline explanation from asset JSON
      // Try common name FIRST (since JSON keys use common names matching model labels)
      final commonNameExplanation = await getExplanationOffline(
        plantName,
        enrichWithPlantData: true,
      );

      if (commonNameExplanation != null) {
        if (_lastExplanationSource == null) {
          _lastExplanationSource = 'offline';
        }
        _logger.d(
            'Using offline explanation from asset JSON (common name) for $plantName');
        return commonNameExplanation.formattedExplanation;
      }

      // Try with scientific name as fallback
      final offlineExplanation = await getExplanationOffline(
        scientificName,
        enrichWithPlantData: true,
      );

      if (offlineExplanation != null) {
        if (_lastExplanationSource == null) {
          _lastExplanationSource = 'offline';
        }
        _logger.d(
            'Using offline explanation from asset JSON (scientific name) for $scientificName');
        return offlineExplanation.formattedExplanation;
      }

      // STEP 4: Only call Gemini if forceOnline=true (user explicitly requested refresh)
      // AND we have the necessary API key and images
      if (forceOnline &&
          await ConfigService.isGeminiApiKeyConfigured() &&
          (imagePath != null || originalImageBytes != null)) {
        _logger.d(
            'No cache found, forceOnline=true - Attempting online explanation for $plantName ($scientificName)');
        // Try online explanation with images
        final onlineExplanationText = await getExplanationOnline(
          plantName: plantName,
          scientificName: scientificName,
          confidence: confidence,
          predictions: predictions ?? [],
          originalImagePath: imagePath ?? '',
          originalImageBytes: originalImageBytes,
          heatmapImagePath: heatmapImagePath,
          heatmapImageBytes: heatmapImageBytes,
          plantData: plantData,
        );

        if (onlineExplanationText != null && onlineExplanationText.isNotEmpty) {
          _logger.i('Successfully retrieved online explanation from Gemini');
          return onlineExplanationText; // Return markdown text directly
        }

        // If online fails, fall through to fallback
        _logger.w(
            'Online explanation failed or returned empty, falling back to generic explanation');
      } else if (forceOnline) {
        _logger.d(
            'forceOnline=true but missing requirements: hasApiKey=${await ConfigService.isGeminiApiKeyConfigured()}, hasImage=${imagePath != null || originalImageBytes != null}');
      }

      // STEP 5: Fallback - generic explanation
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
          medicinalUses: '',
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
          medicinalUses: '',
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

      // Debug logging
      _logger.d(
          'Looking for key: "$normalizedKeyName" (original: "$keyName") in database keys: ${_offlineExplanationsCache?.keys.toList()}');

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
        if (_lastExplanationSource == null) {
          _lastExplanationSource = 'offline';
        }
        return null;
      }

      // Update source if not already set
      if (_lastExplanationSource == null) {
        _lastExplanationSource = 'offline';
      }

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
              medicinalUses: explanation.medicinalUses,
              usability: explanation.usability,
              taxonomy: explanation.taxonomy ?? _formatTaxonomy(matchingPlant),
              ecology: explanation.ecology ?? _formatEcology(matchingPlant),
              safety: explanation.safety ?? _formatSafety(matchingPlant),
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
          medicinalUses: explanationData['medicinal_uses'] as String? ?? '',
          usability: explanationData['usability'] as String? ?? '',
          taxonomy: explanationData['taxonomy'] as String?,
          ecology: explanationData['ecology'] as String?,
          safety: explanationData['safety'] as String?,
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
    if (plant.habitat.isNotEmpty)
      buffer.writeln('**Habitat:** ${plant.habitat}');
    return buffer.toString().trim();
  }

  String _formatSafety(Plant plant) {
    if (plant.safetyWarnings.isEmpty)
      return 'Consult a healthcare provider before use.';
    final buffer = StringBuffer();
    buffer.writeln('**Important Safety Warnings:**');
    for (final warning in plant.safetyWarnings) {
      buffer.writeln('- $warning');
    }
    return buffer.toString().trim();
  }

  Future<PlantExplanation> _generateFallbackExplanation({
    required String plantName,
    required String scientificName,
    required double confidence,
  }) async {
    final confidencePercent = (confidence * 100).toStringAsFixed(1);

    return PlantExplanation(
      identification:
          "Identified as $plantName ($scientificName) with $confidencePercent% confidence.",
      medicinalUses:
          "Specific medicinal details for this plant are not currently in the offline database.",
      usability: "Please consult a local expert before using this plant.",
      taxonomy: null,
      ecology: null,
      safety: null,
      heatmapGuidance: null,
    );
  }

  /// Check if plant is a dangerous look-alike
  bool _isDangerousLookAlike(String scientificName) {
    return _dangerLookAlikes.containsKey(scientificName);
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
        // If cache source is 'gemini', it's from online analysis
        // Otherwise, treat it as offline/cache
        _lastExplanationSource = cacheSource == 'gemini' ? 'gemini' : 'cache';
        _logger.d(
            'Found cached explanation in SharedPreferences for $scientificName (source: $cacheSource)');
        return cachedText;
      }
    } catch (e) {
      _logger.w('Error reading from SharedPreferences cache: $e');
    }
    return null;
  }

  /// Save explanation to SharedPreferences cache
  Future<void> _saveCachedExplanation(
    String scientificName,
    String text,
    String source,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'xai_explanation_${_normalizeKey(scientificName)}';
      await prefs.setString(key, text);
      await prefs.setString('${key}_source', source);
      await prefs.setString(
          '${key}_timestamp', DateTime.now().toIso8601String());
      _logger.d(
          'Saved explanation to SharedPreferences cache for $scientificName');
    } catch (e) {
      _logger.w('Error saving to SharedPreferences cache: $e');
    }
  }

  /// Load cache from JSON file
  Future<void> _loadCacheFromFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/xai_cache');
      if (!await cacheDir.exists()) {
        _geminiCache = {};
        return;
      }

      final cacheFile = File('${cacheDir.path}/plant_explanations_cache.json');
      if (!await cacheFile.exists()) {
        _geminiCache = {};
        return;
      }

      final jsonString = await cacheFile.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      _geminiCache = jsonData.map((key, value) => MapEntry(
            key,
            value as Map<String, dynamic>,
          ));
      _logger.d('Loaded ${_geminiCache!.length} cached explanations from file');
    } catch (e) {
      _logger.w('Error loading cache from file: $e');
      _geminiCache = {};
    }
  }

  /// Save explanation to JSON cache file
  Future<void> _saveToCacheFile(
    String scientificName,
    String text,
    String source,
    String plantName,
  ) async {
    try {
      if (_geminiCache == null) {
        await _loadCacheFromFile();
      }

      _geminiCache ??= {};
      _geminiCache![_normalizeKey(scientificName)] = {
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
      await cacheFile.writeAsString(jsonEncode(_geminiCache));
      _logger.d('Saved explanation to JSON cache file for $scientificName');
    } catch (e) {
      _logger.w('Error saving to JSON cache file: $e');
    }
  }

  /// Get cached explanation from JSON file
  /// Returns the cached text and sets the source based on cache metadata
  Future<String?> _getCachedFromFile(String scientificName) async {
    try {
      if (_geminiCache == null) {
        await _loadCacheFromFile();
      }

      final key = _normalizeKey(scientificName);
      final cached = _geminiCache?[key];
      if (cached != null && cached['text'] != null) {
        // Check the source of the cache
        final cacheSource = cached['source'] as String?;
        // If cache source is 'gemini', it's from online analysis
        // Otherwise, treat it as offline/cache
        _lastExplanationSource = cacheSource == 'gemini' ? 'gemini' : 'cache';
        _logger.d(
            'Found cached explanation in JSON file for $scientificName (source: $cacheSource)');
        return cached['text'] as String;
      }
    } catch (e) {
      _logger.w('Error reading from JSON cache file: $e');
    }
    return null;
  }

  /// Normalize key for caching (lowercase, trim)
  String _normalizeKey(String key) {
    return key.trim().toLowerCase();
  }

  /// Load image bytes from file path
  Future<Uint8List?> _loadImageBytes(String? imagePath) async {
    if (imagePath == null) return null;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      _logger.e('Error loading image bytes: $e');
    }
    return null;
  }

  /// Get explanation online using Gemini API with images
  /// Returns formatted markdown text string (not PlantExplanation)
  Future<String?> getExplanationOnline({
    required String plantName,
    required String scientificName,
    required double confidence,
    required List<Map<String, dynamic>> predictions,
    required String originalImagePath,
    Uint8List? originalImageBytes,
    String? heatmapImagePath,
    Uint8List? heatmapImageBytes,
    Plant? plantData,
  }) async {
    try {
      // Check if API key is configured
      if (!await ConfigService.isGeminiApiKeyConfigured()) {
        _logger.w('Gemini API key not configured, falling back to offline');
        return null;
      }

      // Load images as bytes
      final originalBytes =
          originalImageBytes ?? await _loadImageBytes(originalImagePath);
      final heatmapBytes =
          heatmapImageBytes ?? await _loadImageBytes(heatmapImagePath);

      if (originalBytes == null) {
        _logger.w('Original image not available, falling back to offline');
        return null;
      }

      // Extract only the top prediction (index 0) to avoid confusing Gemini
      // The model's prediction is absolute truth - Gemini should only justify it, not identify
      final topPrediction = predictions.isNotEmpty
          ? [predictions.first] // Only pass the top prediction
          : <Map<String, dynamic>>[];

      // Call Gemini API with images
      final explanationText = await _geminiService.generateExplanation(
        plantName: plantName,
        scientificName: scientificName,
        confidence: confidence,
        predictions:
            topPrediction, // Only top prediction - model's decision is absolute
        originalImageBytes: originalBytes,
        heatmapImageBytes: heatmapBytes,
        plantData: plantData,
        isDangerousLookAlike: _isDangerousLookAlike(scientificName),
        dangerInfo: _isDangerousLookAlike(scientificName)
            ? _dangerLookAlikes[scientificName]
            : null,
      );

      if (explanationText != null && explanationText.isNotEmpty) {
        // Save to cache (both SharedPreferences and JSON file)
        await _saveCachedExplanation(scientificName, explanationText, 'gemini');
        await _saveToCacheFile(
            scientificName, explanationText, 'gemini', plantName);

        _lastExplanationSource = 'gemini';
        return explanationText; // Return markdown text directly
      }

      return null;
    } catch (e) {
      _logger.e('Error getting online explanation: $e');
      return null;
    }
  }
}
