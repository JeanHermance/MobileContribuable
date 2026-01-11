import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Service pour gérer les sons de notification
class NotificationSoundService {
  static const String _soundEnabledKey = 'notification_sound_enabled';
  static bool _soundEnabled = true;

  /// Initialise le service et charge les préférences
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      debugPrint('🔊 NotificationSoundService initialisé: son ${_soundEnabled ? "activé" : "désactivé"}');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation du service de son: $e');
    }
  }

  /// Vérifie si le son est activé
  static bool get isSoundEnabled => _soundEnabled;

  /// Active ou désactive le son des notifications
  static Future<void> setSoundEnabled(bool enabled) async {
    try {
      _soundEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, enabled);
      debugPrint('🔊 Son de notification ${enabled ? "activé" : "désactivé"}');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde des préférences de son: $e');
    }
  }

  /// Teste tous les types de sons disponibles pour diagnostiquer le problème
  static Future<void> testAllSounds() async {
    debugPrint('🧪 === TEST DE TOUS LES SONS SYSTÈME ===');
    
    // Test SystemSoundType.alert
    try {
      debugPrint('🔔 Test SystemSoundType.alert...');
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('✅ SystemSoundType.alert - OK');
    } catch (e) {
      debugPrint('❌ SystemSoundType.alert - ÉCHEC: $e');
    }
    
    // Test SystemSoundType.click
    try {
      debugPrint('🔔 Test SystemSoundType.click...');
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('✅ SystemSoundType.click - OK');
    } catch (e) {
      debugPrint('❌ SystemSoundType.click - ÉCHEC: $e');
    }
    
    // Test vibrations
    try {
      debugPrint('📳 Test HapticFeedback.lightImpact...');
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('✅ HapticFeedback.lightImpact - OK');
    } catch (e) {
      debugPrint('❌ HapticFeedback.lightImpact - ÉCHEC: $e');
    }
    
    try {
      debugPrint('📳 Test HapticFeedback.mediumImpact...');
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('✅ HapticFeedback.mediumImpact - OK');
    } catch (e) {
      debugPrint('❌ HapticFeedback.mediumImpact - ÉCHEC: $e');
    }
    
    try {
      debugPrint('📳 Test HapticFeedback.heavyImpact...');
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('✅ HapticFeedback.heavyImpact - OK');
    } catch (e) {
      debugPrint('❌ HapticFeedback.heavyImpact - ÉCHEC: $e');
    }
    
    debugPrint('🧪 === FIN DU TEST DES SONS ===');
  }

  /// Joue le son de notification si activé
  static Future<void> playNotificationSound() async {
    if (!_soundEnabled) {
      debugPrint('🔇 Son désactivé, pas de lecture');
      return;
    }

    try {
      debugPrint('🎵 Tentative de lecture du son de notification...');
      
      // Essayer plusieurs types de sons système
      bool soundPlayed = false;
      
      // Méthode 1: Son d'alerte
      try {
        await SystemSound.play(SystemSoundType.alert);
        soundPlayed = true;
        debugPrint('🔔 Son d\'alerte joué avec succès');
      } catch (e) {
        debugPrint('⚠️ Échec son d\'alerte: $e');
      }
      
      // Méthode 2: Son de clic si l'alerte a échoué
      if (!soundPlayed) {
        try {
          await SystemSound.play(SystemSoundType.click);
          soundPlayed = true;
          debugPrint('🔔 Son de clic joué avec succès');
        } catch (e) {
          debugPrint('⚠️ Échec son de clic: $e');
        }
      }
      
      // Méthode 3: Vibration comme alternative
      if (!soundPlayed) {
        try {
          await HapticFeedback.heavyImpact();
          debugPrint('📳 Vibration de notification activée');
        } catch (e) {
          debugPrint('⚠️ Échec vibration: $e');
        }
      }
      
      if (!soundPlayed) {
        debugPrint('❌ Aucun son n\'a pu être joué - vérifiez les paramètres audio du système');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur générale lors de la lecture du son: $e');
    }
  }

  /// Joue un son de succès
  static Future<void> playSuccessSound() async {
    if (!_soundEnabled) return;

    try {
      await SystemSound.play(SystemSoundType.click);
      debugPrint('✅ Son de succès joué');
    } catch (e) {
      debugPrint('❌ Erreur lors de la lecture du son de succès: $e');
    }
  }

  /// Joue un son d'erreur
  static Future<void> playErrorSound() async {
    if (!_soundEnabled) return;

    try {
      await SystemSound.play(SystemSoundType.alert);
      debugPrint('❌ Son d\'erreur joué');
    } catch (e) {
      debugPrint('❌ Erreur lors de la lecture du son d\'erreur: $e');
    }
  }
}
