import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'gemini_api_service.dart';
import 'plant_service.dart';
import '../models/plant.dart';

/// Model for plant explanation data
class PlantExplanation {
  final String identification;
  final String medicinalUses;
  final String usability;
  final String? taxonomy;
  final String? ecology;
  final String? safety;

  PlantExplanation({
    required this.identification,
    required this.medicinalUses,
    required this.usability,
    this.taxonomy,
    this.ecology,
    this.safety,
  });

  /// Combine all sections into a formatted explanation
  String get formattedExplanation {
    final buffer = StringBuffer();

    buffer.writeln('**Plant Identification Summary**');
    buffer.writeln();
    buffer.writeln(identification);
    buffer.writeln();

    if (taxonomy != null && taxonomy!.isNotEmpty) {
      buffer.writeln('**Taxonomy**');
      buffer.writeln();
      buffer.writeln(taxonomy);
      buffer.writeln();
    }

    if (ecology != null && ecology!.isNotEmpty) {
      buffer.writeln('**Ecology & Habitat**');
      buffer.writeln();
      buffer.writeln(ecology);
      buffer.writeln();
    }

    buffer.writeln('**Medicinal Uses Overview**');
    buffer.writeln();
    buffer.writeln(medicinalUses);
    buffer.writeln();

    if (safety != null && safety!.isNotEmpty) {
      buffer.writeln('**Safety Information**');
      buffer.writeln();
      buffer.writeln(safety);
      buffer.writeln();
    }

    buffer.writeln('**Usability Assessment**');
    buffer.writeln();
    buffer.writeln(usability);

    return buffer.toString();
  }
}

/// Service for generating Explainable AI (XAI) explanations
/// Handles both offline (retrieval-based) and online (Gemini API) explanations
class XAIExplanationService {
  static final XAIExplanationService _instance =
      XAIExplanationService._internal();
  factory XAIExplanationService() => _instance;
  XAIExplanationService._internal();

  final Logger _logger = Logger();
  final GeminiAPIService _geminiService = GeminiAPIService();
  final PlantService _plantService = PlantService();

  // Cache for offline explanations
  Map<String, PlantExplanation>? _offlineExplanationsCache;

  /// Get explanation from offline JSON file
  /// Optionally enriches with plant data from database
  Future<PlantExplanation?> getExplanationOffline(
    String scientificName, {
    bool enrichWithPlantData = true,
  }) async {
    try {
      // Load cache if not already loaded
      if (_offlineExplanationsCache == null) {
        await _loadOfflineExplanations();
      }

      // Look up explanation by scientific name
      var explanation = _offlineExplanationsCache?[scientificName];
      if (explanation == null) {
        _logger.w('No offline explanation found for $scientificName');
        return null;
      }

      // Enrich with plant data from database if available
      if (enrichWithPlantData) {
        try {
          final plants = await _plantService.getAllPlants();
          Plant? matchingPlant;

          // Try exact match first
          try {
            matchingPlant = plants.firstWhere(
              (p) =>
                  p.scientificName.toLowerCase() ==
                  scientificName.toLowerCase(),
            );
          } catch (e) {
            // Try partial match
            try {
              matchingPlant = plants.firstWhere(
                (p) =>
                    p.scientificName
                        .toLowerCase()
                        .contains(scientificName.toLowerCase()) ||
                    scientificName
                        .toLowerCase()
                        .contains(p.scientificName.toLowerCase()),
              );
            } catch (e2) {
              // No match found
              matchingPlant = null;
            }
          }

          // Only enrich if we found a matching plant
          if (matchingPlant != null) {
            explanation = PlantExplanation(
              identification: explanation.identification,
              medicinalUses: explanation.medicinalUses,
              usability: explanation.usability,
              taxonomy: explanation.taxonomy ?? _formatTaxonomy(matchingPlant),
              ecology: explanation.ecology ?? _formatEcology(matchingPlant),
              safety: explanation.safety ?? _formatSafety(matchingPlant),
            );
            _logger.d(
                'Enriched offline explanation with plant data for $scientificName');
          }
        } catch (e) {
          _logger.w('Could not enrich explanation with plant data: $e');
          // Continue with original explanation
        }
      }

      _logger.d('Found offline explanation for $scientificName');
      return explanation;
    } catch (e) {
      _logger.e('Error loading offline explanation: $e');
      return null;
    }
  }

  /// Format taxonomy information from Plant object
  String _formatTaxonomy(Plant plant) {
    return '''**Kingdom:** Plantae
**Family:** ${plant.family}
**Genus:** ${plant.genus}
**Species:** ${plant.species}''';
  }

