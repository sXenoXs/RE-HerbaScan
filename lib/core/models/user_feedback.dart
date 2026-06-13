/// Model for user feedback data
class UserFeedback {
  final String id;
  final int rating; // 1-5 stars
  final String category;
  final String comment;
  final String? featureSuggestion;
  final DateTime createdAt;
  final Map<String, dynamic>
      metadata; // Additional context (app version, device, etc.)

  final bool isAnonymous;

  UserFeedback({
    required this.id,
    required this.rating,
    required this.category,
    required this.comment,
    this.featureSuggestion,
    required this.createdAt,
    this.metadata = const {},
    this.isAnonymous = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'rating': rating,
        'category': category,
        'comment': comment,
        'feature_suggestion': featureSuggestion,
        'created_at': createdAt.toIso8601String(),
        'metadata': metadata,
        'is_anonymous': isAnonymous,
      };

  factory UserFeedback.fromJson(Map<String, dynamic> json) => UserFeedback(
        id: json['id'] as String,
        rating: json['rating'] as int,
        category: json['category'] as String,
        comment: json['comment'] as String,
        featureSuggestion: json['feature_suggestion'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        metadata: json['metadata'] as Map<String, dynamic>? ?? {},
        isAnonymous: json['is_anonymous'] as bool? ?? false,
      );
}

/// Categories for user feedback
class FeedbackCategory {
  static const String accuracy = 'accuracy';
  static const String usability = 'usability';
  static const String performance = 'performance';
  static const String features = 'features';
  static const String bugs = 'bugs';
  static const String general = 'general';

  static List<String> get all => [
        accuracy,
        usability,
        performance,
        features,
        bugs,
        general,
      ];

  static String getDisplayName(String category) {
    switch (category) {
      case accuracy:
        return 'AI Accuracy';
      case usability:
        return 'Ease of Use';
      case performance:
        return 'App Performance';
      case features:
        return 'Features';
      case bugs:
        return 'Bugs/Issues';
      case general:
        return 'General Feedback';
      default:
        return category;
    }
  }
}
