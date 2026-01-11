import 'package:flutter/material.dart';
import 'real_time_service.dart';

/// Service pour gérer les événements de l'application et déclencher
/// les rafraîchissements automatiques des données
class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final RealTimeService _realTimeService = RealTimeService();

  /// Appelé après qu'une réservation ait été créée avec succès
  void onReservationCreated({
    required String reservationId,
    Map<String, dynamic>? reservationData,
  }) {
    debugPrint('🎉 Nouvelle réservation créée: $reservationId');
    
    // Notifier le changement des réservations
    _realTimeService.notifyNewReservation();
    
    // Rafraîchir les notifications pour voir les confirmations
    _realTimeService.refreshNotifications();
    
    debugPrint('✅ Événements de réservation déclenchés');
  }

  /// Appelé après qu'un paiement ait été effectué avec succès
  void onPaymentCompleted({
    required String paymentId,
    required String status,
    Map<String, dynamic>? paymentData,
  }) {
    debugPrint('💳 Paiement complété: $paymentId (status: $status)');
    
    if (status.toLowerCase() == 'success') {
      // Notifier le changement des paiements
      _realTimeService.notifyNewPayment();
      
      // Si le paiement concerne une réservation, rafraîchir aussi les réservations
      _realTimeService.notifyNewReservation();
      
      // Rafraîchir les notifications
      _realTimeService.refreshNotifications();
      
      debugPrint('✅ Événements de paiement réussi déclenchés');
    } else {
      debugPrint('⚠️ Paiement échoué, pas de rafraîchissement des données');
    }
  }

  /// Appelé après qu'une réservation ait été annulée
  void onReservationCancelled({
    required String reservationId,
    Map<String, dynamic>? reservationData,
  }) {
    debugPrint('❌ Réservation annulée: $reservationId');
    
    // Notifier le changement des réservations
    _realTimeService.notifyNewReservation();
    
    // Rafraîchir les notifications
    _realTimeService.refreshNotifications();
    
    debugPrint('✅ Événements d\'annulation déclenchés');
  }

  /// Appelé après qu'une réservation ait été modifiée
  void onReservationUpdated({
    required String reservationId,
    Map<String, dynamic>? reservationData,
  }) {
    debugPrint('📝 Réservation mise à jour: $reservationId');
    
    // Notifier le changement des réservations
    _realTimeService.notifyNewReservation();
    
    debugPrint('✅ Événements de mise à jour déclenchés');
  }

  /// Force le rafraîchissement de toutes les données
  Future<void> forceRefreshAll() async {
    debugPrint('🔄 Force refresh de toutes les données demandé');
    
    _realTimeService.notifyNewReservation();
    _realTimeService.notifyNewPayment();
    await _realTimeService.forceRefresh();
    
    debugPrint('✅ Force refresh terminé');
  }

  /// Méthode utilitaire pour déclencher manuellement un rafraîchissement
  /// Utile pour les tests ou les cas spéciaux
  void triggerDataRefresh(String dataType) {
    debugPrint('🔧 Déclenchement manuel du rafraîchissement: $dataType');
    _realTimeService.notifyDataChange(dataType);
  }
}
