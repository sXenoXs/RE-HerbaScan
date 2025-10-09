import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en', 'US');
  bool _isLoading = false;

  // Getters
  Locale get locale => _locale;
  bool get isLoading => _isLoading;
  String get languageCode => _locale.languageCode;
  bool get isEnglish => _locale.languageCode == 'en';
  bool get isFilipino => _locale.languageCode == 'fil';

  LanguageProvider() {
    _loadLanguage();
  }

  // Load saved language preference
  Future<void> _loadLanguage() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('language_code') ?? 'en';
      final countryCode = prefs.getString('country_code') ?? 'US';
      
      _locale = Locale(languageCode, countryCode);
    } catch (e) {
      // Default to English if loading fails
      _locale = const Locale('en', 'US');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Save language preference
  Future<void> _saveLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', _locale.languageCode);
      await prefs.setString('country_code', _locale.countryCode ?? 'US');
    } catch (e) {
      // Handle error silently
    }
  }

  // Change language
  Future<void> changeLanguage(Locale newLocale) async {
    if (_locale == newLocale) return;

    _isLoading = true;
    notifyListeners();

    _locale = newLocale;
    await _saveLanguage();

    _isLoading = false;
    notifyListeners();
  }

  // Toggle between English and Filipino
  Future<void> toggleLanguage() async {
    final newLocale = isEnglish 
        ? const Locale('fil', 'PH') 
        : const Locale('en', 'US');
    await changeLanguage(newLocale);
  }

  // Get localized text
  String getLocalizedText(Map<String, String> translations) {
    return translations[languageCode] ?? translations['en'] ?? '';
  }

  // Get supported languages
  List<Map<String, String>> getSupportedLanguages() {
    return [
      {
        'code': 'en',
        'name': 'English',
        'nativeName': 'English',
        'flag': '🇺🇸',
      },
      {
        'code': 'fil',
        'name': 'Filipino',
        'nativeName': 'Filipino',
        'flag': '🇵🇭',
      },
    ];
  }
}
