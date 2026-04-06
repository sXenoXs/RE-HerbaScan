class Plant {
  final String id;
  final String commonName;
  final String scientificName;
  final String localName;
  final String englishName; // English/common English name
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
  /// Optional Supabase Storage URL for admin-uploaded image. When set, app uses CachedNetworkImage.
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Plant({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.localName,
    required this.englishName,
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
    this.imageUrl,
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
      englishName: json['englishName'] ?? '',
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
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
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
      'englishName': englishName,
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
      if (imageUrl != null) 'imageUrl': imageUrl,
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

/// Optional schedule for calendar export (frequency_hours, duration_days).
class PreparationSchedule {
  final String dosage;
  final int frequencyHours;
  final int durationDays;

  const PreparationSchedule({
    required this.dosage,
    required this.frequencyHours,
    required this.durationDays,
  });

  factory PreparationSchedule.fromJson(Map<String, dynamic> json) {
    return PreparationSchedule(
      dosage: json['dosage'] as String? ?? '',
      frequencyHours: json['frequency_hours'] as int? ?? 24,
      durationDays: json['duration_days'] as int? ?? 7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dosage': dosage,
      'frequency_hours': frequencyHours,
      'duration_days': durationDays,
    };
  }
}

/// Per-step detail for interactive guide (optional timer).
class PreparationStepDetail {
  final String instruction;
  final bool hasTimer;
  final int? timerDurationSeconds;

  const PreparationStepDetail({
    required this.instruction,
    this.hasTimer = false,
    this.timerDurationSeconds,
  });

  factory PreparationStepDetail.fromJson(Map<String, dynamic> json) {
    return PreparationStepDetail(
      instruction: json['instruction'] as String? ?? '',
      hasTimer: json['has_timer'] as bool? ?? false,
      timerDurationSeconds: json['timer_duration_seconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instruction': instruction,
      'has_timer': hasTimer,
      if (timerDurationSeconds != null) 'timer_duration_seconds': timerDurationSeconds,
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
  /// Optional: per-step instructions with timer metadata. If non-null and non-empty, use instead of [steps] for display.
  final List<PreparationStepDetail>? stepDetails;
  /// Optional: structured schedule for calendar export. If null, use dosage/frequency/duration strings only.
  final PreparationSchedule? schedule;

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
    this.stepDetails,
    this.schedule,
  });

  /// Ordered list of step instructions to show (from stepDetails or steps).
  List<String> get stepInstructions {
    if (stepDetails != null && stepDetails!.isNotEmpty) {
      return stepDetails!.map((s) => s.instruction).toList();
    }
    return steps;
  }

  /// True if any step has a timer.
  bool get hasAnyTimer =>
      stepDetails != null &&
      stepDetails!.any((s) => s.hasTimer && (s.timerDurationSeconds ?? 0) > 0);

  factory PreparationMethod.fromJson(Map<String, dynamic> json) {
    List<PreparationStepDetail>? stepDetails;
    if (json['stepDetails'] != null && json['stepDetails'] is List) {
      stepDetails = (json['stepDetails'] as List<dynamic>)
          .map((e) => PreparationStepDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    PreparationSchedule? schedule;
    if (json['schedule'] != null && json['schedule'] is Map) {
      schedule = PreparationSchedule.fromJson(json['schedule'] as Map<String, dynamic>);
    }
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
      stepDetails: stepDetails,
      schedule: schedule,
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
      if (stepDetails != null) 'stepDetails': stepDetails!.map((s) => s.toJson()).toList(),
      if (schedule != null) 'schedule': schedule!.toJson(),
    };
  }
}
