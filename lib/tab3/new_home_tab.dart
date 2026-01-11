import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/real_time_service.dart';
import '../models/user_location.dart';
import '../models/municipality.dart';
import 'new_main_navigation.dart';
import '../screens/zone_locals_screen.dart';
import '../components/skeletons/home_skeleton.dart';
import '../components/qr_code_modal.dart';
import '../components/place_calendar_modal.dart';

class NewHomeTab extends StatefulWidget {
  const NewHomeTab({super.key});

  @override
  State<NewHomeTab> createState() => _NewHomeTabState();
}

class _NewHomeTabState extends State<NewHomeTab> {
  String _userName = 'default_user'.tr();
  String _userRole = 'default_role'.tr();
  bool _isLoading = true;

  // Municipality state
  Municipality? _currentMunicipality;
  List<Municipality> _availableMunicipalities = [];
  bool _isLoadingMunicipalities = true;

  // New state for zones
  List<Map<String, dynamic>> _zonesWithFokotany = [];
  List<Map<String, dynamic>> _filteredZonesWithFokotany = [];
  bool _isZonesLoading = true;
  
  // Cache pour éviter les appels API redondants
  List<dynamic>? _cachedUserLocations;
  final Map<String, String> _fokotanyCache = {};
  
  // Cache pour la dernière location enrichie (pour éviter l'async sur le bouton)
  Map<String, dynamic>? _cachedLastLocationData;
  
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
      
