import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import 'package:tsena_servisy/components/custom_app_bar.dart';
import 'package:tsena_servisy/services/location_service.dart';
import 'package:tsena_servisy/components/custom_text_field.dart';
import 'package:tsena_servisy/components/success_snackbar.dart';
import 'package:tsena_servisy/models/cart_item.dart';
import 'package:tsena_servisy/models/enums.dart';
import 'package:tsena_servisy/services/cart_service.dart';
import 'package:tsena_servisy/services/payment_service.dart';
import 'package:tsena_servisy/services/notification_service.dart';
import 'package:tsena_servisy/services/real_time_service.dart';
import 'package:tsena_servisy/services/user_service.dart' as user_service;

class PaymentScreen extends StatefulWidget {
  final String nif;
  final int municipalityId;

  const PaymentScreen({
    super.key, 
    required this.nif,
    required this.municipalityId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isPaying = false;
  String? _selectedPaymentMethodId;
  String? _successfulTransactionId; // To track if payment was successful but reservation failed
  bool _useDifferentNumber = false;
  String? _selectedMobileMoneyOperator;
  final TextEditingController _phoneController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {
    'cardNumber': TextEditingController(),
    'cardHolderName': TextEditingController(),
    'expirationDate': TextEditingController(),
    'cvv': TextEditingController(),
  };
  
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _transactionTypes = [];
  String? _selectedTransactionTypeId;
  String? _userProfilePhone;
  
  // Map pour stocker le nombre de mois sélectionné pour chaque local annuel
  final Map<String, int> _selectedMonthsForAnnuals = {};

  @override
  void initState() {
    super.initState();
    _initializeSelectedMonths();
    // Charger les données critiques d'abord (méthodes de paiement)
    _loadPaymentMethods();
    // Charger les données non-critiques en arrière-plan
    _loadBackgroundData();
  }

  // Charger les données non-critiques en arrière-plan
  Future<void> _loadBackgroundData() async {
    // Lancer les chargements en parallèle pour optimiser les performances
    await Future.wait([
      _loadTransactionTypes(),
      _loadUserProfile(),
    ]);
  }
  
  void _initializeSelectedMonths() {
    final cartService = Provider.of<CartService>(context, listen: false);
    for (final item in cartService.items) {
      if (item.contractType == ContractType.annual) {
        // Initialiser à 1 mois
        _selectedMonthsForAnnuals[item.local.id] = 1;
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  /// Formatte une date dans un format lisible
  /// 
  /// [date] La date à formater
  /// [withTime] Si vrai, inclut l'heure dans le format de sortie
  /// [separator] Le séparateur à utiliser entre le jour, le mois et l'année
  String _formatDate(
    DateTime date, {
    bool withTime = false,
    String separator = '/',
  }) {
    try {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      
      if (withTime) {
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return '$day$separator$month$separator$year $hour:$minute';
      }
      
      return '$day$separator$month$separator$year';
    } catch (e) {
      // En cas d'erreur, on retourne une chaîne vide
      return '';
    }
  }
  
  // Build a detail row with label and value
  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? const Color(0xFF1A1D1E) : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget pour la sélection du nombre de mois pour les contrats annuels
  Widget _buildMonthSelector(CartItem item) {
    final selectedMonths = _selectedMonthsForAnnuals[item.local.id] ?? 1;
    final monthlyPrice = (item.local.typeLocal?['tarif'] ?? 0.0).toDouble();
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'months_remaining_to_pay'.tr(namedArgs: {'max': '${item.numberOfMonths ?? 12}'}),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: (selectedMonths > 1 && _successfulTransactionId == null) ? () {
                    setState(() {
                      _selectedMonthsForAnnuals[item.local.id] = selectedMonths - 1;
                    });
                  } : null,
                  icon: Icon(
                    Icons.remove,
                    color: selectedMonths > 1 ? Theme.of(context).primaryColor : Colors.grey,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$selectedMonths ${'months_unit'.tr()}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: (selectedMonths < (item.numberOfMonths ?? 12) && _successfulTransactionId == null) ? () {
                    setState(() {
                      _selectedMonthsForAnnuals[item.local.id] = selectedMonths + 1;
                    });
                  } : null,
                  icon: Icon(
                    Icons.add,
                    color: selectedMonths < (item.numberOfMonths ?? 12) ? Theme.of(context).primaryColor : Colors.grey,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'total_to_pay'.tr(),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  '${(monthlyPrice * selectedMonths).toStringAsFixed(0)} ${'ar_currency'.tr()}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final paymentService = PaymentService(municipalityId: widget.municipalityId.toString());
      
      // Charger les méthodes en parallèle pour optimiser les performances
      final results = await Future.wait([
        paymentService.getMobileMoneyMethods(),
        paymentService.getCreditCardMethod(),
      ]);
      
      final mobileMoneyMethods = results[0] as List<Map<String, dynamic>>;
      final creditCardMethod = results[1] as Map<String, dynamic>?;
      
      if (mounted) {
        setState(() {
          _paymentMethods = [
            ...mobileMoneyMethods.map((method) => {
              ...method,
              'id': method['id'],
              'name': method['name'] ?? 'Mobile Money',
              'type': 'mobile_money',
              'description': method['description'] ?? tr('mobile_money_description'),
            }),
            if (creditCardMethod != null)
              {
                'id': creditCardMethod['id'] ?? 'credit_card',
                'name': creditCardMethod['name'] ?? tr('credit_card_name'),
                'type': 'credit_card',
                'description': creditCardMethod['description'] ?? tr('credit_card_description'),
              },
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('payment_methods_loading_error'.tr(), isError: true);
      }
    }
  }

  Future<void> _loadTransactionTypes() async {
    try {
      final paymentService = PaymentService(municipalityId: widget.municipalityId.toString());
      final response = await paymentService.getTransactionTypes(widget.municipalityId.toString());
      
      if (mounted && response['success'] == true) {
        final data = response['data'];
        final rawTransactionTypes = List<Map<String, dynamic>>.from(data['data'] ?? []);
        
        // Ensure all IDs are strings and filter if necessary
        final transactionTypes = rawTransactionTypes.map((type) {
          return {
            ...type,
            'id': type['id'].toString(), // Force ID to string
          };
        }).toList();
        
        debugPrint('Loaded ${transactionTypes.length} transaction types');
        
        // LOG: Afficher tous les types de transaction
        debugPrint('===== TYPES DE TRANSACTION DISPONIBLES =====');
        for (var type in transactionTypes) {
          debugPrint('Type: ${type['name']} | ID: ${type['id']}');
        }
        debugPrint('==========================================');
        
        // LOG: Vérifier si "PAIEMENT LOCATION" existe
        final paiementLocationExists = transactionTypes.any(
          (type) => type['name']?.toString().toUpperCase() == 'PAIEMENT LOCATION'
        );
        debugPrint('🔍 PAIEMENT LOCATION existe: ${paiementLocationExists ? "OUI ✅" : "NON ❌"}');
        
        if (mounted) {
          setState(() {
            _transactionTypes = transactionTypes;
            
            // Auto-select logic
            if (_transactionTypes.isNotEmpty) {
              // 1. Try to find by specific name "PAIEMENT LOCATION" (Primary choice)
              final paiementLocationType = _transactionTypes.firstWhere(
                (type) => type['name']?.toString().toUpperCase() == 'PAIEMENT LOCATION',
                orElse: () => <String, dynamic>{},
              );

              if (paiementLocationType.isNotEmpty) {
                _selectedTransactionTypeId = paiementLocationType['id'];
                debugPrint('✅ Auto-selected by Name: ${paiementLocationType['name']} (ID: $_selectedTransactionTypeId)');
              } else {
                debugPrint('⚠️ PAIEMENT LOCATION non trouvé, passage au fallback...');
                // 2. Try to find by specific ID (Reservation)
                // Note: We use the ID from PaymentService if available, or check for known IDs
                final reservationType = _transactionTypes.firstWhere(
                  (type) => type['id'] == PaymentService.reservationTransactionTypeId,
                  orElse: () => <String, dynamic>{},
                );

                if (reservationType.isNotEmpty) {
                   _selectedTransactionTypeId = reservationType['id'];
                   debugPrint('✅ Auto-selected by ID: ${reservationType['name']} (ID: $_selectedTransactionTypeId)');
                } else {
                  debugPrint('⚠️ Reservation ID non trouvé, passage au fallback suivant...');
                  // 3. Try to find by name containing "LOCATION" (relaxed check)
                  final locationType = _transactionTypes.firstWhere(
                    (type) => type['name']?.toString().toUpperCase().contains('LOCATION') == true,
                    orElse: () => <String, dynamic>{},
                  );
                  
                  if (locationType.isNotEmpty) {
                    _selectedTransactionTypeId = locationType['id'];
                    debugPrint('✅ Auto-selected by Name (contains LOCATION): ${locationType['name']} (ID: $_selectedTransactionTypeId)');
                  } else {
                    debugPrint('⚠️ Aucun type avec LOCATION, utilisation du premier type disponible...');
                    // 4. Fallback to the first available type
                    _selectedTransactionTypeId = _transactionTypes.first['id'];
                    debugPrint('✅ Fallback auto-selected type: ${_transactionTypes.first['name']} (ID: $_selectedTransactionTypeId)');
                  }
                }
              }
            } else {
              debugPrint('❌ No transaction types available to select');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des types de transaction: $e');
      // Ne pas afficher d'erreur pour les données en arrière-plan
      // L'utilisateur peut toujours procéder au paiement sans sélection de type
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await user_service.UserService.getUserProfile();
      if (mounted && userProfile != null) {
        setState(() {
          _userProfilePhone = userProfile['user_phone']?.toString();
          // Set default phone number if not using different number
          if (_userProfilePhone != null && !_useDifferentNumber) {
            _phoneController.text = _userProfilePhone ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement du profil utilisateur: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _submitPayment() async {
    if (_formKey.currentState?.validate() != true) {
      debugPrint('form_validation_failed'.tr());
      return;
    }
    
    // Si le paiement a déjà réussi, on ne fait que finaliser la réservation
    if (_successfulTransactionId != null) {
      await _finalizeReservation(_successfulTransactionId!);
      return;
    }

    if (_selectedPaymentMethodId == null) {
      NotificationService.showError(context, 'please_select_payment_method'.tr());
      return;
    }

    setState(() => _isPaying = true);

    try {
      // 1. Effectuer la transaction financière
      final transactionId = await _performTransaction();
      
      if (transactionId != null) {
        setState(() {
          _successfulTransactionId = transactionId;
        });
        
        // 2. Finaliser la réservation (création locations + enregistrement)
        await _finalizeReservation(transactionId);
      }
    } catch (e) {
      _handlePaymentError(e);
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  Future<String?> _performTransaction() async {
    try {
      // Récupération des services nécessaires
      final cartService = context.read<CartService>();
      final paymentService = context.read<PaymentService>();
      
      // Vérification du profil utilisateur
      final userProfile = await user_service.UserService.getUserProfile();
      
      final userId = userProfile?['user_id']?.toString();
      if (userId == null || userId.isEmpty) {
        throw Exception('user_not_connected_or_incomplete_profile'.tr());
      }

      // Vérification du type de transaction sélectionné
      if (_selectedTransactionTypeId == null) {
        if (mounted) {
          NotificationService.showError(context, tr('select_transaction_type_error'));
        }
        return null;
      }

      // Récupération de la méthode de paiement sélectionnée
      Map<String, dynamic> selectedMethod = {};
      for (var method in _paymentMethods) {
        if (method['id'] == _selectedPaymentMethodId) {
          selectedMethod = method;
          break;
        }
      }
      
      if (selectedMethod.isEmpty) {
        throw Exception('payment_method_not_found'.tr());
      }

      // Déterminer le numéro de téléphone à utiliser pour mobile money
      String? senderPhone;
      if (selectedMethod['type'] == 'mobile_money') {
        if (_useDifferentNumber) {
          senderPhone = _phoneController.text.trim();
          if (senderPhone.isEmpty) {
            if (mounted) {
              NotificationService.showError(context, tr('phone_number_required'));
            }
            return null;
          }
        } else {
          senderPhone = _userProfilePhone;
        }
      }

      // Calculer le montant total en tenant compte des mois sélectionnés
      final totalAmount = cartService.items.fold<double>(
        0, 
        (sum, item) {
          if (item.contractType == ContractType.annual) {
            final selectedMonths = _selectedMonthsForAnnuals[item.local.id] ?? 12;
            final monthlyPrice = (item.local.typeLocal?['tarif'] ?? 0.0).toDouble();
            return sum + (monthlyPrice * selectedMonths);
          } else {
            return sum + item.totalAmount;
          }
        }
      );
      
      // Soumission de la transaction de paiement
      final paymentResponse = await paymentService.submitTransaction(
        userId: userId,
        paymentMethodId: _selectedPaymentMethodId ?? '',
        amount: totalAmount,
        description: 'payment_for_local_reservation'.tr(),
        transactionTypeId: _selectedTransactionTypeId,
        senderPhone: senderPhone,
        creditCardDetails: selectedMethod['type'] == 'credit_card' ? {
          'cardNumber': _controllers['cardNumber']?.text ?? '',
          'cardHolderName': _controllers['cardHolderName']?.text ?? '',
          'expirationDate': _controllers['expirationDate']?.text ?? '',
          'cvv': _controllers['cvv']?.text ?? '',
        } : null,
      );

      // Vérification de la réponse du paiement
      if (paymentResponse['success'] == true) {
        final transactionData = paymentResponse['data']?['data'] ?? paymentResponse['data'];
        if (transactionData == null) {
          throw Exception('invalid_payment_response_missing_data'.tr());
        }
        
        final transactionStatus = transactionData['status']?.toString().toUpperCase();
        
        if (transactionStatus != 'COMPLETED') {
          throw Exception('${'invalid_transaction_status'.tr()}: $transactionStatus');
        }
        
        final transactionId = transactionData['id'];
        if (transactionId == null) {
          throw Exception('transaction_id_missing_in_response'.tr());
        }
        
        return transactionId;
      } else {
        final errorMsg = paymentResponse['message'] ?? tr('payment_failed_default');
        throw Exception(errorMsg);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _finalizeReservation(String transactionId) async {
    setState(() => _isPaying = true);
    
    try {
      final cartService = context.read<CartService>();
      final paymentService = context.read<PaymentService>();
      final locationService = LocationService();
      final realTimeService = RealTimeService();
      
      // Vérification du profil utilisateur (encore nécessaire pour l'ID)
      final userProfile = await user_service.UserService.getUserProfile();
      final userId = userProfile?['user_id']?.toString();
      
      if (userId == null) throw Exception('User ID missing');

      // Vérification de la disponibilité - seulement pour les nouvelles réservations
      for (final item in cartService.items) {
        if (item.existingLocationId != null && (item.existingLocationId?.isNotEmpty ?? false)) {
          continue;
        }
        
        final isLocalAvailable = (item.local.status == "DISPONIBLE")? true: false;
        if (!isLocalAvailable) {
          throw Exception('local_no_longer_available'.tr(namedArgs: {'name': item.local.nom}));
        }
      }

      // Création des locations pour chaque article du panier
      final List<Map<String, dynamic>> paymentLocations = [];

      for (final item in cartService.items) {
        try {
          String locationId;
          int locationFrequence = 1;
          
          if (item.existingLocationId != null && (item.existingLocationId?.isNotEmpty ?? false)) {
            locationId = item.existingLocationId ?? '';
            locationFrequence = item.numberOfMonths ?? 1;
          } else {
            final finalCheck = (item.local.status == "DISPONIBLE")? true: false;
            if (!finalCheck) {
              throw Exception('local_reserved_meanwhile'.tr(namedArgs: {'name': item.local.nom}));
            }
            
            if (item.contractType == ContractType.daily && item.selectedDates != null && item.selectedDates!.isNotEmpty) {
              final dailyPrice = (item.local.typeLocal?['tarif'] ?? 0.0).toDouble();
              
              for (int i = 0; i < item.selectedDates!.length; i++) {
                final date = item.selectedDates![i];
                final dateDebutLoc = date.toUtc().toIso8601String();
                
                final locationResponse = await locationService.createLocation(
                  userId: userId,
                  nif: widget.nif,
                  localId: item.local.id,
                  usage: item.usage,
                  periodicite: 'JOURNALIER',
                  dateDebutLoc: dateDebutLoc,
                  frequence: 1,
                );
                
                final responseLocationId = locationResponse['id_location'] ?? locationResponse['data']?['id'] ?? locationResponse['id'];
                if (responseLocationId == null) {
                  throw Exception('location_id_missing_in_response'.tr());
                }
                
                final locationData = {
                  'locationId': responseLocationId,
                  'nombre_paye': 1,
                  'montant_paye': dailyPrice,
                  'location_frequence': 1,
                  'local_nom': item.local.nom,
                  'date_debut': dateDebutLoc,
                  'is_existing_location': false,
                };
                
                paymentLocations.add(locationData);
              }
              continue;
            } else {
              final dateDebutLoc = DateTime.now().toUtc().toIso8601String();
              final locationResponse = await locationService.createLocation(
                userId: userId,
                nif: widget.nif,
                localId: item.local.id,
                usage: item.usage,
                periodicite: 'MENSUEL',
                dateDebutLoc: dateDebutLoc,
                frequence: null,
              );
              
              final responseLocationId = locationResponse['id_location'] ?? locationResponse['data']?['id'] ?? locationResponse['id'];
              if (responseLocationId == null) {
                throw Exception('location_id_missing_in_response'.tr());
              }
              locationId = responseLocationId;
              locationFrequence = locationResponse['frequence'] ?? 1;
            }
          }
          
          int nombrePaye;
          double montantPaye;
          
          if (item.contractType == ContractType.annual) {
            nombrePaye = _selectedMonthsForAnnuals[item.local.id] ?? 1;
            final monthlyPrice = (item.local.typeLocal?['tarif'] ?? 0.0).toDouble();
            montantPaye = monthlyPrice * nombrePaye;
          } else {
            final dailyPrice = (item.local.typeLocal?['tarif'] ?? 0.0).toDouble();
            nombrePaye = item.numberOfPeriods;
            montantPaye = dailyPrice * nombrePaye;
          }
          
          final validNombrePaye = nombrePaye > locationFrequence ? locationFrequence : nombrePaye;
          
          if (validNombrePaye != nombrePaye) {
            final pricePerPeriod = montantPaye / (nombrePaye > 0 ? nombrePaye : 1);
            montantPaye = pricePerPeriod * validNombrePaye;
          }
          
          final locationData = {
            'locationId': locationId,
            'nombre_paye': validNombrePaye,
            'montant_paye': montantPaye,
            'location_frequence': locationFrequence,
            'local_nom': item.local.nom,
            'date_debut': DateTime.now().toUtc().toIso8601String(),
            'is_existing_location': item.existingLocationId != null,
          };
          
          paymentLocations.add(locationData);
        } catch (e) {
          // Gestion spécifique des erreurs de local déjà réservé
          final errorMessage = e.toString().toLowerCase();
          if (errorMessage.contains('déjà') || 
              errorMessage.contains('existe déjà') ||
              errorMessage.contains('déjà réservé') ||
              errorMessage.contains('déjà en location')) {
            // NOTE: Si le paiement est déjà passé, on ne devrait peut-être pas supprimer l'item du panier
            // Mais pour l'instant on garde la logique existante, l'utilisateur devra contacter le support
            // ou on pourrait implémenter un remboursement automatique ici
            
            cartService.removeItem(item);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('local_already_reserved'.tr(namedArgs: {'name': item.local.nom})),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            
            if (cartService.items.isEmpty) {
              throw Exception('all_cart_locals_already_reserved'.tr());
            }
            return;
          }
          rethrow;
        }
      }

      // Enregistrement du paiement
      await paymentService.createPayment(
        reference: transactionId.toString(),
        status: 'success',
        raison: 'Paiement de location',
        locations: paymentLocations,
        userId: userId,
      );

      // Nettoyage et redirection
      cartService.clear();
      
      realTimeService.notifyNewPayment(
        paymentId: transactionId,
        status: 'success',
      );
      
      for (final locationData in paymentLocations) {
        if (locationData['is_existing_location'] != true) {
          realTimeService.notifyNewReservation(
            reservationId: locationData['locationId'],
            localId: locationData['locationId'],
          );
        }
      }
      
      realTimeService.refreshGeneralData();
      realTimeService.refreshNotifications();
      
      if (mounted) {
        SuccessSnackBar.show(
          context,
          'payment_and_reservation_successful'.tr(),
          icon: Icons.check_circle,
        );
        
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      _handlePaymentError(e);
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  void _handlePaymentError(dynamic e) {
    debugPrint('Erreur lors du processus de paiement: $e');
    String errorMessage = tr('unexpected_error_payment');
    
    if (e is FormatException) {
      errorMessage = 'data_format_error'.tr();
    } else if (e is http.ClientException) {
      errorMessage = 'server_connection_error'.tr();
    } else if (e is http.Response) {
      errorMessage = '${'server_error'.tr()} (${e.statusCode})';
    } else if (e is Exception) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    
    if (!errorMessage.contains('a été retiré de votre panier')) {
      if (mounted) {
        ErrorSnackBar.show(
          context,
          '${tr('error')}: $errorMessage',
          icon: Icons.error,
        );
      }
    }
  }

  List<Widget> _buildPaymentFormFields(Map<String, dynamic> selectedMethod) {
    if (selectedMethod.isEmpty) return [const SizedBox.shrink()];

    final fields = <Widget>[];
    final type = selectedMethod['type'];

    fields.add(
      Text(
        'payment_details'.tr(),
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1A1D1E),
        ),
      ),
    );

    fields.add(const SizedBox(height: 16));

    if (type == 'mobile_money') {
      fields.addAll([
        // Afficher le numéro par défaut du profil utilisateur
        if (_userProfilePhone != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_android, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  tr('default_number_label', namedArgs: {'number': _userProfilePhone!}),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Checkbox(
              value: _useDifferentNumber,
              onChanged: (value) {
                setState(() {
                  _useDifferentNumber = value ?? false;
                  if (!_useDifferentNumber && _userProfilePhone != null) {
                    _phoneController.text = _userProfilePhone ?? '';
                  } else if (_useDifferentNumber) {
                    _phoneController.clear();
                  }
                });
              },
            ),
            Expanded(
              child: Text(
                _userProfilePhone != null 
                  ? tr('use_other_number')
                  : 'use_different_number'.tr(),
              ),
            ),
          ],
        ),
      ]);

      // Utilisation de la méthode sélectionnée passée en argument

      
      if (_useDifferentNumber) {
        fields.addAll([
          const SizedBox(height: 8),
          // Opérateur Mobile Money Dropdown
          if (selectedMethod['operators'] != null && (selectedMethod['operators'] as List).isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'operator'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1D1E),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMobileMoneyOperator,
                      isExpanded: true,
                      hint: Text(tr('select_operator')),
                      items: (selectedMethod['operators'] as List<dynamic>).map<DropdownMenuItem<String>>((op) {
                        return DropdownMenuItem<String>(
                          value: op['id'],
                          child: Text(op['name'] ?? tr('unknown_operator')),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedMobileMoneyOperator = newValue;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          // Numéro de téléphone
          CustomTextField(
            controller: _phoneController,
            labelText: tr('phone_number_label'),
            prefixIcon: Icons.phone_android,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return tr('phone_number_required');
              }
              if (_selectedMobileMoneyOperator == null && selectedMethod['operators'] != null) {
                return tr('operator_required');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: TextEditingController(),
            labelText: tr('owner_name_label'),
            prefixIcon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return tr('owner_name_required');
              }
              return null;
            },
          ),
        ]);
      }
    } else if (type == 'credit_card') {
      fields.addAll([
        Text(
          'card_information'.tr(),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1D1E),
          ),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _controllers['cardNumber'] ?? TextEditingController(),
          labelText: tr('card_number_label'),
          prefixIcon: Icons.credit_card,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr('card_number_required');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _controllers['cardHolderName'] ?? TextEditingController(),
          labelText: tr('card_holder_label'),
          prefixIcon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr('card_holder_required');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: CustomTextField(
                controller: _controllers['expirationDate'] ?? TextEditingController(),
                labelText: tr('expiration_label'),
                prefixIcon: Icons.calendar_today,
                keyboardType: TextInputType.datetime,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'MM/AA';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
child: CustomTextField(
                controller: _controllers['cvv'] ?? TextEditingController(),
                labelText: tr('cvv_label'),
                prefixIcon: Icons.lock_outline,
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr('cvv_required');
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ]);
    }

    return fields;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: tr('payment_title'),
        showBackButton: true,
        gradientColors: [
          Theme.of(context).primaryColor,
          Theme.of(context).primaryColor.withBlue(200),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Récapitulatif de la commande
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'order_summary'.tr(),
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1D1E),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...Provider.of<CartService>(context, listen: true).items.map((item) {
                              final isAnnual = item.contractType == ContractType.annual;
                              final monthlyPrice = isAnnual 
                                  ? (item.local.typeLocal?['tarif'] ?? 0.0).toDouble()
                                  : 0.0;
                              final dailyPrice = !isAnnual 
                                  ? (item.local.typeLocal?['tarif'] ?? 0.0).toDouble()
                                  : 0.0;
                                  
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Ligne principale avec le nom et le montant total
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'local_number'.tr(namedArgs: {'number': item.local.number}),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${isAnnual ? 'annual_contract'.tr() : 'daily_contract'.tr()}${isAnnual && item.contractEndDate != null ? ' - ${'until_date'.tr(namedArgs: {'date': _formatDate(item.contractEndDate!, separator: '/')})}' : ''}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          isAnnual 
                                              ? '${monthlyPrice.toStringAsFixed(0)} ${'ar_currency'.tr()}${'per_month'.tr()}'
                                              : '${dailyPrice.toStringAsFixed(0)} ${'ar_currency'.tr()}${'per_day'.tr()}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isAnnual ? Colors.blue : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Détails supplémentaires pour les contrats annuels
                                    if (isAnnual) ...[
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildDetailRow(
                                              tr('days_remaining_to_pay'),
                                              '${item.numberOfMonths} mois',
                                            ),
                                            const SizedBox(height: 4),
                                            _buildDetailRow(
                                              tr('period_label_colon'),
                                              'Du ${_formatDate(DateTime.now(), separator: '/')} au ${_formatDate(item.contractEndDate!, separator: '/')}',
                                            ),
                                            const SizedBox(height: 4),
                                            _buildDetailRow(
                                              tr('contract_total_label'),
                                              '${item.totalAmount.toStringAsFixed(0)} Ar',
                                              isBold: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Sélecteur de mois pour les contrats annuels
                                      _buildMonthSelector(item),
                                    ],
                                    
                                    // Détails supplémentaires pour les contrats journaliers
                                    if (!isAnnual) ...[
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildDetailRow(
                                              tr('days_count_label'),
                                              '${item.numberOfPeriods} jour${item.numberOfPeriods > 1 ? 's' : ''}',
                                            ),
                                            const SizedBox(height: 4),
                                            _buildDetailRow(
                                              tr('total_to_pay_label'),
                                              '${item.totalAmount.toStringAsFixed(0)} Ar',
                                              isBold: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    
                                    // Séparateur entre les éléments
                                    if (item != Provider.of<CartService>(context, listen: false).items.last)
                                      const Divider(height: 24, thickness: 1),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 32),
                            // Vérifier s'il y a des contrats annuels
                            Builder(
                              builder: (context) {
                                final cartService = Provider.of<CartService>(context, listen: true);
                                final hasAnnualContracts = cartService.items.any((item) => item.contractType == ContractType.annual);
                                
                                // Calculer les totaux en tenant compte des mois sélectionnés
                                final totalAmount = cartService.items.fold<double>(
                                  0, 
                                  (sum, item) {
                                    if (item.contractType == ContractType.annual) {
                                      final selectedMonths = _selectedMonthsForAnnuals[item.local.id] ?? 1;
                                      final monthlyPrice = (item.local.typeLocal?['tarif'] ?? 0.0).toDouble();
                                      return sum + (monthlyPrice * selectedMonths);
                                    } else {
                                      return sum + item.totalAmount;
                                    }
                                  }
                                );
                                
                                final monthlyTotal = cartService.items
                                    .where((item) => item.contractType == ContractType.annual)
                                    .fold<double>(
                                      0, 
                                      (sum, item) => sum + (item.local.typeLocal?['tarif'] ?? 0.0).toDouble()
                                    );
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Afficher le total mensuel s'il y a des contrats annuels
                                    if (hasAnnualContracts) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'monthly_total'.tr(),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${monthlyTotal.toStringAsFixed(0)} ${'ar_currency'.tr()}${'per_month'.tr()}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    
                                    // Afficher le total général
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('total_amount'.tr(),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${totalAmount.toStringAsFixed(0)} ${'ar_currency'.tr()}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Type de transaction
                    if (_transactionTypes.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          tr('transaction_type_label'),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1D1E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: _transactionTypes.map<Widget>((transactionType) {
                              final isSelected = _selectedTransactionTypeId == transactionType['id'];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: _successfulTransactionId != null ? null : () {
                                    setState(() {
                                      _selectedTransactionTypeId = transactionType['id'];
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                                : Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.payment,
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey.shade500,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                transactionType['name'] ?? tr('unknown_type'),
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: isSelected
                                                      ? Theme.of(context).primaryColor
                                                      : const Color(0xFF1A1D1E),
                                                ),
                                              ),
                                              if (transactionType['description'] != null)
                                                Text(
                                                  transactionType['description'],
                                                  style: GoogleFonts.inter(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Radio<String>(
                                          value: transactionType['id'],
                                          groupValue: _selectedTransactionTypeId,
                                          onChanged: _successfulTransactionId != null ? null : (value) {
                                            setState(() {
                                              _selectedTransactionTypeId = value;
                                            });
                                          },
                                          activeColor: Theme.of(context).primaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Section Méthodes de paiement
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'payment_method'.tr(),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1D1E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: _paymentMethods.map<Widget>((method) {
                            final isSelected = _selectedPaymentMethodId == method['id'];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: _successfulTransactionId != null ? null : () {
                                  setState(() {
                                    _selectedPaymentMethodId = method['id'];
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                              : Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          method['type'] == 'mobile_money'
                                              ? Icons.phone_android
                                              : Icons.credit_card,
                                          color: isSelected
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey.shade500,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              method['name'] ?? tr('unknown_method'),
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isSelected
                                                    ? Theme.of(context).primaryColor
                                                    : const Color(0xFF1A1D1E),
                                              ),
                                            ),
                                            if (method['description'] != null)
                                              Text(
                                                method['description'],
                                                style: GoogleFonts.inter(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Radio<String>(
                                        value: method['id'],
                                        groupValue: _selectedPaymentMethodId,
                                        onChanged: _successfulTransactionId != null ? null : (value) {
                                          setState(() {
                                            _selectedPaymentMethodId = value;
                                          });
                                        },
                                        activeColor: Theme.of(context).primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Formulaire de paiement
                    if (_selectedPaymentMethodId != null) ...[
                      const SizedBox(height: 24),
                      AbsorbPointer(
                        absorbing: _successfulTransactionId != null,
                        child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildPaymentFormFields(
                              _paymentMethods.firstWhere(
                                (method) => method['id'] == _selectedPaymentMethodId,
                                orElse: () => <String, dynamic>{},
                              ),
                            ),
                          ),
                        ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Bouton de paiement
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isPaying ? null : _submitPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isPaying
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _successfulTransactionId != null
                                    ? tr('finalize_reservation')
                                    : tr('pay_now'),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

}
