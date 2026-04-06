import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_drawing/path_drawing.dart';

/// SVG path command letters that must be separated from adjacent numbers for parsing.
const String _pathCommands = 'MmLlHhVvCcSsQqTtAaZz';

/// Ensures a space before each path command letter when it immediately follows a digit or decimal.
/// Many design tools output "288.19L57" which some parsers misread; this becomes "288.19 L57".
String _normalizePathString(String s) {
  return s.replaceAllMapped(
    RegExp('(\\d)([$_pathCommands])'),
    (m) => '${m[1]} ${m[2]}',
  );
}

/// Parses SVG path `d="..."` string to a Flutter [Path].
/// Returns empty path for invalid or empty input; logs in debug.
/// Normalizes the string so paths from design tools (e.g. no space before L, C, V) parse correctly.
Path parseSvgPath(String? svgPathString) {
  if (svgPathString == null || svgPathString.trim().isEmpty) {
    return Path();
  }
  final trimmed = svgPathString.trim();
  final normalized = _normalizePathString(trimmed);
  try {
    return parseSvgPathData(normalized);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[SvgPathParser] Failed to parse path: $e');
      debugPrint('[SvgPathParser] Path preview: ${trimmed.length > 80 ? "${trimmed.substring(0, 80)}..." : trimmed}');
      debugPrint(st.toString());
    }
    return Path();
  }
}

/// Parses hex color string (e.g. "4CAF50", "#4CAF50") to [Color].
/// Returns a default green if parsing fails.
Color colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF4CAF50);
  String s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) {
    final r = int.tryParse(s.substring(0, 2), radix: 16);
    final g = int.tryParse(s.substring(2, 4), radix: 16);
    final b = int.tryParse(s.substring(4, 6), radix: 16);
    if (r != null && g != null && b != null) {
      return Color.fromARGB(255, r, g, b);
    }
  }
  return const Color(0xFF4CAF50);
}
