import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tsena_servisy/models/cart_item.dart';
import 'package:tsena_servisy/services/api_service.dart';
import 'package:tsena_servisy/services/user_service.dart';

class CartService extends ChangeNotifier {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  factory CartService() {
    return _instance;
  }
  CartService._internal();

  final List<CartItem> _items = [];
  
  // Getter pour accéder à la liste privée depuis l'extérieur (pour les paniers temporaires)
  List<CartItem> get itemsList => _items;
  final ApiService _apiService = ApiService();

  // Maximum locations allowed
  static const int maxLocationsAllowed = 2;

  List<CartItem> get items => _items;

  int get itemCount => _items.length;

  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  // Check if user can add more items to cart
  Future<CartValidationResult> canAddItem(CartItem item) async {
    debugPrint('🔍 CartService.canAddItem() - DÉBUT');
    debugPrint('🔍 Item à valider: ${item.local.id} - ${item.local.number}');
    
    try {
      // Get current user
      debugPrint('🔍 Récupération du profil utilisateur...');
      final user = await UserService.getUserProfile();
      if (user == null) {
        debugPrint('❌ Utilisateur non connecté');
        return CartValidationResult(
          canAdd: false,
          message: tr('user_not_connected'),
        );
      }
      debugPrint('🔍 Utilisateur: ${user['user_id']}');

      // Check current locations count from API
      debugPrint('🔍 Vérification du nombre de locations actuelles...');
      final locationsResponse = await _apiService.getCurrentLocationsCount(user['user_id']);
      if (!locationsResponse.success) {
        debugPrint('❌ Erreur API getCurrentLocationsCount: ${locationsResponse.error}');
        return CartValidationResult(
          canAdd: false,
          message: tr('error_checking_locations', namedArgs: {'error': locationsResponse.error ?? 'Unknown error'}),
        );
      }

      final currentLocationsCount = locationsResponse.data ?? 0;
      final cartItemsCount = _items.length;
      debugPrint('🔍 Locations actuelles: $currentLocationsCount, Items panier: $cartItemsCount');
      
      // Check if adding this item would exceed the limit
      final existingIndex = _items.indexWhere((cartItem) => cartItem.local.id == item.local.id);
      final newItemsCount = existingIndex != -1 ? 0 : 1; // If replacing existing, no new item
      debugPrint('🔍 Index existant: $existingIndex, Nouveaux items: $newItemsCount');
      
      final totalAfterAdd = currentLocationsCount + cartItemsCount + newItemsCount;
      debugPrint('🔍 Total après ajout: $totalAfterAdd, Limite: $maxLocationsAllowed');
      
      if (totalAfterAdd > maxLocationsAllowed) {
        debugPrint('❌ Limite dépassée');
        return CartValidationResult(
          canAdd: false,
          message: tr('limit_reached', namedArgs: {
            'current': currentLocationsCount.toString(),
            'cart': cartItemsCount.toString(),
            'max': maxLocationsAllowed.toString(),
          }),
        );
      }

      // ✅ NOUVELLE VALIDATION: Vérifier que tous les locaux appartiennent à la même commune
      if (_items.isNotEmpty && existingIndex == -1) {
        debugPrint('🔍 Validation de la commune...');
        final municipalityValidation = await _validateSameMunicipality(item);
        if (!municipalityValidation.canAdd) {
          debugPrint('❌ Validation commune échouée: ${municipalityValidation.message}');
          return municipalityValidation;
        }
        debugPrint('✅ Validation commune réussie');
      }

      debugPrint('✅ CartService.canAddItem() - VALIDATION RÉUSSIE');
      return CartValidationResult(canAdd: true);
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR CRITIQUE dans CartService.canAddItem(): $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return CartValidationResult(
        canAdd: false,
        message: tr('error_validating_municipality', namedArgs: {'error': e.toString()}),
      );
    }
  }
  
