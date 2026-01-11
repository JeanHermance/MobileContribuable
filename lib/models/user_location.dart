class UserLocation {
  final String idLocation;
  final String periodicite;
  final String idUser;
  final String nif;
  final DateTime dateDebutLoc;
  final DateTime dateFinLoc;
  final int frequence;
  final String usage;
  final List<PaiementLocationDetail> paiementLocations;
  final LocalDetail local;
  final String localId;

  UserLocation({
    required this.idLocation,
    required this.periodicite,
    required this.idUser,
    required this.nif,
    required this.dateDebutLoc,
    required this.dateFinLoc,
    required this.frequence,
    required this.usage,
    required this.paiementLocations,
    required this.local,
    required this.localId,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      idLocation: json['id_location'] ?? '',
      periodicite: json['periodicite'] ?? '',
      idUser: json['id_user'] ?? '',
      nif: json['nif'] ?? '',
      dateDebutLoc: DateTime.parse(json['date_debut_loc'] ?? DateTime.now().toIso8601String()),
      dateFinLoc: DateTime.parse(json['date_fin_loc'] ?? DateTime.now().toIso8601String()),
      frequence: json['frequence'] ?? 0,
      usage: json['usage'] ?? '',
      paiementLocations: (json['paiement_locations'] as List<dynamic>?)
          ?.map((e) => PaiementLocationDetail.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      local: LocalDetail.fromJson(json['local'] as Map<String, dynamic>? ?? {}),
      localId: json['localId'] ?? '',
    );
  }
}

class PaiementLocationDetail {
  final String idPaiementLocation;
  final String locationId;
  final int nombrePaye;
  final DateTime dateDebut;
  final DateTime dateFin;
  final DateTime datePaiement;
  final int montantPaye;

  PaiementLocationDetail({
    required this.idPaiementLocation,
    required this.locationId,
    required this.nombrePaye,
    required this.dateDebut,
    required this.dateFin,
    required this.datePaiement,
    required this.montantPaye,
  });

  factory PaiementLocationDetail.fromJson(Map<String, dynamic> json) {
    return PaiementLocationDetail(
      idPaiementLocation: json['id_paiement_location'] ?? '',
      locationId: json['locationId'] ?? '',
      nombrePaye: json['nombre_paye'] ?? 0,
      dateDebut: DateTime.parse(json['date_debut'] ?? DateTime.now().toIso8601String()),
      dateFin: DateTime.parse(json['date_fin'] ?? DateTime.now().toIso8601String()),
      datePaiement: DateTime.parse(json['date_paiement'] ?? DateTime.now().toIso8601String()),
      montantPaye: json['montant_paye'] ?? 0,
    );
  }
}

class LocalDetail {
  final String idLocal;
  final String numero;
  final String statut;
  final String zoneId;
  final String typelocalId;
  final String latitude;
  final String longitude;
  final String nom;
  final String adresse;

  LocalDetail({
    required this.idLocal,
    required this.numero,
    required this.statut,
    required this.zoneId,
    required this.typelocalId,
    required this.latitude,
    required this.longitude,
    this.nom = '',
    this.adresse = '',
  });

  factory LocalDetail.fromJson(Map<String, dynamic> json) {
    return LocalDetail(
      idLocal: json['id_local'] ?? '',
      numero: json['numero'] ?? '',
      statut: json['statut'] ?? '',
      zoneId: json['zoneId'] ?? '',
      typelocalId: json['typelocalId'] ?? '',
      latitude: json['latitude'] ?? '',
      longitude: json['longitude'] ?? '',
      nom: json['nom'] ?? json['numero'] ?? '',
      adresse: json['adresse'] ?? '',
    );
  }
}

class ResteAPayer {
  final int montantTotal;
  final int totalPayer;
  final int resteAPayer;

  ResteAPayer({
    required this.montantTotal,
    required this.totalPayer,
    required this.resteAPayer,
  });

  factory ResteAPayer.fromJson(Map<String, dynamic> json) {
    return ResteAPayer(
      montantTotal: json['Montant_total'] ?? 0,
      totalPayer: json['total_payer'] ?? 0,
      resteAPayer: json['Reste_a_payer'] ?? 0,
    );
  }

  int get moisRestants {
     if (montantTotal == 0 || totalPayer >= montantTotal) return 0;
     final montantMensuel = (montantTotal / 12).round();
     if (montantMensuel == 0) return 0;
     return (resteAPayer / montantMensuel).ceil();
  }
}
