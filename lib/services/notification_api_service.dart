import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import 'user_service.dart';

class NotificationApiService {
  static const String baseUrl = 'https://gateway.agvm.mg';
  
  /// Récupère le nombre de notifications non lues
  static Future<ApiResponse<int>> getUnreadNotificationCount() async {
    try {
      final userProfile = await UserService.getUserProfile();
      final userId = userProfile?['user_id'];
      
      if (userId == null) {
        return ApiResponse<int>(
          success: false,
          error: 'User ID non trouvé',
        );
      }

      final token = await UserService.getAccessToken();
      if (token == null) {
        return ApiResponse<int>(
          success: false,
          error: 'Token d\'accès non trouvé',
        );
      }

      final response = await http.get(
        Uri.parse('$baseUrl/servicemodernmarket/notifications/unread/count/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Debug: afficher la structure de la réponse
        debugPrint('🔍 Structure de la réponse API: $data');
        debugPrint('🔍 Type de data: ${data.runtimeType}');
        
        // L'API retourne directement un nombre, pas un objet avec 'count'
        int count;
        if (data is int) {
          count = data;
        } else if (data is Map<String, dynamic>) {
          count = data['count'] ?? data['unread_count'] ?? 0;
        } else {
          count = 0;
        }
        
        return ApiResponse<int>(
          success: true,
          data: count,
        );
      } else {
        return ApiResponse<int>(
          success: false,
          error: 'Erreur HTTP: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse<int>(
        success: false,
        error: 'Erreur lors de la récupération du nombre de notifications: $e',
      );
    }
  }

  /// Récupère toutes les notifications de l'utilisateur
  static Future<ApiResponse<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 6,
  }) async {
    try {
      final userProfile = await UserService.getUserProfile();
      final userId = userProfile?['user_id'];
      
      if (userId == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'User ID non trouvé',
        );
      }

      final token = await UserService.getAccessToken();
      if (token == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'Token d\'accès non trouvé',
        );
      }

      final response = await http.get(
        Uri.parse('$baseUrl/servicemodernmarket/notifications?userId=$userId&page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'Erreur HTTP: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Erreur lors de la récupération des notifications: $e',
      );
    }
  }

  /// Marque une notification comme lue
  static Future<ApiResponse<void>> markNotificationAsRead(String notificationId) async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Token d\'accès non trouvé',
        );
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/servicemodernmarket/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return ApiResponse<void>(
          success: true,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: 'Erreur HTTP: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        error: 'Erreur lors du marquage de la notification: $e',
      );
    }
  }

  /// Marque toutes les notifications comme lues
  static Future<ApiResponse<void>> markAllNotificationsAsRead() async {
    try {
      final userProfile = await UserService.getUserProfile();
      final userId = userProfile?['user_id'];
      
      if (userId == null) {
        return ApiResponse<void>(
          success: false,
          error: 'User ID non trouvé',
        );
      }

      final token = await UserService.getAccessToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Token d\'accès non trouvé',
        );
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/servicemodernmarket/notifications/$userId/read-all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return ApiResponse<void>(
          success: true,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: 'Erreur HTTP: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        error: 'Erreur lors du marquage de toutes les notifications: $e',
      );
    }
  }
}
