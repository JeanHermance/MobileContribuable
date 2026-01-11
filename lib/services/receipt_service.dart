import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/user_service.dart';

class ReceiptService {
  static const String _baseUrl = 'https://gateway.agvm.mg';
  
  /// Endpoint: GET /servicepaiement/transactions/{reference}/{municipality_id}/receipt

  /// Récupère l'URL du justificatif PDF pour un paiement
  static Future<String> getReceiptPdfUrl(String reference, String municipalityId) async {
    try {
      debugPrint('📄 Récupération du justificatif pour référence: $reference, municipalityId: $municipalityId');
      
      // Récupérer le token d'authentification
      final token = await UserService.getAccessToken();
      if (token == null) {
        throw Exception('Token d\'authentification non disponible');
      }

      final url = Uri.parse('$_baseUrl/servicepaiement/transactions/$reference/$municipalityId/receipt');
      debugPrint('🔗 URL: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📊 Status code: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 200 && responseData['pdfUrl'] != null) {
          final pdfUrl = responseData['pdfUrl'] as String;
          debugPrint('✅ URL du justificatif récupérée: $pdfUrl');
          return pdfUrl;
        } else {
          throw Exception('Réponse API invalide: ${responseData['message'] ?? 'Erreur inconnue'}');
        }
      } else {
        throw Exception('Erreur lors de la récupération du justificatif: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération du justificatif: $e');
      rethrow;
    }
  }

  /// Vérifie si un justificatif est disponible pour un paiement
  static Future<bool> isReceiptAvailable(String reference, String municipalityId) async {
    try {
      await getReceiptPdfUrl(reference, municipalityId);
      return true;
    } catch (e) {
      debugPrint('⚠️ Justificatif non disponible pour la référence $reference: $e');
      return false;
    }
  }

  /// Récupère les informations du justificatif sans télécharger le PDF
  static Future<Map<String, dynamic>?> getReceiptInfo(String reference, String municipalityId) async {
    try {
      debugPrint('ℹ️ Récupération des infos du justificatif pour: $reference');
      
      final token = await UserService.getAccessToken();
      if (token == null) {
        throw Exception('Token d\'authentification non disponible');
      }

      final url = Uri.parse('$_baseUrl/servicepaiement/transactions/$reference/$municipalityId/receipt');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 200) {
          return {
            'message': responseData['message'],
            'pdfUrl': responseData['pdfUrl'],
            'status': responseData['status'],
          };
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des infos du justificatif: $e');
      return null;
    }
  }
}
