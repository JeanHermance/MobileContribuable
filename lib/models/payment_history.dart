class PaymentHistory {
  final String idPaiement;
  final String reference;
  final String status;
  final String raison;
  final List<PaiementLocation> paiementLocations;
  final DateTime dateCreation;

  PaymentHistory({
    required this.idPaiement,
    required this.reference,
    required this.status,
    required this.raison,
    required this.paiementLocations,
    required this.dateCreation,
  });

  factory PaymentHistory.fromJson(Map<String, dynamic> json) {
    return PaymentHistory(
      idPaiement: json['id_paiement'],
      reference: json['reference'],
      status: json['status'],
      raison: json['raison'],
      paiementLocations: (json['paiement_locations'] as List)
          .map((e) => PaiementLocation.fromJson(e))
          .toList(),
      dateCreation: DateTime.parse(json['date_creation']),
    );
  }
}

class PaiementLocation {
  final String idPaiementLocation;
  final String locationId;
  final int nombrePaye;
  final Location location;
  final DateTime dateDebut;
  final DateTime dateFin;
  final DateTime datePaiement;
  final int montantPaye;

  PaiementLocation({
    required this.idPaiementLocation,
    required this.locationId,
    required this.nombrePaye,
    required this.location,
    required this.dateDebut,
    required this.dateFin,
    required this.datePaiement,
    required this.montantPaye,
  });

  factory PaiementLocation.fromJson(Map<String, dynamic> json) {
    return PaiementLocation(
      idPaiementLocation: json['id_paiement_location'] ?? '',
      locationId: json['locationId'] ?? '',
      nombrePaye: _safeParseInt(json['nombre_paye']),
      location: Location.fromJson(json['location'] ?? {}),
      dateDebut: DateTime.parse(json['date_debut'] ?? DateTime.now().toIso8601String()),
      dateFin: DateTime.parse(json['date_fin'] ?? DateTime.now().toIso8601String()),
      datePaiement: DateTime.parse(json['date_paiement'] ?? DateTime.now().toIso8601String()),
      montantPaye: _safeParseInt(json['montant_paye']),
    );
  }
  
  // Méthode utilitaire pour parser les entiers de manière sécurisée
  static int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) {
      return value.toInt();
    }
    return 0;
  }
}

class Location {
  final String idLocation;
  final String periodicite;
  final String idUser;
  final String nif;
  final DateTime dateDebutLoc;
  final DateTime dateFinLoc;
  final int frequence;
  final String usage;
  final Local local;

  Location({
    required this.idLocation,
    required this.periodicite,
    required this.idUser,
    required this.nif,
    required this.dateDebutLoc,
    required this.dateFinLoc,
    required this.frequence,
    required this.usage,
    required this.local,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      idLocation: json['id_location'] ?? '',
      periodicite: json['periodicite'] ?? '',
      idUser: json['id_user'] ?? '',
      nif: json['nif'] ?? '',
      dateDebutLoc: DateTime.parse(json['date_debut_loc'] ?? DateTime.now().toIso8601String()),
      dateFinLoc: DateTime.parse(json['date_fin_loc'] ?? DateTime.now().toIso8601String()),
      frequence: _safeParseInt(json['frequence']),
      usage: json['usage'] ?? '',
      local: Local.fromJson(json['local'] ?? {}),
    );
  }
  
  // Méthode utilitaire pour parser les entiers de manière sécurisée
  static int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) {
      return value.toInt();
    }
    return 0;
  }
}

class Local {
  final String idLocal;
  final String numero;
  final String statut;
  final String zoneId;
  final String typelocalId;
  final String latitude;
  final String longitude;
  final Zone zone;

  Local({
    required this.idLocal,
    required this.numero,
    required this.statut,
    required this.zoneId,
    required this.typelocalId,
    required this.latitude,
    required this.longitude,
    required this.zone,
  });

  factory Local.fromJson(Map<String, dynamic> json) {
    return Local(
      idLocal: json['id_local'],
      numero: json['numero'],
      statut: json['statut'],
      zoneId: json['zoneId'],
      typelocalId: json['typelocalId'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      zone: Zone.fromJson(json['zone']),
    );
  }
}

class Zone {
  final String idZone;
  final String nom;
  final bool status;
  final int fokotanyId;
  final int municipalityId;

  Zone({
    required this.idZone,
    required this.nom,
    required this.status,
    required this.fokotanyId,
    required this.municipalityId,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      idZone: json['id_zone'] ?? '',
      nom: json['nom'] ?? '',
      status: json['status'] ?? false,
      fokotanyId: _safeParseInt(json['fokotany_id']),
      municipalityId: _safeParseInt(json['municipalityId']),
    );
  }
  
  // Méthode utilitaire pour parser les entiers de manière sécurisée
  static int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) {
      return value.toInt();
    }
    return 0;
  }
}