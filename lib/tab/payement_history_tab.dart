import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tsena_servisy/services/user_service.dart';
import '../models/payment_history.dart';
import '../models/user_location.dart';
import '../services/payment_service.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../screens/payment/payment_screen.dart';
import '../models/cart_item.dart';
import '../models/local_model.dart';
import '../models/enums.dart';
import '../services/cart_service.dart';
import '../mixins/data_refresh_mixin.dart';
import '../screens/receipt_viewer_screen.dart';
import '../services/receipt_service.dart';

class PaymentHistoryTab extends StatefulWidget {
  final String? initialFilter;
  
  const PaymentHistoryTab({super.key, this.initialFilter});

  @override
  State<PaymentHistoryTab> createState() => _PaymentHistoryTabState();
}

class _PaymentHistoryTabState extends State<PaymentHistoryTab> with TickerProviderStateMixin, DataRefreshMixin {
  bool _isLoading = true;
  String? _error;
  List<PaymentHistory> _payments = [];
  List<UserLocation> _pendingLocations = [];
  final Map<String, ResteAPayer> _resteAPayerCache = {};
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, success, pending, failed
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  // Variables pour la pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  final int _pageSize = 10;
  
  // Variables pour la sélection multiple et la bulle flottante
  final Set<String> _selectedLocationIds = {};
  bool _isSelectionMode = false;
  
  // Animation
  late AnimationController _animationController;



