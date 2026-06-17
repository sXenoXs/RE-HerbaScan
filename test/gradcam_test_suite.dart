// test/gradcam_test_suite.dart
// Comprehensive test suite for hybrid Grad-CAM/CAM system

import 'package:flutter_test/flutter_test.dart';
import 'package:herbascan/core/services/adaptive_gradcam_service.dart';
import 'package:herbascan/core/services/online_gradcam_service.dart';
import 'package:herbascan/core/services/offline_cam_service.dart';
import 'package:herbascan/core/services/performance_monitor.dart';
import 'dart:typed_data';

/// Test suite for Grad-CAM/CAM hybrid system
class GradCAMTestSuite {
  final AdaptiveGradCAMService _adaptiveService = AdaptiveGradCAMService();
  final OnlineGradCAMService _onlineService = OnlineGradCAMService();
  final OfflineCAMService _offlineService = OfflineCAMService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  // Test results storage
  final List<Map<String, dynamic>> _testResults = [];

  /// Initialize all services for testing
  Future<void> initialize() async {
    print('🧪 Initializing test suite...');
    await _adaptiveService.initialize();
    await _offlineService.initialize();
    print('✅ Test suite initialized');
  }

  /// Test 5.1: Online Grad-CAM Testing
  Future<Map<String, dynamic>> testOnlineGradCAM({
    required String imagePath,
    required String testName,
  }) async {
    print('\n🔬 Testing Online Grad-CAM: $testName');

    final stopwatch = Stopwatch()..start();
    _performanceMonitor.startTimer('online_gradcam_test');

    try {
      // Check server connectivity
      final isOnline = await _onlineService.hasConnectivity();
      if (!isOnline) {
        return {
          'test_name': testName,
          'status': 'skipped',
          'reason': 'Server not available',
          'duration_ms': stopwatch.elapsedMilliseconds,
        };
      }

      // Run identification
      final result = await _onlineService.identifyPlant(imagePath);
      stopwatch.stop();
      _performanceMonitor.stopTimer('online_gradcam_test');

      if (result == null) {
        return {
          'test_name': testName,
          'status': 'failed',
          'reason': 'Result is null',
          'duration_ms': stopwatch.elapsedMilliseconds,
        };
      }

      final duration = stopwatch.elapsedMilliseconds;
      final hasHeatmap = result['gradcam_image'] != null;
      final method = result['method'] ?? 'unknown';

      final testResult = {
        'test_name': testName,
        'status': hasHeatmap ? 'passed' : 'failed',
        'duration_ms': duration,
        'method': method,
        'has_heatmap': hasHeatmap,
        'plant_name': result['plant_name'],
        'confidence': result['confidence'],
        'processing_time_ms': result['processing_time_ms'],
      };

      // Performance check
      if (duration > 5000) {
        testResult['warning'] = 'Processing time exceeds 5 seconds target';
      }

      _testResults.add(testResult);
      print('✅ Test completed: ${duration}ms');

      return testResult;
    } catch (e) {
      stopwatch.stop();
      _performanceMonitor.stopTimer('online_gradcam_test');

      final testResult = {
        'test_name': testName,
        'status': 'error',
        'error': e.toString(),
        'duration_ms': stopwatch.elapsedMilliseconds,
      };

      _testResults.add(testResult);
      print('❌ Test failed: $e');

      return testResult;
    }
  }

  /// Test 5.2: Offline CAM Testing
  Future<Map<String, dynamic>> testOfflineCAM({
    required Uint8List imageBytes,
    required String testName,
  }) async {
    print('\n🔬 Testing Offline CAM: $testName');

    final stopwatch = Stopwatch()..start();
    _performanceMonitor.startTimer('offline_cam_test');

    try {
      // Run offline identification
      final result = await _offlineService.identifyPlantWithCAM(imageBytes);
      stopwatch.stop();
      _performanceMonitor.stopTimer('offline_cam_test');

      if (result == null) {
        return {
          'test_name': testName,
          'status': 'failed',
          'reason': 'Result is null',
          'duration_ms': stopwatch.elapsedMilliseconds,
        };
      }

      final duration = stopwatch.elapsedMilliseconds;
      final hasHeatmap = result['gradcam_image'] != null;
      final method = result['method'] ?? 'unknown';

      final testResult = {
        'test_name': testName,
        'status': hasHeatmap ? 'passed' : 'failed',
        'duration_ms': duration,
        'method': method,
        'has_heatmap': hasHeatmap,
        'plant_name': result['plant_name'],
        'confidence': result['confidence'],
        'processing_time_ms': result['processing_time_ms'],
      };

      // Performance check
      if (duration > 2000) {
        testResult['warning'] = 'Processing time exceeds 2 seconds target';
      }

      _testResults.add(testResult);
      print('✅ Test completed: ${duration}ms');

      return testResult;
    } catch (e) {
      stopwatch.stop();
      _performanceMonitor.stopTimer('offline_cam_test');

      final testResult = {
        'test_name': testName,
        'status': 'error',
        'error': e.toString(),
        'duration_ms': stopwatch.elapsedMilliseconds,
      };

      _testResults.add(testResult);
      print('❌ Test failed: $e');

      return testResult;
    }
  }

