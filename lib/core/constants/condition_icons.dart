import "package:flutter/material.dart";

/// Registry of icon_key (String) to IconData for Condition Search and admin.
/// Condition names in catalog_conditions use these keys; UI looks up icon here.
/// Icon keys for admin dropdown (20–30 predefined Material icons per PRD).
final Map<String, IconData> conditionIconRegistry = {
  'sick': Icons.sick,
  'air': Icons.air,
  'thermostat': Icons.thermostat,
  'healing': Icons.healing,
  'water_drop': Icons.water_drop,
  'favorite': Icons.favorite,
  'local_hospital': Icons.local_hospital,
  'bubble_chart': Icons.bubble_chart,
  'medical_services': Icons.medical_services,
  'restaurant': Icons.restaurant,
  'spa': Icons.spa,
  'accessibility_new': Icons.accessibility_new,
  'local_fire_department': Icons.local_fire_department,
  'bug_report': Icons.bug_report,
  'vaccines': Icons.vaccines,
  'medication': Icons.medication,
  'coronavirus': Icons.coronavirus,
  'bloodtype': Icons.bloodtype,
  'psychology': Icons.psychology,
  'self_improvement': Icons.self_improvement,
  'bedtime': Icons.bedtime,
  'local_dining': Icons.local_dining,
  'fitness_center': Icons.fitness_center,
  'sanitizer': Icons.sanitizer,
  'clean_hands': Icons.clean_hands,
  'elderly': Icons.elderly,
  'child_care': Icons.child_care,
};

/// Returns IconData for a condition icon_key; fallback to Icons.healing.
IconData getConditionIcon(String iconKey) {
  return conditionIconRegistry[iconKey] ?? Icons.healing;
}
