/// Static habitat data for a plant: known coordinates and optional metadata.
/// Used for the Habitat Map feature; no live API—data from assets or Supabase.
class PlantHabitat {
  final String plantId;
  final List<HabitatPoint> knownCoordinates;
  final List<String> regionNames;
  final String climateNotes;

  const PlantHabitat({
    required this.plantId,
    required this.knownCoordinates,
    this.regionNames = const [],
    this.climateNotes = '',
  });

  factory PlantHabitat.fromJson(Map<String, dynamic> json) {
    final coords = json['known_coordinates'] as List<dynamic>?;
    final regions = json['region_names'] as List<dynamic>?;
    return PlantHabitat(
      plantId: json['plant_id'] as String? ?? '',
      knownCoordinates: coords != null
          ? coords
              .map((e) => HabitatPoint.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      regionNames: regions?.map((e) => e.toString()).toList() ?? [],
      climateNotes: json['climate_notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plant_id': plantId,
      'known_coordinates':
          knownCoordinates.map((e) => e.toJson()).toList(),
      'region_names': regionNames,
      'climate_notes': climateNotes,
    };
  }

  bool get hasCoordinates => knownCoordinates.isNotEmpty;
}

/// A single lat/lng point representing a known habitat or cultivation zone.
class HabitatPoint {
  final double lat;
  final double lng;

  const HabitatPoint({required this.lat, required this.lng});

  factory HabitatPoint.fromJson(Map<String, dynamic> json) {
    return HabitatPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}
