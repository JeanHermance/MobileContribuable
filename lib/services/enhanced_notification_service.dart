import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class EnhancedNotificationService {
  static final EnhancedNotificationService _instance = EnhancedNotificationService._internal();
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();

  // Services
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // État
  bool _isInitialized = false;
  bool _soundEnabled = true;
  bool _pushNotificationsEnabled = true;
  BuildContext? _context;
  
  // Overlay pour les notifications en haut
  OverlayEntry? _currentNotificationOverlay;
  Timer? _notificationTimer;

  /// Initialise le service de notifications
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;
    
    _context = context;
    
    try {
      // Charger les préférences
      await _loadPreferences();
      
      // Initialiser l'AudioPlayer
      await _initializeAudioPlayer();
      
      // Initialiser les notifications locales
      await _initializeLocalNotifications();
      
      // Demander les permissions
      await _requestPermissions();
      
      _isInitialized = true;
      debugPrint('✅ Enhanced Notification Service initialisé');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation du service de notifications: $e');
    }
  }
  
  /// Initialise le système de son (utilise maintenant les sons système)
  Future<void> _initializeAudioPlayer() async {
    try {
      // Vérifier la plateforme
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        debugPrint('🖥️ Plateforme desktop détectée - Sons système disponibles');
        return;
      }
      
      // Mobile: sons système + vibration disponibles
      debugPrint('📱 Plateforme mobile détectée - Sons système + vibration disponibles');
      
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation du système de son: $e');
    }
  }

  /// Initialise les notifications locales
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // Configuration Linux pour éviter l'erreur
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Demande les permissions nécessaires
  Future<void> _requestPermissions() async {
    // Permission pour les notifications
    await Permission.notification.request();
    
    // Permission pour les sons (Android)
    if (await Permission.audio.isDenied) {
      await Permission.audio.request();
    }
  }

  /// Charge les préférences utilisateur
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('notification_sound_enabled') ?? true;
    _pushNotificationsEnabled = prefs.getBool('push_notifications_enabled') ?? true;
  }

  /// Sauvegarde les préférences utilisateur
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_sound_enabled', _soundEnabled);
    await prefs.setBool('push_notifications_enabled', _pushNotificationsEnabled);
  }

  /// Active/désactive le son des notifications
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _savePreferences();
    debugPrint('🔊 Son des notifications: ${enabled ? "activé" : "désactivé"}');
  }

  /// Active/désactive les notifications push
  Future<void> setPushNotificationsEnabled(bool enabled) async {
    _pushNotificationsEnabled = enabled;
    await _savePreferences();
    debugPrint('📱 Notifications push: ${enabled ? "activées" : "désactivées"}');
  }

  /// Getters pour les préférences
  bool get soundEnabled => _soundEnabled;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;

  /// Affiche une notification en haut de l'écran (style Facebook/Messenger)
  void showTopNotification({
    required String title,
    required String message,
    String? avatar,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
    Color backgroundColor = Colors.white, // Fond blanc
  }) {
    if (_context == null || !_context!.mounted) return;

    // Supprimer la notification précédente si elle existe
    _hideCurrentNotification();

    // Jouer le son si activé
    if (_soundEnabled) {
      _playNotificationSound();
    }

    // Faire vibrer le téléphone
    HapticFeedback.lightImpact();

    // Créer l'overlay de notification
    _currentNotificationOverlay = OverlayEntry(
      builder: (context) => _buildTopNotificationWidget(
        title: title,
        message: message,
        avatar: avatar,
        onTap: onTap,
        backgroundColor: backgroundColor,
      ),
    );

    // Insérer l'overlay
    Overlay.of(_context!).insert(_currentNotificationOverlay!);

    // Programmer la suppression automatique
    _notificationTimer = Timer(duration, () {
      _hideCurrentNotification();
    });
  }

  /// Construit le widget de notification en haut
  Widget _buildTopNotificationWidget({
    required String title,
    required String message,
    String? avatar,
    VoidCallback? onTap,
    required Color backgroundColor,
  }) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: GestureDetector(
          onTap: () {
            _hideCurrentNotification();
            onTap?.call();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar ou icône
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: avatar != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            avatar,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.notifications, color: Color(0xFF1877F2), size: 24),
                          ),
                        )
                      : const Icon(Icons.notifications, color: Color(0xFF1877F2), size: 24),
                ),
                const SizedBox(width: 12),
                
                // Contenu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black.withValues(alpha: 0.7),
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Bouton fermer
                GestureDetector(
                  onTap: _hideCurrentNotification,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: Colors.black.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Cache la notification actuelle
  void _hideCurrentNotification() {
    _notificationTimer?.cancel();
    _currentNotificationOverlay?.remove();
    _currentNotificationOverlay = null;
  }

  /// Joue le son de notification
  Future<void> _playNotificationSound() async {
    try {
      // Utiliser la vibration système sur toutes les plateformes
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        debugPrint('🖥️ Desktop: Utilisation de la vibration système');
        HapticFeedback.mediumImpact();
        return;
      }
      
      // Pour mobile: utiliser vibration + son système
      debugPrint('📱 Mobile: Utilisation de la vibration + son système');
      HapticFeedback.mediumImpact();
      
      // Jouer un son système simple
      SystemSound.play(SystemSoundType.alert);
      
    } catch (e) {
      // Fallback vers vibration simple
      debugPrint('⚠️ Erreur lors de la lecture du son: $e');
      debugPrint('🔄 Utilisation de la vibration uniquement');
      HapticFeedback.mediumImpact();
    }
  }

  /// Affiche une notification système (Android/iOS)
  Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_pushNotificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'reservation_notifications',
      'Notifications de réservation',
      channelDescription: 'Notifications pour les réservations et paiements',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Gère le tap sur une notification système
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tappée: ${response.payload}');
    // Implémenter la navigation selon le payload
  }

  /// Traite une nouvelle notification reçue
  void processNewNotification(NotificationModel notification) {
    debugPrint('🔔 Nouvelle notification reçue: ${notification.title}');
    
    // Vérifier si la notification est récente (moins de 5 minutes)
    final now = DateTime.now();
    final difference = now.difference(notification.createdAt);
    
    if (difference.inMinutes > 5) {
      debugPrint('🔕 Notification ancienne (${difference.inMinutes} min), pas de son/overlay');
      return;
    }
    
    // Afficher la notification en haut de l'écran
    showTopNotification(
      title: notification.title,
      message: notification.message,
      onTap: () {
        // Navigation vers l'écran de notifications ou action spécifique
        debugPrint('👆 Notification tappée: ${notification.id}');
      },
    );

    // Afficher aussi une notification système si l'app est en arrière-plan
    showSystemNotification(
      title: notification.title,
      body: notification.message,
      payload: notification.id,
    );
  }

  /// Nettoie les ressources
  void dispose() {
    _hideCurrentNotification();
    // Plus de _audioPlayer à nettoyer
  }
}
