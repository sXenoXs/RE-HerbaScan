import 'package:shared_preferences/shared_preferences.dart';

class AiMetrics {
  final double accuracy;
  final double precision;
  final double recall;
  final double f1Score;

  const AiMetrics({
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1Score,
  });
}

class AiMetricsService {
  static const String _accuracyKey = 'admin_ai_metric_accuracy';
  static const String _precisionKey = 'admin_ai_metric_precision';
  static const String _recallKey = 'admin_ai_metric_recall';
  static const String _f1ScoreKey = 'admin_ai_metric_f1_score';
  static const String _updatedAtKey = 'admin_ai_metric_updated_at';

  static const AiMetrics defaults = AiMetrics(
    accuracy: 89.23,
    precision: 87.56,
    recall: 88.34,
    f1Score: 87.95,
  );

  Future<AiMetrics> loadMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    return AiMetrics(
      accuracy: prefs.getDouble(_accuracyKey) ?? defaults.accuracy,
      precision: prefs.getDouble(_precisionKey) ?? defaults.precision,
      recall: prefs.getDouble(_recallKey) ?? defaults.recall,
      f1Score: prefs.getDouble(_f1ScoreKey) ?? defaults.f1Score,
    );
  }

  Future<void> saveMetrics(AiMetrics metrics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_accuracyKey, metrics.accuracy);
    await prefs.setDouble(_precisionKey, metrics.precision);
    await prefs.setDouble(_recallKey, metrics.recall);
    await prefs.setDouble(_f1ScoreKey, metrics.f1Score);
    await prefs.setString(_updatedAtKey, DateTime.now().toIso8601String());
  }

  Future<void> resetDefaults() async {
    await saveMetrics(defaults);
  }
}
