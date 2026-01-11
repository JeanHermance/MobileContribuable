import 'package:flutter/foundation.dart';
import 'pagination_service.dart';
import 'api_service.dart';
import 'user_service.dart';

/// Service de pagination spécialisé pour les zones
class ZonesPaginationService extends PaginationService<Map<String, dynamic>> {
  final ApiService _apiService = ApiService();
  String? _municipalityId;
  
  ZonesPaginationService({
    super.pageSize = 6,
    super.enableInfiniteScroll = true,
  }) : super(
    fetchFunction: _dummyFetch,
  );
  
  /// Fonction statique dummy pour le constructeur parent
  static Future<PaginationResult<Map<String, dynamic>>> _dummyFetch(int page, int limit) {
    return Future.value(PaginationResult.error('Not implemented'));
  }
  
  /// Initialise le service avec un municipalityId
  void initialize(String municipalityId) {
    _municipalityId = municipalityId;
  }
  
  /// Charge les zones avec pagination
  Future<PaginationResult<Map<String, dynamic>>> fetchZones(int page, int limit) async {
    try {
      if (_municipalityId == null) {
        // Essayer de récupérer depuis UserService
        final municipalityData = await UserService.getMunicipalityData();
        if (municipalityData == null || municipalityData['formatted_id'] == null) {
          return PaginationResult.error('Municipality ID non trouvé');
        }
        _municipalityId = municipalityData['formatted_id'].toString();
      }
      
      final zonesResponse = await _apiService.getZones(
        _municipalityId!,
        page: page,
        limit: limit,
      );
      
      if (!zonesResponse.success || zonesResponse.data == null) {
        return PaginationResult.error(
          zonesResponse.error ?? 'Erreur lors du chargement des zones'
        );
      }
      
      final responseData = zonesResponse.data;
      if (responseData == null) {
        return PaginationResult.error('Données de zones non disponibles');
      }
      final zones = responseData['data'] as List<dynamic>? ?? [];
      final pagination = responseData['pagination'] as Map<String, dynamic>?;
      
      // Enrichir les zones avec les noms de fokotany
      final enrichedZones = await _enrichZonesWithFokotany(zones);
      
      PaginationInfo? paginationInfo;
      if (pagination != null) {
        paginationInfo = PaginationInfo.fromJson(pagination);
      }
      
      return PaginationResult.success(
        enrichedZones.cast<Map<String, dynamic>>(),
        paginationInfo,
      );
    } catch (e) {
      debugPrint('Error fetching zones: $e');
      return PaginationResult.error('Erreur de connexion: $e');
    }
  }
  
  /// Enrichit les zones avec les noms de fokotany
  Future<List<Map<String, dynamic>>> _enrichZonesWithFokotany(List<dynamic> zones) async {
    // Cache pour éviter les appels API redondants
    final Map<int, String> fokotanyCache = <int, String>{};
    
    final List<Future<Map<String, dynamic>>> futureZones = zones.map((zone) async {
      final zoneMap = zone as Map<String, dynamic>;
      
      // Correction: Utiliser formatted_Id au lieu de fokotany_id
      final fokotanyId = int.tryParse(zoneMap['formatted_Id']?.toString() ?? '');
      String fokotanyName = 'N/A';
      
      if (fokotanyId != null) {
        // Vérifier le cache d'abord
        if (fokotanyCache.containsKey(fokotanyId)) {
          fokotanyName = fokotanyCache[fokotanyId]!;
        } else {
          // Faire l'appel API seulement si pas en cache
          try {
            final fokotanyResponse = await _apiService.getFokotany(fokotanyId);
            if (fokotanyResponse.success && fokotanyResponse.data != null) {
              final fokotanyData = fokotanyResponse.data!;
              // Correction: utiliser 'nom' au lieu de 'name'
              fokotanyName = fokotanyData['nom']?.toString() ?? 'N/A';
              // Ajouter au cache
              fokotanyCache[fokotanyId] = fokotanyName;
            }
          } catch (e) {
            debugPrint('Error fetching fokotany $fokotanyId: $e');
          }
        }
      }
      
      return {
        'id_zone': zoneMap['id_zone'],
        'nom': zoneMap['nom'],
        'status': zoneMap['status'],
        'fokotany_id': zoneMap['fokotany_id'],
        'fokotany_name': fokotanyName,
        'municipalityId': zoneMap['municipalityId'],
        'formatted_Id': zoneMap['formatted_Id'],
        'geo_delimitation': zoneMap['geo_delimitation'],
      };
    }).toList();
    
    return await Future.wait(futureZones);
  }
  
  /// Override de la méthode loadFirstPage pour utiliser notre logique
  @override
  Future<void> loadFirstPage() async {
    if (isLoading) return;
    
    // Utiliser une approche différente - créer un nouveau PaginationService avec notre fonction
    final tempService = PaginationService<Map<String, dynamic>>(
      fetchFunction: fetchZones,
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
      final result = await fetchZones(nextPage, pageSize);
      
      if (result.success && result.data != null) {
        for (final item in result.data!) {
          addItem(item, atBeginning: false);
        }
      }
    } catch (e) {
      debugPrint('ZonesPaginationService loadNextPage error: $e');
    }
  }
  
  /// Filtre les zones par nom ou fokotany
  List<Map<String, dynamic>> filterZones(String query) {
    if (query.isEmpty) return items;
    
    return items.where((zone) {
      final zoneName = zone['nom']?.toString().toLowerCase() ?? '';
      final fokotanyName = zone['fokotany_name']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();
      return zoneName.contains(searchQuery) || fokotanyName.contains(searchQuery);
    }).toList();
  }
  
  /// Change de municipalité et recharge les données
  Future<void> changeMunicipality(String municipalityId) async {
    if (_municipalityId == municipalityId) return;
    
    _municipalityId = municipalityId;
    await loadFirstPage();
  }
}
