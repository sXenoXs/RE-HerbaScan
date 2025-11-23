import 'package:shared_preferences/shared_preferences.dart';
import 'package:herbascan/core/models/user_feedback.dart';
import 'dart:convert';

/// Service for managing user feedback
class FeedbackService {
  static const String _feedbackKey = 'user_feedback_list';
  static const String _feedbackCountKey = 'user_feedback_count';
  static const String _lastFeedbackDateKey = 'last_feedback_date';

  /// Save user feedback
  Future<void> saveFeedback(UserFeedback feedback) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing feedback
    final feedbackList = await getAllFeedback();
    
    // Add new feedback
    feedbackList.add(feedback);
    
    // Save to preferences
    final jsonList = feedbackList.map((f) => f.toJson()).toList();
    await prefs.setString(_feedbackKey, jsonEncode(jsonList));
    
    // Update metadata
    await prefs.setInt(_feedbackCountKey, feedbackList.length);
    await prefs.setString(_lastFeedbackDateKey, DateTime.now().toIso8601String());
    
    print('Feedback saved: ${feedback.category} - ${feedback.rating} stars');
  }

  /// Get all feedback
  Future<List<UserFeedback>> getAllFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_feedbackKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => UserFeedback.fromJson(json)).toList();
    } catch (e) {
      print('Error loading feedback: $e');
      return [];
    }
  }

  /// Get feedback count
  Future<int> getFeedbackCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_feedbackCountKey) ?? 0;
  }

  /// Get last feedback date
  Future<DateTime?> getLastFeedbackDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastFeedbackDateKey);
    
    if (dateString == null) return null;
    
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Check if user should be prompted for feedback
  /// (e.g., after 5 successful scans and not asked in last 7 days)
  Future<bool> shouldPromptForFeedback(int successfulScans) async {
    if (successfulScans < 5) return false;
    
    final lastDate = await getLastFeedbackDate();
    if (lastDate == null) return true;
    
    final daysSinceLastFeedback = DateTime.now().difference(lastDate).inDays;
    return daysSinceLastFeedback >= 7;
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStats() async {
    final feedbackList = await getAllFeedback();
    
    if (feedbackList.isEmpty) {
      return {
        'total_feedback': 0,
        'average_rating': 0.0,
        'category_breakdown': {},
        'rating_distribution': {},
      };
    }
    
    // Calculate average rating
    final totalRating = feedbackList.fold<int>(0, (sum, f) => sum + f.rating);
    final averageRating = totalRating / feedbackList.length;
    
    // Category breakdown
    final categoryBreakdown = <String, int>{};
    for (var feedback in feedbackList) {
      categoryBreakdown[feedback.category] = 
          (categoryBreakdown[feedback.category] ?? 0) + 1;
    }
    
    // Rating distribution
    final ratingDistribution = <int, int>{};
    for (var feedback in feedbackList) {
      ratingDistribution[feedback.rating] = 
          (ratingDistribution[feedback.rating] ?? 0) + 1;
    }
    
    return {
      'total_feedback': feedbackList.length,
      'average_rating': averageRating,
      'category_breakdown': categoryBreakdown,
      'rating_distribution': ratingDistribution,
    };
  }

  /// Export feedback for thesis analysis
  Future<String> exportFeedbackAsJson() async {
    final feedbackList = await getAllFeedback();
    final stats = await getFeedbackStats();
    
    final export = {
      'export_date': DateTime.now().toIso8601String(),
      'statistics': stats,
      'feedback_list': feedbackList.map((f) => f.toJson()).toList(),
    };
    
    return jsonEncode(export);
  }

  /// Clear all feedback (for testing)
  Future<void> clearAllFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_feedbackKey);
    await prefs.remove(_feedbackCountKey);
    await prefs.remove(_lastFeedbackDateKey);
  }
}

