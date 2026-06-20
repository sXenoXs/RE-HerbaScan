import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Traces a plant part image into an SVG path d="..." string.
/// [imageBytes]   Raw image bytes (JPEG, PNG, etc.)
/// [threshold]    0–255 bitmask threshold (default 128). Pixels darker than
///                this value become foreground. Adjust with the UI slider.
/// [blur]         0–15 Gaussian blur radius applied before thresholding.
///                Reduces jagged edges on detailed photos (default 2).
/// [invert]       If true, traces light areas instead of dark areas.
/// [simplify]     Ramer-Douglas-Peucker epsilon (default 1.5).
///                Lower = more detail, higher = smoother path.
///
/// Returns: SVG path d="..." string normalized to 300×300 coordinate space.
/// Throws: [SvgTracerException] if the image cannot be decoded.
class SvgTracerService {
  SvgTracerService._();
  static final SvgTracerService _instance = SvgTracerService._();
  factory SvgTracerService() => _instance;

  /// Traces a plant part image into an SVG path d="..." string.
  static Future<String> traceToSvgPath({
    required Uint8List imageBytes,
    int threshold = 128,
    int blur = 2,
    bool invert = false,
    double simplify = 1.5,
    int ignoreLessThan = 20,
    int smoothness = 0,
  }) async {
    return compute(_traceToSvgPath, {
      'imageBytes': imageBytes,
      'threshold': threshold,
      'blur': blur,
      'invert': invert,
      'simplify': simplify,
      'ignoreLessThan': ignoreLessThan,
      'smoothness': smoothness,
    });
  }
}

class SvgTracerException implements Exception {
  final String message;
  const SvgTracerException(this.message);

  @override
  String toString() => 'SvgTracerException: $message';
}

/// Internal function that performs the actual tracing.
/// This runs in a separate isolate via [compute].
String _traceToSvgPath(Map<String, dynamic> args) {
  final imageBytes = args['imageBytes'] as Uint8List;
  final threshold = args['threshold'] as int;
  final blur = args['blur'] as int;
  final invert = args['invert'] as bool;
  final simplify = args['simplify'] as double;
  final ignoreLessThan = args['ignoreLessThan'] as int;
  final smoothness = args['smoothness'] as int;

  try {
    // Step 1: Decode & resize to 300×300 using `image` package
    final img.Image decoded = img.decodeImage(imageBytes)!;
    if (decoded == null) {
      throw const SvgTracerException('Failed to decode image');
    }
    final img.Image resized =
        img.copyResize(decoded, width: 300, height: 300);

    // Step 2: Apply blur (if blur > 0)
    final img.Image blurred = blur > 0
        ? img.gaussianBlur(resized, radius: blur)
        : resized;

    // Step 3: Convert to grayscale bitmask (foreground = dark pixels by default)
    final bitmask = _buildBitmask(blurred, threshold, invert);
    // Returns List<List<int>> of 0/1 values (302×302 with 1-pixel border of 0)

    // Step 4: Boundary trace (Moore neighbourhood contour following)
    final contours = _traceContours(bitmask, ignoreLessThan);

    // Step 5: Ramer-Douglas-Peucker simplification
    final simplified =
        contours.map((c) => _simplify(c, simplify)).toList();

    // Step 5b: Smoothness (Laplacian filter on path)
    final smoothed = smoothness > 0
        ? simplified.map((c) => _smooth(c, smoothness)).toList()
        : simplified;

    // Step 6: Convert to SVG path commands
    return _toSvgPathString(smoothed);
    // Returns: "M x y L x y ... Z M x y L x y ... Z"
  } on SvgTracerException {
    rethrow;
  } catch (e) {
    throw SvgTracerException('Unexpected error during tracing: $e');
  }
}

/// Step 3: Build bitmask from image.
/// Returns a 2D list with a 1-pixel border of 0s around the image.
List<List<int>> _buildBitmask(
    img.Image image, int threshold, bool invert) {
  final width = image.width;
  final height = image.height;
  // Create bitmask with 1-pixel border
  final List<List<int>> bitmask =
      List.generate(height + 2, (_) => List.filled(width + 2, 0));

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = image.getPixel(x, y);
      final intensity = img.getLuminance(pixel);
      final isForeground = invert ? intensity > threshold : intensity < threshold;
      bitmask[y + 1][x + 1] = isForeground ? 1 : 0;
    }
  }

  return bitmask;
}

