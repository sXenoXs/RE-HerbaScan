import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for logging and tracking app errors
class ErrorLogger {
  static const String _errorsKey = 'error_logs';
  static const int _maxErrorLogs = 100;
  static final ErrorLogger _instance = ErrorLogger._internal();

  factory ErrorLogger() => _instance;
  ErrorLogger._internal();

  final List<ErrorLog> _recentErrors = [];

  /// Log an error
  Future<void> logError(
    String errorType,
    String message, {
    String? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    final errorLog = ErrorLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      errorType: errorType,
      message: message,
      stackTrace: stackTrace,
      context: context ?? {},
      timestamp: DateTime.now(),
    );

    _recentErrors.add(errorLog);

    // Keep only recent errors in memory
    if (_recentErrors.length > 20) {
      _recentErrors.removeAt(0);
    }

    await _saveError(errorLog);

    print('🔴 Error Logged: [$errorType] $message');
  }

  /// Save error to persistent storage
  Future<void> _saveError(ErrorLog errorLog) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingErrors = await getAllErrors();

      existingErrors.add(errorLog);

      // Keep only last _maxErrorLogs
      if (existingErrors.length > _maxErrorLogs) {
        existingErrors.removeRange(0, existingErrors.length - _maxErrorLogs);
      }

      final jsonList = existingErrors.map((e) => e.toJson()).toList();
      await prefs.setString(_errorsKey, jsonEncode(jsonList));
    } catch (e) {
      print('Error saving error log: $e');
    }
  }

  /// Get all stored errors
  Future<List<ErrorLog>> getAllErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_errorsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => ErrorLog.fromJson(json)).toList();
    } catch (e) {
      print('Error loading error logs: $e');
      return [];
    }
  }

  /// Get errors by type
  Future<List<ErrorLog>> getErrorsByType(String errorType) async {
    final allErrors = await getAllErrors();
    return allErrors.where((e) => e.errorType == errorType).toList();
  }

  /// Get error statistics
  Future<Map<String, dynamic>> getErrorStats() async {
    final allErrors = await getAllErrors();

    if (allErrors.isEmpty) {
      return {
        'total_errors': 0,
        'error_types': {},
        'last_error': null,
      };
    }

    // Group by type
    final errorTypes = <String, int>{};
    for (var error in allErrors) {
      errorTypes[error.errorType] = (errorTypes[error.errorType] ?? 0) + 1;
    }

    return {
      'total_errors': allErrors.length,
      'error_types': errorTypes,
      'last_error': allErrors.last.toJson(),
      'last_24h': allErrors
          .where((e) => DateTime.now().difference(e.timestamp).inHours < 24)
          .length,
    };
  }

  /// Export errors for debugging
  Future<String> exportErrorsAsJson() async {
    final errors = await getAllErrors();
    final stats = await getErrorStats();

    final export = {
      'export_date': DateTime.now().toIso8601String(),
      'statistics': stats,
      'error_logs': errors.map((e) => e.toJson()).toList(),
    };

    return jsonEncode(export);
  }

  /// Clear all errors
  Future<void> clearAllErrors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_errorsKey);
    _recentErrors.clear();
  }

  /// Get recent errors (in-memory only)
  List<ErrorLog> getRecentErrors() => List.from(_recentErrors);
}

/// Model for error logs
class ErrorLog {
  final String id;
  final String errorType;
  final String message;
  final String? stackTrace;
  final Map<String, dynamic> context;
  final DateTime timestamp;

  ErrorLog({
    required this.id,
    required this.errorType,
    required this.message,
    this.stackTrace,
    this.context = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'error_type': errorType,
        'message': message,
        'stack_trace': stackTrace,
        'context': context,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ErrorLog.fromJson(Map<String, dynamic> json) {
    return ErrorLog(
      id: json['id'] as String,
      errorType: json['error_type'] as String,
      message: json['message'] as String,
      stackTrace: json['stack_trace'] as String?,
      context: json['context'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Common error types for consistency
class ErrorType {
  static const String cameraError = 'camera_error';
  static const String aiInferenceError = 'ai_inference_error';
  static const String databaseError = 'database_error';
  static const String networkError = 'network_error';
  static const String storageError = 'storage_error';
  static const String imageProcessingError = 'image_processing_error';
  static const String validationError = 'validation_error';
  static const String unknownError = 'unknown_error';
}
