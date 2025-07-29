import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  
  Locale get locale => _locale;

  LocaleProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('selected_language') ?? AppConstants.languageEnglish;
    _locale = _createLocaleFromCode(languageCode);
    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', languageCode);
    _locale = _createLocaleFromCode(languageCode);
    notifyListeners();
  }
  
  Locale _createLocaleFromCode(String languageCode) {
    // Handle Traditional Chinese specifically
    if (languageCode == AppConstants.languageTraditionalChinese) {
      return const Locale('zh', 'TW');
    }
    // Handle other languages normally
    return Locale(languageCode);
  }
}