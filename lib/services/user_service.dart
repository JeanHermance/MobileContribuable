import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _userProfileKey = 'user_profile';
  static const String _citizenDataKey = 'citizen_data';
  static const String _userRolesKey = 'user_roles';
  static const String _municipalityDataKey = 'municipality_data';

  // Get access token from SharedPreferences
  static Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      debugPrint('Error getting access token: $e');
      return null;
    }
  }

  // Get user profile data
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileString = prefs.getString(_userProfileKey);
      if (profileString != null) {
        try {
          // First try to parse as JSON directly
          final profileData = json.decode(profileString);
          
          // Ensure we have a Map and extract user_id correctly
          if (profileData is Map) {
            final Map<String, dynamic> result = {};
            
            // Copy all existing fields
            profileData.forEach((key, value) {
              result[key.toString()] = value;
            });
            
            // Ensure user_id is set correctly
            if (profileData['user_id'] == null && profileData['id'] != null) {
              result['user_id'] = profileData['id'].toString();
            } else if (profileData['user_id'] != null) {
              result['user_id'] = profileData['user_id'].toString();
            }
            return result;
          }
          
          return null;
        } catch (e) {
          debugPrint('Error parsing user profile JSON: $e');
          
          // Fallback to string parsing if JSON parsing fails
          try {
            final userPseudo = _extractValue(profileString, 'user_pseudo');
            final userEmail = _extractValue(profileString, 'user_email');
            final nationalCardNumber = _extractValue(profileString, 'citizen_national_card_number');
            final userId = _extractValue(profileString, 'user_id') ?? _extractValue(profileString, 'id');
            
            return {
              if (userId != null) 'user_id': userId,
              if (userPseudo != null) 'user_pseudo': userPseudo,
              if (userEmail != null) 'user_email': userEmail,
              if (nationalCardNumber != null) 'citizen_national_card_number': 
                int.tryParse(nationalCardNumber) ?? nationalCardNumber,
            };
          } catch (e) {
            debugPrint('Error extracting user profile data: $e');
            return null;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Save user profile
  static Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = json.encode(profile);
      await prefs.setString(_userProfileKey, profileJson);
    } catch (e) {
      debugPrint('Error saving user profile: $e');
    }
  }

  // Get citizen data
  static Future<Map<String, dynamic>?> getCitizenData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Debug: Print all keys in SharedPreferences
      debugPrint('🔍 All SharedPreferences keys: ${prefs.getKeys()}');
      
      final citizenString = prefs.getString(_citizenDataKey);
      debugPrint('🔍 citizenString from key "$_citizenDataKey": $citizenString');
      
      if (citizenString != null) {
        try {
          final decoded = json.decode(citizenString);
          debugPrint('✅ Citizen data decoded successfully: $decoded');
          return decoded;
        } catch (e) {
          debugPrint('⚠️ JSON parsing failed, trying manual extraction: $e');
          // If JSON parsing fails, try to extract key information manually
          final citizenPhoto = _extractValue(citizenString, 'citizen_photo');
          final citizenName = _extractValue(citizenString, 'citizen_name');
          final citizenLastname = _extractValue(citizenString, 'citizen_lastname');
          return {
            'citizen_photo': citizenPhoto,
            'citizen_name': citizenName,
            'citizen_lastname': citizenLastname,
          };
        }
      }
      
      debugPrint('❌ citizenString is NULL - no data found in SharedPreferences!');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting citizen data: $e');
      return null;
    }
  }

  // Helper method to extract values from string representation
  static String? _extractValue(String data, String key) {
    final pattern = RegExp('$key: ([^,}]+)');
    final match = pattern.firstMatch(data);
    return match?.group(1)?.trim();
  }

  // Get user display name
  static Future<String> getUserDisplayName() async {
    final profile = await getUserProfile();
    return profile?['user_pseudo'] ?? 'Utilisateur';
  }

  // Get profile photo URL
  static Future<String?> getProfilePhotoUrl() async {
    final citizen = await getCitizenData();
    debugPrint("citizen data: $citizen");

    return citizen?['citizen_photo'];
  }

  // Save user roles
  static Future<void> saveUserRoles(List<Map<String, dynamic>> roles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rolesJson = json.encode(roles);
      await prefs.setString(_userRolesKey, rolesJson);
    } catch (e) {
      debugPrint('Error saving user roles: $e');
    }
  }

  // Get user roles
  static Future<List<Map<String, dynamic>>> getUserRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rolesString = prefs.getString(_userRolesKey);
      if (rolesString != null) {
        final List<dynamic> rolesList = json.decode(rolesString);
        return rolesList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting user roles: $e');
      return [];
    }
  }

  // Get primary user role (first role or default)
  static Future<String> getUserRole() async {
    final roles = await getUserRoles();
    if (roles.isNotEmpty) {
      return roles.first['role_name'] ?? 'Citoyen';
    }
    return 'Citoyen';
  }

  // Save municipality data
  static Future<void> saveMunicipalityData(Map<String, dynamic> municipalityData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final municipalityJson = json.encode(municipalityData);
      await prefs.setString(_municipalityDataKey, municipalityJson);
    } catch (e) {
      debugPrint('Error saving municipality data: $e');
    }
  }

  // Get municipality data
  static Future<Map<String, dynamic>?> getMunicipalityData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final municipalityString = prefs.getString(_municipalityDataKey);
      if (municipalityString != null) {
        return json.decode(municipalityString);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting municipality data: $e');
      return null;
    }
  }

  // Get municipality name
  static Future<String> getMunicipalityName() async {
    final municipalityData = await getMunicipalityData();
    return municipalityData?['name'] ?? 'Commune';
  }

  // Get municipality logo
  static Future<String> getMunicipalityLogo() async {
    final municipalityData = await getMunicipalityData();
    final logo = municipalityData?['logo_commune'];
    if (logo != null && logo.isNotEmpty) {
      return logo;
    }
    return 'assets/images/logo/FIANARANTSOA.png';
  }

  // Clear user data (for logout)
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userProfileKey);
    await prefs.remove(_citizenDataKey);
    await prefs.remove(_userRolesKey);
    await prefs.remove(_municipalityDataKey);
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}
