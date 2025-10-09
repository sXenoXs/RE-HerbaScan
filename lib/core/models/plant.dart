class Plant {
  final String id;
  final String commonName;
  final String scientificName;
  final String localName;
  final String family;
  final String genus;
  final String species;
  final bool isDOHApproved;
  final String morphology;
  final String ecology;
  final String habitat;
  final List<MedicinalUse> medicinalUses;
  final List<PreparationMethod> preparationMethods;
  final List<String> safetyWarnings;
  final String imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Plant({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.localName,
    required this.family,
    required this.genus,
    required this.species,
    required this.isDOHApproved,
    required this.morphology,
    required this.ecology,
    required this.habitat,
    required this.medicinalUses,
    required this.preparationMethods,
    required this.safetyWarnings,
    required this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor from JSON
  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'] ?? '',
      commonName: json['commonName'] ?? '',
      scientificName: json['scientificName'] ?? '',
      localName: json['localName'] ?? '',
      family: json['family'] ?? '',
      genus: json['genus'] ?? '',
      species: json['species'] ?? '',
      isDOHApproved: json['isDOHApproved'] ?? false,
      morphology: json['morphology'] ?? '',
      ecology: json['ecology'] ?? '',
      habitat: json['habitat'] ?? '',
      medicinalUses: (json['medicinalUses'] as List<dynamic>?)
          ?.map((use) => MedicinalUse.fromJson(use))
          .toList() ?? [],
      preparationMethods: (json['preparationMethods'] as List<dynamic>?)
          ?.map((method) => PreparationMethod.fromJson(method))
          .toList() ?? [],
      safetyWarnings: (json['safetyWarnings'] as List<dynamic>?)
          ?.cast<String>() ?? [],
      imagePath: json['imagePath'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commonName': commonName,
      'scientificName': scientificName,
      'localName': localName,
      'family': family,
      'genus': genus,
      'species': species,
      'isDOHApproved': isDOHApproved,
      'morphology': morphology,
      'ecology': ecology,
      'habitat': habitat,
      'medicinalUses': medicinalUses.map((use) => use.toJson()).toList(),
      'preparationMethods': preparationMethods.map((method) => method.toJson()).toList(),
      'safetyWarnings': safetyWarnings,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Get display name based on language
  String getDisplayName(String languageCode) {
    switch (languageCode) {
      case 'fil':
        return localName.isNotEmpty ? localName : commonName;
      default:
        return commonName;
    }
  }

  // Get scientific classification
  String get scientificClassification {
    return '$genus $species';
  }

  // Get full taxonomy
  String get fullTaxonomy {
    return 'Kingdom: Plantae\nFamily: $family\nGenus: $genus\nSpecies: $species';
  }

  // Check if plant treats specific condition
  bool treatsCondition(String condition) {
    return medicinalUses.any((use) => 
        use.condition.toLowerCase().contains(condition.toLowerCase()));
  }

  // Get preparation methods for specific condition
  List<PreparationMethod> getPreparationMethodsForCondition(String condition) {
    return preparationMethods.where((method) => 
        method.condition.toLowerCase().contains(condition.toLowerCase())).toList();
  }
}

class MedicinalUse {
  final String condition;
  final String description;
  final String effectiveness;
  final List<String> activeCompounds;
  final String dosage;
  final String duration;

  MedicinalUse({
    required this.condition,
    required this.description,
    required this.effectiveness,
    required this.activeCompounds,
    required this.dosage,
    required this.duration,
  });

  factory MedicinalUse.fromJson(Map<String, dynamic> json) {
    return MedicinalUse(
      condition: json['condition'] ?? '',
      description: json['description'] ?? '',
      effectiveness: json['effectiveness'] ?? '',
      activeCompounds: (json['activeCompounds'] as List<dynamic>?)
          ?.cast<String>() ?? [],
      dosage: json['dosage'] ?? '',
      duration: json['duration'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'description': description,
      'effectiveness': effectiveness,
      'activeCompounds': activeCompounds,
      'dosage': dosage,
      'duration': duration,
    };
  }
}

class PreparationMethod {
  final String id;
  final String condition;
  final String title;
  final String description;
  final List<String> steps;
  final String dosage;
  final String frequency;
  final String duration;
  final List<String> warnings;
  final String preparationType; // tea, decoction, poultice, etc.

  PreparationMethod({
    required this.id,
    required this.condition,
    required this.title,
    required this.description,
    required this.steps,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.warnings,
    required this.preparationType,
  });

  factory PreparationMethod.fromJson(Map<String, dynamic> json) {
    return PreparationMethod(
      id: json['id'] ?? '',
      condition: json['condition'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      steps: (json['steps'] as List<dynamic>?)?.cast<String>() ?? [],
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
      duration: json['duration'] ?? '',
      warnings: (json['warnings'] as List<dynamic>?)?.cast<String>() ?? [],
      preparationType: json['preparationType'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'condition': condition,
      'title': title,
      'description': description,
      'steps': steps,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'warnings': warnings,
      'preparationType': preparationType,
    };
  }
}
