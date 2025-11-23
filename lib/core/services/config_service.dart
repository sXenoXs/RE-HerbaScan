import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing application configuration, including API keys
class ConfigService {
  static const String _geminiApiKeyKey =
      'gemini_api_key'; // SharedPreferences key name

  // PLACEHOLDER: Replace with your API key for testing, or configure via setGeminiApiKey()

  static const String _defaultGeminiApiKey =
      'AIzaSyBiYp5sWppWetPjg3eEF0IyDjU0X25Szw8'; // TODO: Add your Gemini API key here or use setGeminiApiKey() method

  /// Get the Gemini API key from SharedPreferences
  /// Returns default API key if not configured in SharedPreferences
  static Future<String> getGeminiApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // First try to get from SharedPreferences, fallback to default
      return prefs.getString(_geminiApiKeyKey) ?? _defaultGeminiApiKey;
    } catch (e) {
      return _defaultGeminiApiKey;
    }
  }

  /// Set the Gemini API key in SharedPreferences
  static Future<bool> setGeminiApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_geminiApiKeyKey, apiKey);
    } catch (e) {
      return false;
    }
  }

  /// Check if Gemini API key is configured
  static Future<bool> isGeminiApiKeyConfigured() async {
    final apiKey = await getGeminiApiKey();
    return apiKey.isNotEmpty;
  }

  /// Clear the Gemini API key
  static Future<bool> clearGeminiApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_geminiApiKeyKey);
    } catch (e) {
      return false;
    }
  }
}