  // Valider que le nouvel item appartient à la même municipalité que les items existants
  Future<CartValidationResult> _validateSameMunicipality(CartItem newItem) async {
    debugPrint('🏛️ _validateSameMunicipality() - DÉBUT');
    debugPrint('🏛️ Nouvel item zoneId: ${newItem.local.zoneId}');
    
    try {
      if (_items.isEmpty) {
        debugPrint('🏛️ Panier vide, validation OK');
        return CartValidationResult(canAdd: true);
      }
      
      // Récupérer le municipalityId du nouvel item
      debugPrint('🏛️ Récupération zone du nouvel item...');
      final newItemZoneResponse = await _apiService.getZoneById(newItem.local.zoneId);
      debugPrint('🏛️ Réponse zone nouvel item: success=${newItemZoneResponse.success}');
      debugPrint('🏛️ Data zone nouvel item: ${newItemZoneResponse.data}');
      
      if (!newItemZoneResponse.success || newItemZoneResponse.data == null) {
        debugPrint('❌ Impossible de récupérer la zone du nouvel item');
        return CartValidationResult(
          canAdd: false,
          message: tr('error_checking_municipality_selected'),
        );
      }
      
      final newItemMunicipalityId = newItemZoneResponse.data?['municipalityId']?.toString();
      debugPrint('🏛️ MunicipalityId nouvel item: $newItemMunicipalityId');
      
      if (newItemMunicipalityId == null || newItemMunicipalityId.isEmpty) {
        debugPrint('❌ MunicipalityId nouvel item null ou vide');
        return CartValidationResult(
          canAdd: false,
          message: tr('municipality_undefined_selected'),
        );
      }
      
      // Récupérer le municipalityId du premier item existant
      final firstItem = _items.first;
      debugPrint('🏛️ Premier item zoneId: ${firstItem.local.zoneId}');
      
      final firstItemZoneResponse = await _apiService.getZoneById(firstItem.local.zoneId);
      debugPrint('🏛️ Réponse zone premier item: success=${firstItemZoneResponse.success}');
      debugPrint('🏛️ Data zone premier item: ${firstItemZoneResponse.data}');
      
      if (!firstItemZoneResponse.success || firstItemZoneResponse.data == null) {
        debugPrint('❌ Impossible de récupérer la zone du premier item');
        return CartValidationResult(
          canAdd: false,
          message: tr('error_checking_municipality_cart'),
        );
      }
      
      final firstItemMunicipalityId = firstItemZoneResponse.data?['municipalityId']?.toString();
      debugPrint('🏛️ MunicipalityId premier item: $firstItemMunicipalityId');
      
      if (firstItemMunicipalityId == null || firstItemMunicipalityId.isEmpty) {
        debugPrint('❌ MunicipalityId premier item null ou vide');
        return CartValidationResult(
          canAdd: false,
          message: tr('municipality_undefined_cart'),
        );
      }
      
      // Comparer les municipalityId
      debugPrint('🏛️ Comparaison: $newItemMunicipalityId vs $firstItemMunicipalityId');
      if (newItemMunicipalityId != firstItemMunicipalityId) {
        debugPrint('❌ Communes différentes');
        return CartValidationResult(
          canAdd: false,
          message: tr('different_municipality_error'),
        );
      }
      
      debugPrint('✅ Validation commune réussie: $newItemMunicipalityId');
      return CartValidationResult(canAdd: true);
      
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR CRITIQUE dans _validateSameMunicipality(): $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return CartValidationResult(
        canAdd: false,
        message: tr('error_validating_municipality', namedArgs: {'error': e.toString()}),
      );
    }
  }