/// Step 4: Boundary walk (Moore neighborhood contour tracing).
/// Returns list of contours, where each contour is a list of (x,y) points.
List<List<({int x, int y})>> _traceContours(List<List<int>> bitmask, int ignoreLessThan) {
  final height = bitmask.length;
  final width = bitmask[0].length;
  final visited = List.generate(height, (_) => List.filled(width, false));
  final contours = <List<({int x, int y})>>[];

  // 8-connected offsets in clockwise order
  final List<({int dx, int dy})> moore = [
    (dx: -1, dy: -1), // 0: Top-Left
    (dx: 0, dy: -1),  // 1: Top
    (dx: 1, dy: -1),  // 2: Top-Right
    (dx: 1, dy: 0),   // 3: Right
    (dx: 1, dy: 1),   // 4: Bottom-Right
    (dx: 0, dy: 1),   // 5: Bottom
    (dx: -1, dy: 1),  // 6: Bottom-Left
    (dx: -1, dy: 0)   // 7: Left
  ];

  for (int y = 1; y < height - 1; y++) {
    for (int x = 1; x < width - 1; x++) {
      // Find an unvisited boundary pixel (1 with a 0 to its left)
      if (bitmask[y][x] == 1 && bitmask[y][x - 1] == 0 && !visited[y][x]) {
        final contour = <({int x, int y})>[];
        int curX = x;
        int curY = y;
        
        // We entered from the left (0), which is direction 7
        int backtrackDir = 7; 
        
        int startX = curX;
        int startY = curY;

        do {
          visited[curY][curX] = true;
          contour.add((x: curX, y: curY));

          int nextDir = -1;
          // Look clockwise for the next 1
          for (int i = 1; i <= 8; i++) {
            int dir = (backtrackDir + i) % 8;
            int nx = curX + moore[dir].dx;
            int ny = curY + moore[dir].dy;

            if (bitmask[ny][nx] == 1) {
              nextDir = dir;
              break;
            }
          }

          if (nextDir == -1) break; // Isolated pixel

          curX += moore[nextDir].dx;
          curY += moore[nextDir].dy;
          
          // Backtrack direction is opposite of nextDir
          backtrackDir = (nextDir + 4) % 8;

        } while (!(curX == startX && curY == startY));

        if (contour.length >= max(3, ignoreLessThan)) {
          // Adjust coordinates back to original image space
          final adjustedContour = contour.map((p) => (x: p.x - 1, y: p.y - 1)).toList();
          contours.add(adjustedContour);
        }
      }
    }
  }

  return contours;
}

/// Step 5: Ramer-Douglas-Peucker line simplification.
List<({int x, int y})> _simplify(
    List<({int x, int y})> points, double epsilon) {
  if (points.length < 3) {
    return points;
  }

  // Find the point with the maximum distance
  double maxDist = 0;
  int index = 0;
  final start = points.first;
  final end = points.last;

  for (int i = 1; i < points.length - 1; i++) {
    final dist = _perpendicularDistance(points[i], start, end);
    if (dist > maxDist) {
      maxDist = dist;
      index = i;
    }
  }

  // If max distance is greater than epsilon, recursively simplify
  if (maxDist > epsilon) {
    // Recursively call _simplify for left and right parts
    final leftPoints =
        points.sublist(0, index + 1);
    final rightPoints =
        points.sublist(index, points.length);

    final leftResult = _simplify(leftPoints, epsilon);
    final rightResult = _simplify(rightPoints, epsilon);

    // Concatenate the results (avoid duplicating the point at index)
    return [
      ...leftResult.take(leftResult.length - 1),
      ...rightResult,
    ];
  } else {
    // Return just the endpoints
    return [start, end];
  }
}

/// Calculate perpendicular distance from point to line
double _perpendicularDistance(
    ({int x, int y}) point, ({int x, int y}) lineStart, ({int x, int y}) lineEnd) {
  final dx = lineEnd.x - lineStart.x;
  final dy = lineEnd.y - lineStart.y;

  // If line is actually a point, return distance to that point
  if (dx == 0 && dy == 0) {
    return _distance(point, lineStart);
  }

  // Calculate distance using cross product formula
  final numerator = ((lineEnd.y - lineStart.y) * point.x -
      (lineEnd.x - lineStart.x) * point.y +
      lineEnd.x * lineStart.y -
      lineEnd.y * lineStart.x)
      .abs();
  final denominator = sqrt(dx * dx + dy * dy);

  return numerator / denominator;
}

/// Calculate Euclidean distance between two points
double _distance(
    ({int x, int y}) a, ({int x, int y}) b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  return sqrt(dx * dx + dy * dy);
}

/// Step 6: Convert contours to SVG path string.
String _toSvgPathString(List<List<({int x, int y})>> contours) {
  if (contours.isEmpty) {
    return '';
  }

  final pathBuffers = <StringBuffer>[];
  for (final contour in contours) {
    if (contour.isEmpty) continue;

    final buffer = StringBuffer();
    final first = contour.first;
    buffer.write('M ${first.x} ${first.y}');

    for (int i = 1; i < contour.length; i++) {
      final point = contour[i];
      buffer.write(' L ${point.x} ${point.y}');
    }

    buffer.write(' Z');
    pathBuffers.add(buffer);
  }

  return pathBuffers.join(' ');
}

/// Step 5b: Laplacian smoothing
List<({int x, int y})> _smooth(List<({int x, int y})> points, int iterations) {
  if (points.length < 3) return points;
  var current = points;
  for (int i = 0; i < iterations; i++) {
    final next = <({int x, int y})>[];
    for (int j = 0; j < current.length; j++) {
      int prev = (j - 1) % current.length;
      if (prev < 0) prev += current.length;
      int nextIdx = (j + 1) % current.length;
      
      int nx = (current[prev].x + current[j].x + current[nextIdx].x) ~/ 3;
      int ny = (current[prev].y + current[j].y + current[nextIdx].y) ~/ 3;
      next.add((x: nx, y: ny));
    }
    current = next;
  }
  return current;
}