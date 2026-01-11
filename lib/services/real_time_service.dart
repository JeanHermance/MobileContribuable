import 'dart:async';
import 'package:flutter/material.dart';
import 'notification_api_service.dart';
import 'websocket_service.dart';
import 'enhanced_notification_service.dart';
import '../models/notification_model.dart';

class RealTimeService extends ChangeNotifier {
  static final RealTimeService _instance = RealTimeService._internal();
  factory RealTimeService() => _instance;
  RealTimeService._internal();

  WebSocketService? _webSocketService;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _generalSubscription;
  
  int _unreadNotificationCount = 0;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  final EnhancedNotificationService _enhancedNotificationService = EnhancedNotificationService();
  final List<String> _processedNotificationIds = []; // Pour éviter les doublons

  int get unreadNotificationCount => _unreadNotificationCount;
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isWebSocketConnected => _webSocketService?.isConnected ?? false;

  /// Démarre le service de mise à jour en temps réel (fallback sur API REST)
  void startRealTimeUpdates() {
    debugPrint('🚀 Démarrage du service de notifications (API REST fallback)');
    
    // Arrêter les connexions existantes
    stopRealTimeUpdates();
    
    // Charger les données initiales
    refreshNotifications();
    
    // WebSocket temporairement désactivé - utiliser polling intelligent
    // Polling uniquement sur actions utilisateur ou rafraîchissement manuel
    debugPrint('⚠️ WebSocket désactivé temporairement - utilisation API REST uniquement');
  }

  /// Arrête le service de mise à jour en temps réel
  void stopRealTimeUpdates() {
    debugPrint('🛑 Arrêt du service WebSocket');
    _notificationSubscription?.cancel();
    _generalSubscription?.cancel();
    _webSocketService?.disconnect();
  }


  /// Rafraîchit les notifications
  Future<void> refreshNotifications() async {
    try {
      debugPrint('🔄 Rafraîchissement des notifications...');
      
      // Récupérer le nombre de notifications non lues
      final countResponse = await NotificationApiService.getUnreadNotificationCount();
      debugPrint('📊 Réponse API count: success=${countResponse.success}, data=${countResponse.data}, error=${countResponse.error}');
      
      if (countResponse.success && countResponse.data != null) {
        final newCount = countResponse.data!;
        debugPrint('🔢 Nouveau count: $newCount, ancien count: $_unreadNotificationCount');
        if (newCount != _unreadNotificationCount) {
          _unreadNotificationCount = newCount;
          debugPrint('✅ Count mis à jour: $_unreadNotificationCount');
          notifyListeners();
        }
      } else {
        debugPrint('❌ Erreur lors de la récupération du count: ${countResponse.error}');
      }

      // Récupérer toutes les notifications
      final notificationsResponse = await NotificationApiService.getNotifications();
      debugPrint('📧 Notifications response: ${notificationsResponse.success ? "Success" : "Error: ${notificationsResponse.error}"}');
      if (notificationsResponse.success && notificationsResponse.data != null) {
        final data = notificationsResponse.data!;
        final notificationsList = data['data'] as List<dynamic>? ?? [];
        
        final newNotifications = notificationsList
            .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Trier par date de création (plus récent en premier)
        newNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        if (_notifications.length != newNotifications.length ||
            !_areNotificationListsEqual(_notifications, newNotifications)) {
          
          // Détecter les nouvelles notifications
          final previousIds = _notifications.map((n) => n.id).toSet();
          final newIds = newNotifications.map((n) => n.id).toSet();
          final reallyNewIds = newIds.difference(previousIds);
          
          // Afficher les notifications pour les nouvelles entrées
          for (final newNotification in newNotifications) {
            if (reallyNewIds.contains(newNotification.id) && 
                !_processedNotificationIds.contains(newNotification.id)) {
              
              debugPrint('🔔 Nouvelle notification détectée: ${newNotification.title}');
              _enhancedNotificationService.processNewNotification(newNotification);
              _processedNotificationIds.add(newNotification.id);
              
              // Limiter la liste des IDs traités pour éviter une croissance infinie
              if (_processedNotificationIds.length > 100) {
                _processedNotificationIds.removeRange(0, 50);
              }
            }
          }
          
          _notifications = newNotifications;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du rafraîchissement des notifications: $e');
    }
  }

  /// Compare deux listes de notifications pour détecter les changements
  bool _areNotificationListsEqual(List<NotificationModel> list1, List<NotificationModel> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || 
          list1[i].isRead != list2[i].isRead ||
          list1[i].updatedAt != list2[i].updatedAt) {
        return false;
      }
    }
    return true;
  }

