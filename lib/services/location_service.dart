import 'dart:convert' as convert;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'real_time_service.dart';

// Alias pour la journalisation
void _log(String message) => debugPrint(message);

class LocationService {
  final String _baseUrl = 'https://gateway.agvm.mg/serviceModernMarket';
  final RealTimeService _realTimeService = RealTimeService();

  // Créer une nouvelle location après paiement
  Future<Map<String, dynamic>> createLocation({
    required String userId,
    required String nif,
    required String localId,
    required String usage,
    required String periodicite,
    required String dateDebutLoc,
    int? frequence, // Nombre de jours/mois selon le type de contrat
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/locations');
      
      _log('=== CRÉATION D\'UNE NOUVELLE LOCATION ===');
      _log('URL: $url');
      
      final requestBody = {
        'id_user': userId,
        'nif': nif,
        'localId': localId,
        'usage': usage,
        'periodicite': periodicite.toUpperCase(), // S'assurer que c'est en majuscules
        'date_debut_loc': dateDebutLoc,
      };
      
      // Ajouter la fréquence si fournie
      if (frequence != null) {
        requestBody['frequence'] = frequence.toString();
      }
      
      _log('Corps de la requête: $requestBody');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: convert.jsonEncode(requestBody),
      );

      _log('Réponse de création de location (${response.statusCode}): ${response.body}');
      
      try {
        final responseBody = convert.jsonDecode(convert.utf8.decode(response.bodyBytes));
        _log('Réponse décodée: $responseBody');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Vérifier si la réponse contient un message d'erreur
          if (responseBody is Map && responseBody.containsKey('success') && responseBody['success'] == false) {
            throw Exception(responseBody['message'] ?? 'Échec de la création de la location');
          }
          
          // Notifier la création d'une nouvelle réservation
          final locationId = responseBody['id'] ?? responseBody['locationId'];
          if (locationId != null) {
            _realTimeService.notifyNewReservation(
              reservationId: locationId.toString(),
              localId: localId,
            );
          }
          
          // Retourner directement la réponse complète car elle contient l'ID de location
          return responseBody;
        } else if (response.statusCode == 400) {
          // Gestion spécifique pour les erreurs 400 (local déjà en location)
          final errorMessage = responseBody['message'] ?? 'Le local est déjà en location';
          throw Exception(errorMessage);
        } else {
          // Essayer d'extraire le message d'erreur de la réponse
          final errorMessage = responseBody['message'] ?? 
                             responseBody['error'] ?? 
                             'Erreur inconnue (${response.statusCode})';
          throw Exception('Échec de la création de la location: $errorMessage');
        }
      } catch (e) {
        // En cas d'erreur de décodage du JSON
        _log('Erreur lors du décodage de la réponse: $e');
        throw Exception('Réponse du serveur invalide: ${response.body}');
      }
    } catch (e) {
      _log('Erreur lors de la création de la location: $e');
      rethrow;
    }
  }

  // Valider une location après paiement
  Future<Map<String, dynamic>> validateLocation({
    required String userId,
    required String localId,
    required String nif,
    required String usage,
    required String periodicite,
    String? dateDebut,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/locations');
      
      _log('=== APPEL API VALIDATION LOCATION ===');
      _log('URL: $url');
      final requestBody = {
        'id_user': userId,
        'nif': nif,
        'localId': localId,
        'usage': usage,
        'periodicite': periodicite,
        'date_debut_loc': dateDebut ?? DateTime.now().toUtc().toIso8601String(),
      };
      _log('Corps de la requête: $requestBody');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: convert.jsonEncode(requestBody),
      );

      _log('Réponse de validation de location (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = convert.jsonDecode(convert.utf8.decode(response.bodyBytes));
        _log('Réponse décodée: $responseBody');
        return responseBody;
      } else {
        final errorMsg = 'Échec de la validation de la location: ${response.statusCode} - ${response.body}';
        _log(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      _log('Erreur lors de la validation de la location: $e');
      rethrow;
    }
  }

  // Enregistrer un paiement
  Future<Map<String, dynamic>> recordPayment({
    required String reference,
    required String status,
    required String raison,
    required List<Map<String, dynamic>> paiementLocations,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/paiement');
      
      // Validation et préparation des données de paiement
      final validatedPaiementLocations = paiementLocations.map((loc) {
        final nombrePaye = loc['nombre_paye'] ?? 1;
        final locationFrequence = loc['location_frequence'] ?? 1;
        
        // S'assurer que nombre_paye ne dépasse pas la fréquence de la location
        final validNombrePaye = nombrePaye > locationFrequence ? locationFrequence : nombrePaye;
        
        return {
          'locationId': loc['locationId'],
          'nombre_paye': validNombrePaye,
          'montant_paye': loc['montant_paye'],
        };
      }).toList();
      
      final requestBody = {
        'reference': reference,
        'status': status,
        'raison': raison,
        'paiement_locations': validatedPaiementLocations,
      };
      
      _log('=== APPEL API ENREGISTREMENT PAIEMENT ===');
      _log('URL: $url');
      _log('Corps de la requête: $requestBody');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: convert.jsonEncode(requestBody),
      );

      _log('Réponse d\'enregistrement de paiement (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = convert.jsonDecode(convert.utf8.decode(response.bodyBytes));
        _log('Réponse décodée: $responseBody');
        
        // Notifier l'enregistrement d'un paiement
        _realTimeService.notifyNewPayment(
          paymentId: reference,
          status: status,
        );
        
        return responseBody;
      } else {
        final errorMsg = 'Échec de l\'enregistrement du paiement: ${response.statusCode} - ${response.body}';
        _log(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      _log('Erreur lors de l\'enregistrement du paiement: $e');
      rethrow;
    }
  }
}
