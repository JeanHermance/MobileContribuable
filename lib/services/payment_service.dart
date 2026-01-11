import 'dart:convert' as convert;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'real_time_service.dart';

class PaymentService extends ChangeNotifier {
  final String municipalityId;
  final String _baseUrl = 'https://gateway.agvm.mg/servicepaiement';
  final _uuid = const Uuid();
  final RealTimeService _realTimeService = RealTimeService();

  PaymentService({required this.municipalityId});

  // ID de type de transaction pour les réservations (à remplacer par l'ID réel de votre système)
  static const String reservationTransactionTypeId = '58f2b586-9a70-4a2f-8500-33bf1462f559';

  // Soumettre une transaction de paiement
  Future<Map<String, dynamic>> submitTransaction({
    required String userId,
    required String paymentMethodId,
    required double amount,
    required String description,
    String? transactionTypeId,
    String? senderPhone,
    String? recipientPhone,
    Map<String, dynamic>? creditCardDetails,
  }) async {
    // Journalisation du début de la transaction
    
    try {
      final url = Uri.parse('$_baseUrl/transactions/$municipalityId');
      debugPrint(url.toString());
      final requestId = _uuid.v4();
      
      final Map<String, dynamic> requestBody = {
        'userId': userId,
        'transactionTypeId': transactionTypeId ?? reservationTransactionTypeId,
        'paymentMethodId': paymentMethodId,
        'amount': amount,
        'currency': 'MGA',
        'description': description,
        'idempotencyKey': requestId,
      };

      // Ajouter les détails de paiement en fonction de la méthode
      if (creditCardDetails != null) {
        requestBody['creditCardDetails'] = {
          ...creditCardDetails,
          'cardNumber': '•••• •••• •••• ${creditCardDetails['cardNumber']?.substring((creditCardDetails['cardNumber']?.length ?? 4) - 4) ?? '••••'}' 
        };
      } else if (senderPhone != null) {
        
        requestBody['mobileMoneyDetails'] = {
          'senderPhone': senderPhone,
        };
      } else {
        debugPrint('Aucun détail de paiement spécifique fourni');
      }
      
      // Journalisation du corps de la requête (masquage des données sensibles)
      final loggedRequestBody = Map<String, dynamic>.from(requestBody);
      if (loggedRequestBody.containsKey('creditCardDetails')) {
        loggedRequestBody['creditCardDetails'] = {
          'cardNumber': '•••• •••• •••• ••••',
          'cardHolderName': loggedRequestBody['creditCardDetails']['cardHolderName'] != null ? '••••••••' : null,
          'expirationDate': '••/••',
          'cvv': '•••',
        };
      }
      
      
      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Request-ID': requestId,
          },
          body: convert.jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 30));
        
        // Tenter de décoder la réponse
        Map<String, dynamic> responseData;
        try {
          responseData = convert.jsonDecode(convert.utf8.decode(response.bodyBytes));
        } catch (e) {
          throw FormatException(tr('server_response_invalid'));
        }
        
        // Vérifier le code de statut HTTP
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Notifier le succès de la transaction
          _realTimeService.notifyNewPayment(
            paymentId: requestId,
            amount: amount,
            status: 'success',
          );
          
          return {
            'success': true,
            'data': responseData,
            'statusCode': response.statusCode,
            'requestId': requestId,
          };
        } else {
          // Gestion des erreurs avec plus de détails
          final errorMessage = responseData['message'] ?? 
                             responseData['error'] ?? 
                             '${tr('error')} (${response.statusCode})';
          
          debugPrint('Échec de la transaction: $errorMessage');
          
          // Si nous avons des détails supplémentaires sur l'erreur, les journaliser
          if (responseData['errors'] != null) {
            debugPrint('Détails des erreurs: ${responseData['errors']}');
          }
          
          throw Exception('${tr('payment_failed_default')}: $errorMessage (${response.statusCode})');
        }
      } on http.ClientException catch (e) {
        // Erreur de connexion ou timeout
        debugPrint('Erreur de connexion ou délai d\'attente dépassé lors de la soumission de la transaction: $e');
        throw Exception(tr('server_connection_error'));
      } on FormatException catch (e) {
        // Erreur de format de la réponse
        debugPrint('Erreur de format de la réponse: $e');
        throw Exception(tr('server_response_invalid'));
      } catch (e) {
        // Autres erreurs
        debugPrint('Erreur inattendue lors de la soumission de la transaction: $e');
        rethrow;
      }
    } catch (e) {
      
      if (e is! Exception) {
        throw Exception(tr('unexpected_error_payment'));
      }
      rethrow;
    } finally {
      debugPrint('=== FIN DE LA SOUMISSION DE TRANSACTION ===\n');
    }
  }

  // Récupérer les méthodes de paiement Mobile Money
  Future<List<Map<String, dynamic>>> getMobileMoneyMethods() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payement-methode/mobileMoney/$municipalityId'),
      );

      if (response.statusCode == 200) {
        final data = convert.jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('Erreur lors de la récupération des méthodes de paiement: $e');
      return [];
    }
  }

  // Récupérer la méthode de paiement par carte de crédit
  Future<Map<String, dynamic>?> getCreditCardMethod() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payement-methode/d4dc18f1-2a46-4cdd-a18a-04e2f75b983c/$municipalityId'),
      );

      if (response.statusCode == 200) {
        final data = convert.jsonDecode(response.body);
        return Map<String, dynamic>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la méthode de paiement par carte: $e');
      return null;
    }
  }

  // Effectuer un paiement
  Future<Map<String, dynamic>> processPayment({
    required String userId,
    required String paymentMethodId,
    required double amount,
    String? phoneNumber,
    Map<String, dynamic>? creditCardDetails,
  }) async {
    try {
      final transactionTypeId = 'a96b6fc6-bd94-4785-ad00-efb1e39ab143'; // ID du type de transaction
      final idempotencyKey = const Uuid().v4();
      
      final Map<String, dynamic> requestBody = {
        'userId': userId,
        'transactionTypeId': transactionTypeId,
        'paymentMethodId': paymentMethodId,
        'amount': amount,
        'currency': 'MGA',
        'description': 'Paiement location place de marché',
        'idempotencyKey': idempotencyKey,
      };

      // Ajouter les détails spécifiques au type de paiement
      if (phoneNumber != null) {
        requestBody['mobileMoneyDetails'] = {
          'senderPhone': phoneNumber,
        };
      } else if (creditCardDetails != null) {
        requestBody['creditCardDetails'] = creditCardDetails;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/transactions/$municipalityId'),
        headers: {'Content-Type': 'application/json'},
        body: convert.jsonEncode(requestBody),
      );

      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'data': convert.jsonDecode(response.body),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      debugPrint('Erreur lors du traitement du paiement: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Enregistrer un paiement avec les locations associées
  Future<Map<String, dynamic>> createPayment({
    required String reference,
    required String status,
    required String raison,
    required List<Map<String, dynamic>> locations,
    String? userId, // Ajout du userId optionnel
  }) async {
    try {
      final url = Uri.parse('https://gateway.agvm.mg/serviceModernMarket/paiement');
      
      // Préparer le corps de la requête
      final body = {
        'reference': reference,
        'status': status,
        'raison': raison,
        'paiement_locations': locations,
        if (userId != null) 'id_user': userId, // Envoi du userId si disponible
      };

      // Journalisation détaillée
      
      
      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: convert.jsonEncode(body),
        );

        // Tenter de décoder la réponse
        Map<String, dynamic> responseData;
        try {
          responseData = convert.jsonDecode(convert.utf8.decode(response.bodyBytes));
        } catch (e) {
          debugPrint('Erreur lors du décodage de la réponse: $e');
          // Si le décodage échoue, on retourne quand même une réponse de succès
          // car l'API peut renvoyer une réponse vide ou mal formatée même en cas de succès
          return {
            'success': response.statusCode == 200 || response.statusCode == 201,
            'status': 'success',
            'message': tr('payment_success_message'),
            'reference': reference,
            'locations_count': locations.length,
          };
        }

        // Vérifier le code de statut HTTP
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Notifier l'enregistrement du paiement
          _realTimeService.notifyNewPayment(
            paymentId: reference,
            status: status,
          );
          
          return {
            'success': true,
            'data': responseData,
            'statusCode': response.statusCode,
            'reference': reference,
          };
        } else {
          // Gestion des erreurs avec plus de détails
          final errorMessage = responseData['message'] ?? 
                             responseData['error'] ?? 
                             '${tr('error')} (${response.statusCode})';
          
          debugPrint('Échec de l\'enregistrement du paiement: $errorMessage');
          
          // Si nous avons des détails supplémentaires sur l'erreur, les journaliser
          if (responseData['errors'] != null) {
            debugPrint('Détails des erreurs: ${responseData['errors']}');
          }
          
          throw Exception('${tr('payment_registration_failed', namedArgs: {'error': errorMessage})} (${response.statusCode})');
        }
      } on http.ClientException catch (e) {
        // Erreur de connexion
        debugPrint('Erreur de connexion lors de l\'enregistrement du paiement: $e');
        throw Exception(tr('server_connection_error'));
      } on FormatException catch (e) {
        // Erreur de format de la réponse
        debugPrint('Erreur de format de la réponse: $e');
        throw Exception(tr('server_response_invalid'));
      } catch (e) {
        // Autres erreurs
        debugPrint('Erreur inattendue lors de l\'enregistrement du paiement: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('=== ERREUR LORS DE L\'ENREGISTREMENT DU PAIEMENT ===');
      debugPrint('Type d\'erreur: ${e.runtimeType}');
      debugPrint('Message d\'erreur: $e');
      if (e is Error) {
        debugPrint('Stack trace: ${e.stackTrace}');
      } else {
        // Pour les Exceptions et autres types, on utilise StackTrace.current
        debugPrint('Stack trace: ${StackTrace.current}');
      }
      
      // Relancer l'erreur avec un message plus convivial si nécessaire
      if (e is! Exception) {
        throw Exception(tr('unexpected_error_payment'));
      }
      rethrow;
    }
  }

  // Récupérer l'historique des paiements
  Future<List<Map<String, dynamic>>> getPaymentHistory(String userId) async {
    try {
      final url = Uri.parse('https://gateway.agvm.mg/serviceModernMarket/paiement/user/$userId/history');
      final response = await http.get(url);
      debugPrint('Payment history response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = convert.jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception(tr('history_fetch_error', namedArgs: {'code': response.statusCode.toString()}));
      }
    } catch (e) {
      debugPrint('Erreur: $e');
      rethrow;
    }
  }

  // Récupérer les types de transaction par municipality_id
  Future<Map<String, dynamic>> getTransactionTypes(String municipalityId) async {
    try {
      final url = Uri.parse('$_baseUrl/transaction-type/listes/$municipalityId?search=LOCATION');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = convert.jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        debugPrint('Erreur lors de la récupération des types de transaction: ${response.statusCode}');
        return {
          'success': false,
          'error': '${tr('error')} ${response.statusCode}: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des types de transaction: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Récupérer le QR code d'une paiement location
  Future<String?> getPaymentLocationQr(String paiementLocationId, String municipalityId) async {
    try {
      final url = Uri.parse('https://gateway.agvm.mg/serviceModernMarket/paiement-location/$paiementLocationId/qr?municipalityId=$municipalityId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = convert.jsonDecode(response.body);
        return data['qrCode'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du QR code: $e');
      return null;
    }
  }
}
