import 'package:flutter/foundation.dart';
import 'pagination_service.dart';
import 'api_service.dart';
import '../models/local_model.dart';

/// Service de pagination spécialisé pour les locaux
class LocalsPaginationService extends PaginationService<LocalModel> {
  final ApiService _apiService = ApiService();
  String? _municipalityId;
  String? _zoneId;
  String? _typeLocalId;
  
  LocalsPaginationService({
    super.pageSize = 6,
    super.enableInfiniteScroll = true,
  }) : super(
    fetchFunction: _dummyFetch,
  );
  
  /// Fonction statique dummy pour le constructeur parent
  static Future<PaginationResult<LocalModel>> _dummyFetch(int page, int limit) {
    return Future.value(PaginationResult.error('Not implemented'));
  }
  
  /// Initialise le service avec les paramètres nécessaires
  void initialize({
    required String municipalityId,
    required String zoneId,
    String? typeLocalId,
  }) {
    _municipalityId = municipalityId;
    _zoneId = zoneId;
    _typeLocalId = typeLocalId;
  }
  
  /// Charge les locaux avec pagination
  Future<PaginationResult<LocalModel>> fetchLocals(int page, int limit) async {
    try {
      if (_municipalityId == null || _zoneId == null) {
        return PaginationResult.error('Paramètres manquants pour charger les locaux');
      }
      
      // Fetch available and rented locals concurrently
      final results = await Future.wait([
        _apiService.getLocalsByZone(
          municipalityId: _municipalityId!,
          zoneId: _zoneId!,
          typeLocalId: _typeLocalId,
          page: page,
          limit: limit,
        ),
        _apiService.getRentedLocalsByMunicipality(
          municipalityId: _municipalityId!,
          page: page,
          limit: limit,
        ),
      ]);
      
      final availableResponse = results[0];
      final rentedResponse = results[1];
      
      List<LocalModel> allLocals = [];
      PaginationInfo? paginationInfo;
      
      if (availableResponse.success) {
        final availableLocalsData = availableResponse.data?['data'] as List<dynamic>? ?? [];
        final availableLocals = availableLocalsData
            .map((local) => LocalModel.fromJson(local as Map<String, dynamic>))
            .toList();
        allLocals.addAll(availableLocals);
        
        // Utiliser la pagination des locaux disponibles
        final paginationData = availableResponse.data?['pagination'] as Map<String, dynamic>?;
        if (paginationData != null) {
          paginationInfo = PaginationInfo.fromJson(paginationData);
        }
      }
      
      if (rentedResponse.success) {
        final rentedLocalsData = rentedResponse.data?['data'] as List<dynamic>? ?? [];
        final rentedLocalsInZone = rentedLocalsData
            .map((local) => LocalModel.fromJson(local as Map<String, dynamic>))
            .where((local) => local.zoneId == _zoneId)
            .toList();
        allLocals.addAll(rentedLocalsInZone);
      }
      
      return PaginationResult.success(allLocals, paginationInfo);
    } catch (e) {
      debugPrint('Error fetching locals: $e');
      return PaginationResult.error('Erreur de connexion: $e');
    }
  }
  
  /// Override de la méthode loadFirstPage pour utiliser notre logique
  @override
  Future<void> loadFirstPage() async {
    if (isLoading) return;
    
    // Utiliser une approche différente - créer un nouveau PaginationService avec notre fonction
    final tempService = PaginationService<LocalModel>(
      fetchFunction: fetchLocals,
      pageSize: pageSize,
      enableInfiniteScroll: true,
    );
    
    await tempService.loadFirstPage();
    
    // Copier les résultats
    reset();
    for (final item in tempService.items) {
      addItem(item, atBeginning: false);
    }
    
    notifyListeners();
  }
  
  /// Override de la méthode loadNextPage pour utiliser notre logique
  @override
  Future<void> loadNextPage() async {
    if (isLoadingMore || !hasMoreData || isLoading) {
      return;
    }
    
    try {
      final nextPage = currentPage + 1;
      final result = await fetchLocals(nextPage, pageSize);
      
      if (result.success && result.data != null) {
        for (final item in result.data!) {
          addItem(item, atBeginning: false);
        }
      }
    } catch (e) {
      debugPrint('LocalsPaginationService loadNextPage error: $e');
    }
  }
  
  /// Filtre les locaux selon les critères
  List<LocalModel> filterLocals(String searchQuery, String? selectedTypeId) {
    if (searchQuery.isEmpty && selectedTypeId == null) return items;
    
    return items.where((local) {
      final matchesSearch = searchQuery.isEmpty ||
          local.number.toLowerCase().contains(searchQuery) ||
          (local.typeLocal?['typeLoc']?.toString() ?? '').toLowerCase().contains(searchQuery) ||
          local.surface.toString().contains(searchQuery) ||
          (local.typeLocal?['tarif']?.toString() ?? '').contains(searchQuery);
      
      final matchesType = selectedTypeId == null || 
          local.typeLocal?['id_type_local']?.toString() == selectedTypeId;
      
      return matchesSearch && matchesType;
    }).toList();
  }
  
  /// Change le type de local sélectionné et recharge les données
  Future<void> changeTypeFilter(String? typeLocalId) async {
    if (_typeLocalId == typeLocalId) return;
    
    _typeLocalId = typeLocalId;
    await loadFirstPage();
  }
}
