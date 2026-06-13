/// Deterministic safety profile for a plant (Contraindication Engine).
/// Single source of truth for safety data; never from LLM at runtime.
class SafetyProfile {
  final String plantId;
  final String name;
  final bool isGenerallySafe;
  final bool pregnancyWarning;
  final List<String> knownSideEffects;
  final List<String> drugInteractions;
  final List<String> strictContraindications;
  /// When true, show a prominent "use with strict caution" warning (e.g. Kamias, Kamoteng Kahoy, Kakawate).
  final bool needsStrictContraindications;

  const SafetyProfile({
    required this.plantId,
    required this.name,
    required this.isGenerallySafe,
    required this.pregnancyWarning,
    required this.knownSideEffects,
    required this.drugInteractions,
    required this.strictContraindications,
    this.needsStrictContraindications = false,
  });

  factory SafetyProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['safety_profile'] as Map<String, dynamic>? ?? json;
    final strict = profile['needs_strict_contraindications'];
    final needsStrict = strict is bool
        ? strict
        : (strict == true || strict == 1 || strict == 'true');
    return SafetyProfile(
      plantId: json['plant_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isGenerallySafe: profile['is_generally_safe'] as bool? ?? true,
      pregnancyWarning: profile['pregnancy_warning'] as bool? ?? false,
      knownSideEffects: (profile['known_side_effects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      drugInteractions: (profile['drug_interactions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      strictContraindications:
          (profile['strict_contraindications'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
      needsStrictContraindications: needsStrict,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plant_id': plantId,
      'name': name,
      'safety_profile': {
        'is_generally_safe': isGenerallySafe,
        'pregnancy_warning': pregnancyWarning,
        'known_side_effects': knownSideEffects,
        'drug_interactions': drugInteractions,
        'strict_contraindications': strictContraindications,
        'needs_strict_contraindications': needsStrictContraindications,
      },
    };
  }

  bool get hasWarnings =>
      pregnancyWarning ||
      knownSideEffects.isNotEmpty ||
      drugInteractions.isNotEmpty ||
      strictContraindications.isNotEmpty;
}
