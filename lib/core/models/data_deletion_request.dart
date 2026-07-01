/// Model for a data deletion request as seen by an admin.
class DataDeletionRequest {
  final int id;
  final String? userId;
  final String? email;
  final String? reason;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const DataDeletionRequest({
    required this.id,
    this.userId,
    this.email,
    this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  factory DataDeletionRequest.fromMap(Map<String, dynamic> map) {
    return DataDeletionRequest(
      id: map['id'] as int,
      userId: map['user_id'] as String?,
      email: map['email'] as String?,
      reason: map['reason'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.tryParse(map['reviewed_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