  @override
  void initState() {
    super.initState();
    
    // Set initial filter if provided
    if (widget.initialFilter != null) {
      _selectedFilter = _mapFilterName(widget.initialFilter!);
      debugPrint('🎯 PaymentHistory initial filter set to: ${widget.initialFilter} -> $_selectedFilter');
    }
    
    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    
    _loadPayments();
    
    // Démarrer l'écoute des changements de données avec le mixin
    startListeningToDataChanges(['payments', 'reservations']);
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Future<void> onDataChanged(String dataType, Map<String, dynamic> metadata) async {
    debugPrint('🔄 PaymentHistoryTab - Changement de données détecté: $dataType');
    debugPrint('📋 Métadonnées: $metadata');
    
    switch (dataType) {
      case 'payments':
        await _loadPayments();
        break;
      case 'reservations':
        // Les nouvelles réservations peuvent affecter l'historique des paiements
        if (metadata['action'] == 'created') {
          await _loadPayments();
        }
        break;
    }
  }
  
  String _mapFilterName(String filterName) {
    switch (filterName) {
      case 'En attente':
        return 'pending';
      case 'Réussi':
        return 'success';
      case 'Échoué':
        return 'failed';
      default:
        return 'all';
    }
  }


  Future<void> _loadPayments() async {
    try {
      final user = await UserService.getUserProfile();
      final userId = user?['user_id'] ?? '';
      
      if (userId.isEmpty) {
        setState(() {
          _error = 'user_not_found'.tr();
        });
        return;
      }
      
      // Charger l'historique des paiements directement depuis l'API (première page)
      // (contient déjà le municipalityId correct pour chaque zone)
      _currentPage = 1;
      _hasMoreData = true;
      final rawPayments = await _loadPaymentHistoryDirect(userId, page: 1);
      
      // Charger les locations avec reste à payer pour le filtre "En attente"
      await _loadPendingLocations(userId);
      
      setState(() {
        _payments = rawPayments.map((p) => PaymentHistory.fromJson(p)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // Charger l'historique des paiements avec pagination
  Future<List<Map<String, dynamic>>> _loadPaymentHistoryDirect(String userId, {int page = 1}) async {
    try {
      // Construire l'URL avec les paramètres de pagination
      final uri = Uri.parse('https://gateway.agvm.mg/serviceModernMarket/paiement/user/$userId/history')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': _pageSize.toString(),
      });
      
      final response = await http.get(uri);
      
      debugPrint('🔍 API Request: ${uri.toString()}');
      debugPrint('🔍 API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Extraire les données et les infos de pagination
        if (responseData['data'] != null && responseData['data'] is List) {
          final List<dynamic> paymentsData = responseData['data'];
          
          // Mettre à jour les infos de pagination avec conversion sécurisée
          if (responseData['pagination'] != null) {
            final pagination = responseData['pagination'];
            
            // ✅ CORRECTION: Conversion sécurisée des valeurs de pagination
            _currentPage = _safeParseInt(pagination['page']) ?? page;
            _totalPages = _safeParseInt(pagination['totalPages']) ?? 1;
            _hasMoreData = _currentPage < _totalPages;
            
            debugPrint('📄 Pagination: Page $_currentPage/$_totalPages, HasMore: $_hasMoreData');
            debugPrint('🔍 Raw pagination data: ${pagination.toString()}');
          } else {
            // Pas de pagination dans la réponse, considérer comme une seule page
            _currentPage = page;
            _totalPages = 1;
            _hasMoreData = false;
            debugPrint('⚠️ Aucune info de pagination dans la réponse');
          }
          
          debugPrint('✅ Historique chargé: ${paymentsData.length} paiements (page $page)');
          return paymentsData.cast<Map<String, dynamic>>();
        } else {
          debugPrint('⚠️ Aucune donnée de paiement trouvée dans la réponse');
          return [];
        }
      } else {
        debugPrint('❌ Erreur API: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement de l\'historique des paiements: $e');
      return [];
    }
  }
  
  // Méthode utilitaire pour parser les entiers de manière sécurisée
  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) {
      return value.toInt();
    }
    return null;
  }
  
  // Charger plus de données (pagination)
  Future<void> _loadMorePayments() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final user = await UserService.getUserProfile();
      final userId = user?['user_id'] ?? '';
      
      if (userId.isNotEmpty) {
        final nextPage = _currentPage + 1;
        final morePayments = await _loadPaymentHistoryDirect(userId, page: nextPage);
        
        if (morePayments.isNotEmpty) {
          setState(() {
            _payments.addAll(morePayments.map((p) => PaymentHistory.fromJson(p)).toList());
          });
          debugPrint('📄 Ajouté ${morePayments.length} paiements supplémentaires (page $nextPage)');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement de plus de paiements: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadPendingLocations(String userId) async {
    try {
      // Récupérer toutes les locations de l'utilisateur
      final locationsResponse = await _apiService.getUserLocations(userId);
      
      if (locationsResponse.success && locationsResponse.data != null) {
        List<UserLocation> locationsWithReste = [];
        
        // Pour chaque location, vérifier s'il y a un reste à payer
        final locationsData = locationsResponse.data;
        if (locationsData == null) {
          throw Exception('Données de locations non disponibles');
        }
        
        for (var locationData in locationsData) {
          final location = UserLocation.fromJson(locationData);
          
          // Vérifier le reste à payer pour cette location
          final resteResponse = await _apiService.getLocationResteAPayer(location.idLocation);
          
          if (resteResponse.success && resteResponse.data != null) {
            final resteData = resteResponse.data;
            if (resteData == null) continue;
            final reste = ResteAPayer.fromJson(resteData);
            debugPrint("reste: montantTotal=${reste.montantTotal}, totalPayer=${reste.totalPayer}, resteAPayer=${reste.resteAPayer}, moisRestants=${reste.moisRestants}");
            // Si il y a un reste à payer, ajouter à la liste et au cache
            if (reste.resteAPayer > 0) {
              locationsWithReste.add(location);
              _resteAPayerCache[location.idLocation] = reste;
            }
          }
        }
        
        setState(() {
          _pendingLocations = locationsWithReste;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des locations en attente: $e');
    }
  }

  Future<void> _showReceiptModal(PaiementLocation loc, String municipalityId, String status, String reference) async {
    try {
      debugPrint('📄 Ouverture du justificatif pour la référence: $reference');
      
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Récupérer l'URL du justificatif PDF
      final pdfUrl = await ReceiptService.getReceiptPdfUrl(reference, municipalityId);
      
      if (!mounted) return;
      
      // Fermer l'indicateur de chargement
      Navigator.of(context).pop();
      
      
      debugPrint('✅ Ouverture de l\'écran PDF avec URL: $pdfUrl');
      
      // Naviguer vers l'écran de visualisation du justificatif
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptViewerScreen(
          pdfUrl: pdfUrl,
          title: 'view_receipt'.tr(),
          subtitle: '${'local_qr_label'.tr()} ${loc.location.local.numero} - ${DateFormatter.formatDateString(loc.dateDebut.toString())}',
        ),
      ),
    );
      
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ouverture du justificatif: $e');
      
      if (!mounted) return;
      
      // Fermer l'indicateur de chargement s'il est ouvert
      Navigator.of(context).pop();
      
      // Afficher l'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'receipt_error'.tr(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      e.toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }



  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'failed':
      case 'cancelled':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return 'status_success'.tr();
      case 'pending':
        return 'status_pending'.tr();
      case 'failed':
        return 'status_failed'.tr();
      case 'cancelled':
        return 'status_cancelled'.tr();
      default:
        return 'status_unknown'.tr();
    }
  }

  List<dynamic> get _filteredPayments {
    if (_selectedFilter == 'pending') {
      // Pour le filtre "En attente", afficher les locations avec reste à payer
      List<UserLocation> filtered = _pendingLocations;
      
      if (_searchQuery.isNotEmpty) {
        filtered = filtered.where((location) {
          return location.local.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 location.local.numero.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 location.usage.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
      }
      
      return filtered;
    } else {
      // Pour les autres filtres, utiliser l'historique des paiements
      List<PaymentHistory> filtered = _payments;
      
      if (_selectedFilter != 'all') {
        filtered = filtered.where((payment) => payment.status.toLowerCase() == _selectedFilter).toList();
      }
      
      if (_searchQuery.isNotEmpty) {
        filtered = filtered.where((payment) {
          return payment.raison.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 payment.reference.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 payment.paiementLocations.any((loc) => 
                   loc.location.local.numero.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                   loc.location.local.zone.nom.toLowerCase().contains(_searchQuery.toLowerCase())
                 );
        }).toList();
      }
      
      return filtered..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    }
  }

  Widget _buildPendingLocationItem(UserLocation location) {
    final reste = _resteAPayerCache[location.idLocation];
    final formatter = NumberFormat('#,###', 'fr_FR');
    final isSelected = _selectedLocationIds.contains(location.idLocation);
    
    // Vérifier si la location est sélectionnable (a un reste à payer et est MENSUEL)
    final isSelectable = location.periodicite == 'MENSUEL' && 
                        reste != null && 
                        reste.resteAPayer > 0;
    
    // Calculer les mois restants
    int moisRestants = 0;
    if (reste != null && reste.resteAPayer > 0) {
      final montantTotal = reste.montantTotal;
      if (montantTotal > 0) {
        final montantMensuel = montantTotal / 12;
        moisRestants = (reste.resteAPayer / montantMensuel).ceil();
      }
    }
        // Get gradient colors from header
        final primaryColor = Theme.of(context).primaryColor;
        final leftGradientColor = primaryColor;
        final rightGradientColor = primaryColor.withBlue(200);
        
        return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: isSelectable ? () {
              setState(() {
                if (isSelected) {
                  _selectedLocationIds.remove(location.idLocation);
                } else {
                  _selectedLocationIds.add(location.idLocation);
                }
                _isSelectionMode = _selectedLocationIds.isNotEmpty;
              });
            } : null,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: !isSelectable ? [
                    Colors.grey.shade100,
                    Colors.grey.shade200,
                  ] : isSelected ? [
                    Colors.green.shade50,
                    Colors.green.shade100,
                  ] : [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
                border: Border.all(
                  color: isSelected ? Colors.green.shade400 : 
                         !isSelectable ? Colors.grey.shade300 : 
                         Colors.grey.shade200,
                  width: isSelected ? 3 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header avec statut et sélection
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: !isSelectable ? Colors.grey.shade400 : 
                                   isSelected ? leftGradientColor : rightGradientColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            !isSelectable ? Icons.block : 
                            isSelected ? Icons.check_circle : Icons.access_time,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    location.local.numero,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.green.shade800 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 16,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location.usage,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: !isSelectable ? Colors.grey.shade300 :
                                   isSelected ? leftGradientColor.withValues(alpha: 0.2) : rightGradientColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !isSelectable ? Colors.grey.shade400 :
                                     isSelected ? leftGradientColor.withValues(alpha: 0.5) : rightGradientColor.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            location.periodicite,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !isSelectable ? Colors.grey.shade700 :
                                     isSelected ? leftGradientColor : rightGradientColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Informations de paiement dans une carte moderne
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? leftGradientColor.withValues(alpha: 0.3) : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      child: Column(
                        children: [
                          // Montant restant à payer
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: reste?.resteAPayer == 0 ? 
                                       leftGradientColor.withValues(alpha: 0.1) : rightGradientColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: reste?.resteAPayer == 0 ? 
                                         leftGradientColor.withValues(alpha: 0.3) : rightGradientColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    reste?.resteAPayer == 0 ? Icons.check_circle : Icons.payment,
                                    color: reste?.resteAPayer == 0 ? leftGradientColor : rightGradientColor,
                                    size: 20,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  'remaining_to_pay'.tr(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const Spacer(),
                                  Text(
                                    reste?.resteAPayer == 0 ? 'fully_paid'.tr() : 
                                    '${formatter.format(reste?.resteAPayer ?? 0).replaceAll(',', ' ')} Ar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: reste?.resteAPayer == 0 ? leftGradientColor : rightGradientColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          if (moisRestants > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: rightGradientColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${'remaining_months'.tr()}:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: rightGradientColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: rightGradientColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '$moisRestants mois',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: rightGradientColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.date_range,
                                  color: Colors.grey.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${'period_label'.tr()}:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${DateFormatter.formatDate(location.dateDebutLoc)} - ${DateFormatter.formatDate(location.dateFinLoc)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildLocationItem(PaiementLocation loc, String municipalityId, String status, String reference) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReceiptModal(loc, municipalityId, status, reference),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec icône et informations du local
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.store_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'local_qr_label'.tr()} ${loc.location.local.numero}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1D1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  loc.location.local.zone.nom,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Informations de paiement
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Montant payé
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.payments_rounded,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'amount_paid'.tr(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${NumberFormat('#,###', 'fr_FR').format(loc.montantPaye).replaceAll(',', ' ')} Ar',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Période
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withBlue(200).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.date_range_rounded,
                              color: Theme.of(context).primaryColor.withBlue(200),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'period'.tr(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormatter.formatDateString(loc.dateDebut.toString())} - ${DateFormatter.formatDateString(loc.dateFin.toString())}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Theme.of(context).primaryColor.withBlue(200),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Bouton pour voir le justificatif
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        Theme.of(context).primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: Theme.of(context).primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'view_receipt'.tr(),
                        style: GoogleFonts.inter(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Theme.of(context).primaryColor,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentItem(PaymentHistory payment) {
    final totalAmount = payment.paiementLocations.fold<int>(0, (sum, loc) => sum + loc.montantPaye);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor(payment.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _statusIcon(payment.status),
                  color: _statusColor(payment.status),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.raison,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(payment.status).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(payment.status),
                            style: TextStyle(
                              color: _statusColor(payment.status),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${NumberFormat('#,###', 'fr_FR').format(totalAmount).replaceAll(',', ' ')} Ar',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  DateFormatter.formatDate(payment.dateCreation.toLocal(), format: 'dd/MM/yyyy à HH:mm'),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withBlue(200).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 14, color: Theme.of(context).primaryColor.withBlue(200)),
                      const SizedBox(width: 4),
                      Text(
                        '${payment.paiementLocations.length} ${payment.paiementLocations.length > 1 ? 'locals_count'.tr() : 'local_count'.tr()}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor.withBlue(200),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Theme.of(context).primaryColor.withBlue(200), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'payment_reference'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor.withBlue(200),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payment.reference,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...payment.paiementLocations.map((loc) => _buildLocationItem(loc, loc.location.local.zone.municipalityId.toString(), payment.status, payment.reference)),
          ],
        ),
      ),
    );
  }



  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withBlue(200),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget pour l'indicateur de chargement de plus de données
  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Chargement...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.payment_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'no_payment_found'.tr()
                  : 'no_payment_history'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'modify_search_criteria'.tr()
                  : 'payments_will_appear'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedFilter != 'all') ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedFilter = 'all';
                  });
                },
                icon: const Icon(Icons.clear_all),
                label: Text('clear_filters'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final filteredPayments = _filteredPayments;
    
    int totalAmount = 0;
    int successCount = 0;
    
    if (_selectedFilter == 'pending') {
      // Pour les locations en attente, calculer le montant total restant à payer
      final locations = filteredPayments.cast<UserLocation>();
      totalAmount = locations.fold<int>(0, (sum, location) {
        final reste = _resteAPayerCache[location.idLocation];
        return sum + (reste?.resteAPayer ?? 0);
      });
      successCount = locations.length;
    } else {
      // Pour l'historique des paiements
      final payments = filteredPayments.cast<PaymentHistory>();
      totalAmount = payments.fold<int>(0, (sum, payment) => 
        sum + payment.paiementLocations.fold<int>(0, (locSum, loc) => locSum + loc.montantPaye));
      successCount = payments.where((p) => p.status.toLowerCase() == 'success').length;
    }
    
    // Calculer la couleur centrale du gradient de l'en-tête
    final primaryColor = Theme.of(context).primaryColor;
    final centerColor = Color.lerp(
      primaryColor,
      primaryColor.withBlue(200),
      0.5,
    ) ?? primaryColor;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            centerColor,
            centerColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: centerColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'total_payments'.tr(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${NumberFormat('#,###', 'fr_FR').format(totalAmount).replaceAll(',', ' ')} Ar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$successCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'successful_payments'.tr(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToPayment() async {
    if (_selectedLocationIds.isEmpty) return;
    
    try {
      // Récupérer le profil utilisateur pour obtenir le NIF
      final userProfile = await UserService.getUserProfile();
      final userId = userProfile?['user_id']?.toString();
      
      if (userId == null || userId.isEmpty) {
        throw Exception('Utilisateur non connecté');
      }

      // Vérifier si l'utilisateur a un NIF
      final nifResponse = await _apiService.getUserNif(userId);
      
      final nifData = nifResponse.data;
      if (!nifResponse.success || nifData == null || nifData.isEmpty) {
        throw Exception('NIF non trouvé. Veuillez mettre à jour votre profil.');
      }

      final userNif = nifData;
      
      // Créer un service de panier temporaire avec les locations sélectionnées
      final tempCartService = CartService();
      
      // Vider le panier temporaire pour éviter la duplication
      tempCartService.clear();
      
      // Set pour éviter les doublons
      final Set<String> processedLocationIds = <String>{};
      
      // Grouper les locations par municipalityId
      final Map<String, List<UserLocation>> locationsByMunicipality = {};
      
      // Récupérer le municipalityId pour chaque location sélectionnée
      for (final locationId in _selectedLocationIds) {
        if (processedLocationIds.contains(locationId)) continue;
        processedLocationIds.add(locationId);
        
        try {
          final location = _pendingLocations.firstWhere((loc) => loc.idLocation == locationId);
          final reste = _resteAPayerCache[locationId];
          
          // Vérifier que la location est MENSUEL ET qu'il y a un reste à payer
          if (location.periodicite == 'MENSUEL' && reste != null && reste.resteAPayer > 0) {
            // Récupérer le municipalityId depuis la zone de cette location
            final zoneResponse = await _apiService.getZoneById(location.local.zoneId);
            if (zoneResponse.success && zoneResponse.data != null) {
              final zoneData = zoneResponse.data;
              final municipalityId = zoneData?['municipalityId']?.toString();
              if (municipalityId != null && municipalityId.isNotEmpty) {
                // Grouper par municipalityId
                if (!locationsByMunicipality.containsKey(municipalityId)) {
                  locationsByMunicipality[municipalityId] = [];
                }
                locationsByMunicipality[municipalityId]!.add(location);
                debugPrint('Location ${location.idLocation} appartient à la municipalité: $municipalityId');
              }
            }
          }
        } catch (e) {
          debugPrint('Erreur lors du traitement de la location $locationId: $e');
        }
      }
      
      if (locationsByMunicipality.isEmpty) {
        throw Exception('Aucune location valide sélectionnée pour le paiement.');
      }
      
      // Vérifier s'il y a plusieurs municipalités
      if (locationsByMunicipality.length > 1) {
        final municipalityNames = locationsByMunicipality.keys.join(', ');
        throw Exception('Les locations sélectionnées appartiennent à différentes municipalités ($municipalityNames). Veuillez sélectionner des locations d\'une seule municipalité à la fois.');
      }
      
      // Récupérer la seule municipalityId et ses locations
      final municipalityId = locationsByMunicipality.keys.first;
      final locationsForPayment = locationsByMunicipality[municipalityId]!;
      
      debugPrint('Traitement du paiement pour la municipalité $municipalityId avec ${locationsForPayment.length} locations');
      
      // Ajouter les locations de cette municipalité au panier temporaire
      for (final location in locationsForPayment) {
        try {
          final reste = _resteAPayerCache[location.idLocation];
          
          if (reste != null && reste.resteAPayer > 0) {
            debugPrint('Ajout de la location ${location.idLocation} au panier: ${reste.moisRestants} mois restants');
            final localDetail = location.local;
            final localModel = LocalModel(
              id: localDetail.idLocal.isNotEmpty ? localDetail.idLocal : 'temp_${DateTime.now().millisecondsSinceEpoch}',
              nom: localDetail.nom.isNotEmpty ? localDetail.nom : localDetail.numero,
              number: localDetail.numero.isNotEmpty ? localDetail.numero : 'N/A',
              status: localDetail.statut.isNotEmpty ? localDetail.statut : 'DISPONIBLE',
              zoneId: localDetail.zoneId.isNotEmpty ? localDetail.zoneId : '0',
              typeLocalId: localDetail.typelocalId,
              surface: 0.0,
              latitude: double.tryParse(localDetail.latitude ) ?? 0.0,
              longitude: double.tryParse(localDetail.longitude ) ?? 0.0,
              zone: {},
              typeLocal: {'tarif': (reste.montantTotal / 12).toDouble()},
            );
            
            // Utiliser la vraie date de fin de location
            final endDate = location.dateFinLoc;
            
            tempCartService.addItemDirect(CartItem(
              local: localModel,
              contractType: ContractType.annual,
              contractEndDate: endDate,
              isPaid: false,
              usage: location.usage,
              numberOfMonths: reste.moisRestants,
              existingLocationId: location.idLocation, // Ajouter l'ID de location existante
            ));
            
            debugPrint('Added location ${location.idLocation} to cart with ${reste.moisRestants} months remaining');
            debugPrint('Cart items: ${tempCartService.items.map((item) => 'Local: ${item.local.number}, Months: ${item.numberOfMonths}, Amount: ${item.totalAmount}').join(', ')}');
          } else {
            debugPrint('Location ${location.idLocation} has no remaining amount to pay (${reste?.resteAPayer ?? 0}), skipping');
          }
        } catch (e) {
          debugPrint('Error processing location ${location.idLocation}: $e');
        }
      }
      
      debugPrint('Final cart items count: ${tempCartService.items.length}');
      
      // Vérifier qu'au moins un item a été ajouté
      if (tempCartService.items.isEmpty) {
        throw Exception('Aucune location valide sélectionnée pour le paiement.');
      }
      
      // Naviguer vers l'écran de paiement
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: tempCartService,
              child: ChangeNotifierProvider(
                create: (_) => PaymentService(municipalityId: municipalityId),
                child: PaymentScreen(
                  nif: userNif,
                  municipalityId: int.tryParse(municipalityId) ?? 0,
                ),
              ),
            ),
          ),
        ).then((_) {
          // Nettoyer la sélection après le retour
          setState(() {
            _selectedLocationIds.clear();
            _isSelectionMode = false;
          });
          // Recharger les données
          _loadPayments();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'error_prefix'.tr()}: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 80.0,
      toolbarHeight: 80.0,
      collapsedHeight: 80.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Text(
        'payment_history_title'.tr(),
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      centerTitle: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withBlue(200),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickySearchBar() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'search_payment_placeholder'.tr(),
              hintStyle: GoogleFonts.inter(
                color: Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade600),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 20.0,
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildFilterChip('all', 'filter_all'.tr(), Icons.list),
            const SizedBox(width: 8),
            _buildFilterChip('success', 'filter_success'.tr(), Icons.check_circle),
            const SizedBox(width: 8),
            _buildFilterChip('pending', 'filter_pending'.tr(), Icons.schedule),
            const SizedBox(width: 8),
            _buildFilterChip('failed', 'filter_failed'.tr(), Icons.error),
          ],
        ),
      ),
    );
  }



  Widget _buildModernLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'loading_history'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'loading_error'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadPayments,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverPaymentsList() {
    final filteredPayments = _filteredPayments;
    
    if (filteredPayments.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(),
      );
    }
    
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Pagination: Charger plus de données quand on approche de la fin
            if (_selectedFilter != 'pending' && index >= filteredPayments.length - 2 && _hasMoreData && !_isLoadingMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadMorePayments();
              });
            }
            
            // Pagination: Afficher le loader à la fin
            if (index >= filteredPayments.length) {
              return _buildLoadingMoreIndicator();
            }
            
            if (_selectedFilter == 'pending') {
              final location = filteredPayments[index] as UserLocation;
              return _buildPendingLocationItem(location);
            } else {
              final payment = filteredPayments[index] as PaymentHistory;
              return _buildPaymentItem(payment);
            }
          },
          childCount: filteredPayments.length + (_hasMoreData && _selectedFilter != 'pending' ? 1 : 0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Écouter les changements de localisation pour se reconstruire automatiquement
    context.locale;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: _isLoading
            ? _buildModernLoadingState()
            : _error != null
                ? _buildModernErrorState(_error!)
                : RefreshIndicator(
                    onRefresh: _loadPayments,
                    color: Theme.of(context).colorScheme.primary,
                    child: CustomScrollView(
                      slivers: [
                        _buildSliverAppBar(),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _StickyHeaderDelegate(
                            minHeight: 160.0,
                            maxHeight: 160.0,
                            child: _buildStickyHeader(),
                          ),
                        ),
                        if (_payments.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildSummaryCard(),
                          ),
                        _buildSliverPaymentsList(),
                      ],
                    ),
                  ),
        floatingActionButton: _isSelectionMode && _selectedLocationIds.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _navigateToPayment,
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.payment),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('pay_button'.tr()),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedLocationIds.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildStickyHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStickySearchBar(),
          _buildFilterSection(),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(maxHeight, minHeight);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
