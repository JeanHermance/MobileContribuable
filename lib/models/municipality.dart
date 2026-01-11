class Municipality {
  final int communeId;
  final String name;
  final String? code;
  final String? postalCode;
  final String? phoneNumber;
  final String? email;
  final String? description;
  final bool isMember;
  final District district;
  final Region region;
  final List<Fokotany> fokotanys;
  final String formattedId;

  Municipality({
    required this.communeId,
    required this.name,
    this.code,
    this.postalCode,
    this.phoneNumber,
    this.email,
    this.description,
    required this.isMember,
    required this.district,
    required this.region,
    required this.fokotanys,
    required this.formattedId,
  });

  factory Municipality.fromJson(Map<String, dynamic> json) {
    return Municipality(
      communeId: json['commune_id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
      postalCode: json['postal_code'],
      phoneNumber: json['phone_number'],
      email: json['email'],
      description: json['description'],
      isMember: json['isMember'] ?? false,
      district: District.fromJson(json['district'] ?? {}),
      region: Region.fromJson(json['region'] ?? {}),
      fokotanys: (json['fokotanys'] as List<dynamic>? ?? [])
          .map((f) => Fokotany.fromJson(f as Map<String, dynamic>))
          .toList(),
      formattedId: json['formatted_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commune_id': communeId,
      'name': name,
      'code': code,
      'postal_code': postalCode,
      'phone_number': phoneNumber,
      'email': email,
      'description': description,
      'isMember': isMember,
      'district': district.toJson(),
      'region': region.toJson(),
      'fokotanys': fokotanys.map((f) => f.toJson()).toList(),
      'formatted_id': formattedId,
    };
  }
}

class District {
  final int districtId;
  final String name;
  final String formattedId;

  District({
    required this.districtId,
    required this.name,
    required this.formattedId,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      districtId: json['district_id'] ?? 0,
      name: json['name'] ?? '',
      formattedId: json['formatted_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'district_id': districtId,
      'name': name,
      'formatted_id': formattedId,
    };
  }
}

class Region {
  final int regionId;
  final String name;
  final String formattedId;

  Region({
    required this.regionId,
    required this.name,
    required this.formattedId,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      regionId: json['region_id'] ?? 0,
      name: json['name'] ?? '',
      formattedId: json['formatted_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'region_id': regionId,
      'name': name,
      'formatted_id': formattedId,
    };
  }
}

class Fokotany {
  final int fokotanyId;
  final String name;
  final String formattedId;

  Fokotany({
    required this.fokotanyId,
    required this.name,
    required this.formattedId,
  });

  factory Fokotany.fromJson(Map<String, dynamic> json) {
    return Fokotany(
      fokotanyId: json['fokotany_id'] ?? 0,
      name: json['name'] ?? '',
      formattedId: json['formatted_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fokotany_id': fokotanyId,
      'name': name,
      'formatted_id': formattedId,
    };
  }
}
