import 'package:flutter/foundation.dart';
import 'package:tsena_servisy/models/local_model.dart';
import 'package:tsena_servisy/models/enums.dart';

class CartItem {
  final LocalModel local;
  final List<DateTime>? selectedDates;
  final DateTime? contractEndDate;
  final ContractType contractType;
  final String? paymentMethodId;
  final String? transactionId;
  final DateTime? paymentDate;
  final bool isPaid;
  final String usage; // Usage du local (ex: "Fivarotana voakazo")
  final int? numberOfMonths; // Nombre de mois pour les contrats annuels
  final String? existingLocationId; // ID de location existante pour les paiements restants
  
  // Cache pour éviter les recalculs
  double? _cachedTotalAmount;
  int? _cachedNumberOfPeriods;

  CartItem({
    required this.local,
    this.selectedDates,
    this.contractEndDate,
    required this.contractType,
    this.paymentMethodId,
    this.transactionId,
    this.paymentDate,
    this.isPaid = false,
    this.usage = 'Fivarotana voakazo', // Valeur par défaut
    this.numberOfMonths, // Nombre de mois pour les contrats annuels
    this.existingLocationId, // ID de location existante
  });

  double get totalAmount {
    // Utiliser le cache si disponible
    if (_cachedTotalAmount != null) {
      return _cachedTotalAmount!;
    }
    
    try {
      debugPrint('💰 CartItem.totalAmount - CALCUL INITIAL');
      debugPrint('💰 ContractType: $contractType');
      
      double total;
      if (contractType == ContractType.daily) {
        // Pour un contrat journalier, calculer selon le nombre de jours sélectionnés
        final tarif = local.typeLocal?['tarif'];
        final dailyPrice = (tarif ?? 0.0) as num;
        final daysCount = selectedDates?.length ?? 0;
        total = (daysCount * dailyPrice).toDouble();
        debugPrint('💰 Total journalier calculé: $total');
      } else {
        // Pour un contrat annuel, calculer selon le nombre de mois choisi
        final tarif = local.typeLocal?['tarif'];
        final monthlyPrice = (tarif ?? 0.0) as num;
        final months = numberOfMonths ?? 1;
        total = (monthlyPrice * months).toDouble();
        debugPrint('💰 Total annuel calculé: $total');
      }
      
      // Mettre en cache le résultat
      _cachedTotalAmount = total;
      return total;
    } catch (e) {
      debugPrint('❌ ERREUR dans CartItem.totalAmount: $e');
      return 0.0;
    }
  }

  // Getter pour obtenir le nombre de périodes payées
  int get numberOfPeriods {
    // Utiliser le cache si disponible
    if (_cachedNumberOfPeriods != null) {
      return _cachedNumberOfPeriods!;
    }
    
    try {
      debugPrint('📅 CartItem.numberOfPeriods - CALCUL INITIAL');
      debugPrint('📅 ContractType: $contractType');
      
      int periods;
      if (contractType == ContractType.daily) {
        periods = selectedDates?.length ?? 1;
        debugPrint('📅 Périodes journalières: $periods');
      } else {
        periods = numberOfMonths ?? 1;
        debugPrint('📅 Périodes mensuelles: $periods');
      }
      
      // Mettre en cache le résultat
      _cachedNumberOfPeriods = periods;
      return periods;
    } catch (e) {
      debugPrint('❌ ERREUR dans CartItem.numberOfPeriods: $e');
      return 1;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'local': local.toJson(),
      'selectedDates': selectedDates?.map((d) => d.toIso8601String()).toList(),
      'contractEndDate': contractEndDate?.toIso8601String(),
      'contractType': contractType.toString(),
      'paymentMethodId': paymentMethodId,
      'transactionId': transactionId,
      'paymentDate': paymentDate?.toIso8601String(),
      'isPaid': isPaid,
      'usage': usage,
      'numberOfMonths': numberOfMonths,
      'existingLocationId': existingLocationId,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      local: LocalModel.fromJson(json['local']),
      selectedDates: json['selectedDates'] != null
          ? (json['selectedDates'] as List)
              .map((d) => DateTime.parse(d as String))
              .toList()
          : null,
      contractEndDate: json['contractEndDate'] != null
          ? DateTime.parse(json['contractEndDate'] as String)
          : null,
      contractType: json['contractType'] == 'ContractType.annual'
          ? ContractType.annual
          : ContractType.daily,
      paymentMethodId: json['paymentMethodId'],
      transactionId: json['transactionId'],
      paymentDate: json['paymentDate'] != null
          ? DateTime.parse(json['paymentDate'] as String)
          : null,
      isPaid: json['isPaid'] ?? false,
      usage: json['usage'] ?? 'Fivarotana voakazo',
      numberOfMonths: json['numberOfMonths'],
      existingLocationId: json['existingLocationId'],
    );
  }
}
