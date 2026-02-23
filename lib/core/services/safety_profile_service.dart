import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/safety_profile.dart';

/// Single source of truth for deterministic safety data (Contraindication Engine).
/// Loads from assets/data/safety_profiles.json; no LLM at runtime.
class SafetyProfileService {
  static final SafetyProfileService _instance = SafetyProfileService._internal();
  factory SafetyProfileService() => _instance;
  SafetyProfileService._internal();

  Map<String, SafetyProfile>? _byKey;
  Map<String, SafetyProfile>? _byPlantId;

  static String _normalizeKey(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'[\s\-/]+'), '')
        .replaceAll(' ', '');
  }

  Future<void> _ensureLoaded() async {
    if (_byKey != null) return;
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/safety_profiles.json');
      final Map<String, dynamic> data =
          jsonDecode(jsonString) as Map<String, dynamic>;
      _byKey = {};
      _byPlantId = {};
      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value as Map<String, dynamic>;
        value['plant_id'] ??= '${_normalizeKey(key).toLowerCase()}-001';
        value['name'] ??= key;
        final profile = SafetyProfile.fromJson(value);
        _byKey![key] = profile;
        _byPlantId![profile.plantId] = profile;
        final normalized = _normalizeKey(key);
        if (!_byKey!.containsKey(normalized)) {
          _byKey![normalized] = profile;
        }
      }
    } catch (e) {
      _byKey = {};
      _byPlantId = {};
    }
  }

  /// Get safety profile by Plant (uses id then commonName).
  Future<SafetyProfile?> getSafetyProfile(Plant plant) async {
    await _ensureLoaded();
    if (_byPlantId == null || _byKey == null) return null;
    final byId = _byPlantId![plant.id];
    if (byId != null) return byId;
    final byName = _byKey![plant.commonName] ?? _byKey![_normalizeKey(plant.commonName)];
    return byName;
  }

  /// Get safety profile by plant id (e.g. lagundi-001).
  Future<SafetyProfile?> getSafetyProfileByPlantId(String plantId) async {
    await _ensureLoaded();
    return _byPlantId?[plantId];
  }

  /// Get safety profile by common name or prediction label (e.g. Bawang, AloeVera, Lagundi).
  Future<SafetyProfile?> getSafetyProfileByCommonName(String name) async {
    if (name.isEmpty) return null;
    await _ensureLoaded();
    if (_byKey == null) return null;
    final trimmed = name.trim();
    return _byKey![trimmed] ?? _byKey![_normalizeKey(trimmed)];
  }
}
