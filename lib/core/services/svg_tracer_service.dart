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
  }) async {
    return compute(_traceToSvgPath, {
      'imageBytes': imageBytes,
      'threshold': threshold,
      'blur': blur,
      'invert': invert,
      'simplify': simplify,
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
    final contours = _traceContours(bitmask);
    // Returns List<List<(int x, int y)>> — one list per closed contour

    // Step 5: Ramer-Douglas-Peucker simplification
    final simplified =
        contours.map((c) => _simplify(c, simplify)).toList();

    // Step 6: Convert to SVG path commands
    return _toSvgPathString(simplified);
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
List<List<({int x, int y})>> _traceContours(List<List<int>> bitmask) {
  final height = bitmask.length;
  final width = bitmask[0].length;
  final visited = List.generate(
      height, (_) => List.filled(width, false));
  final contours = <List<({int x, int y})>>[];

  // Moore neighborhood offsets (8-connected)
  final List<({int dx, int dy})> moore = [
    (dx: -1, dy: -1),
    (dx: 0, dy: -1),
    (dx: 1, dy: -1),
    (dx: 1, dy: 0),
    (dx: 1, dy: 1),
    (dx: 0, dy: 1),
    (dx: -1, dy: 1),
    (dx: -1, dy: 0)
  ];

  for (int y = 1; y < height - 1; y++) {
    for (int x = 1; x < width - 1; x++) {
      // Find an unvisited foreground pixel to start a new contour
      if (bitmask[y][x] == 1 && !visited[y - 1][x - 1]) {
        final contour = <({int x, int y})>[];
        int curX = x - 1;
        int curY = y - 1;
        int startX = curX;
        int startY = curY;
        int? prevDir;

        do {
          visited[curY][curX] = true;
          contour.add((x: curX, y: curY));

          // Find next pixel in contour using Moore neighborhood tracing
          int nextDir = -1;
          int checkStart = (prevDir == null) ? 0 : ((prevDir! + 6) % 8);

          for (int i = 0; i < 8; i++) {
            int dir = (checkStart + i) % 8;
            int nx = curX + moore[dir].dx;
            int ny = curY + moore[dir].dy;

            // Check bounds (accounting for 1-pixel border)
            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
              if (bitmask[ny][nx] == 1 && !visited[ny][nx]) {
                nextDir = dir;
                break;
              }
            }
          }

          if (nextDir == -1) {
            // No more pixels in this contour
            break;
          }

          curX += moore[nextDir].dx;
          curY += moore[nextDir].dy;
          prevDir = nextDir;
        } while (!(curX == startX && curY == startY));

        // Only add contour if it has enough points
        if (contour.length >= 3) {
          contours.add(contour);
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