  Future<bool> addItem(CartItem item) async {
    debugPrint('🛒 CartService.addItem() - DÉBUT');
    debugPrint('🛒 Item local ID: ${item.local.id}');
    debugPrint('🛒 Item local number: ${item.local.number}');
    debugPrint('🛒 Item contractType: ${item.contractType}');
    debugPrint('🛒 Item usage: ${item.usage}');
    debugPrint('🛒 Item totalAmount: ${item.totalAmount}');
    
    try {
      // Validate before adding
      debugPrint('🛒 Validation en cours...');
      final validation = await canAddItem(item);
      debugPrint('🛒 Résultat validation: canAdd=${validation.canAdd}, message=${validation.message}');
      
      if (!validation.canAdd) {
        debugPrint('❌ Validation échouée: ${validation.message}');
        // Return false to indicate failure, caller should handle the message
        return false;
      }

      // Vérifier si un local identique est déjà dans le panier
      final existingIndex = _items.indexWhere((cartItem) => cartItem.local.id == item.local.id);
      debugPrint('🛒 Index existant: $existingIndex');

      if (existingIndex != -1) {
        // Remplacer l'article existant (ou mettre à jour)
        _items[existingIndex] = item;
        debugPrint('🛒 CartService: Replaced existing item for local ${item.local.id}');
      } else {
        _items.add(item);
        debugPrint('🛒 CartService: Added new item for local ${item.local.id}');
      }
      
      debugPrint('🛒 Nombre d\'items dans le panier: ${_items.length}');
      notifyListeners();
      debugPrint('✅ CartService.addItem() - SUCCÈS');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR CRITIQUE dans CartService.addItem(): $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  // Méthode pour ajouter un item sans validation (pour les paniers temporaires)
  void addItemDirect(CartItem item) {
    final existingIndex = _items.indexWhere((cartItem) => cartItem.local.id == item.local.id);

    if (existingIndex != -1) {
      // Remplacer l'article existant
      _items[existingIndex] = item;
      debugPrint('CartService: Direct replaced existing item for local ${item.local.id}');
    } else {
      _items.add(item);
      debugPrint('CartService: Direct added new item for local ${item.local.id}');
    }
    // Ne pas appeler notifyListeners() pour les paniers temporaires
  }

  // Get validation result for UI display
  Future<CartValidationResult> getLastValidationResult(CartItem item) async {
    return await canAddItem(item);
  }

  void removeItem(CartItem item) {
    _items.removeWhere((cartItem) => cartItem.local.id == item.local.id);
    notifyListeners();
  }

  void updateItemDates(CartItem item, List<DateTime> newDates) {
    final index = _items.indexWhere((cartItem) => cartItem.local.id == item.local.id);
    if (index != -1) {
      // Créer une nouvelle instance de CartItem avec les dates mises à jour
      final updatedItem = CartItem(
        local: item.local,
        selectedDates: newDates,
        contractType: item.contractType,
        usage: item.usage,
        numberOfMonths: item.numberOfMonths,
      );
      
      // Si la nouvelle liste de dates est vide, supprimer l'article
      if (newDates.isEmpty) {
        _items.removeAt(index);
      } else {
        // Sinon, mettre à jour l'article avec les nouvelles dates
        _items[index] = updatedItem;
      }
      
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
  
  // Récupérer le municipalityId du panier (tous les items ont la même commune)
  Future<String?> getCurrentMunicipalityId() async {
    if (_items.isEmpty) return null;
    
    try {
      final firstItem = _items.first;
      final zoneResponse = await _apiService.getZoneById(firstItem.local.zoneId);
      if (zoneResponse.success && zoneResponse.data != null) {
        return zoneResponse.data?['municipalityId']?.toString();
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération du municipalityId du panier: $e');
    }
    
    return null;
  }
  
  // Vérifier si le panier contient des items d'une commune spécifique
  Future<bool> containsMunicipality(String municipalityId) async {
    final currentMunicipalityId = await getCurrentMunicipalityId();
    return currentMunicipalityId == municipalityId;
  }
  
  // Récupérer les informations de la commune du panier pour l'affichage
  Future<Map<String, dynamic>?> getCurrentMunicipalityInfo() async {
    if (_items.isEmpty) return null;
    
    try {
      final firstItem = _items.first;
      final zoneResponse = await _apiService.getZoneById(firstItem.local.zoneId);
      if (zoneResponse.success && zoneResponse.data != null) {
        final zoneData = zoneResponse.data;
        if (zoneData != null) {
          return {
            'municipalityId': zoneData['municipalityId']?.toString(),
            'zoneName': zoneData['nom']?.toString(),
            'zoneId': zoneData['id_zone']?.toString(),
          };
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des infos de commune: $e');
    }
    
    return null;
  }
}

// Validation result class
class CartValidationResult {
  final bool canAdd;
  final String? message;

  CartValidationResult({
    required this.canAdd,
    this.message,
  });
}