  /// Test 5.3: Adaptive Service Testing
  Future<Map<String, dynamic>> testAdaptiveService({
    required String? imagePath,
    required Uint8List? imageBytes,
    required String testName,
    bool simulateOffline = false,
  }) async {
    print('\n🔬 Testing Adaptive Service: $testName');

    final stopwatch = Stopwatch()..start();
    _performanceMonitor.startTimer('adaptive_test');

    try {
      // Test adaptive identification
      final result = await _adaptiveService.identifyPlant(
        imagePath: imagePath,
        imageBytes: imageBytes,
      );
      stopwatch.stop();
      _performanceMonitor.stopTimer('adaptive_test');

      if (result == null) {
        return {
          'test_name': testName,
          'status': 'failed',
          'reason': 'Result is null',
          'duration_ms': stopwatch.elapsedMilliseconds,
        };
      }

      final duration = stopwatch.elapsedMilliseconds;
      final method = result['method'] ?? 'unknown';
      final fallbackUsed = result['fallback_used'] ?? false;
      final hasHeatmap = result['gradcam_image'] != null;

      final testResult = {
        'test_name': testName,
        'status': hasHeatmap ? 'passed' : 'failed',
        'duration_ms': duration,
        'method': method,
        'fallback_used': fallbackUsed,
        'has_heatmap': hasHeatmap,
        'plant_name': result['plant_name'],
        'confidence': result['confidence'],
        'processing_time_ms': result['processing_time_ms'],
      };

      // Validate method badge
      final connectivity = await _adaptiveService.getConnectivityStatus();
      if (connectivity && method != 'grad-cam' && !fallbackUsed) {
        testResult['warning'] = 'Expected online mode but got $method';
      } else if (!connectivity && method != 'cam') {
        testResult['warning'] = 'Expected offline mode but got $method';
      }

      _testResults.add(testResult);
      print('✅ Test completed: ${duration}ms (method: $method)');

      return testResult;
    } catch (e) {
      stopwatch.stop();
      _performanceMonitor.stopTimer('adaptive_test');

      final testResult = {
        'test_name': testName,
        'status': 'error',
        'error': e.toString(),
        'duration_ms': stopwatch.elapsedMilliseconds,
      };

      _testResults.add(testResult);
      print('❌ Test failed: $e');

      return testResult;
    }
  }

