/// Parses preparation step instruction text for time phrases
/// (e.g. "10 minutes", "10-15 minutes", "30 seconds") and provides
/// duration in seconds. Used by Preparation Instructions and Focus Mode.
class PreparationStepParser {
  PreparationStepParser._();

  /// Parses step instruction for time and returns duration in seconds.
  /// Uses upper bound for ranges (e.g. "10-15 minutes" → 15 min).
  /// Returns null if no minute/second pattern found.
  static int? parseTimerSecondsFromInstruction(String instruction) {
    if (instruction.isEmpty) return null;
    final lower = instruction.toLowerCase();
    // Range: "10-15 minutes" or "10 - 15 minutes" -> use 15
    final rangeMinMatch = RegExp(r'(\d+)\s*-\s*(\d+)\s*(?:minute|minutes)')
        .firstMatch(lower);
    if (rangeMinMatch != null) {
      final minutes = int.tryParse(rangeMinMatch.group(2) ?? '');
      if (minutes != null && minutes > 0 && minutes <= 180) return minutes * 60;
    }
    // Single: "10 minutes" or "1 minute"
    final singleMinMatch =
        RegExp(r'(?:for\s+)?(\d+)\s*(?:minute|minutes)').firstMatch(lower);
    if (singleMinMatch != null) {
      final minutes = int.tryParse(singleMinMatch.group(1) ?? '');
      if (minutes != null && minutes > 0 && minutes <= 180) return minutes * 60;
    }
    // Range seconds: "30-60 seconds"
    final rangeSecMatch = RegExp(r'(\d+)\s*-\s*(\d+)\s*(?:second|seconds)')
        .firstMatch(lower);
    if (rangeSecMatch != null) {
      final seconds = int.tryParse(rangeSecMatch.group(2) ?? '');
      if (seconds != null && seconds > 0 && seconds <= 7200) return seconds;
    }
    // Single seconds: "30 seconds"
    final singleSecMatch =
        RegExp(r'(?:for\s+)?(\d+)\s*(?:second|seconds)').firstMatch(lower);
    if (singleSecMatch != null) {
      final seconds = int.tryParse(singleSecMatch.group(1) ?? '');
      if (seconds != null && seconds > 0 && seconds <= 7200) return seconds;
    }
    return null;
  }

  /// Formats total seconds as MM:SS (e.g. 900 → "15:00", 65 → "01:05").
  static String formatMinutesSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
