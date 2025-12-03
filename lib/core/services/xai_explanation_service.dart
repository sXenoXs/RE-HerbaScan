import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
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

    return buffer.toString();
  }
}

class XAIExplanationService {
  static final XAIExplanationService _instance = XAIExplanationService._internal();
  factory XAIExplanationService() => _instance;
  XAIExplanationService._internal();

  final Logger _logger = Logger();
  final PlantService _plantService = PlantService();

  // Cache for offline explanations
  Map<String, PlantExplanation>? _offlineExplanationsCache;

  /// COMPATIBILITY FIX: Restored all parameters to match your existing app calls
  Future<String?> generateExplanation({
    required String plantName,
    required String scientificName, // Restored
    required double confidence,
    List<Map<String, dynamic>>? predictions, // Restored (optional)
    String? imagePath, // Restored (optional)
    bool isOnline = false, // Restored (optional)
    bool forceOnline = false, // Restored (optional)
  }) async {
    try {
      // 1. Try to get detailed explanation from JSON using Scientific Name
      // (This is usually the most accurate key in TFLite class indices)
      final offlineExplanation = await getExplanationOffline(
        scientificName,
        enrichWithPlantData: true,
      );

      if (offlineExplanation != null) {
        return offlineExplanation.formattedExplanation;
      }

      // 2. If not found, try using the Common Name (plantName)
      final commonNameExplanation = await getExplanationOffline(
        plantName,
        enrichWithPlantData: true,
      );

      if (commonNameExplanation != null) {
        return commonNameExplanation.formattedExplanation;
      }

      // 3. Fallback
      _logger.d('No offline explanation found, generating fallback...');
      final fallback = await _generateFallbackExplanation(
        plantName: plantName,
        scientificName: scientificName,
        confidence: confidence,
      );
      return fallback.formattedExplanation;

    } catch (e) {
      _logger.e('Error generating explanation: $e');
      return "Could not generate explanation details.";
    }
  }

  Future<PlantExplanation?> getExplanationOffline(
      String keyName, {
        bool enrichWithPlantData = true,
      }) async {
    try {
      if (_offlineExplanationsCache == null) {
        await _loadOfflineExplanations();
      }

      var explanation = _offlineExplanationsCache?[keyName];

      // Case-insensitive fallback
      if (explanation == null) {
        final key = _offlineExplanationsCache!.keys.firstWhere(
              (k) => k.toLowerCase() == keyName.toLowerCase(),
          orElse: () => '',
        );
        if (key.isNotEmpty) explanation = _offlineExplanationsCache![key];
      }

      if (explanation == null) {
        return null;
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
              identification: explanation!.identification,
              medicinalUses: explanation.medicinalUses,
              usability: explanation.usability,
              taxonomy: explanation.taxonomy ?? _formatTaxonomy(matchingPlant),
              ecology: explanation.ecology ?? _formatEcology(matchingPlant),
              safety: explanation.safety ?? _formatSafety(matchingPlant),
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
      final jsonString = await rootBundle.loadString('assets/data/plant_explanations.json');
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
    if (plant.habitat.isNotEmpty) buffer.writeln('**Habitat:** ${plant.habitat}');
    return buffer.toString().trim();
  }

  String _formatSafety(Plant plant) {
    if (plant.safetyWarnings.isEmpty) return 'Consult a healthcare provider before use.';
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
      identification: "Identified as $plantName ($scientificName) with $confidencePercent% confidence.",
      medicinalUses: "Specific medicinal details for this plant are not currently in the offline database.",
      usability: "Please consult a local expert before using this plant.",
      taxonomy: null,
      ecology: null,
      safety: null,
    );
  }
}