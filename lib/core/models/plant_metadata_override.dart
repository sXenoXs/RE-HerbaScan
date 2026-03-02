/// One row from public.plant_metadata (admin-editable override for a plant).
class PlantMetadataOverride {
  final String plantId;
  final String? description;
  final String? safetyWarnings;
  final String? preparationStepsJson;
  final DateTime? updatedAt;

  PlantMetadataOverride({
    required this.plantId,
    this.description,
    this.safetyWarnings,
    this.preparationStepsJson,
    this.updatedAt,
  });

  factory PlantMetadataOverride.fromJson(Map<String, dynamic> json) {
    return PlantMetadataOverride(
      plantId: json['plant_id'] as String,
      description: json['description'] as String?,
      safetyWarnings: json['safety_warnings'] as String?,
      preparationStepsJson: json['preparation_steps_json'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plant_id': plantId,
      'description': description,
      'safety_warnings': safetyWarnings,
      'preparation_steps_json': preparationStepsJson,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
