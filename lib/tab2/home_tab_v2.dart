import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../components/hero_section.dart';
import '../components/search_bar_widget.dart';
import '../components/reservation_calendar_modal.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/real_time_service.dart';
import '../models/user_location.dart';
import '../models/municipality.dart';
import '../components/main_navigation.dart';
import '../screens/zone_locals_screen.dart';
import '../components/skeletons/home_skeleton.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _userName = 'default_user'.tr();
  String _userRole = 'default_role'.tr();
  bool _isLoading = true;
  String _searchQuery = '';

  // Municipality state
  Municipality? _currentMunicipality;
  List<Municipality> _availableMunicipalities = [];
  bool _isLoadingMunicipalities = true;

  // New state for zones
  List<Map<String, dynamic>> _zonesWithFokotany = [];
  List<Map<String, dynamic>> _filteredZonesWithFokotany = [];
  bool _isZonesLoading = true;

  // State for last location zone
  Map<String, dynamic>? _lastLocationZone;
  int? _lastLocationMunicipalityId;
  
  // Cache pour éviter les appels API redondants
  List<dynamic>? _cachedUserLocations;
  final Map<String, String> _fokotanyCache = {};
  
  // Stream subscription pour écouter les changements de données
  StreamSubscription<Map<String, dynamic>>? _dataChangeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAllData(); // Flux unifié et optimisé
    _setupDataChangeListener(); // Écouter les changements de données
    
    // Charger les vraies notifications depuis l'API
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final realTimeService = Provider.of<RealTimeService>(context, listen: false);
        realTimeService.refreshNotifications();
      }
    });
  }

  /// Configure l'écoute des changements de données en temps réel
  void _setupDataChangeListener() {
    final realTimeService = Provider.of<RealTimeService>(context, listen: false);
    
    _dataChangeSubscription = realTimeService.dataChangeStream.listen((event) {
      final dataType = event['type'] as String?;
      final metadata = event['metadata'] as Map<String, dynamic>?;
      
      debugPrint('🔔 Changement de données détecté: $dataType');
      debugPrint('📋 Métadonnées: $metadata');
      
      // Recharger les données selon le type de changement
      if (dataType != null && (dataType == 'payments' || dataType == 'reservations' || dataType == 'profile')) {
        _handleDataChange(dataType, metadata);
      }
    });
  }

  /// Gère les changements de données spécifiques
  Future<void> _handleDataChange(String dataType, Map<String, dynamic>? metadata) async {
    if (!mounted) return;
    
    debugPrint('🔄 Rechargement des données suite à changement: $dataType');
    
    switch (dataType) {
      case 'payments':
        // Un paiement a été effectué - recharger les données utilisateur
        final action = metadata?['action'] as String?;
        final status = metadata?['status'] as String?;
        
        if (action == 'created' && status == 'success') {
          debugPrint('✅ Paiement réussi détecté - rechargement complet');
          await _reloadUserDataAfterPayment();
        }
        break;
        
      case 'reservations':
        // Une réservation a été créée/modifiée - recharger les données
        debugPrint('📋 Changement de réservation détecté - rechargement');
        await _reloadUserDataAfterReservation();
        break;
        
      case 'profile':
        // Le profil utilisateur a été mis à jour
        debugPrint('👤 Profil utilisateur mis à jour - rechargement');
        await _reloadUserProfile();
        break;
    }
  }

  /// Recharge les données après un paiement réussi
  Future<void> _reloadUserDataAfterPayment() async {
    try {
      debugPrint('💳 === RECHARGEMENT APRÈS PAIEMENT RÉUSSI ===');
      
      // Vider le cache pour forcer le rechargement
      _cachedUserLocations = null;
      
      // Recharger les données utilisateur
      await _loadUserLocationsOnce();
      
      // Détecter le nouveau type d'utilisateur
      final newUserType = _detectUserTypeFromCache();
      
      // Ajuster la municipalité si nécessaire
      await _adjustMunicipalityFromCache();
      
      if (mounted) {
        setState(() {
          _userRole = newUserType;
        });
        
        // Afficher un message de confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Données mises à jour après paiement réussi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      debugPrint('✅ Rechargement après paiement terminé - nouveau type: $newUserType');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du rechargement après paiement: $e');
    }
  }

  /// Recharge les données après une nouvelle réservation
  Future<void> _reloadUserDataAfterReservation() async {
    try {
      debugPrint('📋 === RECHARGEMENT APRÈS NOUVELLE RÉSERVATION ===');
      
      // Vider le cache pour forcer le rechargement
      _cachedUserLocations = null;
      
      // Recharger les données utilisateur
      await _loadUserLocationsOnce();
      
      // Détecter le nouveau type d'utilisateur
      final newUserType = _detectUserTypeFromCache();
      
      // Ajuster la municipalité si nécessaire
      await _adjustMunicipalityFromCache();
      
      if (mounted) {
        setState(() {
          _userRole = newUserType;
        });
      }
      
      debugPrint('✅ Rechargement après réservation terminé - nouveau type: $newUserType');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du rechargement après réservation: $e');
    }
  }

  /// Recharge le profil utilisateur
  Future<void> _reloadUserProfile() async {
    try {
      debugPrint('👤 === RECHARGEMENT PROFIL UTILISATEUR ===');
      
      final userName = await UserService.getUserDisplayName();
      
      if (mounted) {
        setState(() {
          _userName = userName;
        });
      }
      
      debugPrint('✅ Profil utilisateur rechargé: $userName');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du rechargement du profil: $e');
    }
  }

  @override
  void dispose() {
    _dataChangeSubscription?.cancel();
    super.dispose();
  }

  /// Flux unifié et optimisé pour charger toutes les données
  Future<void> _initializeAllData() async {
    debugPrint('🚀 === INITIALISATION OPTIMISÉE ===');
    
    try {
      // Lancement des requêtes indépendantes en parallèle
      final results = await Future.wait([
        UserService.getUserDisplayName(), // 0: UserName
        _loadUserLocationsOnce(),         // 1: Locations (void, but awaited)
        _loadMunicipalities(),            // 2: Municipalities (void, but awaited)
      ]);
      
      final userName = results[0] as String;
      
      // 3. Détecter le type d'utilisateur depuis le cache
      final detectedUserType = _detectUserTypeFromCache();
      
      // 4. Ajuster selon la dernière location si disponible
      await _adjustMunicipalityFromCache();
      
      if (mounted) {
        setState(() {
          _userName = userName;
          _userRole = detectedUserType;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      debugPrint('❌ Erreur initialisation: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    
    debugPrint('🏁 === FIN INITIALISATION OPTIMISÉE ===');
  }

  /// Charge les locations utilisateur une seule fois et les met en cache
  Future<void> _loadUserLocationsOnce() async {
    if (_cachedUserLocations != null) {
      debugPrint('📋 Locations déjà en cache, pas de rechargement');
      return;
    }
    
    try {
      final userProfile = await UserService.getUserProfile();
      final userId = userProfile?['user_id']?.toString();
      
      if (userId == null || userId.isEmpty) {
        debugPrint('❌ Aucun userId trouvé');
        return;
      }
      
      final apiService = ApiService();
      final locationsResponse = await apiService.getUserLocations(userId);
      
      if (locationsResponse.success && locationsResponse.data != null) {
        _cachedUserLocations = locationsResponse.data;
        debugPrint('✅ ${_cachedUserLocations?.length ?? 0} locations mises en cache');
      } else {
        debugPrint('❌ Erreur chargement locations: ${locationsResponse.error}');
      }
    } catch (e) {
      debugPrint('❌ Erreur cache locations: $e');
    }
  }
  
  /// Détecte le type d'utilisateur depuis le cache (sans appel API)
  String _detectUserTypeFromCache() {
    if (_cachedUserLocations == null || _cachedUserLocations!.isEmpty) {
      debugPrint('📭 Aucune location en cache - type par défaut');
      return 'default';
    }
    
    try {
      // Trier par date de création (plus récente en premier)
      final locations = List<dynamic>.from(_cachedUserLocations!);
      locations.sort((a, b) {
        final dateA = DateTime.tryParse(a['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      
      final lastLocationData = locations.first;
      final lastLocation = UserLocation.fromJson(lastLocationData);
      
      debugPrint('🎯 Dernière location (cache): ${lastLocation.idLocation}');
      debugPrint('📅 Périodicité: ${lastLocation.periodicite}');
      
      if (lastLocation.periodicite == 'MENSUEL') {
        debugPrint('✅ Type détecté: Contribuable Mensuel');
        return 'contribuable mensuel';
      } else if (lastLocation.periodicite == 'JOURNALIER') {
        debugPrint('✅ Type détecté: Contribuable Journalier');
        return 'contribuable journalier';
      } else {
        debugPrint('⚠️ Périodicité inconnue: ${lastLocation.periodicite}');
        return 'default';
      }
    } catch (e) {
      debugPrint('❌ Erreur détection type depuis cache: $e');
      return 'default';
    }
  }
  
  /// Ajuste la municipalité selon la dernière location (depuis le cache)
  Future<void> _adjustMunicipalityFromCache() async {
    if (_cachedUserLocations == null || _cachedUserLocations!.isEmpty) {
      debugPrint('📍 Pas de locations en cache - chargement zones par défaut');
      if (_currentMunicipality != null) {
        await _loadZonesDataOptimized(_currentMunicipality!.formattedId);
      }
      return;
    }
    
    try {
      // Récupérer la dernière location depuis le cache
      final locations = List<dynamic>.from(_cachedUserLocations!);
      locations.sort((a, b) {
        final dateA = DateTime.tryParse(a['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      
      final lastLocationData = locations.first;
      final lastLocation = UserLocation.fromJson(lastLocationData);
      final zoneId = lastLocation.local.zoneId;
      
      debugPrint('🌍 Récupération zone pour dernière location: $zoneId');
      
      final apiService = ApiService();
      final zoneResponse = await apiService.getZoneById(zoneId);
      
      if (zoneResponse.success && zoneResponse.data != null) {
        final zoneData = zoneResponse.data!;
        final lastLocationMunicipalityId = zoneData['municipalityId']?.toString();
        
        // Stocker les informations de la dernière location
        if (mounted) {
          setState(() {
            _lastLocationZone = zoneData;
            _lastLocationMunicipalityId = int.tryParse(lastLocationMunicipalityId ?? '');
          });
        }
        
        // Ajuster la municipalité si nécessaire
        if (_currentMunicipality == null || 
            _currentMunicipality!.formattedId != lastLocationMunicipalityId) {
          
          final targetMunicipality = _availableMunicipalities.firstWhere(
            (m) => m.formattedId == lastLocationMunicipalityId,
            orElse: () => _currentMunicipality!,
          );
          
          if (targetMunicipality.formattedId == lastLocationMunicipalityId) {
            debugPrint('🔄 Changement municipalité: ${targetMunicipality.name}');
            
            if (mounted) {
              setState(() {
                _currentMunicipality = targetMunicipality;
              });
            }
          }
        }
        
        // Charger les zones pour la municipalité (sans await pour ne pas bloquer le squelette)
        if (_currentMunicipality != null) {
          _loadZonesDataOptimized(_currentMunicipality!.formattedId);
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur ajustement municipalité depuis cache: $e');
      // Fallback vers chargement normal (sans await)
      if (_currentMunicipality != null) {
        _loadZonesDataOptimized(_currentMunicipality!.formattedId);
      }
    }
  }
  
  /// Version optimisée du chargement des zones avec cache fokotany
  Future<void> _loadZonesDataOptimized([String? municipalityId]) async {
    if (!mounted) return;
    setState(() {
      _isZonesLoading = true;
    });
    
    try {
      String? finalMunicipalityId = municipalityId;
      
      if (finalMunicipalityId == null) {
        final municipalityData = await UserService.getMunicipalityData();
        if (municipalityData == null || municipalityData['formatted_id'] == null) {
          if (mounted) {
            setState(() {
              _isZonesLoading = false;
            });
          }
          return;
        }
        finalMunicipalityId = municipalityData['formatted_id'].toString();
      }

      // Pré-remplir le cache fokotany avec les données de la municipalité actuelle
      if (_currentMunicipality != null && _currentMunicipality!.fokotanys.isNotEmpty) {
        for (var fokotany in _currentMunicipality!.fokotanys) {
          _fokotanyCache[fokotany.fokotanyId.toString()] = fokotany.name;
          if (fokotany.formattedId.isNotEmpty) {
            _fokotanyCache[fokotany.formattedId] = fokotany.name;
          }
        }
        debugPrint('📦 Cache fokotany pré-rempli avec ${_currentMunicipality!.fokotanys.length} entrées');
      }

      final apiService = ApiService();
      final zonesResponse = await apiService.getZones(finalMunicipalityId);
      
      if (zonesResponse.success && zonesResponse.data != null) {
        final responseData = zonesResponse.data;
        if (responseData?['data'] != null) {
          List<dynamic> zones = responseData!['data'];
          
          // Traitement optimisé avec cache fokotany
          List<Future<Map<String, dynamic>>> futureZones = zones.map((zone) async {
            final fokotanyIdStr = zone['fokotany_id']?.toString() ?? 
                                 zone['formatted_id']?.toString() ?? 
                                 zone['formatted_Id']?.toString() ?? '';
            final fokotanyId = int.tryParse(fokotanyIdStr);
            String fokotanyName = 'N/A';

            if (fokotanyIdStr.isNotEmpty) {
              // Vérifier le cache d'abord (par ID ou formattedId)
              if (_fokotanyCache.containsKey(fokotanyIdStr)) {
                fokotanyName = _fokotanyCache[fokotanyIdStr]!;
              } else if (fokotanyId != null && _fokotanyCache.containsKey(fokotanyId.toString())) {
                fokotanyName = _fokotanyCache[fokotanyId.toString()]!;
              } 
              // NOTE: Appel API supprimé pour performance. Si pas en cache, on affiche N/A.
            }
            
            return {
              'id_zone': zone['id_zone'],
              'nom': zone['nom'],
              'status': zone['status'],
              'fokotany_id': zone['fokotany_id'],
              'municipalityId': zone['municipalityId'],
              'fokotany_name': fokotanyName,
              'geo_delimitation': zone['geo_delimitation'],
              'total_locaux': zone['total_locaux'],
              'locaux_disponibles': zone['locaux_disponibles'],
            };
          }).toList();

          final resolvedZones = await Future.wait(futureZones);

          if (mounted) {
            setState(() {
              _zonesWithFokotany = List<Map<String, dynamic>>.from(resolvedZones);
              _filteredZonesWithFokotany = List<Map<String, dynamic>>.from(resolvedZones);
              _isZonesLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _zonesWithFokotany = [];
              _filteredZonesWithFokotany = [];
              _isZonesLoading = false;
            });
          }
        }
      } else {
        debugPrint('❌ Erreur zones API: ${zonesResponse.error}');
        if (mounted) {
          setState(() {
            _isZonesLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement zones optimisé: $e');
      if (mounted) {
        setState(() {
          _isZonesLoading = false;
        });
      }
    }
  }
  




  /// Récupère les informations de la zone de la dernière location de l'utilisateur
  /// Note: Cette méthode est maintenant obsolète, remplacée par _initializeDataWithLastLocation()
  /// Gardée pour compatibilité mais ne fait plus rien car la logique est dans le nouveau flux
 

  /// Enrichit une zone avec son nom de fokotany et ses délimitations complètes (fonction unifiée)
  Future<Map<String, dynamic>> _enrichZoneWithFokotany(Map<String, dynamic> zone) async {
    debugPrint('🔍 === ENRICHISSEMENT ZONE COMPLET ===');
    debugPrint('  Zone ID: ${zone['id_zone']}');
    debugPrint('  Zone nom: ${zone['nom']}');
    debugPrint('  Fokotany ID: ${zone['fokotany_id']}');
    debugPrint('  Municipality ID: ${zone['municipalityId']}');
    
    try {
      final apiService = ApiService();
      Map<String, dynamic> enrichedZone = Map<String, dynamic>.from(zone);
      
      // 1. Récupérer le fokotany_name
      // Essayer plusieurs champs possibles pour le fokotany_id
      final fokotanyIdStr = zone['fokotany_id']?.toString() ?? 
                           zone['formatted_id']?.toString() ?? 
                           zone['formatted_Id']?.toString() ?? '';
      final fokotanyId = int.tryParse(fokotanyIdStr);
      String fokotanyName = 'N/A';
      
      debugPrint('🔍 Recherche fokotany_id dans la zone:');
      debugPrint('  fokotany_id: ${zone['fokotany_id']}');
      debugPrint('  formatted_id: ${zone['formatted_id']}');
      debugPrint('  formatted_Id: ${zone['formatted_Id']}');
      debugPrint('  fokotanyId final: $fokotanyId');
      
      if (fokotanyId != null) {
        debugPrint('📡 Appel API getFokotany pour fokotanyId: $fokotanyId');
        final fokotanyResponse = await apiService.getFokotany(fokotanyId);
        
        if (fokotanyResponse.success && fokotanyResponse.data != null) {
          final fokotanyData = fokotanyResponse.data;
          if (fokotanyData != null) {
            // Essayer plusieurs clés possibles pour le nom
            fokotanyName = fokotanyData['nom'] ?? 
                         fokotanyData['name'] ?? 
                         fokotanyData['libelle'] ?? 
                         fokotanyData['designation'] ?? 'N/A';
            debugPrint('✅ Fokotany récupéré: $fokotanyName');
            debugPrint('  Données fokotany reçues: ${fokotanyData.keys.toList()}');
          }
        } else {
          debugPrint('❌ Erreur récupération fokotany: ${fokotanyResponse.error}');
        }
      } else {
        debugPrint('⚠️ Aucun fokotany_id valide trouvé dans la zone');
        debugPrint('  Champs vérifiés: fokotany_id, formatted_id, formatted_Id');
        debugPrint('  Valeurs: ${zone['fokotany_id']}, ${zone['formatted_id']}, ${zone['formatted_Id']}');
      }
      
      enrichedZone['fokotany_name'] = fokotanyName;
      
      // 2. Récupérer les délimitations complètes depuis getZones() si manquantes
      if (enrichedZone['geo_delimitation'] == null || 
          (enrichedZone['geo_delimitation'] is Map && (enrichedZone['geo_delimitation'] as Map).isEmpty)) {
        
        debugPrint('🗺️ Délimitations manquantes - récupération depuis getZones()');
        final municipalityId = zone['municipalityId']?.toString();
        
        if (municipalityId != null) {
          debugPrint('📡 Appel API getZones pour municipalityId: $municipalityId');
          final zonesResponse = await apiService.getZones(municipalityId);
          
          if (zonesResponse.success && zonesResponse.data != null) {
            final responseData = zonesResponse.data;
            if (responseData != null && responseData['data'] != null) {
              final zones = responseData['data'] as List<dynamic>;
              
              // Chercher la zone correspondante dans la liste complète
              final matchingZone = zones.firstWhere(
                (z) => z['id_zone'] == zone['id_zone'],
                orElse: () => null,
              );
              
              if (matchingZone != null && matchingZone['geo_delimitation'] != null) {
                enrichedZone['geo_delimitation'] = matchingZone['geo_delimitation'];
                enrichedZone['total_locaux'] = matchingZone['total_locaux'];
                enrichedZone['locaux_disponibles'] = matchingZone['locaux_disponibles'];
                debugPrint('✅ Délimitations récupérées depuis getZones()');
                debugPrint('  geo_delimitation type: ${matchingZone['geo_delimitation'].runtimeType}');
                debugPrint('  total_locaux: ${matchingZone['total_locaux']}');
                debugPrint('  locaux_disponibles: ${matchingZone['locaux_disponibles']}');
              } else {
                debugPrint('⚠️ Zone correspondante non trouvée dans getZones() ou pas de délimitations');
              }
            }
          } else {
            debugPrint('❌ Erreur récupération zones: ${zonesResponse.error}');
          }
        } else {
          debugPrint('⚠️ Municipality ID manquant pour récupérer les délimitations');
        }
      } else {
        debugPrint('✅ Délimitations déjà présentes dans la zone');
      }
      
      debugPrint('✅ Zone enrichie complètement:');
      debugPrint('  fokotany_name: $fokotanyName');
      debugPrint('  geo_delimitation: ${enrichedZone['geo_delimitation'] != null ? 'présent' : 'absent'}');
      
      return enrichedZone;
      
    } catch (e) {
      debugPrint('❌ Erreur enrichissement zone complet: $e');
      // Retourner la zone originale avec fokotany_name par défaut
      final enrichedZone = Map<String, dynamic>.from(zone);
      enrichedZone['fokotany_name'] = 'N/A';
      return enrichedZone;
    }
  }

  Future<void> _loadMunicipalities() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingMunicipalities = true;
    });

    try {
      final apiService = ApiService();
      
      // Charger toutes les municipalités membres
      final municipalitiesResponse = await apiService.getMemberMunicipalities();
      
      if (municipalitiesResponse.success && municipalitiesResponse.data != null) {
        final municipalitiesData = municipalitiesResponse.data;
        if (municipalitiesData == null) return;
        
        final municipalitiesList = municipalitiesData
            .map((data) => Municipality.fromJson(data as Map<String, dynamic>))
            .toList();

        // Obtenir la municipalité par défaut de l'utilisateur
        final municipalityData = await UserService.getMunicipalityData();
        Municipality? defaultMunicipality;
        Municipality? userOwnMunicipality;
        
        if (municipalityData != null && municipalityData['formatted_id'] != null) {
          final userMunicipalityId = municipalityData['formatted_id'].toString();
          
          // Chercher la municipalité de l'utilisateur dans la liste des membres
          try {
            defaultMunicipality = municipalitiesList.firstWhere(
              (m) => m.formattedId == userMunicipalityId,
            );
            debugPrint('✅ Municipalité utilisateur trouvée dans les membres: ${defaultMunicipality.name}');
          } catch (e) {
            // La municipalité de l'utilisateur n'est pas membre
            debugPrint('⚠️ Municipalité utilisateur non membre, création d\'une entrée personnalisée');
            
            // Créer une municipalité personnalisée basée sur les données utilisateur
            userOwnMunicipality = Municipality(
              communeId: int.tryParse(municipalityData['commune_id']?.toString() ?? '0') ?? 0,
              name: municipalityData['name']?.toString() ?? 'Ma municipalité',
              isMember: false, // Pas membre du système
              district: District(
                districtId: int.tryParse(municipalityData['district_id']?.toString() ?? '0') ?? 0,
                name: municipalityData['district_name']?.toString() ?? 'District inconnu',
                formattedId: municipalityData['district_formatted_id']?.toString() ?? '',
              ),
              region: Region(
                regionId: int.tryParse(municipalityData['region_id']?.toString() ?? '0') ?? 0,
                name: municipalityData['region_name']?.toString() ?? 'Région inconnue',
                formattedId: municipalityData['region_formatted_id']?.toString() ?? '',
              ),
              fokotanys: [], // Pas de fokotanys pour les non-membres
              formattedId: userMunicipalityId,
            );
            
            // Ajouter la municipalité utilisateur en première position
            municipalitiesList.insert(0, userOwnMunicipality);
            defaultMunicipality = userOwnMunicipality;
          }
        }
        
        // Si pas de municipalité utilisateur, prendre la première membre disponible
        if (defaultMunicipality == null && municipalitiesList.isNotEmpty) {
          defaultMunicipality = municipalitiesList.first;
          debugPrint('📍 Utilisation de la première municipalité membre: ${defaultMunicipality.name}');
        }

        if (mounted) {
          setState(() {
            _availableMunicipalities = municipalitiesList;
            _currentMunicipality = defaultMunicipality;
            _isLoadingMunicipalities = false;
          });
          
          debugPrint('✅ Municipalités chargées - municipalité par défaut: ${defaultMunicipality?.name}');
          // Note: Les zones seront chargées par _setMunicipalityFromLastLocation() ou en fallback
        }
      } else {
        debugPrint('Error loading municipalities: ${municipalitiesResponse.error}');
        if (mounted) {
          setState(() {
            _isLoadingMunicipalities = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading municipalities: $e');
      if (mounted) {
        setState(() {
          _isLoadingMunicipalities = false;
        });
      }
    }
  }

  void _onMunicipalityChanged(Municipality municipality) {
    if (municipality.communeId == _currentMunicipality?.communeId) return;
    
    debugPrint('🔄 === CHANGEMENT DE MUNICIPALITÉ ===');
    debugPrint('  Ancienne: ${_currentMunicipality?.name} (${_currentMunicipality?.formattedId})');
    debugPrint('  Nouvelle: ${municipality.name} (${municipality.formattedId})');
    
    setState(() {
      _currentMunicipality = municipality;
      // Réinitialiser les zones pendant le chargement
      _zonesWithFokotany = [];
      _filteredZonesWithFokotany = [];
    });
    
    // Recharger les zones pour la nouvelle municipalité
    debugPrint('🔄 Rechargement des zones pour la nouvelle municipalité...');
    _loadZonesDataOptimized(municipality.formattedId);
  }


  void _filterZones(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredZonesWithFokotany = _zonesWithFokotany;
      } else {
        _filteredZonesWithFokotany = _zonesWithFokotany.where((zone) {
          final zoneName = zone['nom']?.toLowerCase() ?? '';
          final fokotanyName = zone['fokotany_name']?.toLowerCase() ?? '';
          final searchQuery = query.toLowerCase();
          return zoneName.contains(searchQuery) || fokotanyName.contains(searchQuery);
        }).toList();
      }
    });
  }

  // Navigate to notification tab
  void _navigateToNotifications() {
    // Use MainNavigation's static method to change tabs
    final mainNav = MainNavigation.of(context);
    if (mainNav != null) {
      mainNav.changeTab(2); // Notification tab is at index 2 (0-based index)
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const HomeSkeleton();
    }

    // Configuration de la barre de statut pour qu'elle soit transparente
    // et laisse le gradient du HeroSection la colorer
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Transparent pour laisser voir le gradient
        statusBarIconBrightness: Brightness.light, // Icônes blanches sur fond coloré (gradient bleu)
        statusBarBrightness: Brightness.dark, // Pour iOS - fond sombre donc icônes claires
        systemNavigationBarColor: Colors.white, // Barre de navigation blanche
        systemNavigationBarIconBrightness: Brightness.dark, // Icônes sombres sur fond blanc
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(300), // Augmenté pour accommoder le sélecteur de municipalité et éviter le chevauchement
        child: Consumer<RealTimeService>(
          builder: (context, realTimeService, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(), // Désactiver le scroll pour l'AppBar
                  child: HeroSection(
                    userPseudo: _userName,
                    title: 'market_subtitle'.tr(),
                    // subtitle: 'market_subtitle'.tr(),
                    onNotificationTap: _navigateToNotifications,
                    notificationCount: realTimeService.unreadNotificationCount,
                    currentMunicipality: _currentMunicipality,
                    availableMunicipalities: _availableMunicipalities,
                    onMunicipalityChanged: _onMunicipalityChanged,
                    isLoadingMunicipalities: _isLoadingMunicipalities,
                  ),
                ),
                // Search Bar positioned over the hero section
                Positioned(
                  bottom: -30,
                  left: 16,
                  right: 16,
                  child: SearchBarWidget(
                    placeholder: 'search_placeholder'.tr(), 
                    onChanged: _filterZones,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24, top: 30), // Top padding pour compenser le SearchBar qui chevauche
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30), // Espace supplémentaire pour le SearchBar
              // Content with padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildRoleSpecificSection(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
    );
  }

  Widget _buildRoleSpecificSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final userType = _userRole.toLowerCase();

    switch (userType) {
      case 'contribuable mensuel':
        return Column(
          children: [
            _buildStatisticsSection(),
            const SizedBox(height: 24),
            _buildZonesSection(),
          ],
        );
        
      case 'contribuable journalier':
        return Column(
          children: [
            _buildQuickActionsSection(),
            const SizedBox(height: 24),
            _buildZonesSection(),
          ],
        );
        
      default:
        return Column(
          children: [
            _buildWelcomeMessage('discover_zones'.tr(), Icons.explore, Colors.green),
            const SizedBox(height: 16),
            _buildZonesSection(),
          ],
        );
    }
  }

  /// Message de bienvenue personnalisé selon le type détecté
  Widget _buildWelcomeMessage(String title, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha((0.1 * 255).round()),
            color.withAlpha((0.05 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withAlpha((0.2 * 255).round()),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha((0.15 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonesSection() {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9).withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE8F5E9).withAlpha((0.1 * 255).round()),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.location_on, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'market_zones'.tr(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (!_isZonesLoading && _filteredZonesWithFokotany.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green, Colors.green.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withAlpha((0.3 * 255).round()),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${_filteredZonesWithFokotany.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isZonesLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9).withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.green,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'loading_zones'.tr(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'server_data_retrieval'.tr(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_zonesWithFokotany.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.08 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.black.withAlpha((0.2 * 255).round()),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'no_zones_available'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'zones_admin_message'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_searchQuery.isNotEmpty && _filteredZonesWithFokotany.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withAlpha((0.08 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF9800).withAlpha((0.3 * 255).round()),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'no_search_results'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'no_zone_matches'.tr(namedArgs: {'query': _searchQuery}),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_filteredZonesWithFokotany.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredZonesWithFokotany.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final zone = _filteredZonesWithFokotany[index];
                    final isActive = zone['status'] == true;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? Colors.green : Colors.grey,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.store,
                          color: isActive ? Colors.green : Colors.grey,
                        ),
                        title: Text(zone['nom'] ?? 'Zone sans nom'),
                        subtitle: Text(zone['fokotany_name'] ?? 'N/A'),
                        trailing: Icon(
                          isActive ? Icons.check_circle : Icons.circle_outlined,
                          color: isActive ? Colors.green : Colors.grey,
                        ),
                        onTap: () {
                          final municipalityId = zone['municipalityId'];
                          if (municipalityId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ZoneLocalsScreen(
                                  zone: zone,
                                  municipalityId: int.tryParse(municipalityId.toString()) ?? 1,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    )
    );
  }


  Widget _buildStatisticsSection() {
    return FutureBuilder<Map<String, String>>(
      future: _getStatsData(),
      builder: (context, snapshot) {
        final aPayer = snapshot.data?['aPayer'] ?? '-';
        final expirant = snapshot.data?['expirant'] ?? '-';
        return Card(
          elevation: 3,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  const Color(0xFFE3F2FD).withAlpha((0.3 * 255).round()),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E88E5).withAlpha((0.1 * 255).round()),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.analytics, color: Colors.blue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'my_statistics'.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final mainNav = MainNavigation.of(context);
                            if (mainNav != null) {
                              mainNav.changeTab(3, paymentFilter: 'En attente'); // Payment history tab with 'En attente' filter
                            }
                          },
                          child: _buildStatCard(
                            icon: Icons.payment,
                            title: 'to_pay'.tr(),
                            value: aPayer,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final mainNav = MainNavigation.of(context);
                            if (mainNav != null) {
                              mainNav.changeTab(1, reservationFilter: 'En cours'); // Reservation tab with 'En cours' filter
                            }
                          },
                          child: _buildStatCard(
                            icon: Icons.schedule,
                            title: 'expiring'.tr(),
                            value: expirant,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Version optimisée des statistiques utilisant le cache
  Future<Map<String, String>> _getStatsData() async {
    // Utiliser le cache si disponible
    if (_cachedUserLocations == null || _cachedUserLocations!.isEmpty) {
      debugPrint('📊 Pas de locations en cache pour les stats');
      return {'aPayer': '-', 'expirant': '-'};
    }
    
    try {
      final now = DateTime.now();
      int totalResteAPayer = 0;
      int minDaysToExpire = 99999;
      int minMonthsToExpire = 99999;
      int maxDaysSinceExpired = 0;
      int maxMonthsSinceExpired = 0;
      
      final apiService = ApiService();
      
      // Traitement optimisé avec cache
      for (final locData in _cachedUserLocations!) {
        final location = UserLocation.fromJson(locData);
        
        // Appel API pour le reste à payer (nécessaire car change fréquemment)
        final resteResponse = await apiService.getLocationResteAPayer(location.idLocation);
        int reste = 0;
        if (resteResponse.success && resteResponse.data != null) {
          final resteData = resteResponse.data;
          if (resteData != null) {
            final resteObj = ResteAPayer.fromJson(resteData);
            reste = resteObj.resteAPayer;
          }
        }
        
        // Location en cours ?
        if (location.dateFinLoc.isAfter(now)) {
          totalResteAPayer += reste;
          final daysToExpire = location.dateFinLoc.difference(now).inDays;
          // Calcul plus précis des mois
          int monthsToExpire = (location.dateFinLoc.year - now.year) * 12 + (location.dateFinLoc.month - now.month);
          if (location.dateFinLoc.day < now.day) {
            monthsToExpire -= 1;
          }
          if (daysToExpire < minDaysToExpire) minDaysToExpire = daysToExpire;
          if (monthsToExpire < minMonthsToExpire && monthsToExpire >= 0) minMonthsToExpire = monthsToExpire;
        } else {
          // Contrat expiré
          final daysSinceExpired = now.difference(location.dateFinLoc).inDays;
          double monthsSinceExpiredDouble = (now.year - location.dateFinLoc.year) * 12.0 + (now.month - location.dateFinLoc.month);
          int monthsSinceExpired = monthsSinceExpiredDouble.round();
          if (now.day < location.dateFinLoc.day) {
            monthsSinceExpired -= 1;
          }
          if (daysSinceExpired > maxDaysSinceExpired) maxDaysSinceExpired = daysSinceExpired;
          if (monthsSinceExpired > maxMonthsSinceExpired && monthsSinceExpired >= 0) maxMonthsSinceExpired = monthsSinceExpired;
        }
      }
      
      String aPayerStr = totalResteAPayer > 0 ? '${totalResteAPayer.toString()} Ar' : '0 Ar';
      String expirantStr = '-';
      if (minDaysToExpire != 99999) {
        expirantStr = minDaysToExpire < 31 ? '$minDaysToExpire jours' : '$minMonthsToExpire mois';
      } else if (maxDaysSinceExpired > 0) {
        expirantStr = maxDaysSinceExpired < 31 ? 'Expiré il y a $maxDaysSinceExpired jours' : 'Expiré il y a $maxMonthsSinceExpired mois';
      }
      
      debugPrint('📊 Stats calculées depuis cache: à payer=$aPayerStr, expirant=$expirantStr');
      return {'aPayer': aPayerStr, 'expirant': expirantStr};
      
    } catch (e) {
      debugPrint('❌ Erreur calcul stats depuis cache: $e');
      return {'aPayer': '-', 'expirant': '-'};
    }
  }

  Widget _buildQuickActionsSection() {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFFF3E5F5).withAlpha((0.3 * 255).round()),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E24AA).withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8E24AA).withAlpha((0.1 * 255).round()),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.flash_on, color: Colors.purple, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'quick_actions'.tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.add_circle_outline,
                      title: 'new_reservation_action'.tr(),
                      color: Colors.green,
                      onTap: () async {
                        debugPrint('🎯 === ACTION NOUVELLE RÉSERVATION DÉCLENCHÉE ===');
                        
                        // Rediriger vers la zone de la dernière location de l'utilisateur
                        if (_lastLocationZone != null && _lastLocationMunicipalityId != null) {
                          
                          // Vérifier la municipalité actuelle
                          if (_currentMunicipality != null) {
                            debugPrint('🏛️ Municipalité actuellement sélectionnée: ${_currentMunicipality!.name} (${_currentMunicipality!.formattedId})');
                            
                            final lastLocationMunicipalityId = _lastLocationZone!['municipalityId']?.toString();
                            if (_currentMunicipality!.formattedId == lastLocationMunicipalityId) {
                              debugPrint('✅ La municipalité actuelle correspond à celle de la dernière location');
                            } else {
                              debugPrint('⚠️ Municipalité différente - Actuelle: ${_currentMunicipality!.formattedId}, Dernière location: $lastLocationMunicipalityId');
                            }
                          }
                          
                          
                          
                          // Enrichir la zone avec le fokotany_name et les délimitations complètes
                          final enrichedZone = await _enrichZoneWithFokotany(_lastLocationZone!);
                          
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ZoneLocalsScreen(
                                zone: enrichedZone, // ← Zone enrichie avec fokotany_name
                                municipalityId: _lastLocationMunicipalityId!,
                              ),
                            ),
                          );
                        } else {
                          debugPrint('❌ Données de la dernière location manquantes:');
                          debugPrint('  _lastLocationZone: ${_lastLocationZone != null ? 'disponible' : 'null'}');
                          debugPrint('  _lastLocationMunicipalityId: $_lastLocationMunicipalityId');
                          
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Aucune zone de dernière location trouvée. Veuillez d\'abord effectuer une réservation.'),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.calendar_month,
                      title: 'view_calendar'.tr(),
                      color: Colors.blue,
                      onTap: () {
                        // Afficher la modal de calendrier des réservations
                        showDialog(
                          context: context,
                          builder: (context) => const ReservationCalendarModal(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcul responsive des tailles
        final cardWidth = constraints.maxWidth;
        final iconSize = cardWidth * 0.15; // 15% de la largeur
        final valueSize = cardWidth * 0.18; // 18% de la largeur
        final titleSize = cardWidth * 0.08; // 8% de la largeur
        final padding = cardWidth * 0.12; // 12% de la largeur
        
        return Container(
          height: 160, // Hauteur fixe pour uniformiser
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withAlpha((0.2 * 255).round()),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha((0.1 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(padding.clamp(16.0, 24.0)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all((iconSize * 0.4).clamp(10.0, 16.0)),
                  decoration: BoxDecoration(
                    color: color.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon, 
                    color: color, 
                    size: iconSize.clamp(24.0, 32.0)
                  ),
                ),
                SizedBox(height: (cardWidth * 0.08).clamp(8.0, 16.0)),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: valueSize.clamp(20.0, 32.0),
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(height: (cardWidth * 0.03).clamp(2.0, 6.0)),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: titleSize.clamp(11.0, 15.0),
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha((0.2 * 255).round()),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((0.1 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withAlpha((0.1 * 255).round()),
                        color.withAlpha((0.2 * 255).round()),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}