  /// Marque une notification comme lue via API REST
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final response = await NotificationApiService.markNotificationAsRead(notificationId);
      if (response.success) {
        // Mettre à jour localement
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1 && !_notifications[index].isRead) {
          _notifications[index] = _notifications[index].copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
          _unreadNotificationCount = (_unreadNotificationCount - 1).clamp(0, double.infinity).toInt();
          debugPrint('✅ Notification marquée comme lue via API: $notificationId');
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du marquage de la notification: $e');
    }
  }

  /// Marque toutes les notifications comme lues via API REST
  Future<void> markAllNotificationsAsRead() async {
    try {
      final response = await NotificationApiService.markAllNotificationsAsRead();
      if (response.success) {
        // Mettre à jour localement
        _notifications = _notifications.map((n) => n.copyWith(
          isRead: true,
          readAt: DateTime.now(),
        )).toList();
        _unreadNotificationCount = 0;
        debugPrint('✅ Toutes les notifications marquées comme lues via API');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du marquage de toutes les notifications: $e');
    }
  }

  // Événements pour notifier les changements de données
  final StreamController<Map<String, dynamic>> _dataChangeController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataChangeStream => _dataChangeController.stream;

  /// Notifie un changement de données spécifique avec métadonnées
  void notifyDataChange(String dataType, {Map<String, dynamic>? metadata}) {
    final event = {
      'type': dataType,
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': metadata ?? {},
    };
    debugPrint('🔔 Notification de changement de données: $dataType ${metadata != null ? 'avec métadonnées: $metadata' : ''}');
    _dataChangeController.add(event);
    
    // Déclencher un rafraîchissement automatique des notifications
    Future.delayed(const Duration(milliseconds: 500), () {
      refreshNotifications();
    });
  }

  /// Notifie qu'une nouvelle réservation a été créée
  void notifyNewReservation({String? reservationId, String? localId}) {
    notifyDataChange('reservations', metadata: {
      'action': 'created',
      'reservationId': reservationId,
      'localId': localId,
    });
  }

  /// Notifie qu'une réservation a été modifiée
  void notifyReservationUpdated({String? reservationId, String? status}) {
    notifyDataChange('reservations', metadata: {
      'action': 'updated',
      'reservationId': reservationId,
      'status': status,
    });
  }

  /// Notifie qu'une réservation a été annulée
  void notifyReservationCancelled({String? reservationId}) {
    notifyDataChange('reservations', metadata: {
      'action': 'cancelled',
      'reservationId': reservationId,
    });
  }

  /// Notifie qu'un nouveau paiement a été effectué
  void notifyNewPayment({String? paymentId, double? amount, String? status}) {
    notifyDataChange('payments', metadata: {
      'action': 'created',
      'paymentId': paymentId,
      'amount': amount,
      'status': status,
    });
  }

  /// Notifie qu'un paiement a été mis à jour
  void notifyPaymentUpdated({String? paymentId, String? status}) {
    notifyDataChange('payments', metadata: {
      'action': 'updated',
      'paymentId': paymentId,
      'status': status,
    });
  }

  /// Notifie qu'un local a été créé ou modifié
  void notifyLocalChanged({String? localId, String? zoneId, String? action}) {
    notifyDataChange('locals', metadata: {
      'action': action ?? 'updated',
      'localId': localId,
      'zoneId': zoneId,
    });
  }

  /// Notifie qu'une zone a été créée ou modifiée
  void notifyZoneChanged({String? zoneId, String? municipalityId, String? action}) {
    notifyDataChange('zones', metadata: {
      'action': action ?? 'updated',
      'zoneId': zoneId,
      'municipalityId': municipalityId,
    });
  }

  /// Notifie qu'un profil utilisateur a été mis à jour
  void notifyProfileUpdated({String? userId}) {
    notifyDataChange('profile', metadata: {
      'action': 'updated',
      'userId': userId,
    });
  }

  /// Notifie qu'une nouvelle notification a été reçue
  void notifyNewNotification({String? notificationId, String? type}) {
    notifyDataChange('notifications', metadata: {
      'action': 'created',
      'notificationId': notificationId,
      'type': type,
    });
  }

  /// Rafraîchit les données générales (réservations, paiements, etc.)
  Future<void> _refreshGeneralData() async {
    // Cette méthode peut être étendue pour rafraîchir d'autres données
    // comme les réservations, l'historique des paiements, etc.
    debugPrint('Rafraîchissement des données générales...');
  }

  /// Méthode publique pour rafraîchir les données générales
  Future<void> refreshGeneralData() async {
    await _refreshGeneralData();
  }

  /// Force le rafraîchissement de toutes les données
  Future<void> forceRefresh() async {
    debugPrint('🔄 Force refresh demandé');
    _isLoading = true;
    notifyListeners();
    
    await Future.wait([
      refreshNotifications(),
      _refreshGeneralData(),
    ]);
    
    _isLoading = false;
    notifyListeners();
  }

  /// Méthode de test pour simuler des notifications
  void simulateNotifications(int count) {
    debugPrint('🧪 Simulation de $count notifications');
    _unreadNotificationCount = count;
    notifyListeners();
  }

  @override
  void dispose() {
    stopRealTimeUpdates();
    _dataChangeController.close();
    super.dispose();
  }
}
