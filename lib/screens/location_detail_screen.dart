import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tsena_servisy/services/api_service.dart';

class LocationDetailScreen extends StatefulWidget {
  final String idLocation;
  final Map<String, dynamic> reservation;
  const LocationDetailScreen({super.key, required this.idLocation, required this.reservation});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _paymentInfo;
  Map<String, dynamic>? _locationDetail;
  bool _loading = true;
  String? _error;
  late final MapController _mapController = MapController();
  latlong2.LatLng? _locationLatLng;
  List<latlong2.LatLng> _zonePolygon = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Polygon? _cachedLocalPolygon; // Cache pour le polygone du local


  // Centre la carte sur la position du local
  void _centerMapOnLocation() {
    if (_locationLatLng != null) {
      // Utiliser un délai pour s'assurer que la carte est prête
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _locationLatLng != null) {
          try {
            _mapController.move(_locationLatLng!, 16.0);
          } catch (e) {
            debugPrint('Erreur lors du centrage de la carte: $e');
          }
        }
      });
    }
  }

  // Obtenir le nom localisé d'un type de local
  // L'API retourne déjà la bonne langue selon le paramètre lang
  String _getLocalizedTypeName(Map<String, dynamic>? typeLocal) {
    if (typeLocal == null) return 'unknown_type'.tr();
    return typeLocal['typeLoc']?.toString() ?? 'unknown_type'.tr();
  }

  // Obtenir la description localisée d'un type de local
  // L'API retourne déjà la bonne langue selon le paramètre lang
  String? _getLocalizedDescription(Map<String, dynamic>? typeLocal) {
    if (typeLocal == null) return null;
    
    final description = typeLocal['description']?.toString();
    return (description?.isNotEmpty == true) ? description : null;
  }

  @override
  void initState() {
    super.initState();
    
    // Initialiser le contrôleur de carte
    _mapController.mapEventStream.listen((event) {
      debugPrint('Map event: $event');
    });
    
    // Démarrer l'animation de fondu
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Charger toutes les données (location + paiement)
    _fetchAllDetails();
    
    // Démarrer l'animation après un court délai
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }


  Future<void> _fetchAllDetails() async {
    
    setState(() { 
      _loading = true; 
      _error = null; 
    });
    
    try {
      // Récupérer le municipalityId depuis les données de réservation
      String? municipalityId;
      String? zoneId;
      
      // Essayer d'abord de récupérer depuis les données de réservation
      final reservationLocal = widget.reservation['local'] as Map<String, dynamic>?;
      
      // Récupérer l'ID de la zone depuis le local
      if (reservationLocal != null) {
        zoneId = reservationLocal['zoneId']?.toString();
        debugPrint('✅ Zone ID récupéré depuis le local: $zoneId');
      }
      
      // Récupérer le municipalityId depuis l'API zones
      if (zoneId != null) {
        debugPrint('🔍 Récupération du municipalityId pour la zone: $zoneId');
        final apiService = ApiService();
        final zoneResponse = await apiService.getZoneById(zoneId);
        
        if (zoneResponse.success && zoneResponse.data != null) {
          final zoneData = zoneResponse.data;
          if (zoneData != null) {
            municipalityId = zoneData['municipalityId']?.toString();
            debugPrint('✅ MunicipalityId récupéré depuis l\'API zone: $municipalityId');
            debugPrint('📊 Nom de la zone: ${zoneData['nom']}');
            debugPrint('📊 Status de la zone: ${zoneData['status']}');
          }
        } else {
          debugPrint('❌ Erreur lors de la récupération de la zone: ${zoneResponse.error}');
          setState(() {
            _error = 'Impossible de récupérer les données de la zone: ${zoneResponse.error}';
            _loading = false;
          });
          return;
        }
      }
      
      if (municipalityId == null) {
        debugPrint('❌ MunicipalityId non trouvé');
        setState(() {
          _error = 'Impossible de récupérer l\'ID de la municipalité';
          _loading = false;
        });
        return;
      }
      
      // Préparer les URLs pour les appels parallèles
      final urlDetail = Uri.parse('https://gateway.agvm.mg/servicemodernmarket/locations/${widget.idLocation}/$municipalityId/location');
      final urlPayment = Uri.parse('https://gateway.agvm.mg/servicemodernmarket/locations/${widget.idLocation}/reste-a-payer');
      
      // Effectuer les appels API en parallèle
      final responses = await Future.wait([
        http.get(urlDetail),
        http.get(urlPayment),
      ]);
      
      final responseDetail = responses[0];
      final responsePayment = responses[1];
      
      if (responseDetail.statusCode == 200 && responsePayment.statusCode == 200) {
        final locationData = json.decode(responseDetail.body);
        final paymentData = json.decode(responsePayment.body);
        
        setState(() {
          _locationDetail = locationData;
          _paymentInfo = paymentData;
          
          // Traiter les coordonnées GPS
          final local = locationData['local'] ?? {};
          final lat = double.tryParse(local['latitude']?.toString() ?? '0') ?? 0.0;
          final lng = double.tryParse(local['longitude']?.toString() ?? '0') ?? 0.0;
          _locationLatLng = latlong2.LatLng(lat, lng);
          
          // Traiter les polygones de zone
          final zone = locationData['local']?['zone'];
          if (zone != null && zone['geo_delimitation'] != null) {
            final delimitation = zone['geo_delimitation'];
            final coordinates = delimitation['coordinates'];
            if (coordinates != null && coordinates is List && coordinates.isNotEmpty) {
              final polygonCoords = coordinates[0];
              if (polygonCoords is List) {
                _zonePolygon = polygonCoords.map<latlong2.LatLng>((coord) {
                  final lng = coord[0] is num ? coord[0].toDouble() : 0.0;
                  final lat = coord[1] is num ? coord[1].toDouble() : 0.0;
                  return latlong2.LatLng(lat, lng);
                }).toList();
              }
            }
          }
          
          _loading = false;
        });
        
        // Centrer la carte sur la location après un délai
        _centerMapOnLocation();
        
        debugPrint('Location details loaded successfully');
        debugPrint('Location coordinates: $_locationLatLng');
        
      } else {
        setState(() {
          _error = '${'loading_error'.tr()}: ${responseDetail.statusCode} / ${responsePayment.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchAllDetails: $e');
      setState(() {
        _error = '${'error'.tr()}: $e';
        _loading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    try {
      _mapController.dispose();
    } catch (e) {
      debugPrint('Error disposing map controller: $e');
    }
    super.dispose();
  }
  
  Widget _buildLocationMap() {
    debugPrint('_buildLocationMap() called');
    debugPrint('_locationLatLng: $_locationLatLng');
    
    // Afficher un indicateur de chargement si les données ne sont pas encore chargées
    if (_locationLatLng == null) {
      debugPrint('_locationLatLng is null, showing loading');
      return Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('loading_map'.tr()),
            ],
          ),
        ),
      );
    }
    
    // Vérifier si les coordonnées sont valides
    if (_locationLatLng!.latitude == 0 && _locationLatLng!.longitude == 0) {
      return Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'gps_coordinates_unavailable'.tr(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    try {
      return Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _locationLatLng!,
                  initialZoom: 18.0,
                  initialCameraFit: _zonePolygon.isNotEmpty
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(_zonePolygon),
                          padding: const EdgeInsets.all(24.0),
                        )
                      : null,
                  minZoom: 10.0,
                  maxZoom: 20.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'mg.reservation.app',
                    maxZoom: 20,
                    tileProvider: NetworkTileProvider(
                      headers: {
                        'User-Agent': 'ReservationApp/1.0 (contact@agvm.mg)',
                      },
                    ),
                  ),
                  if (_zonePolygon.isNotEmpty)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _zonePolygon,
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          borderColor: Theme.of(context).primaryColor,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  // Polygone de la superficie du local
                  if (_locationDetail != null && _locationLatLng != null && _buildLocalPolygon() != null)
                    PolygonLayer(
                      polygons: [_buildLocalPolygon()!],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 30.0,
                        height: 30.0,
                        point: _locationLatLng!,
                        child: Transform.translate(
                          offset: const Offset(0, -6),
                          child: Icon(
                            Icons.location_on,
                            color: Theme.of(context).primaryColor,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error building map: $e');
      return Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Center(
          child: Text(
            '${'map_loading_error'.tr()}: ${e.toString()}',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  // Méthode pour construire le polygone de la superficie du local
  Polygon? _buildLocalPolygon() {
    // Retourner le cache si disponible
    if (_cachedLocalPolygon != null) {
      return _cachedLocalPolygon;
    }
    
    if (_locationDetail == null || _locationLatLng == null) return null;
    
    final local = _locationDetail!['local'];
    if (local == null) return null;
    
    final typelocal = local['typelocal'] ?? local['typeLocal'];
    if (typelocal == null) return null;
    
    final longueur = typelocal['longueur'];
    final largeur = typelocal['largeur'];
    
    if (longueur == null || largeur == null) return null;
    if (longueur is! num || largeur is! num) return null;
    if (longueur <= 0 || largeur <= 0) return null;
    
    final lat = _locationLatLng!.latitude;
    final lng = _locationLatLng!.longitude;
    
    // Conversion précise: 1 degré de latitude ≈ 111320 mètres
    final metersToDegreesLat = 1 / 111320.0;
    final metersToDegreesLng = metersToDegreesLat;
    
    final halfLength = (longueur.toDouble() * metersToDegreesLng) / 2;
    final halfWidth = (largeur.toDouble() * metersToDegreesLat) / 2;
    
    debugPrint('🗺️ Building polygon for local:');
    debugPrint('  - Longueur: $longueur m, Largeur: $largeur m');
    debugPrint('  - Center: ($lat, $lng)');
    debugPrint('  - Half dimensions: ($halfLength, $halfWidth) degrees');
    
    // Créer et mettre en cache le polygone
    _cachedLocalPolygon = Polygon(
      points: [
        latlong2.LatLng(lat + halfWidth, lng - halfLength),
        latlong2.LatLng(lat + halfWidth, lng + halfLength),
        latlong2.LatLng(lat - halfWidth, lng + halfLength),
        latlong2.LatLng(lat - halfWidth, lng - halfLength),
      ],
      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
      borderColor: Theme.of(context).primaryColor,
      borderStrokeWidth: 2,
      isFilled: true,
    );
    
    return _cachedLocalPolygon;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchAllDetails,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _loading 
                    ? _buildLoadingSkeleton()
                    : _buildLocationMap(),
                ),
                SliverToBoxAdapter(
                  child: _loading
                    ? _buildDetailsSkeleton()
                    : _buildDetail(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Skeleton pour la carte pendant le chargement
  Widget _buildLoadingSkeleton() {
    return Container(
      height: 250,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(
              'Chargement de la carte...',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // Skeleton pour les détails pendant le chargement
  Widget _buildDetailsSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          _buildSkeletonCard(),
          const SizedBox(height: 16),
          _buildSkeletonCard(),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 24,
              width: 150,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(4, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final local = _locationDetail?['local'] ?? {};
    final numero = local['numero'] ?? 'N/A';
    
    return SliverAppBar(
      expandedHeight: 80.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).primaryColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reservation_detail_title'.tr(),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (!_loading && _error == null)
            Text(
              'local_number_format'.tr(namedArgs: {'number': numero}),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
      centerTitle: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withBlue(200),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Méthode utilitaire pour formater les dates
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Méthode utilitaire pour formater les nombres
  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    final formatter = NumberFormat('#,##0', 'fr_FR');
    return formatter.format(double.tryParse(number.toString()) ?? 0);
  }

  // Méthode utilitaire pour obtenir la couleur selon le statut
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'LOUE':
        return Colors.blue;
      case 'DISPONIBLE':
        return Colors.green;
      case 'OCCUPE':
        return Colors.red;
      case 'EN_ATTENTE':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // Méthode pour construire les détails de paiement
  List<Widget> _buildPaymentDetails() {
    // final info = _paymentInfo ?? {};

    return [
      // ...progress bar et pourcentage supprimés...
      const SizedBox(height: 24),
    ];
  }

  // Méthode pour construire une ligne d'information moderne
  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Méthode pour construire une puce d'information (comme dans zone_locals_screen)
  // Méthode supprimée car non utilisée

  // Calculer la surface à partir des dimensions du type local
  // Méthode supprimée car non utilisée

  // Méthode pour construire une ligne de paiement
  Widget _buildPaymentRow(String label, String value, {bool isHighlighted = false, bool isPaid = false, bool isDue = false}) {
    final bool isNegative = !isPaid && isDue && !value.startsWith('-');
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: isHighlighted ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: isHighlighted 
                    ? Theme.of(context).primaryColor 
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted 
                    ? Theme.of(context).primaryColor
                    : isPaid 
                        ? Colors.green
                        : isNegative
                            ? Colors.red
                            : Theme.of(context).colorScheme.onSurface,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                fontSize: 15,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail() {
  final info = _paymentInfo ?? {};
  final detail = _locationDetail ?? {};
  final local = detail['local'] ?? {};
  // Correction : récupérer le typeLoc depuis local['typelocal'] si présent, sinon local['typeLocal']
  final typelocal = local['typelocal'] ?? local['typeLocal'] ?? {};
  // final zone = local['zone'] ?? {};
  final statut = local['statut']?.toString().toUpperCase() ?? '';
  final dateDebut = detail['date_debut_loc'] ?? '-';
  final dateFin = detail['date_fin_loc'] ?? '-';
  // Calcul du reste à payer en s'assurant qu'il ne soit pas négatif
  final montantTotal = double.tryParse(info['Montant_total']?.toString() ?? '0') ?? 0;
  final totalPaye = double.tryParse(info['total_payer']?.toString() ?? '0') ?? 0;
  final resteAPayer = (montantTotal - totalPaye).clamp(0.0, montantTotal);

  final isEnCours = statut == 'LOUE' && 
      DateTime.tryParse(dateDebut) != null && 
      DateTime.tryParse(dateFin) != null && 
      DateTime.now().isAfter(DateTime.parse(dateDebut)) && 
      DateTime.now().isBefore(DateTime.parse(dateFin));
 
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Carte des informations principales
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'local_number_format'.tr(namedArgs: {'number': local['numero'] ?? 'N/A'}),
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getLocalizedTypeName(typelocal),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(statut).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(statut)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statut == 'DISPONIBLE' ? Icons.check_circle : Icons.info,
                              color: _getStatusColor(statut),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statut == 'DISPONIBLE' ? 'available_short'.tr() : statut,
                              style: GoogleFonts.inter(
                                color: _getStatusColor(statut),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, thickness: 1),
                  _buildModernInfoRow(Icons.calendar_today, 'period_label'.tr(), 
                      'from_to_period'.tr(namedArgs: {'from': _formatDate(dateDebut), 'to': _formatDate(dateFin)})),
                  const SizedBox(height: 12),
                  _buildModernInfoRow(Icons.business_center, 'usage_label'.tr(), detail['usage'] ?? '-'),
                  const SizedBox(height: 12),
                  _buildModernInfoRow(Icons.location_on, 'zone_label'.tr(), local['zone']?['nom'] ?? '-'),
                  const SizedBox(height: 12),
                  if (typelocal['longueur'] != null && typelocal['largeur'] != null)
                    _buildModernInfoRow(
                      Icons.square_foot,
                      'surface_label'.tr(),
                      'surface_format'.tr(namedArgs: {'surface': '${((typelocal['longueur'] is num ? typelocal['longueur'].toDouble() : 0.0) * (typelocal['largeur'] is num ? typelocal['largeur'].toDouble() : 0.0)).toStringAsFixed(1)}'}),
                    ),
                  const SizedBox(height: 12),
                  _buildModernInfoRow(Icons.repeat, 'periodicity_label'.tr(), detail['periodicite'] ?? '-'),
                  const SizedBox(height: 12),
                  // Dimensions détaillées
                  if (typelocal['typeLoc'] != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernInfoRow(
                            Icons.straighten, 
                            'length_label'.tr(), 
                            'length_format'.tr(namedArgs: {'length': typelocal['longueur']?.toString() ?? 'N/A'})
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildModernInfoRow(
                            Icons.height, 
                            'width_label'.tr(), 
                            'width_format'.tr(namedArgs: {'width': typelocal['largeur']?.toString() ?? 'N/A'})
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Afficher la description si disponible dans la langue courante
                  if (_getLocalizedDescription(local['typeLocal']) != null) ...[
                    const SizedBox(height: 12),
                    _buildModernInfoRow(Icons.description, 'description_label'.tr(), _getLocalizedDescription(local['typeLocal'])!),
                  ],
                ],
              ),
            ),
          ),
          // Carte des détails de paiement
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'payment_details'.tr(),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Barre de progression supprimée (doublon)
                  
                  // Détails de paiement
                  if (_paymentInfo != null) ..._buildPaymentDetails(),
                  _buildPaymentRow('total_amount_label'.tr(), 'amount_format'.tr(namedArgs: {'amount': _formatNumber(montantTotal)})),
                  const SizedBox(height: 12),
                  _buildPaymentRow('total_paid_label'.tr(), 'amount_format'.tr(namedArgs: {'amount': _formatNumber(totalPaye)}), isPaid: true),
                  const SizedBox(height: 12),
                  _buildPaymentRow(
                    'remaining_to_pay_label'.tr(),
                    'amount_format'.tr(namedArgs: {'amount': _formatNumber(resteAPayer)}),
                    isHighlighted: true,
                    isDue: resteAPayer > 0,
                  ),
                  
                  // Message d'information
                  if (isEnCours && resteAPayer > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'partial_payment_info'.tr(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