  /// Test 5.4: Performance Benchmark
  Future<Map<String, dynamic>> benchmarkPerformance({
    required String imagePath,
    required Uint8List imageBytes,
    int iterations = 10,
  }) async {
    print('\n📊 Running performance benchmark ($iterations iterations)...');

    final onlineTimes = <int>[];
    final offlineTimes = <int>[];
    final adaptiveTimes = <int>[];

    for (int i = 0; i < iterations; i++) {
      print('  Iteration ${i + 1}/$iterations');

      // Online test
      try {
        final onlineStart = Stopwatch()..start();
        final onlineResult = await _onlineService.identifyPlant(imagePath);
        onlineStart.stop();
        if (onlineResult != null) {
          onlineTimes.add(onlineStart.elapsedMilliseconds);
        }
      } catch (e) {
        print('    Online test failed: $e');
      }

      // Offline test
      try {
        final offlineStart = Stopwatch()..start();
        final offlineResult =
            await _offlineService.identifyPlantWithCAM(imageBytes);
        offlineStart.stop();
        if (offlineResult != null) {
          offlineTimes.add(offlineStart.elapsedMilliseconds);
        }
      } catch (e) {
        print('    Offline test failed: $e');
      }

      // Adaptive test
      try {
        final adaptiveStart = Stopwatch()..start();
        final adaptiveResult = await _adaptiveService.identifyPlant(
          imagePath: imagePath,
          imageBytes: imageBytes,
        );
        adaptiveStart.stop();
        if (adaptiveResult != null) {
          adaptiveTimes.add(adaptiveStart.elapsedMilliseconds);
        }
      } catch (e) {
        print('    Adaptive test failed: $e');
      }
    }

    final onlineAvg = onlineTimes.isEmpty
        ? 0
        : onlineTimes.reduce((a, b) => a + b) / onlineTimes.length;
    final offlineAvg = offlineTimes.isEmpty
        ? 0
        : offlineTimes.reduce((a, b) => a + b) / offlineTimes.length;
    final adaptiveAvg = adaptiveTimes.isEmpty
        ? 0
        : adaptiveTimes.reduce((a, b) => a + b) / adaptiveTimes.length;

    return {
      'test_name': 'Performance Benchmark',
      'iterations': iterations,
      'online': {
        'average_ms': onlineAvg.round(),
        'min_ms': onlineTimes.isEmpty
            ? 0
            : onlineTimes.reduce((a, b) => a < b ? a : b),
        'max_ms': onlineTimes.isEmpty
            ? 0
            : onlineTimes.reduce((a, b) => a > b ? a : b),
        'samples': onlineTimes.length,
      },
      'offline': {
        'average_ms': offlineAvg.round(),
        'min_ms': offlineTimes.isEmpty
            ? 0
            : offlineTimes.reduce((a, b) => a < b ? a : b),
        'max_ms': offlineTimes.isEmpty
            ? 0
            : offlineTimes.reduce((a, b) => a > b ? a : b),
        'samples': offlineTimes.length,
      },
      'adaptive': {
        'average_ms': adaptiveAvg.round(),
        'min_ms': adaptiveTimes.isEmpty
            ? 0
            : adaptiveTimes.reduce((a, b) => a < b ? a : b),
        'max_ms': adaptiveTimes.isEmpty
            ? 0
            : adaptiveTimes.reduce((a, b) => a > b ? a : b),
        'samples': adaptiveTimes.length,
      },
    };
  }

  /// Get all test results
  List<Map<String, dynamic>> getTestResults() => List.from(_testResults);

  /// Clear test results
  void clearResults() {
    _testResults.clear();
  }

  /// Generate test report
  Map<String, dynamic> generateReport() {
    final passed = _testResults.where((r) => r['status'] == 'passed').length;
    final failed = _testResults.where((r) => r['status'] == 'failed').length;
    final errors = _testResults.where((r) => r['status'] == 'error').length;
    final skipped = _testResults.where((r) => r['status'] == 'skipped').length;

    final onlineTimes = _testResults
        .where((r) => r['method'] == 'grad-cam')
        .map((r) => r['duration_ms'] as int)
        .toList();
    final offlineTimes = _testResults
        .where((r) => r['method'] == 'cam')
        .map((r) => r['duration_ms'] as int)
        .toList();

    return {
      'summary': {
        'total_tests': _testResults.length,
        'passed': passed,
        'failed': failed,
        'errors': errors,
        'skipped': skipped,
        'success_rate':
            _testResults.isEmpty ? 0.0 : (passed / _testResults.length * 100),
      },
      'performance': {
        'online': {
          'average_ms': onlineTimes.isEmpty
              ? 0
              : onlineTimes.reduce((a, b) => a + b) / onlineTimes.length,
          'min_ms': onlineTimes.isEmpty
              ? 0
              : onlineTimes.reduce((a, b) => a < b ? a : b),
          'max_ms': onlineTimes.isEmpty
              ? 0
              : onlineTimes.reduce((a, b) => a > b ? a : b),
        },
        'offline': {
          'average_ms': offlineTimes.isEmpty
              ? 0
              : offlineTimes.reduce((a, b) => a + b) / offlineTimes.length,
          'min_ms': offlineTimes.isEmpty
              ? 0
              : offlineTimes.reduce((a, b) => a < b ? a : b),
          'max_ms': offlineTimes.isEmpty
              ? 0
              : offlineTimes.reduce((a, b) => a > b ? a : b),
        },
      },
      'test_results': _testResults,
    };
  }

  /// Dispose resources
  void dispose() {
    _offlineService.dispose();
  }
}
