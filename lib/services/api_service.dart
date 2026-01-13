import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart';

class ApiService {
  // Base URLs
  static const String baseUrl = 'https://gateway.agvm.mg';
  static const String baseUrl1 = 'http://localhost:5000';
  
  // Auth Endpoints
  static const String loginEndpoint = '/serviceauth/auth/login';
  static const String profileEndpoint = '/serviceauth/auth/profile';
  static const String logoutEndpoint = '/serviceauth/auth/logout';
  static const String verifyTokenEndpoint = '/serviceauth/auth/verify-token';
  static const String forgotPasswordEndpoint = '/serviceauth/forgot-password';
  
  // User Management Endpoints
  static const String userEndpoint = '/serviceauth/users';
  static const String userRolesEndpoint = '/serviceauth/users';
  static const String rolesEndpoint = '/serviceauth/roles';
  
  // Citizen Endpoints
  static const String citizenEndpoint = '/servicecitoyen/citizens';
  
  // Territory Endpoints
  static const String municipalityEndpoint = '/serviceterritoire-v2/communes';
  static const String fokotanyEndpoint = '/serviceterritoire-v2/fokotanys';
  
  // Market Endpoints
  static const String zonesEndpoint = '/serviceModernMarket/zones';
  static const String localsEndpoint = '/serviceModernMarket/local';
  static const String localTypesEndpoint = '/serviceModernMarket/type-locals';
  static const String locationsEndpoint = '/serviceModernMarket/locations';

  final Dio _dio = Dio();
  final Dio _dioLocal = Dio();
  final CacheService _cacheService = CacheService();
  String? _accessToken;
  bool _useLocalForModernMarket = false; // Par défaut, utiliser le serveur local pour serviceModernMarket

  ApiService() {
    // Configuration pour le serveur principal
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 45); // Augmenté à 45s
    _dio.options.receiveTimeout = const Duration(seconds: 60); // Augmenté à 60s pour les gros volumes de données
    _dio.options.headers = {
      'Accept': 'application/json',
    };
    // Configuration pour le serveur local
    _dioLocal.options.baseUrl = baseUrl1;
    _dioLocal.options.connectTimeout = const Duration(seconds: 30);
    _dioLocal.options.receiveTimeout = const Duration(seconds: 30);
    _dioLocal.options.headers = {
      'Accept': 'application/json',
    };

