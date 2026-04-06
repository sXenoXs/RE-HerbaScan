import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for monitoring app performance metrics
class PerformanceMonitor {
  static const String _metricsKey = 'performance_metrics';
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, DateTime> _startTimes = {};
  final List<PerformanceMetric> _recentMetrics = [];

  /// Start timing an operation
  void startTimer(String operationName) {
    _startTimes[operationName] = DateTime.now();
  }

  /// Stop timing an operation and record the metric
  Future<void> stopTimer(String operationName, {Map<String, dynamic>? metadata}) async {
    final startTime = _startTimes[operationName];
    if (startTime == null) {
      print('Warning: No start time found for $operationName');
      return;
    }

    final duration = DateTime.now().difference(startTime);
    _startTimes.remove(operationName);

    final metric = PerformanceMetric(
      operationName: operationName,
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    );

    _recentMetrics.add(metric);
    
    // Keep only last 100 metrics in memory
    if (_recentMetrics.length > 100) {
      _recentMetrics.removeAt(0);
    }

    await _saveMetric(metric);
    
    print('⚡ $operationName: ${duration.inMilliseconds}ms');
  }

  /// Record a metric directly
  Future<void> recordMetric(String operationName, Duration duration, {Map<String, dynamic>? metadata}) async {
    final metric = PerformanceMetric(
      operationName: operationName,
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    );

    _recentMetrics.add(metric);
    if (_recentMetrics.length > 100) {
      _recentMetrics.removeAt(0);
    }

    await _saveMetric(metric);
  }

  /// Save metric to persistent storage
  Future<void> _saveMetric(PerformanceMetric metric) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingMetrics = await getAllMetrics();
      
      existingMetrics.add(metric);
      
      // Keep only last 500 metrics
      if (existingMetrics.length > 500) {
        existingMetrics.removeRange(0, existingMetrics.length - 500);
      }
      
      final jsonList = existingMetrics.map((m) => m.toJson()).toList();
      await prefs.setString(_metricsKey, jsonEncode(jsonList));
    } catch (e) {
      print('Error saving metric: $e');
    }
  }

  /// Get all stored metrics
  Future<List<PerformanceMetric>> getAllMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_metricsKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => PerformanceMetric.fromJson(json)).toList();
    } catch (e) {
      print('Error loading metrics: $e');
      return [];
    }
  }

  /// Get metrics for a specific operation
  Future<List<PerformanceMetric>> getMetricsForOperation(String operationName) async {
    final allMetrics = await getAllMetrics();
    return allMetrics.where((m) => m.operationName == operationName).toList();
  }

  /// Get performance statistics
  Future<Map<String, dynamic>> getPerformanceStats() async {
    final allMetrics = await getAllMetrics();
    
    if (allMetrics.isEmpty) {
      return {
        'total_operations': 0,
        'operations_breakdown': {},
      };
    }

    // Group by operation
    final operationGroups = <String, List<PerformanceMetric>>{};
    for (var metric in allMetrics) {
      operationGroups.putIfAbsent(metric.operationName, () => []).add(metric);
    }

    // Calculate stats for each operation
    final operationStats = <String, Map<String, dynamic>>{};
    operationGroups.forEach((operation, metrics) {
      final durations = metrics.map((m) => m.duration.inMilliseconds).toList();
      durations.sort();
      
      final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
      final minDuration = durations.first;
      final maxDuration = durations.last;
      final medianDuration = durations[durations.length ~/ 2];
      
      operationStats[operation] = {
        'count': metrics.length,
        'avg_ms': avgDuration.round(),
        'min_ms': minDuration,
        'max_ms': maxDuration,
        'median_ms': medianDuration,
      };
    });

    return {
      'total_operations': allMetrics.length,
      'operations_breakdown': operationStats,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Export metrics for analysis
  Future<String> exportMetricsAsJson() async {
    final metrics = await getAllMetrics();
    final stats = await getPerformanceStats();
    
    final export = {
      'export_date': DateTime.now().toIso8601String(),
      'statistics': stats,
      'raw_metrics': metrics.map((m) => m.toJson()).toList(),
    };
    
    return jsonEncode(export);
  }

  /// Clear all metrics
  Future<void> clearAllMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_metricsKey);
    _recentMetrics.clear();
    _startTimes.clear();
  }

  /// Get recent metrics (in-memory only)
  List<PerformanceMetric> getRecentMetrics() => List.from(_recentMetrics);
}

/// Model for performance metrics
class PerformanceMetric {
  final String operationName;
  final Duration duration;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'operation_name': operationName,
        'duration_ms': duration.inMilliseconds,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) {
    return PerformanceMetric(
      operationName: json['operation_name'] as String,
      duration: Duration(milliseconds: json['duration_ms'] as int),
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Common operation names for consistency
class PerformanceOperation {
  static const String appStart = 'app_start';
  static const String databaseInit = 'database_init';
  static const String imageCapture = 'image_capture';
  static const String imageProcessing = 'image_processing';
  static const String aiInference = 'ai_inference';
  static const String gradcamGeneration = 'gradcam_generation';
  static const String plantSearch = 'plant_search';
  static const String screenLoad = 'screen_load';
}

