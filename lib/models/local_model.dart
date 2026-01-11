import 'package:flutter/foundation.dart';

class LocalModel {
  final String id;
  final String nom;
  final String number;
  final String status;
  final String zoneId;
  final String? typeLocalId;
  final double surface;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> zone;
  final Map<String, dynamic>? typeLocal;

  LocalModel({
    required this.id,
    required this.nom,
    required this.number,
    required this.status,
    required this.zoneId,
    this.typeLocalId,
    required this.surface,
    this.latitude,
    this.longitude,
    required this.zone,
    this.typeLocal,
  });

  factory LocalModel.fromJson(Map<String, dynamic> json) {
    // Handle null or invalid numeric values
    final dynamic surface = json['surface'];
    final double surfaceValue = surface != null 
        ? (surface is num ? surface.toDouble() : 0.0)
        : 0.0;

    return LocalModel(
      id: json['id_local']?.toString() ?? '',
      nom: (json['nom'] as String?) ?? (json['numero'] as String?) ?? '',
      number: (json['numero'] as String?) ?? '',
      status: (json['statut'] as String?) ?? 'inconnu',
      zoneId: json['zoneId']?.toString() ?? '',
      typeLocalId: json['typelocalId']?.toString(),
      surface: surfaceValue,
      latitude: json['latitude'] != null 
          ? (json['latitude'] is num 
              ? json['latitude'].toDouble() 
              : double.tryParse(json['latitude'].toString()) ?? 0.0)
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] is num
              ? json['longitude'].toDouble()
              : double.tryParse(json['longitude'].toString()) ?? 0.0)
          : null,
      zone: (json['zone'] as Map<String, dynamic>?) ?? {},
      typeLocal: json['typelocal'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_local': id,
      'nom': nom,
      'numero': number,
      'statut': status,
      'zoneId': zoneId,
      'typelocalId': typeLocalId,
      'surface': surface,
      'latitude': latitude,
      'longitude': longitude,
      'zone': zone,
      'typelocal': typeLocal,
    };
  }
}

class LocalType {
  final String id;
  final int municipalityId;
  final String name;
  final double price;
  final String description;
  final String contractType;

  LocalType({
    required this.id,
    required this.municipalityId,
    required this.name,
    required this.price,
    required this.description,
    required this.contractType,
  });

  factory LocalType.fromJson(Map<String, dynamic> json) {
    try {
      // Handle null or invalid numeric values
      final dynamic tarif = json['tarif'];
      final double price = tarif != null 
          ? (tarif is num ? tarif.toDouble() : 0.0)
          : 0.0;

      // Handle municipalityId that might come in different formats
      int municipalityIdValue = 0;
      if (json.containsKey('municipalityId')) {
        final dynamic municipalityId = json['municipalityId'];
        
        if (municipalityId is int) {
          municipalityIdValue = municipalityId;
        } else if (municipalityId is String) {
          municipalityIdValue = int.tryParse(municipalityId) ?? 0;
        } else if (municipalityId is Map<String, dynamic>) {
          // Handle case where it might be an object with an 'id' field
          final id = municipalityId['id'];
          if (id is int) {
            municipalityIdValue = id;
          } else if (id is String) {
            municipalityIdValue = int.tryParse(id) ?? 0;
          }
        }
      }

      // Handle typeLoc which might be a String or a Map
      String typeLocName = 'Type inconnu';
      if (json['typeLoc'] is String) {
        final typeLocStr = json['typeLoc'] as String;
        typeLocName = typeLocStr.isNotEmpty ? typeLocStr : 'Type inconnu';
      } else if (json['typeLoc'] is Map<String, dynamic>) {
        typeLocName = (json['typeLoc']?['fr'] ?? 'Type inconnu') as String;
      }

      // Handle description which might be a String or a Map
      String description = '';
      if (json['description'] is String) {
        description = json['description'] as String;
      } else if (json['description'] is Map<String, dynamic>) {
        description = (json['description']?['fr'] ?? '') as String;
      }

      return LocalType(
        id: json['id_type_local']?.toString() ?? '',
        municipalityId: municipalityIdValue,
        name: typeLocName,
        price: price,
        description: description,
        contractType: (json['type_contrat'] as String?)?.toLowerCase() ?? 'inconnu',
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error parsing LocalType: $e');
        debugPrint('Stack trace: $stackTrace');
        debugPrint('JSON data: $json');
      }
      // Return a default LocalType with error information in debug mode
      return LocalType(
        id: 'error-${DateTime.now().millisecondsSinceEpoch}',
        municipalityId: 0,
        name: 'Error',
        price: 0,
        description: 'Failed to parse local type',
        contractType: 'error',
      );
    }
  }
}