  /// Format ecology and habitat information from Plant object
  String _formatEcology(Plant plant) {
    final buffer = StringBuffer();
    if (plant.ecology.isNotEmpty) {
      buffer.writeln(plant.ecology);
    }
    if (plant.habitat.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('**Habitat:** ${plant.habitat}');
    }
    return buffer.toString().trim();
  }

  /// Format safety information from Plant object
  String _formatSafety(Plant plant) {
    if (plant.safetyWarnings.isEmpty) {
      return 'No specific safety warnings available. Always consult with a healthcare provider before using medicinal plants.';
    }

    final buffer = StringBuffer();
    buffer.writeln('**Important Safety Warnings:**');
    for (final warning in plant.safetyWarnings) {
      buffer.writeln('- $warning');
    }
    if (plant.isDOHApproved) {
      buffer.writeln();
      buffer
          .writeln('✅ This plant is DOH-approved for specific medicinal uses.');
    }
    return buffer.toString().trim();
  }

  /// Generate a fallback explanation when plant is not in offline JSON
  Future<PlantExplanation> _generateFallbackExplanation({
    required String plantName,
    required String scientificName,
    required double confidence,
  }) async {
    final confidencePercent = (confidence * 100).toStringAsFixed(1);

    // Determine usability status based on confidence
    String usabilityStatus;
    String usabilityGuidance;

    if (confidence >= 0.7) {
      usabilityStatus = "USE WITH CAUTION";
      usabilityGuidance =
          "The model identified this plant with ${confidencePercent}% confidence. However, without specific information about this plant's properties and condition, use caution. Examine the plant carefully for signs of disease, brown spots, or damage. Consult with a plant expert or healthcare provider before use, especially for medicinal purposes.";
    } else if (confidence >= 0.5) {
      usabilityStatus = "USE WITH CAUTION";
      usabilityGuidance =
          "The model identified this plant with moderate confidence (${confidencePercent}%). The identification may not be certain. Carefully examine the plant for any signs of disease, brown spots, broken parts, or unusual patterns. Do not use this plant for medicinal purposes without expert consultation. Verify the identification with a qualified botanist or plant expert.";
    } else {
      usabilityStatus = "NOT RECOMMENDED";
      usabilityGuidance =
          "The model identified this plant with low confidence (${confidencePercent}%). The identification is uncertain and may be incorrect. Do not use this plant, especially for medicinal purposes. The heatmap visualization may show unusual patterns that require expert analysis. Consult with a qualified plant expert or botanist for proper identification before considering any use.";
    }

    // Try to get plant data from database for enrichment
    String? taxonomy;
    String? ecology;
    String? safety;

    try {
      final plants = await _plantService.getAllPlants();
      Plant? matchingPlant;

      // Try exact match first
      try {
        matchingPlant = plants.firstWhere(
          (p) => p.scientificName.toLowerCase() == scientificName.toLowerCase(),
        );
      } catch (e) {
        // Try partial match
        try {
          matchingPlant = plants.firstWhere(
            (p) =>
                p.scientificName
                    .toLowerCase()
                    .contains(scientificName.toLowerCase()) ||
                scientificName
                    .toLowerCase()
                    .contains(p.scientificName.toLowerCase()),
          );
        } catch (e2) {
          // No match found
          matchingPlant = null;
        }
      }

      // Only use if we found a matching plant
      if (matchingPlant != null) {
        taxonomy = _formatTaxonomy(matchingPlant);
        ecology = _formatEcology(matchingPlant);
        safety = _formatSafety(matchingPlant);
      }
    } catch (e) {
      _logger.w('Could not enrich fallback explanation with plant data: $e');
    }

    return PlantExplanation(
      identification:
          "The model identified this as $plantName ($scientificName) with ${confidencePercent}% confidence. The visual features detected in the image match characteristics typical of this plant species. Review the heatmap visualization to see which areas the AI model focused on during identification.",
      medicinalUses:
          "This plant may have traditional medicinal uses, but specific information is not available in the current database. Please consult with a qualified herbalist or healthcare provider for information about medicinal properties and usage.",
      usability:
          "**Status: $usabilityStatus**\n\n$usabilityGuidance\n\n**Important Notes:**\n- Examine the heatmap visualization carefully - red/hot areas may indicate disease, brown spots, or damaged plant parts\n- If the heatmap shows concentrated attention on specific areas, this may indicate health issues\n- Always verify plant identification with an expert before use\n- Do not use plants showing signs of disease or damage",
      taxonomy: taxonomy,
      ecology: ecology,
      safety: safety,
    );
  }

