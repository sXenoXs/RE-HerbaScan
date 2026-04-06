import 'package:flutter/material.dart' show Matrix4, Offset, Rect, Size;
import 'package:herbascan/core/models/plant_anatomy_part.dart';

/// Pads the target size by this factor so the silhouette doesn't touch edges.
const double kAnatomyScalePadding = 0.9;

/// Computes the union of bounds of all parts' paths.
Rect _computeBounds(List<PlantAnatomyPart> parts) {
  if (parts.isEmpty) return Rect.zero;
  Rect? union;
  for (final part in parts) {
    final bounds = part.path.getBounds();
    if (bounds.width.isFinite &&
        bounds.height.isFinite &&
        bounds.width > 0 &&
        bounds.height > 0) {
      union = union == null ? bounds : union.expandToInclude(bounds);
    }
  }
  return union ?? Rect.zero;
}

/// Scales anatomy parts to fit inside [targetSize] while keeping proportions.
/// Returns a new list of parts with transformed paths (draw order unchanged).
/// Uses a single scale factor (min of scaleX, scaleY) and centers the result.
List<PlantAnatomyPart> scaleAnatomyToFit(
  List<PlantAnatomyPart> parts,
  Size targetSize,
) {
  if (parts.isEmpty || targetSize.width <= 0 || targetSize.height <= 0) {
    return parts;
  }

  final bounds = _computeBounds(parts);
  if (bounds.width <= 0 || bounds.height <= 0) return parts;

  final paddedWidth = targetSize.width * kAnatomyScalePadding;
  final paddedHeight = targetSize.height * kAnatomyScalePadding;
  final scaleX = paddedWidth / bounds.width;
  final scaleY = paddedHeight / bounds.height;
  final scale = scaleX < scaleY ? scaleX : scaleY;

  final center = bounds.center;
  final targetCenter = Offset(targetSize.width / 2, targetSize.height / 2);

  final matrix = Matrix4.identity()
    ..translate(targetCenter.dx, targetCenter.dy)
    ..scale(scale)
    ..translate(-center.dx, -center.dy);

  return parts.map((part) {
    final transformedPath = part.path.transform(matrix.storage);
    return part.copyWith(path: transformedPath);
  }).toList();
}