      // Recharger les données selon le type de changement
      if (dataType != null && (dataType == 'payments' || dataType == 'reservations' || dataType == 'profile')) {
        _handleDataChange(dataType, metadata);
      }
    });
  }

  /// Gère les changements de données spécifiques
  Future<void> _handleDataChange(String dataType, Map<String, dynamic>? metadata) async {
    if (!mounted) return;
    
    switch (dataType) {
      case 'payments':
        final action = metadata?['action'] as String?;
        final status = metadata?['status'] as String?;
        
        if (action == 'created' && status == 'success') {
          await _reloadUserDataAfterPayment();
        }
        break;
        
      case 'reservations':
        await _reloadUserDataAfterReservation();
        break;
        
      case 'profile':
        await _reloadUserProfile();
        break;
    }
  }

  /// Recharge les données après un paiement réussi
  Future<void> _reloadUserDataAfterPayment() async {
    try {
      _cachedUserLocations = null;
      await _loadUserLocationsOnce();
      final newUserType = _detectUserTypeFromCache();
      await _adjustMunicipalityFromCache();
      
      if (mounted) {
        setState(() {
          _userRole = newUserType;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('data_updated_after_payment'.tr()),
            backgroundColor: Theme.of(context).primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du rechargement après paiement: $e');
    }
  }

  /// Recharge les données après une nouvelle réservation
  Future<void> _reloadUserDataAfterReservation() async {
    try {
      _cachedUserLocations = null;
      _cachedLastLocationData = null; // Invalider le cache
      await _loadUserLocationsOnce();
      final newUserType = _detectUserTypeFromCache();
      await _adjustMunicipalityFromCache();
      await _cacheLastLocationData(); // Recharger le cache
      
      if (mounted) {
        setState(() {
          _userRole = newUserType;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du rechargement après réservation: $e');
    }
  }

  /// Recharge le profil utilisateur
  Future<void> _reloadUserProfile() async {
    try {
      final userName = await UserService.getUserDisplayName();
      if (mounted) {
        setState(() {
          _userName = userName;
        });
      }
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
    try {
      final results = await Future.wait([
        UserService.getUserDisplayName(),
        _loadUserLocationsOnce(),
        _loadMunicipalities(),
      ]);
      
      final userName = results[0] as String;
      final detectedUserType = _detectUserTypeFromCache();
      await _adjustMunicipalityFromCache();
      
      // Pré-charger les données de la dernière location pour le bouton rapide
      await _cacheLastLocationData();
      
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
  }

  /// Charge les locations utilisateur une seule fois et les met en cache
  Future<void> _loadUserLocationsOnce() async {
    if (_cachedUserLocations != null) return;
    
    try {
      final userProfile = await UserService.getUserProfile();
      final userId = userProfile?['user_id']?.toString();
      
      if (userId == null || userId.isEmpty) return;
      
      final apiService = ApiService();
      final locationsResponse = await apiService.getUserLocations(userId);
      
      if (locationsResponse.success && locationsResponse.data != null) {
        _cachedUserLocations = locationsResponse.data;
      }
    } catch (e) {
      debugPrint('❌ Erreur cache locations: $e');
    }
  }
  
  /// Détecte le type d'utilisateur depuis le cache (sans appel API)
  String _detectUserTypeFromCache() {
    if (_cachedUserLocations == null || _cachedUserLocations!.isEmpty) {
      return 'default';
    }
    
    try {
      final locations = List<dynamic>.from(_cachedUserLocations!);
      locations.sort((a, b) {
        final dateA = DateTime.tryParse(a['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      
      final lastLocationData = locations.first;
      final lastLocation = UserLocation.fromJson(lastLocationData);
      
      if (lastLocation.periodicite == 'MENSUEL') {
        return 'contribuable mensuel';
      } else if (lastLocation.periodicite == 'JOURNALIER') {
        return 'contribuable journalier';
      } else {
        return 'default';
      }
    } catch (e) {
      return 'default';
    }
  }
  
  /// Ajuste la municipalité selon la dernière location (depuis le cache)
  Future<void> _adjustMunicipalityFromCache() async {
    if (_cachedUserLocations == null || _cachedUserLocations!.isEmpty) {
      if (_currentMunicipality != null) {
        await _loadZonesDataOptimized(_currentMunicipality!.formattedId);
      }
      return;
    }
    
    try {
      final locations = List<dynamic>.from(_cachedUserLocations!);
      locations.sort((a, b) {
        final dateA = DateTime.tryParse(a['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      
      final lastLocationData = locations.first;
      final lastLocation = UserLocation.fromJson(lastLocationData);
      final zoneId = lastLocation.local.zoneId;
      
      final apiService = ApiService();
      final zoneResponse = await apiService.getZoneById(zoneId);
      
      if (zoneResponse.success && zoneResponse.data != null) {
        final zoneData = zoneResponse.data!;
        final lastLocationMunicipalityId = zoneData['municipalityId']?.toString();
        
        if (_currentMunicipality == null || 
            _currentMunicipality!.formattedId != lastLocationMunicipalityId) {
          
          final targetMunicipality = _availableMunicipalities.firstWhere(
            (m) => m.formattedId == lastLocationMunicipalityId,
            orElse: () => _currentMunicipality!,
          );
          
          if (targetMunicipality.formattedId == lastLocationMunicipalityId) {
            if (mounted) {
              setState(() {
                _currentMunicipality = targetMunicipality;
              });
            }
          }
        }
        
        if (_currentMunicipality != null) {
          _loadZonesDataOptimized(_currentMunicipality!.formattedId);
        }
      }
    } catch (e) {
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

      if (_currentMunicipality != null && _currentMunicipality!.fokotanys.isNotEmpty) {
        for (var fokotany in _currentMunicipality!.fokotanys) {
          _fokotanyCache[fokotany.fokotanyId.toString()] = fokotany.name;
          if (fokotany.formattedId.isNotEmpty) {
            _fokotanyCache[fokotany.formattedId] = fokotany.name;
          }
        }
      }

      final apiService = ApiService();
      final zonesResponse = await apiService.getZones(finalMunicipalityId);
      
      if (zonesResponse.success && zonesResponse.data != null) {
        final responseData = zonesResponse.data;
        if (responseData?['data'] != null) {
          List<dynamic> zones = responseData!['data'];
          
          List<Future<Map<String, dynamic>>> futureZones = zones.map((zone) async {
            final fokotanyIdStr = zone['fokotany_id']?.toString() ?? 
                                 zone['formatted_id']?.toString() ?? 
                                 zone['formatted_Id']?.toString() ?? '';
            final fokotanyId = int.tryParse(fokotanyIdStr);
            String fokotanyName = 'not_available_short'.tr();

            if (fokotanyIdStr.isNotEmpty) {
              if (_fokotanyCache.containsKey(fokotanyIdStr)) {
                fokotanyName = _fokotanyCache[fokotanyIdStr]!;
              } else if (fokotanyId != null && _fokotanyCache.containsKey(fokotanyId.toString())) {
                fokotanyName = _fokotanyCache[fokotanyId.toString()]!;
              } 
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
        if (mounted) {
          setState(() {
            _isZonesLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isZonesLoading = false;
        });
      }
    }
  }

  Future<void> _loadMunicipalities() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingMunicipalities = true;
    });

    try {
      final apiService = ApiService();
      final municipalitiesResponse = await apiService.getMemberMunicipalities();
      
      if (municipalitiesResponse.success && municipalitiesResponse.data != null) {
        final municipalitiesData = municipalitiesResponse.data;
        if (municipalitiesData == null) return;
        
        final municipalitiesList = municipalitiesData
            .map((data) => Municipality.fromJson(data as Map<String, dynamic>))
            .toList();

        final municipalityData = await UserService.getMunicipalityData();
        Municipality? defaultMunicipality;
        Municipality? userOwnMunicipality;
        
        if (municipalityData != null && municipalityData['formatted_id'] != null) {
          final userMunicipalityId = municipalityData['formatted_id'].toString();
          
          try {
            defaultMunicipality = municipalitiesList.firstWhere(
              (m) => m.formattedId == userMunicipalityId,
            );
          } catch (e) {
            userOwnMunicipality = Municipality(
              communeId: int.tryParse(municipalityData['commune_id']?.toString() ?? '0') ?? 0,
              name: municipalityData['name']?.toString() ?? 'my_municipality_default'.tr(),
              isMember: false,
              district: District(
                districtId: int.tryParse(municipalityData['district_id']?.toString() ?? '0') ?? 0,
                name: municipalityData['district_name']?.toString() ?? 'unknown_district'.tr(),
                formattedId: municipalityData['district_formatted_id']?.toString() ?? '',
              ),
              region: Region(
                regionId: int.tryParse(municipalityData['region_id']?.toString() ?? '0') ?? 0,
                name: municipalityData['region_name']?.toString() ?? 'unknown_region'.tr(),
                formattedId: municipalityData['region_formatted_id']?.toString() ?? '',
              ),
              fokotanys: [],
              formattedId: userMunicipalityId,
            );
            
            municipalitiesList.insert(0, userOwnMunicipality);
            defaultMunicipality = userOwnMunicipality;
          }
        }
        
        if (defaultMunicipality == null && municipalitiesList.isNotEmpty) {
          defaultMunicipality = municipalitiesList.first;
        }

        if (mounted) {
          setState(() {
            _availableMunicipalities = municipalitiesList;
            _currentMunicipality = defaultMunicipality;
            _isLoadingMunicipalities = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMunicipalities = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMunicipalities = false;
        });
      }
    }
  }

  void _onMunicipalityChanged(Municipality municipality) {
    if (municipality.communeId == _currentMunicipality?.communeId) return;
    
    setState(() {
      _currentMunicipality = municipality;
      _zonesWithFokotany = [];
      _filteredZonesWithFokotany = [];
    });
    
    _loadZonesDataOptimized(municipality.formattedId);
  }

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
      String fokotanyName = 'not_available_short'.tr();
      
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
                         fokotanyData['designation'] ?? 'not_available_short'.tr();
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
      enrichedZone['fokotany_name'] = 'not_available_short'.tr();
      return enrichedZone;
    }
  }

  /// Cache les données de la dernière location pour un accès rapide
  Future<void> _cacheLastLocationData() async {
    try {
      final data = await _getLastLocationData();
      if (mounted) {
        setState(() {
          _cachedLastLocationData = data;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur cache dernière location: $e');
    }
  }

  /// Récupère les données de la dernière location de manière dynamique
  Future<Map<String, dynamic>?> _getLastLocationData() async {
    if (_cachedUserLocations == null || _cachedUserLocations!.isEmpty) {
      return null;
    }

    try {
      final locations = List<dynamic>.from(_cachedUserLocations!);
      locations.sort((a, b) {
        final dateA = DateTime.tryParse(a['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['dateCreation']?.toString() ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      
      final lastLocationData = locations.first;
      final lastLocation = UserLocation.fromJson(lastLocationData);
      final zoneId = lastLocation.local.zoneId;
      
      final apiService = ApiService();
      final zoneResponse = await apiService.getZoneById(zoneId);
      
      if (zoneResponse.success && zoneResponse.data != null) {
        final zoneData = zoneResponse.data!;
        // Enrichir la zone avec le fokotany et les délimitations
        return await _enrichZoneWithFokotany(zoneData);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur récupération dernière location dynamique: $e');
      return null;
    }
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
      
      String aPayerStr = totalResteAPayer > 0 ? tr('amount_format', namedArgs: {'amount': totalResteAPayer.toString()}) : tr('amount_format', namedArgs: {'amount': '0'});
      String expirantStr = '-';
      if (minDaysToExpire != 99999) {
        expirantStr = minDaysToExpire < 31 ? tr('days_remaining', namedArgs: {'days': minDaysToExpire.toString()}) : tr('months_remaining', namedArgs: {'months': minMonthsToExpire.toString()});
      } else if (maxDaysSinceExpired > 0) {
        expirantStr = maxDaysSinceExpired < 31 ? tr('expired_days_ago', namedArgs: {'days': maxDaysSinceExpired.toString()}) : tr('expired_months_ago', namedArgs: {'months': maxMonthsSinceExpired.toString()});
      }
      
      debugPrint('📊 Stats calculées depuis cache: à payer=$aPayerStr, expirant=$expirantStr');
      return {'aPayer': aPayerStr, 'expirant': expirantStr};
      
    } catch (e) {
      debugPrint('❌ Erreur calcul stats depuis cache: $e');
      return {'aPayer': '-', 'expirant': '-'};
    }
  }

  void _filterZones(String query) {
    setState(() {
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

  void _navigateToNotifications() {
    final mainNav = NewMainNavigation.of(context);
    if (mainNav != null) {
      mainNav.changeTab(2);
    }
  }

  void _showQrCodeModal() {
    showDialog(
      context: context,
      builder: (context) => const QrCodeModal(),
    );
  }

  Future<void> _handleNewReservationFallback() async {
    final lastLocationData = await _getLastLocationData();
    
    if (!mounted) return;
    
    if (lastLocationData != null) {
      final municipalityId = lastLocationData['municipalityId']?.toString();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ZoneLocalsScreen(
            zone: lastLocationData,
            municipalityId: int.tryParse(municipalityId ?? '1') ?? 1,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_last_location_zone_found'.tr()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const HomeSkeleton();
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.02), // Light tint of primary color
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          _buildSearchAndFilterHeader(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildRoleSpecificSection(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
              child: Text(
                'available_zones'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
            ),
          ),
          _buildZonesList(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: Container(
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
        child: FlexibleSpaceBar(
          collapseMode: CollapseMode.pin,
          background: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getGreeting(),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        _userName,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Consumer<RealTimeService>(
                        builder: (context, service, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              GestureDetector(
                                onTap: _navigateToNotifications,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (service.unreadNotificationCount > 0)
                                Positioned(
                                  top: 0,
                                  right: 0,
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
                                      '${service.unreadNotificationCount}',
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
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _showQrCodeModal,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterHeader() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SearchAndFilterHeaderDelegate(
        minHeight: 175,
        maxHeight: 175,
        child: Container(
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    onChanged: _filterZones,
                    decoration: InputDecoration(
                      hintText: 'search_zone_placeholder'.tr(),
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildMunicipalitySelector(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMunicipalitySelector() {
    if (_isLoadingMunicipalities) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'your_municipality'.tr(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<Municipality>(
              value: _currentMunicipality,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
              selectedItemBuilder: (BuildContext context) {
                return _availableMunicipalities.map<Widget>((Municipality item) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList();
              },
              items: _availableMunicipalities.map((Municipality municipality) {
                return DropdownMenuItem<Municipality>(
                  value: municipality,
                  child: Text(
                    municipality.name,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1D1E),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (Municipality? newValue) {
                if (newValue != null) {
                  _onMunicipalityChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return FutureBuilder<Map<String, String>>(
      future: _getStatsData(),
      builder: (context, snapshot) {
        final aPayer = snapshot.data?['aPayer'] ?? '-';
        final expirant = snapshot.data?['expirant'] ?? '-';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withBlue(200).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      color: Theme.of(context).primaryColor.withBlue(200),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'my_statistics'.tr(),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1D1E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final mainNav = NewMainNavigation.of(context);
                        if (mainNav != null) {
                          mainNav.changeTab(3); // Payment history tab
                        }
                      },
                      child: _buildStatCard(
                        icon: Icons.payment_rounded,
                        title: 'to_pay'.tr(),
                        value: aPayer,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final mainNav = NewMainNavigation.of(context);
                        if (mainNav != null) {
                          mainNav.changeTab(1); // Reservation tab
                        }
                      },
                      child: _buildStatCard(
                        icon: Icons.schedule_rounded,
                        title: 'expiring'.tr(),
                        value: expirant,
                        color: Theme.of(context).primaryColor.withBlue(200),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withBlue(200).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  color: Theme.of(context).primaryColor.withBlue(200),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'quick_actions'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'new_reservation'.tr(),
                  color: Theme.of(context).primaryColor,
                  onTap: () {
                    // Utiliser le cache pour une réponse instantanée
                    final lastLocationData = _cachedLastLocationData;
                    
                    if (lastLocationData != null) {
                      final municipalityId = lastLocationData['municipalityId']?.toString();
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ZoneLocalsScreen(
                            zone: lastLocationData,
                            municipalityId: int.tryParse(municipalityId ?? '1') ?? 1,
                          ),
                        ),
                      );
                    } else {
                      // Fallback: charger de manière asynchrone si le cache n'est pas disponible
                      _handleNewReservationFallback();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.calendar_month_rounded,
                  title: 'view_calendar'.tr(),
                  color: Theme.of(context).primaryColor.withBlue(200),
                  onTap: () {
                    // Utiliser le cache pour obtenir les informations du local
                    if (_cachedLastLocationData != null) {
                      final municipalityId = _cachedLastLocationData!['municipalityId']?.toString();
                      final localId = _cachedUserLocations?.isNotEmpty == true
                          ? UserLocation.fromJson(_cachedUserLocations!.first).local.idLocal.toString()
                          : null;
                      final placeName = _cachedLastLocationData!['nom']?.toString() ?? 'unknown_place'.tr();
                      
                      if (municipalityId != null && localId != null) {
                        showDialog(
                          context: context,
                          builder: (context) => PlaceCalendarModal(
                            municipalityId: municipalityId,
                            localId: localId,
                            placeName: placeName,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('no_place_info_available'.tr()),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('no_last_location_zone_found'.tr()),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSpecificSection() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    final userType = _userRole.toLowerCase();

    switch (userType) {
      case 'contribuable mensuel':
        return _buildStatisticsSection();
        
      case 'contribuable journalier':
        return _buildQuickActionsSection();
        
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildZonesList() {
    if (_isZonesLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_filteredZonesWithFokotany.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.location_off_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'no_zones_found_title'.tr(),
                style: GoogleFonts.inter(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final zone = _filteredZonesWithFokotany[index];
          return _buildZoneCard(zone);
        },
        childCount: _filteredZonesWithFokotany.length,
      ),
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ZoneLocalsScreen(
                  zone: zone,
                  municipalityId: int.tryParse(zone['municipalityId'].toString()) ?? 0,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.map_outlined,
                    color: Theme.of(context).primaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone['nom'] ?? 'unnamed_zone_default'.tr(),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1D1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        zone['fokotany_name'] ?? 'unknown_fokotany'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.storefront_outlined, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            tr('places_available_format', namedArgs: {'count': (zone['locaux_disponibles'] ?? 0).toString()}),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'greeting_morning'.tr();
    } else if (hour < 18) {
      return 'greeting_afternoon'.tr();
    } else {
      return 'greeting_evening'.tr();
    }
  }
}

// Delegate for the search and filter persistent header
class _SearchAndFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SearchAndFilterHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SearchAndFilterHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
