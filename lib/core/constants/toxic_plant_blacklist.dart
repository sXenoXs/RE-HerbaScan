import 'package:herbascan/core/models/scan_result.dart';

/// Canonical blacklist keys for highly toxic plants (match class_indices.json).
/// These plants must never be shown as recommended or safe; show toxic warning instead.
const Set<String> toxicPlantBlacklist = {'Adelfa', 'IpilIpil', 'TubaTuba'};

/// Normalizes a prediction label to a canonical key for blacklist lookup.
/// Handles backend/offline variants like "Ipil-Ipil", "Tuba-tuba", "ipil ipil".
/// Returns the matching canonical key if the label maps to a blacklisted plant,
/// or another key from [classIndicesKeys] if found; otherwise null.
String? normalizeToCanonicalKey(String? label, {Set<String>? classIndicesKeys}) {
  if (label == null || label.trim().isEmpty) return null;
  final normalized = label
      .trim()
      .replaceAll(RegExp(r'[\s\-]+'), '')
      .toLowerCase();

  // Direct match against blacklist (canonical keys are PascalCase)
  for (final key in toxicPlantBlacklist) {
    if (key.toLowerCase() == normalized) return key;
  }

  // Common display variants (normalized = no spaces/hyphens, lowercased) -> canonical
  const variants = {
    'adelfa': 'Adelfa',
    'ipilipil': 'IpilIpil',
    'tubatuba': 'TubaTuba',
  };
  final fromVariants = variants[normalized];
  if (fromVariants != null) return fromVariants;

  // If we have class indices keys, try to match (e.g. "Ipil-Ipil" -> IpilIpil in set)
  if (classIndicesKeys != null && classIndicesKeys.isNotEmpty) {
    for (final key in classIndicesKeys) {
      if (key.toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '') == normalized) {
        return key;
      }
    }
  }

  return null;
}

/// Returns true if the top prediction in [predictions] is blacklisted.
/// [predictions] is the list of maps from CameraProvider (plantName / label).
bool isTopPredictionBlacklisted(List<Map<String, dynamic>> predictions) {
  if (predictions.isEmpty) return false;
  final top = predictions.first;
  final label = top['plantName'] as String? ?? top['label'] as String?;
  final canonical = normalizeToCanonicalKey(label);
  return canonical != null && toxicPlantBlacklist.contains(canonical);
}

/// Returns true if the scan's top prediction is blacklisted.
bool isScanResultTopPredictionBlacklisted(ScanResult scan) {
  final top = scan.topPrediction;
  if (top == null) return false;
  final canonical = normalizeToCanonicalKey(top.plantName);
  return canonical != null && toxicPlantBlacklist.contains(canonical);
}

/// Display name for a detected toxic plant (e.g. "Adelfa (Nerium oleander)").
/// Uses [canonicalKey] or normalized [label]; scientific names can be added later.
String toxicPlantDisplayName(String? label) {
  if (label == null || label.trim().isEmpty) return 'Toxic plant';
  final canonical = normalizeToCanonicalKey(label);
  final key = canonical ?? label.trim();
  const scientific = {
    'Adelfa': 'Nerium oleander',
    'IpilIpil': 'Leucaena leucocephala',
    'TubaTuba': 'Jatropha curcas',
  };
  final sci = scientific[key];
  return sci != null ? '$key ($sci)' : key;
}