    _loadToken();
  }

  // Load token from SharedPreferences
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    if (_accessToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    }
  }

  // Save token to SharedPreferences
 // Save token to SharedPreferences
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setInt('token_timestamp', DateTime.now().millisecondsSinceEpoch);
    _accessToken = token;
    
    // 🔥 AJOUT CRUCIAL : Mettre à jour le header IMMÉDIATEMENT
    // Sans cela, les appels API juste après le deeplink échoueront en 401
    _dio.options.headers['Authorization'] = 'Bearer $token';
    _dioLocal.options.headers['Authorization'] = 'Bearer $token';
    
    debugPrint("🔑 [ApiService] Header Authorization mis à jour avec le nouveau token.");
  }
  // Remove token from SharedPreferences
  Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('token_timestamp');
    await prefs.remove('remember_session');
    _accessToken = null;
    _dio.options.headers.remove('Authorization');
  }

  // Check if token is still valid (not expired)
  Future<bool> isTokenValid() async {
    if (_accessToken == null) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('token_timestamp');
    final rememberSession = prefs.getBool('remember_session') ?? false;
    
    if (timestamp == null) return false;
    
    // Token expires after 24 hours if remember session is false, 30 days if true
    final expirationDuration = rememberSession 
        ? const Duration(days: 30) 
        : const Duration(hours: 24);
    
    final tokenDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final isExpired = DateTime.now().difference(tokenDate) > expirationDuration;
    
    return !isExpired;
  }

  // Save session preference
  Future<void> saveSessionPreference(bool rememberSession) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_session', rememberSession);
  }

  // --- REGISTER CITIZEN ---
  Future<ApiResponse<Map<String, dynamic>>> registerCitizen({
    required String citizenName,
    required String citizenLastname,
    required String citizenDateOfBirth,
    required String citizenLocationOfBirth,
    required int citizenNationalCardNumber,
    required String citizenAddress,
    required String citizenCity,
    required String citizenWork,
    required int fokotanyId,
    required String citizenFather,
    required String citizenMother,
    required String citizenNationalCardLocation,
    required String citizenNationalCardDate,
    String? citizenPhoto,
  }) async {
    try {
      // Préparer FormData pour l'upload multipart
      final formData = FormData.fromMap({
        'citizen_name': citizenName,
        'citizen_lastname': citizenLastname,
        'citizen_date_of_birth': citizenDateOfBirth,
        'citizen_location_of_birth': citizenLocationOfBirth,
        'citizen_national_card_number': citizenNationalCardNumber,
        'citizen_adress': citizenAddress,
        'citizen_city': citizenCity,
        'citizen_work': citizenWork,
        'fokotany_id': fokotanyId,
        'citizen_father': citizenFather,
        'citizen_mother': citizenMother,
        'citizen_national_card_location': citizenNationalCardLocation,
        'citizen_national_card_date': citizenNationalCardDate,
        if (citizenPhoto != null)
          'citizen_photo': await MultipartFile.fromFile(
            citizenPhoto,
            filename: 'citizen_photo.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
      });

      final response = await _dio.post(citizenEndpoint, data: formData);

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- REGISTER USER ---
  Future<ApiResponse<Map<String, dynamic>>> registerUser({
    required String userPseudo,
    required String userEmail,
    required String userPassword,
    required String userPhone,
    required String municipalityId,
    required String idCitizen,
  }) async {
    try {
      final data = {
        'user_pseudo': userPseudo,
        'user_email': userEmail,
        'user_password': userPassword,
        'user_phone': userPhone,
        'municipality_id': municipalityId,
        'id_citizen': idCitizen,
      };

      final response = await _dio.post(userEndpoint, data: data);

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- LOGIN ---
  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    try {
      final data = {'user_email': email, 'user_password': password};
      final response = await _dio.post(loginEndpoint, data: data);
      
      // Save tokens if login successful
      if (response.data != null && response.data['access_token'] != null) {
        await saveToken(response.data['access_token']);
        
        // Save refresh token
        if (response.data['refresh_token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('refresh_token', response.data['refresh_token']);
        }
      }
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET PROFILE ---
  Future<ApiResponse<Map<String, dynamic>>> getProfile() async {
    try {
      final response = await _dio.get(profileEndpoint);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET USER LOCATIONS ---
  Future<ApiResponse<List<dynamic>>> getUserLocations(String userId) async {
    try {
      final response = await _dio.get('$locationsEndpoint/userLocations/$userId');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET USER LOCATIONS EN COURS ---
  Future<ApiResponse<List<dynamic>>> getUserLocationsEnCours(String userId) async {
    try {
      final response = await _dio.get('$locationsEndpoint/userLocations/$userId/en_cours');
      debugPrint('🔍 API getUserLocationsEnCours - Response: ${response.data}');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      debugPrint('❌ API getUserLocationsEnCours - Error: ${_handleDioError(e)}');
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      debugPrint('❌ API getUserLocationsEnCours - Unexpected error: $e');
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET LOCAL OCCUPIED DATES ---
  Future<ApiResponse<List<Map<String, dynamic>>>> getLocalOccupiedDates(String municipalityId, String localId) async {
    try {
      final response = await _dio.get('/servicemodernmarket/local/municipality/$municipalityId/$localId/occupied-dates');
      debugPrint('🗓️ API getLocalOccupiedDates - Response: ${response.data}');
      
      if (response.data is List) {
        final occupiedDates = (response.data as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        return ApiResponse.success(occupiedDates);
      } else {
        return ApiResponse.success([]);
      }
    } on DioException catch (e) {
      debugPrint('❌ API getLocalOccupiedDates - Error: ${_handleDioError(e)}');
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      debugPrint('❌ API getLocalOccupiedDates - Unexpected error: $e');
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET PAYMENT RECEIPT PDF ---
  Future<ApiResponse<Map<String, dynamic>>> getPaymentReceipt(String reference, String municipalityId) async {
    try {
      final response = await _dio.get('/servicepaiement/transactions/$reference/$municipalityId/receipt');
      debugPrint('🧾 API getPaymentReceipt - Response: ${response.data}');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      debugPrint('❌ API getPaymentReceipt - Error: ${_handleDioError(e)}');
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      debugPrint('❌ API getPaymentReceipt - Unexpected error: $e');
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET LOCATION RESTE A PAYER ---
  Future<ApiResponse<Map<String, dynamic>>> getLocationResteAPayer(String locationId) async {
    try {
      final response = await _dio.get('$locationsEndpoint/$locationId/reste-a-payer');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET CITIZEN DATA ---
  Future<ApiResponse<Map<String, dynamic>>> getCitizenData(int nationalCardNumber) async {
    try {
      final response = await _dio.get('$citizenEndpoint/$nationalCardNumber');
      debugPrint('👤 API getCitizenData - Response: ${response.data}');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET CITIZEN DATA BY ID (UUID) ---
  Future<ApiResponse<Map<String, dynamic>>> getCitizenById(String citizenId) async {
    try {
      final response = await _dio.get('$citizenEndpoint/getCitizenById/$citizenId');
      debugPrint('👤 API getCitizenById - Response: ${response.data}');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      debugPrint('❌ API getCitizenById - Error: ${_handleDioError(e)}');
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      debugPrint('❌ API getCitizenById - Unexpected error: $e');
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- LOGOUT ---
  Future<ApiResponse<Map<String, dynamic>>> logout() async {
    try {
      final response = await _dio.post(logoutEndpoint);
      await _removeToken();
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      await _removeToken(); // Remove token even if logout fails
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      await _removeToken();
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- VERIFY TOKEN ---
  Future<ApiResponse<Map<String, dynamic>>> verifyToken() async {
    try {
      final response = await _dio.get(verifyTokenEndpoint);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- UPDATE PROFILE ---
  Future<ApiResponse<Map<String, dynamic>>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(profileEndpoint, data: data);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- FORGOT PASSWORD ---
  Future<ApiResponse<Map<String, dynamic>>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await _dio.post(forgotPasswordEndpoint, data: {'email': email});
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET ROLES FOR APPLICATION ---
  Future<ApiResponse<Map<String, dynamic>>> getRoles({int applicationId = 13633}) async {
    try {
      final response = await _dio.get('$rolesEndpoint/application/$applicationId');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- ASSIGN ROLE TO USER ---
  Future<ApiResponse<Map<String, dynamic>>> assignRoleToUser({
    required String userId,
    required List<int> roleIds,
  }) async {
    try {
      final data = {'role_ids': roleIds};
      final response = await _dio.post('$userRolesEndpoint/$userId/roles', data: data);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET USER ROLES ---
  Future<ApiResponse<Map<String, dynamic>>> getUserRoles(String userId) async {
    try {
      final response = await _dio.get('$userRolesEndpoint/$userId/roles');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET MUNICIPALITY/COMMUNE DATA ---
  Future<ApiResponse<Map<String, dynamic>>> getMunicipality(String municipalityId) async {
    try {
      final response = await _dio.get('$municipalityEndpoint/noForm/$municipalityId');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET MEMBER MUNICIPALITIES ---
  Future<ApiResponse<List<dynamic>>> getMemberMunicipalities() async {
    final cacheKey = 'member_municipalities';
    
    try {
      // Try to get from cache first
      final cachedData = await _cacheService.getCache<List<dynamic>>(
        cacheKey,
        duration: const Duration(hours: 2),
      );
      
      if (cachedData != null) {
        debugPrint('Cache hit for member municipalities');
        return ApiResponse.success(cachedData);
      }
      
      // If not in cache, fetch from API
      final response = await _dio.get('$municipalityEndpoint/members');
      
      // Cache the response
      await _cacheService.setCache(
        cacheKey,
        response.data,
        duration: const Duration(hours: 2),
      );
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET ZONES FOR MUNICIPALITY ---
  Future<ApiResponse<Map<String, dynamic>>> getZones(
    String municipalityId, {
    int page = 1,
    int limit = 6,
  }) async {
    final cacheKey = 'zones_${municipalityId}_${page}_$limit';
    
    try {
      // Try to get from cache first
      final cachedData = await _cacheService.getCache<Map<String, dynamic>>(
        cacheKey,
        duration: const Duration(minutes: 15),
      );
      
      if (cachedData != null) {
        debugPrint('Cache hit for zones: $municipalityId (page $page)');
        return ApiResponse.success(cachedData);
      }
      
      // If not in cache, fetch from API
      final client = _getClientForUrl(zonesEndpoint);
      final response = await client.get('$zonesEndpoint/$municipalityId?page=$page&limit=$limit');
      
      // Cache the response
      await _cacheService.setCache(
        cacheKey,
        response.data,
        duration: const Duration(minutes: 15),
      );
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // Helper method to get full image URL
  String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    
    // If it's already a full URL, return as is
    if (path.startsWith('http')) return path;
    
    // If it's a local path, prepend the base URL
    if (path.startsWith('commune/')) {
      return '$baseUrl/$path';
    }
    
    return path;
  }

  // --- GET ZONE BY ID WITH MUNICIPALITY ---
  Future<ApiResponse<Map<String, dynamic>>> getZoneById(String zoneId) async {
    final cacheKey = 'zone_$zoneId';
    
    try {
      // Try to get from cache first (15 minutes cache)
      final cachedData = await _cacheService.getCache<Map<String, dynamic>>(
        cacheKey,
        duration: const Duration(minutes: 15),
      );
      
      if (cachedData != null) {
        debugPrint('Cache hit for zone: $zoneId');
        return ApiResponse.success(cachedData);
      }
      
      // If not in cache, fetch from API
      final client = _getClientForUrl(zonesEndpoint);
      final response = await client.get('/serviceModernMarket/zones/edit/$zoneId');
      
      debugPrint('Zone API Response: ${response.data}');
      
      // Cache the response
      await _cacheService.setCache(cacheKey, response.data);
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      debugPrint('Error fetching zone $zoneId: ${e.message}');
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      debugPrint('Unexpected error fetching zone $zoneId: $e');
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET LOCALS BY ZONE ---
  Future<ApiResponse<Map<String, dynamic>>> getLocalsByZone({
    required String municipalityId,
    required String zoneId,
    String? typeLocalId,
    String lang = 'fr',
    int page = 1,
    int limit = 6,
  }) async {
    final cacheKey = 'locals_${municipalityId}_${zoneId}_${typeLocalId ?? 'all'}_${lang}_${page}_$limit';
    
    try {
      // Try to get from cache first
      final cachedData = await _cacheService.getCache<Map<String, dynamic>>(
        cacheKey,
        duration: const Duration(minutes: 5),
      );
      
      if (cachedData != null) {
        debugPrint('Cache hit for locals: $zoneId');
        return ApiResponse.success(cachedData);
      }
      
      // If not in cache, fetch from API
      final client = _getClientForUrl(localsEndpoint);
      final response = await client.get(
        '$localsEndpoint/getAll/municipality/$municipalityId',
        queryParameters: {
          'page': page,
          'limit': limit,
          'zoneId': zoneId,
          'lang': lang,
          if (typeLocalId != null) 'typelocalId': typeLocalId,
          'statut': 'DISPONIBLE',
        },
      );
      
      // Cache the response
      await _cacheService.setCache(
        cacheKey,
        response.data,
        duration: const Duration(minutes: 5),
      );
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET LAST LOCATION FOR LOCAL ---
  Future<ApiResponse<Map<String, dynamic>>> getLastLocationForLocal({
    required String municipalityId,
    required String localId,
  }) async {
    final cacheKey = 'last_location_${municipalityId}_$localId';

    try {
      final cachedData = await _cacheService.getCache<Map<String, dynamic>>(
        cacheKey,
        duration: const Duration(minutes: 5),
      );

      if (cachedData != null) {
        debugPrint('Cache hit for last location: $localId');
        return ApiResponse.success(cachedData);
      }

      final client = _getClientForUrl(localsEndpoint);
      final response = await client.get(
        '$localsEndpoint/municipality/$municipalityId/local/$localId/last-location',
      );

      await _cacheService.setCache(
        cacheKey,
        response.data,
        duration: const Duration(minutes: 5),
      );

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET RENTED LOCALS BY MUNICIPALITY ---
  Future<ApiResponse<Map<String, dynamic>>> getRentedLocalsByMunicipality({
    required String municipalityId,
    String lang = 'fr',
    int page = 1,
    int limit = 6,
  }) async {
    final cacheKey = 'rented_locals_${municipalityId}_${lang}_${page}_$limit';

    try {
      final cachedData = await _cacheService.getCache<Map<String, dynamic>>(
        cacheKey,
        duration: const Duration(minutes: 5),
      );

      if (cachedData != null) {
        debugPrint('Cache hit for rented locals: $municipalityId');
        return ApiResponse.success(cachedData);
      }

      final client = _getClientForUrl(localsEndpoint);
      final response = await client.get(
        '$localsEndpoint/getAll/municipality/$municipalityId',
        queryParameters: {
          'page': page,
          'limit': limit,
          'lang': lang,
          'statut': 'LOUE',
        },
      );

      await _cacheService.setCache(
        cacheKey,
        response.data,
        duration: const Duration(minutes: 5),
      );

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- CHECK LOCAL AVAILABILITY ---
  Future<ApiResponse<Map<String, dynamic>>> checkLocalAvailability({
    required String localId,
  }) async {
    try {
      final response = await _dio.get('$localsEndpoint/$localId');
      
      if (response.statusCode == 200) {
        final data = response.data;
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error('Erreur ${response.statusCode}: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      debugPrint('Erreur lors de la vérification de disponibilité du local: $e');
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      debugPrint('Erreur lors de la vérification de disponibilité du local: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // --- GET LOCAL TYPES ---
  Future<ApiResponse<Map<String, dynamic>>> getLocalTypes({
    required String municipalityId,
    String lang = 'fr',
    int page = 1,
    int limit = 6,
  }) async {
    final cacheKey = 'local_types_${municipalityId}_${lang}_${page}_$limit';
    
    try {
      // Try to get from cache first
      final cachedData = await _cacheService.getCache<Map<String, dynamic>>(
        cacheKey,
        duration: const Duration(hours: 2),
      );
      
      if (cachedData != null) {
        debugPrint('Cache hit for local types: $municipalityId');
        return ApiResponse.success(cachedData);
      }
      
      // If not in cache, fetch from API
      final client = _getClientForUrl(localTypesEndpoint);
      final response = await client.get(
        '$localTypesEndpoint/municipalityId/$municipalityId',
        queryParameters: {
          'lang': lang,
          'page': page,
          'limit': limit,
        },
      );
      
      // Cache the response
      await _cacheService.setCache(
        cacheKey,
        response.data,
        duration: const Duration(hours: 2),
      );
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET FOKOTANY DATA ---
  Future<ApiResponse<Map<String, dynamic>>> getFokotany(int fokotanyId) async {
    final cacheKey = 'fokotany_$fokotanyId';
    
    try {
      // Try to get from cache first
      final cachedData = await _cacheService.getCache<Map<String, dynamic>>(
        cacheKey,
        duration: const Duration(hours: 1),
      );
      
      if (cachedData != null) {
        debugPrint('Cache hit for fokotany: $fokotanyId');
        return ApiResponse.success(cachedData);
      }
      
      // If not in cache, fetch from API
      final response = await _dio.get('$fokotanyEndpoint/$fokotanyId');
      
      // Cache the response
      await _cacheService.setCache(
        cacheKey,
        response.data,
        duration: const Duration(hours: 1),
      );
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      debugPrint('Error fetching fokotany $fokotanyId: $e');
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET USER CURRENT LOCATIONS COUNT ---
  Future<ApiResponse<int>> getCurrentLocationsCount(String userId) async {
    try {
      final client = _getClientForUrl(locationsEndpoint);
      final response = await client.get('$locationsEndpoint/count-current/locations/user/$userId');
      
      // The API returns a number directly
      final count = response.data is int ? response.data : int.tryParse(response.data.toString()) ?? 0;
      return ApiResponse.success(count);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET USER NIF ---
  Future<ApiResponse<String?>> getUserNif(String userId) async {
    try {
      final client = _getClientForUrl(locationsEndpoint);
      final response = await client.get('$locationsEndpoint/nif-user/$userId');
      
      // If user has NIF, API returns the NIF number
      // If user doesn't have NIF, API returns 404 with error message
      if (response.data is String || response.data is num) {
        return ApiResponse.success(response.data.toString());
      }
      return ApiResponse.success(null);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // User doesn't have NIF yet
        return ApiResponse.success(null);
      }
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
    }
  }

  // --- GET USER QR CODE ---
  Future<ApiResponse<String>> getUserQrCode(String userId) async {
  try {
    final client = _getClientForUrl(locationsEndpoint);
    final url = '$locationsEndpoint/$userId/qrcode';
    final fullUrl = '${client.options.baseUrl}$url';
    
    debugPrint('🔍 [QR Code] Request URL: $fullUrl');
    debugPrint('🔍 [QR Code] User ID: $userId');
    debugPrint('🔍 [QR Code] Headers: ${client.options.headers}');
    
    final response = await client.get(url);
    
    debugPrint('✅ [QR Code] Response Status: ${response.statusCode}');
    debugPrint('✅ [QR Code] Response Data Type: ${response.data.runtimeType}');
    
    // The API returns an object with userId and qrCode (base64 image)
    if (response.data is Map) {
      final qrCodeData = response.data['qrCode'] ?? response.data['qrcode'];
      if (qrCodeData != null) {
        debugPrint('✅ [QR Code] QR Code data received (${qrCodeData.toString().length} chars)');
        return ApiResponse.success(qrCodeData.toString());
      }
    } else if (response.data is String) {
      debugPrint('✅ [QR Code] QR Code string received (${response.data.length} chars)');
      return ApiResponse.success(response.data);
    }
    
    debugPrint('❌ [QR Code] Invalid response format');
    return ApiResponse.error('Format de réponse QR code invalide');
  } on DioException catch (e) {
    debugPrint('❌ [QR Code] DioException: ${e.type}');
    debugPrint('❌ [QR Code] Status Code: ${e.response?.statusCode}');
    debugPrint('❌ [QR Code] Response Data: ${e.response?.data}');
    debugPrint('❌ [QR Code] Error Message: ${e.message}');
    return ApiResponse.error(_handleDioError(e));
  } catch (e) {
    debugPrint('❌ [QR Code] Unexpected error: $e');
    return ApiResponse.error('Une erreur inattendue s\'est produite: $e');
  }
}

  /// Bascule entre le serveur local et distant pour les requêtes serviceModernMarket
  void toggleModernMarketServer({bool? useLocal}) {
    _useLocalForModernMarket = useLocal ?? !_useLocalForModernMarket;
    debugPrint('Service ModernMarket: ${_useLocalForModernMarket ? 'Utilisation du serveur LOCAL' : 'Utilisation du serveur DISTANT'}');
  }

  // --- CACHE MANAGEMENT METHODS ---
  
  /// Clear all cached data
  Future<void> clearAllCache() async {
    await _cacheService.clearAllCache();
  }

  /// Clear specific cache by key
  Future<void> clearCache(String key) async {
    await _cacheService.clearCache(key);
  }

  /// Clear zones cache for a specific municipality
  Future<void> clearZonesCache(String municipalityId) async {
    await _cacheService.clearCache('zones_$municipalityId');
  }

  /// Clear locals cache for a specific zone
  Future<void> clearLocalsCache(String municipalityId, String zoneId) async {
    final keys = [
      'locals_${municipalityId}_${zoneId}_all_1_10000',
      'locals_${municipalityId}_${zoneId}_null_1_10000',
    ];
    for (final key in keys) {
      await _cacheService.clearCache(key);
    }
  }

  /// Clear rented locals cache for a specific municipality
  Future<void> clearRentedLocalsCache(String municipalityId) async {
    await _cacheService.clearCache('rented_locals_$municipalityId');
  }

  /// Get cache information
  Future<Map<String, int>> getCacheInfo() async {
    return await _cacheService.getCacheInfo();
  }

  // Méthode utilitaire pour obtenir le client approprié en fonction de l'URL
  Dio _getClientForUrl(String url) {
    if (url.contains('/serviceModernMarket/')) {
      return _useLocalForModernMarket ? _dioLocal : _dio;
    }
    return _dio;
  }

  // --- HANDLE DIO ERRORS ---
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Délai de connexion dépassé. Vérifiez votre connexion internet.';
      case DioExceptionType.sendTimeout:
        return 'Délai d\'envoi dépassé. Veuillez réessayer.';
      case DioExceptionType.receiveTimeout:
        return 'Délai de réception dépassé. Veuillez réessayer.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] ?? 'Erreur du serveur';
        
        if (statusCode == 404) {
          // Resource not found
          return 'Ressource non trouvée (404). L\'endpoint n\'existe pas ou l\'ID est invalide.';
        } else if (statusCode == 400) {
          // Erreur de validation ou autre erreur "Bad Request"
          return message;
        } else if (statusCode == 502) {
          // Bad Gateway - serveur temporairement indisponible
          return 'Service temporairement indisponible. Veuillez réessayer dans quelques instants.';
        } else if (statusCode == 503) {
          // Service Unavailable
          return 'Service en maintenance. Veuillez réessayer plus tard.';
        } else if (statusCode == 504) {
          // Gateway Timeout
          return 'Délai d\'attente du serveur dépassé. Veuillez réessayer.';
        }
        return 'Erreur du serveur ($statusCode). Veuillez réessayer plus tard.';
      case DioExceptionType.cancel:
        return 'Requête annulée';
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return 'Pas de connexion internet. Vérifiez votre connexion.';
        }
        return 'Erreur de connexion: ${e.message}';
      default:
        return 'Une erreur inattendue s\'est produite';
    }
  }
}

// --- GENERIC API RESPONSE ---
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse.success(this.data)
      : success = true,
        error = null;

  ApiResponse.error(this.error)
      : success = false,
        data = null;
}
