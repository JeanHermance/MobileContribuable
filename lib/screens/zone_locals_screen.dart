// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode
import 'package:flutter/services.dart'; // Pour HapticFeedback
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../components/calendar_modal.dart';
import '../components/usage_dialog.dart';
import '../components/error_snackbar.dart' as error_snackbar;
import '../services/notification_service.dart';
import '../models/local_model.dart';
import '../models/cart_item.dart';
import '../models/enums.dart';
import 'cart_screen.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/language_service.dart';

// Modes de visualisation de la carte avec imagerie satellite
enum MapViewMode { twoD, threeDAdvanced }

class ZoneLocalsScreen extends StatefulWidget {
  final Map<String, dynamic> zone;
  final int municipalityId;

  const ZoneLocalsScreen({
    super.key, 
    required this.zone,
    required this.municipalityId,
  });

  @override
  State<ZoneLocalsScreen> createState() => _ZoneLocalsScreenState();
}

class _ZoneLocalsScreenState extends State<ZoneLocalsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String? _errorMessage;
  List<LocalModel> _locals = [];
  List<LocalModel> _filteredLocals = [];
  List<LocalType> _localTypes = [];
  String? _selectedTypeId;
  String _searchQuery = '';
  // État de la vue et du mode de visualisation
  // Mode de visualisation de la carte
  MapViewMode _mapViewMode = MapViewMode.twoD; // Par défaut en 2D
  final MapController _mapController = MapController();
  double _currentZoom = 18.0; // Zoom initial fixé à 19
  bool _hasInitializedMap = false; // Flag pour éviter le reset du zoom
  double _currentScale = 1.0; // Échelle actuelle de la carte
  
  // Cache pour optimiser les performances
  List<Polygon>? _cachedPolygons;
  List<Marker>? _cachedMarkers;
  Timer? _searchDebouncer;
  StreamSubscription? _mapEventSubscription;
  
  // Cache pour les données de location
  final Map<String, Map<String, dynamic>> _locationCache = {};
  
  // Style de la carte en fonction du mode avec serveurs de secours
  List<String> get _mapTileUrls {
    switch (_mapViewMode) {
      case MapViewMode.twoD:
        return [
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
          'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
          'https://c.tile.openstreetmap.org/{z}/{x}/{y}.png',
        ];
      case MapViewMode.threeDAdvanced:
        return [
          'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        ];
    }
  }

  // Méthode pour construire les boutons de mode de carte
  Widget _buildMapModeButton(MapViewMode mode) {
    final isSelected = _mapViewMode == mode;
    final is3D = mode == MapViewMode.threeDAdvanced;
    final icon = is3D ? Icons.landscape : Icons.map;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _mapViewMode = mode;
          _currentZoom = 18.0 ;
          _mapController.move(_mapController.camera.center, _currentZoom);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withBlue(200) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.black87,
          size: 20,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Retirer le listener de changement de langue
    final languageService = Provider.of<LanguageService>(context, listen: false);
    languageService.removeListener(_onLanguageChanged);
    
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebouncer?.cancel();
    _mapEventSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _hasInitializedMap = false; // Reset le flag au chargement
    
    // Écouter les changements de langue pour recharger les données
    final languageService = Provider.of<LanguageService>(context, listen: false);
    languageService.addListener(_onLanguageChanged);
    
    _loadData();
    
    // Écouter les changements de la carte avec throttling
    _mapEventSubscription = _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || event is MapEventRotate || event is MapEventRotateEnd) {
        // Throttle les updates pour éviter trop de rebuilds
        _searchDebouncer?.cancel();
        _searchDebouncer = Timer(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _currentZoom = _mapController.camera.zoom;
              _currentScale = _calculateScaleFactor();
              // Invalider le cache des polygones pour recalculer l'opacité
              _cachedPolygons = null;
            });
          }
        });
      }
    });
  }
  
  // Calculer le facteur d'échelle en fonction du zoom et du mode de vue
  double _calculateScaleFactor() {
    // En vue 2D, l'échelle est plus linéaire avec le zoom
    if (_mapViewMode == MapViewMode.twoD) {
      return 1.0 / (1 + (_currentZoom / 20));
    } 
    // En vue 3D, on applique une correction pour la perspective
    else {
      // Plus le zoom est élevé, plus on réduit l'impact de la perspective
      final perspectiveFactor = 1.0 / (1 + (_currentZoom / 30));
      return perspectiveFactor * 0.7; // Réduction supplémentaire pour la vue 3D
    }
  }

  // Obtenir le nom localisé d'un type de local
  // L'API retourne déjà la bonne langue selon le paramètre lang
  String _getLocalizedTypeName(Map<String, dynamic>? typeLocal) {
    if (typeLocal == null) return 'unknown_type'.tr();
    return typeLocal['typeLoc']?.toString() ?? 'unknown_type'.tr();
  }

  // Callback appelé lors du changement de langue
  void _onLanguageChanged() {
    debugPrint('🌍 Langue changée, rechargement des données...');
    _loadData();
  }

  // Obtenir une couleur cohérente pour un type de local
  Color _getLocalColor(LocalModel local) {
    // Si le local est loué, retourner une couleur spécifique
    if (local.status.toUpperCase() == 'LOUE') {
      return Colors.grey.shade600;
    }

    // Récupérer le nom du type en minuscules pour la correspondance
    final typeName = _getLocalizedTypeName(local.typeLocal).toLowerCase().trim();
    
    // Définir les couleurs fixes selon les types connus en utilisant le thème de l'application
    switch (typeName) {
      case 'pavillon':
        return const Color(0xFF9C27B0); // Violet
      case 'hangar':
      case 'hangare':
        return const Color(0xFF3F51B5); // Indigo
      case 'tracage':
      case 'traçage':
      case 'traçage au sol':
      case 'tracé au sol':
        return const Color(0xFFE91E63); // Vert
      case 'kiosque':
      case 'kiosk':
        return const Color(0xFFFF9800); // Orange
      case 'boutique':
        return const Color(0xFFE91E63); // Rose
      case 'emplacement':
      case 'place':
        return const Color(0xFF00BCD4); // Cyan
      case 'stand':
        return const Color(0xFF795548); // Marron
      case 'espace':
        return const Color(0xFF607D8B); // Bleu gris
      default:
        // Pour les types inconnus, générer une couleur à partir du hash du nom
        if (typeName.isNotEmpty) {
          final hash = typeName.hashCode;
          final hue = (hash % 360).abs().toDouble();
          return HSLColor.fromAHSL(0.8, hue, 0.7, 0.6).toColor();
        }
        return Colors.grey.shade400; // Couleur par défaut
    }
  }

  // Méthodes de chargement des données
  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Charger les types de locaux avec la langue active
      final languageService = Provider.of<LanguageService>(context, listen: false);
      final typesResponse = await _apiService.getLocalTypes(
        municipalityId: widget.municipalityId.toString(),
        lang: languageService.currentLocale.languageCode,
      );
      
      
      if (!mounted) return;
      
      if (!typesResponse.success) {
        setState(() {
          _errorMessage = typesResponse.error ?? 'error_loading_types'.tr();
          _isLoading = false;
        });
        return;
      }

      try {
        final typesData = typesResponse.data?['data'] as List<dynamic>? ?? [];
        
        setState(() {
          _localTypes = typesData.map((type) {
            try {
              return LocalType.fromJson(type as Map<String, dynamic>);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error parsing local type: $e\nType data: $type');
              }
              return null;
            }
          }).whereType<LocalType>().toList();
          
        });
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Error processing local types: $e\n$stackTrace');
        }
        setState(() {
          _errorMessage = 'error_processing_types'.tr();
          _isLoading = false;
        });
        return;
      }

      // Charger les locaux de la zone
      await _loadLocals();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error in _loadData: $e\n$stackTrace');
      }
      if (mounted) {
        setState(() {
          _errorMessage = '${'connection_error'.tr()}: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLocals() async {
    if (!mounted) return;

    try {
      // Récupérer la langue active
      final languageService = Provider.of<LanguageService>(context, listen: false);
      final currentLang = languageService.currentLocale.languageCode;
      
      // Fetch available and rented locals concurrently with pagination
      final results = await Future.wait([
        _apiService.getLocalsByZone(
          municipalityId: widget.municipalityId.toString(),
          zoneId: widget.zone['id_zone'] as String,
          typeLocalId: _selectedTypeId,
          lang: currentLang,
          page: 1,
          limit: 6, // Limite réduite pour la pagination
        ),
        _apiService.getRentedLocalsByMunicipality(
          municipalityId: widget.municipalityId.toString(),
          lang: currentLang,
          page: 1,
          limit: 6,
        ),
      ]);

      if (!mounted) return;

      final availableResponse = results[0];
      final rentedResponse = results[1];

      if (availableResponse.success) {
        final availableLocalsData = availableResponse.data?['data'] as List<dynamic>? ?? [];
        List<LocalModel> availableLocals = availableLocalsData
            .map((local) => LocalModel.fromJson(local as Map<String, dynamic>))
            .toList();

        List<LocalModel> rentedLocalsInZone = [];
        if (rentedResponse.success) {
          final rentedLocalsData = rentedResponse.data?['data'] as List<dynamic>? ?? [];
          rentedLocalsInZone = rentedLocalsData
              .map((local) => LocalModel.fromJson(local as Map<String, dynamic>))
              .where((local) => local.zoneId == widget.zone['id_zone'] as String)
              .toList();
        }

        setState(() {
          _locals = [...availableLocals, ...rentedLocalsInZone];
          _filterLocals();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = availableResponse.error ?? 'error_loading_locals'.tr();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${'connection_error'.tr()}: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Méthodes utilitaires
  void _filterLocals() {
    if (_searchQuery.isEmpty && _selectedTypeId == null) {
      _filteredLocals = _locals;
      return;
    }

    _filteredLocals = _locals.where((local) {
      final matchesSearch = _searchQuery.isEmpty ||
          local.number.toLowerCase().contains(_searchQuery) ||
          _getLocalizedTypeName(local.typeLocal).toLowerCase().contains(_searchQuery) ||
          local.surface.toString().contains(_searchQuery) ||
          (local.typeLocal?['tarif']?.toString() ?? '').contains(_searchQuery);
      
      final matchesType = _selectedTypeId == null || 
          local.typeLocal?['id_type_local']?.toString() == _selectedTypeId;
      
      return matchesSearch && matchesType;
    }).toList();
    
    // Invalider les caches quand les données filtrées changent
    _cachedPolygons = null;
    _cachedMarkers = null;
  }
  
  void _debouncedFilterLocals() {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _filterLocals();
        });
      }
    });
  }


  // Méthodes d'interface utilisateur
  // Gestion du panier
  void _handleLocalTap(LocalModel local) {
    if (local.status.toUpperCase() == 'LOUE') {
      _showRentedLocalDetails(local);
    } else {
      _showLocalDetailsOnMap(local);
    }
  }

  Future<void> _showRentedLocalDetails(LocalModel local) async {
    // Vérifier le cache d'abord
    if (_locationCache.containsKey(local.id)) {
      final cachedData = _locationCache[local.id];
      if (cachedData != null) {
        _showRentedLocalDetailsModal(local, cachedData);
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await _apiService.getLastLocationForLocal(
        municipalityId: widget.municipalityId.toString(),
        localId: local.id,
      );

      if (mounted) Navigator.of(context).pop(); // Dismiss loading indicator

      if (response.success && response.data != null) {
        // Mettre en cache pour éviter les appels futurs
        final responseData = response.data;
        if (responseData == null) return;
        _locationCache[local.id] = responseData;
        _showRentedLocalDetailsModal(local, responseData);
      } else {
        if (mounted) {
          NotificationService.showError(
            context,
            response.error ?? 'error_retrieving_location_info'.tr(),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Dismiss loading indicator
      if (mounted) {
        NotificationService.showError(
          context,
          'Erreur: ${e.toString()}',
        );
      }
    }
  }

  void _handleCartTap() {
    // Navigation vers l'écran du panier
    final cartService = Provider.of<CartService>(context, listen: false);
    if (cartService.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('empty_cart_message'.tr())),
      );
      return;
    }
    // Naviguer vers l'écran du panier
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(municipalityId: widget.municipalityId),
      ),
    );
  }

  Future<void> _handleAddToCart(LocalModel local, {BuildContext? dialogContext}) async {
    if (!mounted) return;
    
    debugPrint('🛒 === DÉBUT AJOUT AU PANIER ===');
    debugPrint('🛒 Local ID: ${local.id}');
    debugPrint('🛒 Local number: ${local.number}');
    debugPrint('🛒 Local status: ${local.status}');
    debugPrint('🛒 Local zoneId: ${local.zoneId}');
    debugPrint('🛒 Local typeLocal: ${local.typeLocal}');
    
    final typeContrat = local.typeLocal?['type_contrat']?.toString().toUpperCase() ?? '';
    debugPrint('🛒 Type contrat: $typeContrat');

    try {
      if (typeContrat == 'JOURNALIER') {
        debugPrint('🛒 Flux contrat journalier');
        _showDailyContractFlow(local, dialogContext);
      } else if (typeContrat == 'ANNUEL') {
        debugPrint('🛒 Flux contrat annuel');
        final now = DateTime.now();
        final contractEndDate = DateTime(now.year + 1, now.month, now.day);
        debugPrint('🛒 Date fin contrat: $contractEndDate');
        _showUsageDialog(local, contractEndDate: contractEndDate, numberOfMonths: 12);
      } else {
        debugPrint('❌ Type de contrat non pris en charge: $typeContrat');
        if (mounted) {
          error_snackbar.ErrorSnackBar.show(
            context,
            'unsupported_contract_type'.tr(),
            icon: Icons.warning,
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR dans _handleAddToCart: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        error_snackbar.ErrorSnackBar.show(
          context,
          '${'error_adding_to_cart'.tr()}: ${e.toString()}',
          icon: Icons.error,
        );
      }
    }
  }

  // Flux optimisé pour les contrats journaliers
  Future<void> _showDailyContractFlow(LocalModel local, BuildContext? dialogContext) async {
    debugPrint('📅 === FLUX CONTRAT JOURNALIER ===');
    debugPrint('📅 Local: ${local.id} - ${local.number}');
    
    // Stocker le context avant les opérations async
    final currentContext = context;
    
    try {
      final selectedDates = await showDialog<List<DateTime>>(
        context: currentContext,
        builder: (calendarDialogContext) => CalendarModal(
          local: local,
          onConfirm: (dates) {
            debugPrint('📅 Dates sélectionnées: $dates');
            return Navigator.of(calendarDialogContext).pop(dates);
          },
        ),
        barrierDismissible: false,
      );

      debugPrint('📅 Dates retournées du modal: $selectedDates');
      if (!mounted || selectedDates == null || selectedDates.isEmpty) {
        debugPrint('📅 Annulé ou aucune date sélectionnée');
        return;
      }

      final usage = await showDialog<String>(
        context: currentContext,
        barrierDismissible: false,
        builder: (usageDialogContext) => UsageDialog(
          local: local,
          isAnnual: false,
          numberOfMonths: null,
          onConfirm: (selectedUsage) {
            debugPrint('📅 Usage sélectionné: $selectedUsage');
            return Navigator.of(usageDialogContext).pop(selectedUsage);
          },
        ),
      );

      debugPrint('📅 Usage retourné du modal: $usage');
      if (!mounted || usage == null) {
        debugPrint('📅 Annulé ou aucun usage sélectionné');
        return;
      }

      // Traitement en arrière-plan
      debugPrint('📅 Traitement de l\'ajout au panier...');
      _processCartAddition(local, selectedDates, usage, dialogContext, currentContext);
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR dans _showDailyContractFlow: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Traitement asynchrone de l'ajout au panier
  Future<void> _processCartAddition(
    LocalModel local, 
    List<DateTime> selectedDates, 
    String usage, 
    BuildContext? dialogContext,
    [BuildContext? contextForCart]
  ) async {
    debugPrint('🛒 === TRAITEMENT AJOUT AU PANIER ===');
    debugPrint('🛒 Local: ${local.id}');
    debugPrint('🛒 Dates sélectionnées: $selectedDates');
    debugPrint('🛒 Usage: $usage');
    
    try {
      debugPrint('🛒 Récupération du CartService...');
      final cartService = Provider.of<CartService>(contextForCart ?? context, listen: false);
      debugPrint('🛒 CartService récupéré: ${cartService.runtimeType}');
      
      debugPrint('🛒 Création du CartItem...');
      debugPrint('🛒 Local data avant création CartItem:');
      debugPrint('🛒   - id: ${local.id}');
      debugPrint('🛒   - nom: ${local.nom}');
      debugPrint('🛒   - number: ${local.number}');
      debugPrint('🛒   - status: ${local.status}');
      debugPrint('🛒   - zoneId: ${local.zoneId}');
      debugPrint('🛒   - typeLocal: ${local.typeLocal}');
      debugPrint('🛒   - surface: ${local.surface}');
      debugPrint('🛒   - latitude: ${local.latitude}');
      debugPrint('🛒   - longitude: ${local.longitude}');
      debugPrint('🛒   - zone: ${local.zone}');
      
      final cartItem = CartItem(
        local: local,
        selectedDates: selectedDates,
        contractType: ContractType.daily,
        usage: usage,
      );
      debugPrint('🛒 CartItem créé avec succès');
      debugPrint('🛒 CartItem totalAmount: ${cartItem.totalAmount}');
      debugPrint('🛒 CartItem numberOfPeriods: ${cartItem.numberOfPeriods}');
      
      debugPrint('🛒 Ajout au panier...');
      final success = await cartService.addItem(cartItem);
      debugPrint('🛒 Résultat ajout: $success');
      
      if (mounted) {
        if (success) {
          debugPrint('✅ Local ajouté au panier avec succès');
          NotificationService.showSuccess(
            context,
            'local_added_to_cart'.tr(),
          );
        } else {
          debugPrint('❌ Échec ajout au panier, récupération du message d\'erreur...');
          final validation = await cartService.getLastValidationResult(cartItem);
          debugPrint('❌ Message de validation: ${validation.message}');
          if (mounted) {
            NotificationService.showError(
              context,
              validation.message ?? 'cannot_add_to_cart'.tr(),
            );
          }
        }
        
        // Fermer la modale de détails si elle existe
        if (dialogContext != null && mounted) {
          try {
            // Vérifier si le context est toujours valide avant d'accéder au Navigator
            // Cela évite l'erreur "Looking up a deactivated widget's ancestor is unsafe"
            final navigator = Navigator.maybeOf(dialogContext);
            if (navigator != null && navigator.canPop()) {
              debugPrint('🛒 Fermeture de la modale de détails');
              navigator.pop();
            } else {
              debugPrint('🛒 Impossible de fermer la modale - pas de route à pop');
            }
          } catch (e) {
            debugPrint('🛒 Erreur lors de la fermeture de la modale: $e');
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR CRITIQUE dans _processCartAddition: $e');
      debugPrint('❌ Stack trace complet: $stackTrace');
      if (mounted) {
        NotificationService.showError(
          context,
          '${'error_adding_to_cart'.tr()}: ${e.toString()}',
        );
      }
    }
  }

  void _showUsageDialog(
    LocalModel local, {
    List<DateTime>? selectedDates,
    DateTime? contractEndDate,
    int? numberOfMonths,
  }) {
    debugPrint('💼 === DIALOG USAGE ===');
    debugPrint('💼 Local: ${local.id}');
    debugPrint('💼 selectedDates: $selectedDates');
    debugPrint('💼 contractEndDate: $contractEndDate');
    debugPrint('💼 numberOfMonths: $numberOfMonths');
    
    final typeContrat = local.typeLocal?['type_contrat']?.toString().toUpperCase() ?? '';
    final isAnnual = typeContrat == 'ANNUEL';
    debugPrint('💼 Type contrat: $typeContrat, isAnnual: $isAnnual');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => UsageDialog(
        local: local,
        isAnnual: isAnnual,
        numberOfMonths: numberOfMonths,
        onConfirm: (usage) async {
          debugPrint('💼 Usage confirmé: $usage');
          
          try {
            final currentContext = context;
            debugPrint('💼 Récupération du CartService...');
            final cartService = Provider.of<CartService>(currentContext, listen: false);
            
            debugPrint('💼 Création du CartItem...');
            debugPrint('💼 Local data avant création:');
            debugPrint('💼   - id: ${local.id}');
            debugPrint('💼   - typeLocal: ${local.typeLocal}');
            
            final cartItem = CartItem(
              local: local,
              selectedDates: selectedDates,
              contractEndDate: contractEndDate,
              contractType: selectedDates != null ? ContractType.daily : ContractType.annual,
              usage: usage,
              numberOfMonths: numberOfMonths,
            );
            debugPrint('💼 CartItem créé avec succès');
            debugPrint('💼 CartItem totalAmount: ${cartItem.totalAmount}');
            
            // Use new validation system
            debugPrint('💼 Ajout au panier...');
            final success = await cartService.addItem(cartItem);
            debugPrint('💼 Résultat ajout: $success');
            
            // Fermer le dialog d'abord en utilisant le contexte du dialog
            try {
              final navigator = Navigator.maybeOf(dialogContext);
              if (navigator != null && navigator.canPop()) {
                debugPrint('💼 Fermeture du dialog usage');
                navigator.pop();
              }
            } catch (e) {
              debugPrint('💼 Erreur lors de la fermeture du dialog: $e');
            }
            
            // Fermer la modal de détails du local seulement si on est en vue carte (modal ouverte)
            if (mounted && ModalRoute.of(currentContext)?.isCurrent == false) {
              debugPrint('💼 Fermeture de la modal de détails');
              Navigator.of(currentContext).pop();
            }
            
            // Afficher le message approprié
            if (mounted) {
              if (success) {
                debugPrint('✅ Succès ajout au panier');
                NotificationService.showSuccess(
                  currentContext,
                  'local_added_to_cart'.tr(),
                );
              } else {
                debugPrint('❌ Échec ajout au panier, récupération du message...');
                // Get validation result to show specific error message
                final validation = await cartService.getLastValidationResult(cartItem);
                debugPrint('❌ Message de validation: ${validation.message}');
                if (mounted) {
                  NotificationService.showError(
                    currentContext,
                    validation.message ?? 'cannot_add_to_cart'.tr(),
                  );
                }
              }
            }
          } catch (e, stackTrace) {
            debugPrint('❌ ERREUR CRITIQUE dans _showUsageDialog.onConfirm: $e');
            debugPrint('❌ Stack trace: $stackTrace');
            
            // Fermer le dialog même en cas d'erreur
            try {
              final navigator = Navigator.maybeOf(dialogContext);
              if (navigator != null && navigator.canPop()) {
                navigator.pop();
              }
            } catch (e) {
              debugPrint('💼 Erreur lors de la fermeture du dialog (erreur): $e');
            }
            
            if (mounted) {
              NotificationService.showError(
                context,
                '${'error_adding_to_cart'.tr()}: ${e.toString()}',
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              minHeight: 160.0,
              maxHeight: 160.0,
              child: _buildStickySearchBar(),
            ),
          ),
          _buildSliverLocalsList(),
        ],
      ),
    );
  }


  Widget _buildStickySearchBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barre de recherche principale
          Container(
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
                hintText: 'search_local_placeholder'.tr(),
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
                          setState(() {
                            _searchQuery = '';
                            _filterLocals();
                          });
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
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
                _debouncedFilterLocals();
              },
            ),
          ),
            if (_localTypes.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Barre de filtres
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildFilterChipsList(),
                  ),
                  if (_localTypes.length > 2) InkWell(
                    onTap: () {
                      final currentOffset = _scrollController.offset;
                      final maxOffset = _scrollController.position.maxScrollExtent;
                      final targetOffset = currentOffset + 150;
                      _scrollController.animateTo(
                        targetOffset > maxOffset ? maxOffset : targetOffset,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.chevron_right, color: Colors.grey, size: 24),
                    ),
                  ),
                  _buildResultsCounter(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipsList() {
    if (_localTypes.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Chip "Tous"
          _buildFilterChip(
            label: 'filter_all_types'.tr(),
            isSelected: _selectedTypeId == null,
            onTap: () {
              setState(() {
                _selectedTypeId = null;
                _filterLocals();
              });
            },
          ),
          const SizedBox(width: 8),
          // Chips pour chaque type
          ..._localTypes.where((type) => type.name.isNotEmpty).map((type) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildFilterChip(
                  label: type.name,
                  isSelected: _selectedTypeId == type.id.toString(),
                  onTap: () {
                    setState(() {
                      _selectedTypeId = type.id.toString();
                      _filterLocals();
                    });
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsCounter() {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withBlue(200).withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_filteredLocals.length} ${_filteredLocals.length > 1 ? 'locals_count_plural'.tr() : 'locals_count_singular'.tr()}',
            style: GoogleFonts.inter(
              color: Theme.of(context).primaryColor.withBlue(200),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 80.0,
      toolbarHeight: 80.0,
      collapsedHeight: 80.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.zone['nom']}',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            '${'fokotany_label'.tr()}: ${widget.zone['fokotany_name']}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
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
      actions: [
        Consumer<CartService>(
          builder: (context, cart, child) {
            return Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: _handleCartTap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                      ),
                      if (cart.itemCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              cart.itemCount > 99 ? '99+' : '${cart.itemCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSliverLocalsList() {
    // Si chargement ou erreur, on affiche le contenu correspondant
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'unknown_error'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: Text('retry_button'.tr()),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sinon on affiche la carte
    return SliverFillRemaining(
      child: _buildMapView(),
    );
  }



  Widget _buildMapView() {
    final bool noLocals = _filteredLocals.isEmpty;
    
    return Stack(
      children: [
        // Carte principale
        _buildMapContent(),
        
        // Message d'information si pas de locaux
        if (noLocals) Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Material(
            elevation: 0,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                           'no_locals_available'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                     _searchQuery.isNotEmpty || _selectedTypeId != null
                         ? 'no_locals_match_search'.tr()
                         : 'no_locals_in_zone'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedTypeId != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedTypeId = null;
                            _searchController.clear();
                            _filterLocals();
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text('reset_filters'.tr()),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // Méthode pour construire les polygones avec cache
  List<Polygon> _buildCachedPolygons() {
    if (_cachedPolygons != null) {
      return _cachedPolygons ?? [];
    }

    _cachedPolygons = _filteredLocals
        .where((local) => local.latitude != null && 
                        local.longitude != null && 
                        local.typeLocal != null &&
                        local.typeLocal?['longueur'] != null &&
                        local.typeLocal?['largeur'] != null &&
                        (local.typeLocal?['longueur'] is num && local.typeLocal?['longueur'] > 0) &&
                        (local.typeLocal?['largeur'] is num && local.typeLocal?['largeur'] > 0))
        .map((local) {
          // Récupérer les dimensions du local de manière sécurisée
          final typeLocal = local.typeLocal;
          if (typeLocal == null) return null;
          
          final longueur = (typeLocal['longueur'] is num 
              ? typeLocal['longueur'].toDouble() 
              : 2.0);
          final largeur = (typeLocal['largeur'] is num 
              ? typeLocal['largeur'].toDouble() 
              : 1.0);
          
          // Convertir les dimensions en degrés (approximatif)
          final lat = local.latitude ?? 0.0;
          final lng = local.longitude ?? 0.0;
          final metersToDegreesLat = 1 / 111320.0;
          final metersToDegreesLng = 1 / (111320 * math.cos(lat * math.pi / 180));
          
          // Calculer les demi-dimensions en degrés
          final halfLength = (longueur * metersToDegreesLng) / 2;
          final halfWidth = (largeur * metersToDegreesLat) / 2;
          
          // Créer un rectangle centré sur la position du local
          return Polygon(
            points: [
              LatLng(lat + halfWidth, lng - halfLength),
              LatLng(lat + halfWidth, lng + halfLength),
              LatLng(lat - halfWidth, lng + halfLength),
              LatLng(lat - halfWidth, lng - halfLength),
            ],
            color: _getLocalColor(local).withValues(alpha: 0.2 + (0.3 * (_currentZoom / 20).clamp(0.0, 1.0))),
            borderColor: _getLocalColor(local),
            borderStrokeWidth: 1.5,
            isFilled: true,
          );
        }).whereType<Polygon>().toList();
    
    return _cachedPolygons ?? [];
  }

  // Méthode pour construire les marqueurs avec cache
  List<Marker> _buildCachedMarkers() {
    if (_cachedMarkers != null) {
      return _cachedMarkers ?? [];
    }

    _cachedMarkers = _filteredLocals
        .where((local) => local.latitude != null && local.longitude != null)
        .map((local) {
          const iconSize = 30.0;
          final verticalOffset = iconSize * 0.4;
          
          return Marker(
            width: iconSize,
            height: iconSize,
            point: LatLng(local.latitude ?? 0.0, local.longitude ?? 0.0),
            child: GestureDetector(
              onTap: () => _handleLocalTap(local),
              child: Transform.translate(
                offset: Offset(0, -verticalOffset / 2),
                child: Icon(
                  Icons.location_on,
                  color: _getLocalColor(local),
                  size: 30,
                ),
              ),
            ),
          );
        }).toList();
    
    return _cachedMarkers ?? [];
  }

  Widget _buildMapContent() {
    // Variables pour la construction de la carte
    LatLng centerPoint = const LatLng(-18.8792, 47.5079);
    final List<LatLng> zonePolygon = [];
    bool hasZoneData = false;
    
    try {
      // Récupération des coordonnées de la zone
      dynamic geoDelimitation = widget.zone['geo_delimitation'];
      
      if (geoDelimitation is String) {
        try {
          geoDelimitation = jsonDecode(geoDelimitation);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Erreur lors du décodage de geo_delimitation: $e');
          }
          geoDelimitation = null;
        }
      }
      
      if (geoDelimitation != null && geoDelimitation is Map) {
        final type = geoDelimitation['type'];
        final coordinates = geoDelimitation['coordinates'];
        
        if (type == 'Polygon' && coordinates != null && coordinates is List && coordinates.isNotEmpty) {
          final polygonCoords = coordinates[0];
          if (polygonCoords is List) {
            for (var coord in polygonCoords) {
              if (coord is List && coord.length >= 2) {
                final lng = coord[0] is num ? coord[0].toDouble() : 0.0;
                final lat = coord[1] is num ? coord[1].toDouble() : 0.0;
                zonePolygon.add(LatLng(lat, lng));
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur lors du traitement des coordonnées de la zone: $e');
      }
    }
    
    if (zonePolygon.isNotEmpty) {
      // Calculer le centre géométrique de la zone
      double sumLat = 0;
      double sumLng = 0;
      for (var point in zonePolygon) {
        sumLat += point.latitude;
        sumLng += point.longitude;
      }
      centerPoint = LatLng(sumLat / zonePolygon.length, sumLng / zonePolygon.length);
      hasZoneData = true;
      
      // Centrer la carte sur la zone uniquement lors de l'initialisation
      if (!_hasInitializedMap && hasZoneData) {
        double minLat = zonePolygon.first.latitude;
        double maxLat = zonePolygon.first.latitude;
        double minLng = zonePolygon.first.longitude;
        double maxLng = zonePolygon.first.longitude;
        
        for (var point in zonePolygon) {
          if (point.latitude < minLat) minLat = point.latitude;
          if (point.latitude > maxLat) maxLat = point.latitude;
          if (point.longitude < minLng) minLng = point.longitude;
          if (point.longitude > maxLng) maxLng = point.longitude;
        }
        
        // Calculer la distance pour déterminer le zoom optimal
        final latDiff = maxLat - minLat;
        final lngDiff = maxLng - minLng;
        final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
        
        // Ajuster le zoom en fonction de la taille de la zone
        if (maxDiff > 0.01) {
          _currentZoom = 14.0; // Zone très large
        } else if (maxDiff > 0.005) {
          _currentZoom = 16.0; // Zone moyenne
        } else if (maxDiff > 0.002) {
          _currentZoom = 17.0; // Zone petite
        } else {
          _currentZoom = _mapViewMode == MapViewMode.threeDAdvanced ? 19.0 : 18.0; // Zone très petite
        }
        
        debugPrint('🗺️ Zone bounds: lat($minLat, $maxLat), lng($minLng, $maxLng)');
        debugPrint('🔍 Zone size: ${maxDiff.toStringAsFixed(6)}, zoom: $_currentZoom');
        
        // Centrer automatiquement la carte sur la zone après un délai
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _mapController.camera.center != centerPoint) {
                _mapController.move(centerPoint, _currentZoom);
                _hasInitializedMap = true; // Marquer comme initialisé
                debugPrint('🎯 Carte centrée sur la zone: ${centerPoint.latitude}, ${centerPoint.longitude}');
              }
            });
          }
        });
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centerPoint,
            initialZoom: _currentZoom,
            minZoom: 14,
            maxZoom: 20,
            interactionOptions: const InteractionOptions(
              flags: ~InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            // Couche de tuiles avec gestion d'erreur
            TileLayer(
              urlTemplate: _mapTileUrls.first,
              userAgentPackageName: 'com.example.reservation',
              maxZoom: 20,
              errorTileCallback: (tile, error, stackTrace) {
                // Gestion silencieuse des erreurs de tuiles
                if (kDebugMode) {
                  debugPrint('Tile loading error: $error');
                }
              },
            ),
            // Couche de polygones (délimitation de zone)
            if (hasZoneData)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: zonePolygon,
                    color: Colors.transparent,
                    borderColor: Theme.of(context).primaryColor,
                    borderStrokeWidth: 2,
                    isFilled: false,
                  ),
                ],
              ),
            // Surfaces des locaux avec cache
            if (_filteredLocals.isNotEmpty)
              PolygonLayer(polygons: _buildCachedPolygons()),
              
            // Marqueurs des locaux avec cache
            if (_filteredLocals.isNotEmpty)
              MarkerLayer(markers: _buildCachedMarkers()),
          ],
        ),
        // Contrôles de la carte
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Sélecteur de vue 2D/3D+
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapModeButton(MapViewMode.twoD),
                    const SizedBox(width: 8),
                    _buildMapModeButton(MapViewMode.threeDAdvanced),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Contrôles de zoom
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton zoom +
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _currentZoom = (_currentZoom + 1).clamp(2.0, 22.0);
                          _mapController.move(
                            _mapController.camera.center,
                            _currentZoom,
                          );
                        },
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.add,
                            color: Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // Séparateur
                    Container(
                      width: 24,
                      height: 1,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    // Bouton zoom -
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _currentZoom = (_currentZoom - 1).clamp(2.0, 22.0);
                          _mapController.move(
                            _mapController.camera.center,
                            _currentZoom,
                          );
                        },
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.remove,
                            color: Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLocalDetailsOnMap(LocalModel local) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildLocalCard(local, dialogContext: context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRentedLocalDetailsModal(LocalModel local, Map<String, dynamic> locationDetails) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false, // Empêche le drag pour éviter les espaces vides
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6, // Hauteur max 60%
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () {}, // Empêche la fermeture quand on clique sur la modal
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header avec statut
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                             '${'local_number_label'.tr()} ${local.number}',
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).primaryColor,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                               local.typeLocal?['typeLoc']?['fr']?.toString() ?? 'unknown_type'.tr(),
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 11,
                                                ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.red[400] ?? Colors.red, Colors.red[600] ?? Colors.red],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withAlpha(51),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.lock,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                             'rented_status'.tr(),
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                letterSpacing: 0.5,
                                              ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                
                                // Informations de location
                                _buildModernInfoSection(
                                   'rental_information'.tr(),
                                  [
                                    _buildModernInfoTile(
                                      Icons.person_outline,
                                       'tenant_label'.tr(),
                                       locationDetails['userPseudo']?.toString() ?? 'not_specified'.tr(),
                                      Theme.of(context).primaryColor.withBlue(200),
                                    ),
                                    _buildModernInfoTile(
                                      Icons.work_outline,
                                       'declared_usage'.tr(),
                                       locationDetails['usage']?.toString() ?? 'not_specified'.tr(),
                                      Theme.of(context).primaryColor,
                                    ),
                                  ],
                                ),
                              ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildLocalCard(LocalModel local, {BuildContext? dialogContext}) {
    final typeLocal = local.typeLocal;
    final tarif = typeLocal?['tarif'];
    final typeContrat = typeLocal?['type_contrat']?.toString().toUpperCase();
    String tarifText = 'rate_unavailable'.tr();

    if (tarif != null) {
      if (typeContrat == 'JOURNALIER') {
        tarifText = '$tarif ${'ar_per_day'.tr()}';
      } else if (typeContrat == 'ANNUEL') {
        tarifText = '$tarif ${'ar_per_month'.tr()}';
      } else {
        tarifText = '$tarif Ar';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: 2,
        shadowColor: Colors.grey.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _handleLocalTap(local);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'place_number_label'.tr()} ${local.number}',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              typeLocal?['typeLoc']?['fr']?.toString() ?? 'unknown_type'.tr(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: local.status.toUpperCase() == 'LOUE'
                          ? Colors.grey.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: local.status.toUpperCase() == 'LOUE' ? Colors.grey : Colors.green,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            local.status.toUpperCase() == 'LOUE' ? Icons.lock : Icons.check_circle,
                            color: local.status.toUpperCase() == 'LOUE' ? Colors.grey : Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            local.status.toUpperCase() == 'LOUE' ? 'rented_label'.tr() : 'available_label'.tr(),
                            style: GoogleFonts.inter(
                              color: local.status.toUpperCase() == 'LOUE' ? Colors.grey : Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoChip(Icons.square_foot, '${(local.surface * _currentScale).round()} m²', local: local),
                      Container(
                        width: 1,
                        height: 16,
                        color: Colors.grey[300],
                      ),
                      _buildInfoChip(FontAwesomeIcons.moneyBill, tarifText),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withBlue(200),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: local.status.toUpperCase() == 'LOUE'
                    ? null // Disable button if rented
                    : () {
                      HapticFeedback.mediumImpact();
                      // Utiliser le dialogContext s'il est fourni, sinon utiliser le contexte actuel si on est dans une modale
                      final contextToUse = dialogContext ?? (ModalRoute.of(context)?.isCurrent == false ? context : null);
                      _handleAddToCart(local, dialogContext: contextToUse);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      'reserve_local_button'.tr(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
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

  // Méthodes utilitaires pour la modal moderne
  Widget _buildModernInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200] ?? Colors.grey),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildModernInfoTile(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  

  Widget _buildInfoChip(IconData icon, String label, {LocalModel? local}) {
    // Si c'est la puce de surface et qu'on a un local, on calcule la surface
    String displayLabel = label;
    if (local != null && icon == Icons.square_foot) {
      final typeLocal = local.typeLocal;
      if (typeLocal != null && 
          typeLocal['longueur'] != null && 
          typeLocal['largeur'] != null) {
        final longueur = typeLocal['longueur'] is num 
            ? typeLocal['longueur'].toDouble() 
            : 0.0;
        final largeur = typeLocal['largeur'] is num 
            ? typeLocal['largeur'].toDouble() 
            : 0.0;
        final surface = (longueur * largeur).round();
        displayLabel = '$surface m²';
      } else {
        displayLabel = 'N/A';
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withBlue(200).withAlpha(26),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).primaryColor.withBlue(200)),
          const SizedBox(width: 6),
          Text(
            displayLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
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
