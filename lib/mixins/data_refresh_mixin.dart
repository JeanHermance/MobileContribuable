import 'dart:async';
import 'package:flutter/material.dart';
import '../services/real_time_service.dart';

/// Mixin pour faciliter l'écoute des changements de données en temps réel
/// 
/// Utilisation:
/// ```dart
/// class MyTabState extends State<MyTab> with DataRefreshMixin {
///   @override
///   void initState() {
///     super.initState();
///     startListeningToDataChanges(['reservations', 'payments']);
///   }
///   
///   @override
///   Future<void> onDataChanged(String dataType, Map<String, dynamic> metadata) async {
///     if (dataType == 'reservations') {
///       await _loadReservations();
///     }
///   }
/// }
/// ```
mixin DataRefreshMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<Map<String, dynamic>>? _dataChangeSubscription;
  final RealTimeService _realTimeService = RealTimeService();
  List<String> _listenedDataTypes = [];

  /// Démarre l'écoute des changements de données pour les types spécifiés
  void startListeningToDataChanges(List<String> dataTypes) {
    _listenedDataTypes = dataTypes;
    _dataChangeSubscription?.cancel();
    
    _dataChangeSubscription = _realTimeService.dataChangeStream.listen((event) {
      final dataType = event['type'] as String?;
      final metadata = event['metadata'] as Map<String, dynamic>? ?? {};
      
      if (dataType != null && _listenedDataTypes.contains(dataType)) {
        debugPrint('🔄 [$T] Changement de données détecté: $dataType');
        
        // Appeler la méthode de rafraîchissement avec un délai pour éviter les appels multiples
        _debounceRefresh(dataType, metadata);
      }
    });
    
    debugPrint('👂 [$T] Écoute des changements de données: $_listenedDataTypes');
  }

  /// Arrête l'écoute des changements de données
  void stopListeningToDataChanges() {
    _dataChangeSubscription?.cancel();
    _dataChangeSubscription = null;
    debugPrint('🔇 [$T] Arrêt de l\'écoute des changements de données');
  }

  Timer? _debounceTimer;
  
  /// Debounce pour éviter les rafraîchissements multiples rapides
  void _debounceRefresh(String dataType, Map<String, dynamic> metadata) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        onDataChanged(dataType, metadata);
      }
    });
  }

  /// Méthode à implémenter pour gérer les changements de données
  /// 
  /// [dataType] - Le type de données qui a changé ('reservations', 'payments', etc.)
  /// [metadata] - Métadonnées supplémentaires sur le changement
  Future<void> onDataChanged(String dataType, Map<String, dynamic> metadata);

  /// Méthode utilitaire pour rafraîchir manuellement les données
  void triggerManualRefresh() {
    debugPrint('🔄 [$T] Rafraîchissement manuel déclenché');
    _realTimeService.forceRefresh();
  }

  /// Méthode utilitaire pour notifier un changement de données depuis ce widget
  void notifyDataChange(String dataType, {Map<String, dynamic>? metadata}) {
    _realTimeService.notifyDataChange(dataType, metadata: metadata);
  }

  @override
  void dispose() {
    stopListeningToDataChanges();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

