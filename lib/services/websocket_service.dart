import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'user_service.dart';

class WebSocketService extends ChangeNotifier {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);

  // Events
  final StreamController<Map<String, dynamic>> _notificationEventController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _generalEventController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>> get notificationEvents => _notificationEventController.stream;
  Stream<Map<String, dynamic>> get generalEvents => _generalEventController.stream;

  /// Démarre la connexion WebSocket
  Future<void> connect() async {
    try {
      final userProfile = await UserService.getUserProfile();
      final userId = userProfile?['user_id'];
      final token = await UserService.getAccessToken();

      if (userId == null || token == null) {
        debugPrint('❌ WebSocket: Impossible de se connecter - données utilisateur manquantes');
        return;
      }

      debugPrint('🔌 WebSocket: Tentative de connexion...');
      
      // URL WebSocket avec authentification
      final wsUrl = 'wss://gateway.agvm.mg/ws/notifications/$userId?token=$token';
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Écouter les messages
      _subscription = _channel?.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      debugPrint('✅ WebSocket: Connexion établie');
      notifyListeners();

    } catch (e) {
      debugPrint('❌ WebSocket: Erreur de connexion - $e');
      _handleError(e);
    }
  }

  /// Gère les messages reçus
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      debugPrint('📨 WebSocket: Message reçu - $data');

      final eventType = data['type'] as String?;
      final payload = data['payload'] as Map<String, dynamic>?;

      if (eventType != null && payload != null) {
        switch (eventType) {
          case 'notification_count_updated':
          case 'new_notification':
          case 'notification_read':
            _notificationEventController.add({
              'type': eventType,
              'data': payload,
            });
            break;
          case 'reservation_updated':
          case 'payment_updated':
            _generalEventController.add({
              'type': eventType,
              'data': payload,
            });
            break;
          default:
            debugPrint('⚠️ WebSocket: Type d\'événement inconnu - $eventType');
        }
      }
    } catch (e) {
      debugPrint('❌ WebSocket: Erreur lors du parsing du message - $e');
    }
  }

  /// Gère les erreurs de connexion
  void _handleError(dynamic error) {
    debugPrint('❌ WebSocket: Erreur - $error');
    _isConnected = false;
    notifyListeners();
    _attemptReconnect();
  }

  /// Gère la déconnexion
  void _handleDisconnection() {
    debugPrint('🔌 WebSocket: Connexion fermée');
    _isConnected = false;
    notifyListeners();
    _attemptReconnect();
  }

  /// Tente une reconnexion automatique
  void _attemptReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ WebSocket: Nombre maximum de tentatives de reconnexion atteint');
      return;
    }

    _reconnectAttempts++;
    debugPrint('🔄 WebSocket: Tentative de reconnexion $_reconnectAttempts/$_maxReconnectAttempts');

    _reconnectTimer = Timer(_reconnectDelay, () {
      connect();
    });
  }

  /// Envoie un message via WebSocket
  void sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      try {
        _channel?.sink.add(jsonEncode(message));
        debugPrint('📤 WebSocket: Message envoyé - $message');
      } catch (e) {
        debugPrint('❌ WebSocket: Erreur lors de l\'envoi - $e');
      }
    } else {
      debugPrint('⚠️ WebSocket: Impossible d\'envoyer le message - non connecté');
    }
  }

  /// Marque une notification comme lue via WebSocket
  void markNotificationAsRead(String notificationId) {
    sendMessage({
      'action': 'mark_as_read',
      'notification_id': notificationId,
    });
  }

  /// Marque toutes les notifications comme lues via WebSocket
  void markAllNotificationsAsRead() {
    sendMessage({
      'action': 'mark_all_as_read',
    });
  }

  /// Ferme la connexion WebSocket
  void disconnect() {
    debugPrint('🔌 WebSocket: Fermeture de la connexion');
    
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close(status.goingAway);
    
    _isConnected = false;
    _reconnectAttempts = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _notificationEventController.close();
    _generalEventController.close();
    super.dispose();
  }
}