  /// Get explanation from Gemini API (online)
  /// Optionally enriches with plant data from database
  Future<String?> getExplanationOnline({
    required String plantName,
    required String scientificName,
    required double confidence,
    required List<Map<String, dynamic>> predictions,
    String? imagePath,
    bool enrichWithPlantData = true,
  }) async {
    try {
      // Check if Gemini API is available
      if (!await _geminiService.isAvailable()) {
        _logger.w('Gemini API not available (API key not configured)');
        return null;
      }

      _logger.d('Generating online explanation from Gemini API...');

      // Get plant data for enrichment if available
      Plant? plantData;
      if (enrichWithPlantData) {
        try {
          final plants = await _plantService.getAllPlants();

          // Try exact match first
          try {
            plantData = plants.firstWhere(
              (p) =>
                  p.scientificName.toLowerCase() ==
                  scientificName.toLowerCase(),
            );
          } catch (e) {
            // Try partial match
            try {
              plantData = plants.firstWhere(
                (p) =>
                    p.scientificName
                        .toLowerCase()
                        .contains(scientificName.toLowerCase()) ||
                    scientificName
                        .toLowerCase()
                        .contains(p.scientificName.toLowerCase()),
              );
            } catch (e2) {
              // No match found
              plantData = null;
            }
          }
        } catch (e) {
          _logger.w('Could not fetch plant data for enrichment: $e');
          plantData = null;
        }
      }

      final explanation = await _geminiService.generateExplanation(
        plantName: plantName,
        scientificName: scientificName,
        confidence: confidence,
        predictions: predictions,
        imagePath: imagePath,
        plantData: plantData,
      );

      if (explanation != null) {
        _logger.i('Successfully generated online explanation');
        return explanation;
      }

      _logger.w('Failed to generate online explanation');
      return null;
    } catch (e) {
      _logger.e('Error generating online explanation: $e');
      return null;
    }
  }

  /// Main method to generate explanation (routes to offline/online based on connectivity)
  ///
  /// Parameters:
  /// - plantName: Common name of the plant
  /// - scientificName: Scientific name of the plant
  /// - confidence: Confidence score (0-1)
  /// - predictions: List of top predictions
  /// - imagePath: Optional path to plant image
  /// - isOnline: Whether device is online
  /// - forceOnline: Force online explanation even if offline explanation exists
  ///
  /// Returns: Explanation text or null
  Future<String?> generateExplanation({
    required String plantName,
    required String scientificName,
    required double confidence,
    required List<Map<String, dynamic>> predictions,
    String? imagePath,
    required bool isOnline,
    bool forceOnline = false,
  }) async {
    try {
      // Try online first if available and requested
      if (isOnline && (forceOnline || await _geminiService.isAvailable())) {
        _logger.d('Attempting online explanation generation...');
        final onlineExplanation = await getExplanationOnline(
          plantName: plantName,
          scientificName: scientificName,
          confidence: confidence,
          predictions: predictions,
          imagePath: imagePath,
        );

        if (onlineExplanation != null) {
          return onlineExplanation;
        }

        // Fallback to offline if online fails
        _logger.d('Online explanation failed, falling back to offline...');
      }

      // Use offline explanation
      _logger.d('Using offline explanation...');
      final offlineExplanation = await getExplanationOffline(
        scientificName,
        enrichWithPlantData: true,
      );

      if (offlineExplanation != null) {
        return offlineExplanation.formattedExplanation;
      }

      // Generate fallback explanation if plant is not in offline JSON
      _logger.d(
          'No offline explanation found, generating fallback explanation...');
      final fallbackExplanation = await _generateFallbackExplanation(
        plantName: plantName,
        scientificName: scientificName,
        confidence: confidence,
      );
      return fallbackExplanation.formattedExplanation;
    } catch (e) {
      _logger.e('Error generating explanation: $e');
      return null;
    }
  }

  /// Load offline explanations from JSON asset
  Future<void> _loadOfflineExplanations() async {
    try {
      _logger.d('Loading offline explanations from JSON...');

      final jsonString =
          await rootBundle.loadString('assets/data/plant_explanations.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      _offlineExplanationsCache = {};

      jsonData.forEach((scientificName, data) {
        final explanationData = data as Map<String, dynamic>;
        _offlineExplanationsCache![scientificName] = PlantExplanation(
          identification: explanationData['identification'] as String? ?? '',
          medicinalUses: explanationData['medicinal_uses'] as String? ?? '',
          usability: explanationData['usability'] as String? ?? '',
          taxonomy: explanationData['taxonomy'] as String?,
          ecology: explanationData['ecology'] as String?,
          safety: explanationData['safety'] as String?,
        );
      });

      _logger.i(
          'Loaded ${_offlineExplanationsCache!.length} offline explanations');
    } catch (e) {
      _logger.e('Error loading offline explanations: $e');
      _offlineExplanationsCache = {};
    }
  }

  /// Clear the offline explanations cache (useful for testing or reloading)
  void clearCache() {
    _offlineExplanationsCache = null;
    _logger.d('Cleared offline explanations cache');
  }
}
