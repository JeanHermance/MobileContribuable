import 'dart:async';
import 'package:flutter/foundation.dart';
import 'real_time_service.dart';

/// Service spécialisé pour gérer le rechargement automatique des données
/// après des événements comme les paiements réussis
class DataRefreshService extends ChangeNotifier {
  static final DataRefreshService _instance = DataRefreshService._internal();
  factory DataRefreshService() => _instance;
  DataRefreshService._internal();

  final RealTimeService _realTimeService = RealTimeService();
  StreamSubscription<Map<String, dynamic>>? _dataChangeSubscription;
  
  // Cache des callbacks de rechargement par type de données
  final Map<String, List<VoidCallback>> _refreshCallbacks = {};
  
  // État de rechargement
  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  /// Initialise le service d'écoute des changements de données
  void initialize() {
    debugPrint('🔄 Initialisation du DataRefreshService');
    
    _dataChangeSubscription?.cancel();
    _dataChangeSubscription = _realTimeService.dataChangeStream.listen((event) {
      _handleDataChange(event);
    });
  }

  /// Gère les changements de données reçus
  void _handleDataChange(Map<String, dynamic> event) {
    final dataType = event['type'] as String?;
    final metadata = event['metadata'] as Map<String, dynamic>?;
    
    debugPrint('🔔 DataRefreshService - Changement détecté: $dataType');
    debugPrint('📋 Métadonnées: $metadata');
    
    if (dataType != null) {
      _triggerRefreshCallbacks(dataType, metadata);
    }
  }

  /// Déclenche les callbacks de rechargement pour un type de données
  void _triggerRefreshCallbacks(String dataType, Map<String, dynamic>? metadata) {
    final callbacks = _refreshCallbacks[dataType];
    if (callbacks != null && callbacks.isNotEmpty) {
      debugPrint('🔄 Déclenchement de ${callbacks.length} callbacks pour $dataType');
      
      // Déclencher les callbacks avec un délai pour éviter les conflits
      Future.delayed(const Duration(milliseconds: 300), () {
        for (final callback in callbacks) {
          try {
            callback();
          } catch (e) {
            debugPrint('❌ Erreur lors de l\'exécution du callback: $e');
          }
        }
      });
    }
  }

  /// Enregistre un callback de rechargement pour un type de données
  void registerRefreshCallback(String dataType, VoidCallback callback) {
    _refreshCallbacks.putIfAbsent(dataType, () => []);
    _refreshCallbacks[dataType]!.add(callback);
    debugPrint('✅ Callback enregistré pour $dataType (${_refreshCallbacks[dataType]!.length} total)');
  }

  /// Supprime un callback de rechargement
  void unregisterRefreshCallback(String dataType, VoidCallback callback) {
    final callbacks = _refreshCallbacks[dataType];
    if (callbacks != null) {
      callbacks.remove(callback);
      if (callbacks.isEmpty) {
        _refreshCallbacks.remove(dataType);
      }
      debugPrint('🗑️ Callback supprimé pour $dataType');
    }
  }

  /// Supprime tous les callbacks pour un type de données
  void clearRefreshCallbacks(String dataType) {
    _refreshCallbacks.remove(dataType);
    debugPrint('🗑️ Tous les callbacks supprimés pour $dataType');
  }

  /// Force le rechargement pour un type de données spécifique
  void forceRefresh(String dataType, {Map<String, dynamic>? metadata}) {
    debugPrint('🔄 Force refresh demandé pour $dataType');
    _triggerRefreshCallbacks(dataType, metadata);
  }

  /// Méthode utilitaire pour notifier un paiement réussi
  void notifyPaymentSuccess({
    String? paymentId,
    double? amount,
    String? userId,
  }) {
    debugPrint('💳 Notification de paiement réussi: $paymentId');
    
    _realTimeService.notifyNewPayment(
      paymentId: paymentId,
      amount: amount,
      status: 'success',
    );
  }

  /// Méthode utilitaire pour notifier une nouvelle réservation
  void notifyNewReservation({
    String? reservationId,
    String? localId,
    String? userId,
  }) {
    debugPrint('📋 Notification de nouvelle réservation: $reservationId');
    
    _realTimeService.notifyNewReservation(
      reservationId: reservationId,
      localId: localId,
    );
  }

  /// Méthode utilitaire pour notifier une mise à jour de profil
  void notifyProfileUpdate({String? userId}) {
    debugPrint('👤 Notification de mise à jour de profil: $userId');
    
    _realTimeService.notifyProfileUpdated(userId: userId);
  }

  /// Démarre un rechargement global avec indicateur de chargement
  Future<void> startGlobalRefresh() async {
    if (_isRefreshing) {
      debugPrint('⚠️ Rechargement déjà en cours, ignoré');
      return;
    }

    _isRefreshing = true;
    notifyListeners();
    
    try {
      debugPrint('🔄 Démarrage du rechargement global');
      
      // Déclencher tous les callbacks de rechargement
      for (final dataType in _refreshCallbacks.keys) {
        _triggerRefreshCallbacks(dataType, {'global': true});
      }
      
      // Attendre un peu pour laisser le temps aux callbacks de s'exécuter
      await Future.delayed(const Duration(milliseconds: 500));
      
      debugPrint('✅ Rechargement global terminé');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du rechargement global: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    debugPrint('🗑️ Nettoyage du DataRefreshService');
    _dataChangeSubscription?.cancel();
    _refreshCallbacks.clear();
    super.dispose();
  }
}

/// Mixin pour faciliter l'utilisation du DataRefreshService dans les widgets
mixin DataRefreshMixin {
  final DataRefreshService _dataRefreshService = DataRefreshService();
  
  /// Enregistre un callback de rechargement
  void registerDataRefresh(String dataType, VoidCallback callback) {
    _dataRefreshService.registerRefreshCallback(dataType, callback);
  }
  
  /// Supprime un callback de rechargement
  void unregisterDataRefresh(String dataType, VoidCallback callback) {
    _dataRefreshService.unregisterRefreshCallback(dataType, callback);
  }
  
  /// Force un rechargement
  void forceDataRefresh(String dataType, {Map<String, dynamic>? metadata}) {
    _dataRefreshService.forceRefresh(dataType, metadata: metadata);
  }
}
