import 'package:herbascan/core/models/plant.dart';

class ScanResult {
  final String id;
  final Plant? plant;
  final double confidenceScore;
  final List<Prediction> predictions;
  final String imagePath;
  final DateTime scanDate;
  final String? gradCAMPath;
  final Map<String, dynamic> metadata;
  final bool isOfflineScan;

  ScanResult({
    required this.id,
    this.plant,
    required this.confidenceScore,
    required this.predictions,
    required this.imagePath,
    required this.scanDate,
    this.gradCAMPath,
    required this.metadata,
    required this.isOfflineScan,
  });

  // Factory constructor from JSON
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['id'] ?? '',
      plant: json['plant'] != null ? Plant.fromJson(json['plant']) : null,
      confidenceScore: (json['confidenceScore'] ?? 0.0).toDouble(),
      predictions: (json['predictions'] as List<dynamic>?)
          ?.map((pred) => Prediction.fromJson(pred))
          .toList() ?? [],
      imagePath: json['imagePath'] ?? '',
      scanDate: DateTime.parse(json['scanDate'] ?? DateTime.now().toIso8601String()),
      gradCAMPath: json['gradCAMPath'],
      metadata: json['metadata'] ?? {},
      isOfflineScan: json['isOfflineScan'] ?? false,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plant': plant?.toJson(),
      'confidenceScore': confidenceScore,
      'predictions': predictions.map((pred) => pred.toJson()).toList(),
      'imagePath': imagePath,
      'scanDate': scanDate.toIso8601String(),
      'gradCAMPath': gradCAMPath,
      'metadata': metadata,
      'isOfflineScan': isOfflineScan,
    };
  }

  // Get top prediction
  Prediction? get topPrediction {
    if (predictions.isEmpty) return null;
    return predictions.first;
  }

  // Get top 3 predictions
  List<Prediction> get top3Predictions {
    return predictions.take(3).toList();
  }

  // Check if result is high confidence
  bool get isHighConfidence => confidenceScore >= 0.8;

  // Check if result is medium confidence
  bool get isMediumConfidence => confidenceScore >= 0.5 && confidenceScore < 0.8;

  // Check if result is low confidence
  bool get isLowConfidence => confidenceScore < 0.5;

  // Get confidence level as string
  String get confidenceLevel {
    if (isHighConfidence) return 'High';
    if (isMediumConfidence) return 'Medium';
    return 'Low';
  }

  // Get confidence color
  String get confidenceColor {
    if (isHighConfidence) return '#22C55E'; // Green
    if (isMediumConfidence) return '#F59E0B'; // Orange
    return '#EF4444'; // Red
  }

  // Check if plant is DOH approved
  bool get isDOHApproved => plant?.isDOHApproved ?? false;

  // Get formatted scan date
  String get formattedScanDate {
    final now = DateTime.now();
    final difference = now.difference(scanDate);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

class Prediction {
  final String plantId;
  final String plantName;
  final String scientificName;
  final double confidence;
  final Map<String, dynamic> features;

  Prediction({
    required this.plantId,
    required this.plantName,
    required this.scientificName,
    required this.confidence,
    required this.features,
  });

  // Factory constructor from JSON
  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      plantId: json['plantId'] ?? '',
      plantName: json['plantName'] ?? '',
      scientificName: json['scientificName'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      features: json['features'] ?? {},
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'plantId': plantId,
      'plantName': plantName,
      'scientificName': scientificName,
      'confidence': confidence,
      'features': features,
    };
  }

  // Get confidence percentage
  String get confidencePercentage {
    return '${(confidence * 100).toStringAsFixed(1)}%';
  }

  // Get confidence level
  String get confidenceLevel {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.5) return 'Medium';
    return 'Low';
  }

  // Get confidence color
  String get confidenceColor {
    if (confidence >= 0.8) return '#22C55E'; // Green
    if (confidence >= 0.5) return '#F59E0B'; // Orange
    return '#EF4444'; // Red
  }
}

class ScanMetadata {
  final String deviceModel;
  final String appVersion;
  final String modelVersion;
  final double processingTime;
  final String imageQuality;
  final Map<String, dynamic> aiFeatures;

  ScanMetadata({
    required this.deviceModel,
    required this.appVersion,
    required this.modelVersion,
    required this.processingTime,
    required this.imageQuality,
    required this.aiFeatures,
  });

  factory ScanMetadata.fromJson(Map<String, dynamic> json) {
    return ScanMetadata(
      deviceModel: json['deviceModel'] ?? '',
      appVersion: json['appVersion'] ?? '',
      modelVersion: json['modelVersion'] ?? '',
      processingTime: (json['processingTime'] ?? 0.0).toDouble(),
      imageQuality: json['imageQuality'] ?? '',
      aiFeatures: json['aiFeatures'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceModel': deviceModel,
      'appVersion': appVersion,
      'modelVersion': modelVersion,
      'processingTime': processingTime,
      'imageQuality': imageQuality,
      'aiFeatures': aiFeatures,
    };
  }
}
