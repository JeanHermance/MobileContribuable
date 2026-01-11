import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  
  Locale _currentLocale = const Locale('fr'); // Français par défaut
  
  Locale get currentLocale => _currentLocale;
  
  // Langues supportées
  static const List<Locale> supportedLocales = [
    Locale('mg'), // Malagasy
    Locale('fr'), // Français
    Locale('en'), // English
  ];
  
  // Noms des langues pour l'affichage
  static const Map<String, String> languageNames = {
    'mg': 'Malagasy',
    'fr': 'Français',
    'en': 'English',
  };
  
  // Drapeaux des langues
  static const Map<String, String> languageFlags = {
    'mg': '🇲🇬',
    'fr': '🇫🇷',
    'en': '🇺🇸',
  };
  
  LanguageService() {
    _loadSavedLanguage();
  }
  
  // Charger la langue sauvegardée
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString(_languageKey);
      
      if (savedLanguageCode != null) {
        final locale = Locale(savedLanguageCode);
        if (supportedLocales.contains(locale)) {
          _currentLocale = locale;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading saved language: $e');
    }
  }
  
  // Changer la langue
  Future<void> changeLanguage(String languageCode) async {
    try {
      final newLocale = Locale(languageCode);
      
      if (supportedLocales.contains(newLocale)) {
        _currentLocale = newLocale;
        
        // Sauvegarder la préférence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_languageKey, languageCode);
        
        notifyListeners();
        debugPrint('Language changed to: $languageCode');
      }
    } catch (e) {
      debugPrint('Error changing language: $e');
    }
  }
  
  // Obtenir le nom de la langue actuelle
  String get currentLanguageName {
    return languageNames[_currentLocale.languageCode] ?? 'Malagasy';
  }
  
  // Obtenir le drapeau de la langue actuelle
  String get currentLanguageFlag {
    return languageFlags[_currentLocale.languageCode] ?? '🇲🇬';
  }
  
  // Vérifier si une langue est sélectionnée
  bool isLanguageSelected(String languageCode) {
    return _currentLocale.languageCode == languageCode;
  }
}
