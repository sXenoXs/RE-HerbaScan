import 'dart:convert';
import 'dart:ui';

import 'package:herbascan/core/utils/svg_path_parser.dart';

/// A single anatomy part for the 2D Interactive Plant Silhouette.
/// Data comes from DB (catalog_plant_anatomy); path is parsed from svg_path in fromMap.
class PlantAnatomyPart {
  final String id;
  final String plantId;
  final String partName;
  final Path path;
  final Color color;
  final int zIndex;
  final bool isInteractive;
  final String title;
  final String description;
  final List<String> conditions;

  const PlantAnatomyPart({
    required this.id,
    required this.plantId,
    required this.partName,
    required this.path,
    required this.color,
    this.zIndex = 0,
    this.isInteractive = true,
    this.title = '',
    this.description = '',
    this.conditions = const [],
  });

  /// Builds from SQLite/Supabase row. Parses [svg_path] to [Path] and [color_hex] to [Color].
  factory PlantAnatomyPart.fromMap(Map<String, dynamic> row) {
    final svgPath = row['svg_path'] as String? ?? '';
    final path = parseSvgPath(svgPath);
    final colorHex = row['color_hex'] as String? ?? '4CAF50';
    final color = colorFromHex(colorHex);

    List<String> conditionsList = [];
    final conditionsRaw = row['conditions'];
    if (conditionsRaw is List) {
      conditionsList = conditionsRaw.map((e) => e.toString()).toList();
    } else if (conditionsRaw is String && conditionsRaw.isNotEmpty && conditionsRaw != '[]') {
      try {
        final decoded = jsonDecode(conditionsRaw) as List<dynamic>?;
        if (decoded != null) {
          conditionsList = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    final zIndexRaw = row['z_index'];
    final zIndex = zIndexRaw is int ? zIndexRaw : int.tryParse(zIndexRaw.toString()) ?? 0;
    final isInteractive = row['is_interactive'] == true ||
        row['is_interactive'] == 1;

    return PlantAnatomyPart(
      id: row['id'] as String? ?? '',
      plantId: row['plant_id'] as String? ?? '',
      partName: row['part_name'] as String? ?? '',
      path: path,
      color: color,
      zIndex: zIndex,
      isInteractive: isInteractive,
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      conditions: conditionsList,
    );
  }

  /// Returns a copy with a new [path] (e.g. after scaling).
  PlantAnatomyPart copyWith({Path? path}) {
    return PlantAnatomyPart(
      id: id,
      plantId: plantId,
      partName: partName,
      path: path ?? this.path,
      color: color,
      zIndex: zIndex,
      isInteractive: isInteractive,
      title: title,
      description: description,
      conditions: conditions,
    );
  }
}
