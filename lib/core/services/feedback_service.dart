import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/models/user_feedback.dart';

/// Service for managing user feedback (local + optional Supabase for admin view).
class FeedbackService {
  static const String _feedbackKey = 'user_feedback_list';
  static const String _feedbackCountKey = 'user_feedback_count';
  static const String _lastFeedbackDateKey = 'last_feedback_date';
  static const String _lastMilestoneFeedbackShownKey =
      'last_milestone_feedback_shown_at';

  /// Save user feedback. Always saves locally; also inserts to Supabase when configured (Option B).
  Future<void> saveFeedback(UserFeedback feedback) async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing feedback
    final feedbackList = await getAllFeedback();

    // Add new feedback
    feedbackList.add(feedback);

    // Save to preferences (source of truth on device)
    final jsonList = feedbackList.map((f) => f.toJson()).toList();
    await prefs.setString(_feedbackKey, jsonEncode(jsonList));

    // Update metadata
    await prefs.setInt(_feedbackCountKey, feedbackList.length);
    await prefs.setString(_lastFeedbackDateKey, DateTime.now().toIso8601String());

    if (kDebugMode) {
      debugPrint('Feedback saved: ${feedback.category} - ${feedback.rating} stars');
    }

    // Option B: insert to Supabase when configured (for admin view across users)
    if (isSupabaseConfigured) {
      try {
        final userId = feedback.isAnonymous
            ? null
            : Supabase.instance.client.auth.currentUser?.id;
        await Supabase.instance.client.from('user_feedback').insert({
          'id': feedback.id,
          'user_id': userId,
          'rating': feedback.rating,
          'category': feedback.category,
          'comment': feedback.comment,
          'feature_suggestion': feedback.featureSuggestion,
          'metadata': feedback.metadata,
          'created_at': feedback.createdAt.toIso8601String(),
          'is_anonymous': feedback.isAnonymous,
          'status': feedback.status,
        });
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('FeedbackService: Supabase insert failed (local save succeeded): $e');
          debugPrint('$st');
        }
      }
    }
  }

  /// Delete a single feedback row from Supabase by id. Admins only (RLS). Returns true if deleted.
  Future<bool> deleteFeedbackFromSupabase(String id) async {
    if (!isSupabaseConfigured) return false;
    try {
      await Supabase.instance.client.from('user_feedback').delete().eq('id', id);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FeedbackService: deleteFeedbackFromSupabase failed: $e');
        debugPrint('$st');
      }
      return false;
    }
  }

  /// Update feedback status in Supabase. Admins only (RLS). Returns true if updated.
  Future<bool> updateFeedbackStatus(String id, String newStatus) async {
    if (!isSupabaseConfigured) return false;
    try {
      await Supabase.instance.client
          .from('user_feedback')
          .update({'status': newStatus})
          .eq('id', id);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FeedbackService: updateFeedbackStatus failed: $e');
        debugPrint('$st');
      }
      return false;
    }
  }

  /// Fetch all feedback from Supabase for admin view. Returns empty list if not configured or on error.
  Future<List<Map<String, dynamic>>> getFeedbackFromSupabase() async {
    if (!isSupabaseConfigured) return [];
    try {
      final res = await Supabase.instance.client
          .from('user_feedback')
          .select()
          .order('created_at', ascending: false);
      final list = res as List<dynamic>?;
      if (list == null) return [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FeedbackService: getFeedbackFromSupabase failed: $e');
        debugPrint('$st');
      }
      return [];
    }
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

  /// Returns true when scanCount is 3 or 5 and we haven't shown milestone prompt in last 7 days.
  Future<bool> shouldShowMilestonePrompt(int scanCount) async {
    if (scanCount != 3 && scanCount != 5) return false;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastMilestoneFeedbackShownKey);
    if (last == null) return true;
    try {
      final lastDate = DateTime.parse(last);
      return DateTime.now().difference(lastDate).inDays >= 7;
    } catch (_) {
      return true;
    }
  }

  /// Call after showing the milestone dialog (so we don't prompt again for 7 days).
  Future<void> recordMilestonePromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastMilestoneFeedbackShownKey,
      DateTime.now().toIso8601String(),
    );
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

