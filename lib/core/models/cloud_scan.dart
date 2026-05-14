/// Represents a single scan row from Supabase (Personal Herbarium).
class CloudScan {
  final String id;
  final String? userId;
  final String? plantId;
  final DateTime scanDate;
  final String? imageUrl;
  final double? confidenceScore;
  final List<dynamic>? predictions;
  final Map<String, dynamic>? metadata;
  final String? gradcamUrl;
  final String status;

  CloudScan({
    required this.id,
    this.userId,
    this.plantId,
    required this.scanDate,
    this.imageUrl,
    this.confidenceScore,
    this.predictions,
    this.metadata,
    this.gradcamUrl,
    this.status = 'pending',
  });

  factory CloudScan.fromJson(Map<String, dynamic> json) {
    return CloudScan(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      plantId: json['plant_id'] as String?,
      scanDate: DateTime.parse(json['scan_date'] as String),
      imageUrl: json['image_url'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      predictions: json['predictions'] as List<dynamic>?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      gradcamUrl: json['gradcam_url'] as String?,
      status: json['status'] as String? ?? 'pending',
    );
  }
}
