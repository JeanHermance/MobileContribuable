import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tsena_servisy/services/api_service.dart';
import 'package:tsena_servisy/services/user_service.dart';
import '../screens/location_detail_screen.dart';
import '../screens/contract_viewer_screen.dart';

import '../components/modern_floating_button.dart';
import '../mixins/data_refresh_mixin.dart';
import 'package:google_fonts/google_fonts.dart';

class ReservationTab extends StatefulWidget {
  final String? initialFilter;
  
  const ReservationTab({super.key, this.initialFilter});

  @override
  State<ReservationTab> createState() => _ReservationTabState();
}

class _ReservationTabState extends State<ReservationTab> with TickerProviderStateMixin, DataRefreshMixin {
  Timer? _debounceTimer;
  Future<ApiResponse<List<dynamic>>>? _reservationsFuture;
  String _selectedFilter = 'all_filter';
  List<dynamic> _allReservations = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 ReservationTab initState called');
    
    // Set initial filter if provided
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
      debugPrint('🎯 Initial filter set to: ${widget.initialFilter}');
    }
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    debugPrint('📞 Calling _loadReservations from initState');
    _loadReservations();
    
    // Démarrer l'écoute des changements de données avec le mixin
    startListeningToDataChanges(['reservations', 'payments']);
    
    _animationController.forward();
  }

  @override
  Future<void> onDataChanged(String dataType, Map<String, dynamic> metadata) async {
    debugPrint('🔄 ReservationTab - Changement de données détecté: $dataType');
    debugPrint('📋 Métadonnées: $metadata');
    
    switch (dataType) {
      case 'reservations':
        await _loadReservations();
        break;
      case 'payments':
        // Les paiements peuvent affecter les réservations (nouvelles réservations créées)
        if (metadata['action'] == 'created') {
          await _loadReservations();
        }
        break;
    }
  }

  /// Ouvre le visualiseur de contrat PDF
  void _openContractViewer(BuildContext context, Map<String, dynamic> reservation) {
    debugPrint('🔍 _openContractViewer appelé');
    debugPrint('📋 Données de réservation complètes: $reservation');
    
    // Essayer différentes clés possibles pour l'ID de location
    String? locationId;
    
    // Essayer 'id' en premier
    locationId = reservation['id']?.toString();
    debugPrint('🆔 Tentative avec "id": "$locationId"');
    
    // Si null ou vide, essayer 'idLocation'
    if (locationId == null || locationId.isEmpty) {
      locationId = reservation['idLocation']?.toString();
      debugPrint('🆔 Tentative avec "idLocation": "$locationId"');
    }
    
    // Si null ou vide, essayer 'id_location'
    if (locationId == null || locationId.isEmpty) {
      locationId = reservation['id_location']?.toString();
      debugPrint('🆔 Tentative avec "id_location": "$locationId"');
    }
    
    // Si null ou vide, essayer 'locationId'
    if (locationId == null || locationId.isEmpty) {
      locationId = reservation['locationId']?.toString();
      debugPrint('🆔 Tentative avec "locationId": "$locationId"');
    }
    
    debugPrint('🆔 LocationId final: "$locationId" (type: ${locationId.runtimeType})');
    
    final localData = reservation['local'] as Map<String, dynamic>?;
    debugPrint('🏠 LocalData: $localData');
    
    final locationName = localData?['nom'] ?? localData?['numero'] ?? 'Local';
    debugPrint('📝 LocationName: "$locationName"');
    
    // Vérifications détaillées
    if (locationId == null) {
      debugPrint('❌ LocationId est null après toutes les tentatives');
      debugPrint('📋 Clés disponibles dans reservation: ${reservation.keys.toList()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'contract_unavailable'.tr()} (ID null)'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (locationId.isEmpty) {
      debugPrint('❌ LocationId est vide après toutes les tentatives');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'contract_unavailable'.tr()} (ID vide)'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    debugPrint('✅ LocationId valide, navigation vers ContractViewerScreen');
    debugPrint('🚀 Paramètres: locationId="$locationId", locationName="$locationName"');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContractViewerScreen(
          locationId: locationId!, // Force unwrap car on a vérifié qu'il n'est pas null
          locationName: locationName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose(); // Le mixin s'occupe de nettoyer les subscriptions
  }

  Future<void> _loadReservations() async {
    debugPrint('🔍 _loadReservations() called');
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      debugPrint('✅ ApiService obtained');
      
      final userProfile = await UserService.getUserProfile();
      debugPrint('👤 UserProfile: $userProfile');
      
      final userId = userProfile?['user_id'] ?? '';
      debugPrint('🆔 UserId: $userId');
      
      if (userId.isEmpty) {
        debugPrint('❌ UserId is empty, cannot load reservations');
        return;
      }
      
      final future = apiService.getUserLocations(userId);
      debugPrint('📡 API call created: $future');
      
      if (mounted) {
        setState(() {
          _reservationsFuture = future;
        });
        debugPrint('🔄 State updated with future');
      }
      
      final response = await future;
      debugPrint('📥 API Response received: ${response.success}');
      
      
      if (mounted && response.success && response.data != null) {
        setState(() {
          final reservationsData = response.data;
          if (reservationsData != null) {
            _allReservations = reservationsData;
          }
        });
        debugPrint('✅ Reservations loaded: ${_allReservations.length} items');
        
        // Log détaillé de la structure des données
        if (_allReservations.isNotEmpty) {
          debugPrint('📊 Structure de la première réservation:');
          final firstReservation = _allReservations.first;
          debugPrint('   - Clés disponibles: ${firstReservation.keys.toList()}');
          debugPrint('   - ID: ${firstReservation['id']} (type: ${firstReservation['id'].runtimeType})');
          debugPrint('   - idLocation: ${firstReservation['idLocation']} (type: ${firstReservation['idLocation']?.runtimeType})');
          debugPrint('   - id_location: ${firstReservation['id_location']} (type: ${firstReservation['id_location']?.runtimeType})');
          debugPrint('   - locationId: ${firstReservation['locationId']} (type: ${firstReservation['locationId']?.runtimeType})');
          debugPrint('   - local: ${firstReservation['local']}');
        }
      } else {
        debugPrint('❌ Failed to load reservations: success=${response.success}, data=${response.data}');
      }
    } catch (e) {
      debugPrint('💥 Error in _loadReservations: $e');
    }
  }


  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
        });
      }
    });
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withBlue(200),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildModernLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'loading_reservations'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'loading_error'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadReservations,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'no_reservations'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'no_reservations_desc'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // Navigation vers l'onglet marché
              },
              icon: const Icon(Icons.add_rounded),
              label: Text('new_reservation'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'no_results'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'no_results_desc'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernReservationCard(Map<String, dynamic> reservation, int index) {
    final local = reservation['local'] as Map<String, dynamic>?;
    final periodicite = reservation['periodicite'] ?? '';
    final usage = reservation['usage'] ?? '';
    final dateDebutRaw = reservation['date_debut_loc'] ?? '';
    final dateFinRaw = reservation['date_fin_loc'] ?? '';
    final numero = local?['numero'] ?? '';
    final status = _getReservationStatus(dateDebutRaw, dateFinRaw);
    final isClickable = _isClickableReservation(periodicite);
    
    // Format dates
    final dateDebut = DateTime.tryParse(dateDebutRaw);
    final dateFin = DateTime.tryParse(dateFinRaw);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateDebutStr = dateDebut != null ? dateFormat.format(dateDebut) : '-';
    final dateFinStr = dateFin != null ? dateFormat.format(dateFin) : '-';
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutBack,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isClickable ? () {
            final locationId = reservation['id_location'];
            if (locationId != null) {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      LocationDetailScreen(
                        idLocation: locationId.toString(),
                        reservation: reservation,
                      ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      )),
                      child: child,
                    );
                  },
                ),
              );
            }
          } : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getContractColor(periodicite).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        periodicite.toLowerCase() == 'mensuel' ? Icons.calendar_month_rounded : Icons.calendar_today_rounded,
                        color: _getContractColor(periodicite),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'local_number_format'.tr(namedArgs: {'number': numero}),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1D1E),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            usage,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(status).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$dateDebutStr - $dateFinStr',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openContractViewer(context, reservation),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            Theme.of(context).primaryColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'view_contract'.tr(),
                            style: GoogleFonts.inter(
                              color: Theme.of(context).primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                minHeight: 160.0,
                maxHeight: 160.0,
                child: _buildStickyHeader(),
              ),
            ),
            _buildSliverReservationsList(),
          ],
        ),
        floatingActionButton: _shouldShowNewReservationButton() ? ModernFloatingButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('new_reservation_coming'.tr()),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          icon: Icons.add_rounded,
          label: 'new_reservation'.tr(),
          showPulseAnimation: true,
          elevation: 8,
        ) : null,
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 80.0,
      toolbarHeight: 80.0,
      collapsedHeight: 80.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Text(
        'reservation_title'.tr(),
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
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

  Widget _buildStickyHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStickySearchBar(),
          _buildFilterSection(),
        ],
      ),
    );
  }

  Widget _buildStickySearchBar() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'search_placeholder'.tr(),
              hintStyle: GoogleFonts.inter(
                color: Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade600),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 20.0,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'all_filter'.tr(),
                      isSelected: _selectedFilter == 'all_filter',
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'all_filter';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'ongoing_filter'.tr(),
                      isSelected: _selectedFilter == 'ongoing_filter',
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'ongoing_filter';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'upcoming_filter'.tr(),
                      isSelected: _selectedFilter == 'upcoming_filter',
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'upcoming_filter';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'finished_filter'.tr(),
                      isSelected: _selectedFilter == 'finished_filter',
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'finished_filter';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSliverReservationsList() {
    return SliverFillRemaining(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: FutureBuilder<ApiResponse<List<dynamic>>>(
          future: _reservationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildModernLoadingState();
            }
            if (snapshot.hasError) {
              return _buildModernErrorState(snapshot.error.toString());
            }
            final response = snapshot.data;
            if (response == null || !response.success || response.data == null || (response.data?.isEmpty ?? true)) {
              return _buildModernEmptyState();
            }
            final reservations = _filterReservations(_allReservations);
            if (reservations.isEmpty) {
              return _buildModernNoResultsState();
            }
            return RefreshIndicator(
              onRefresh: () async => _loadReservations(),
              color: Theme.of(context).colorScheme.primary,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: reservations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final reservation = reservations[index] as Map<String, dynamic>;
                  return _buildModernReservationCard(reservation, index);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  bool _shouldShowNewReservationButton() {
    // Afficher seulement dans le filtre "À venir"
    if (_selectedFilter != 'upcoming_filter') return false;
    
    final filteredReservations = _filterReservations(_allReservations);
    
    // Vérifier s'il y a des locations mensuelles dans cette section
    final hasMonthlyLocations = filteredReservations.any((reservation) {
      return reservation['periodicite'] == 'MENSUEL';
    });
    
    // Afficher le bouton seulement s'il y a des locations mensuelles
    return hasMonthlyLocations;
  }

  List<dynamic> _filterReservations(List<dynamic> reservations) {
    final now = DateTime.now();
    var filtered = reservations.where((reservation) {
      final dateDebut = DateTime.tryParse(reservation['date_debut_loc'] ?? '');
      final dateFin = DateTime.tryParse(reservation['date_fin_loc'] ?? '');
      
      if (dateDebut == null || dateFin == null) return false;
      
      switch (_selectedFilter) {
        case 'ongoing_filter':
          return dateDebut.isBefore(now) && dateFin.isAfter(now);
        case 'upcoming_filter':
          return dateDebut.isAfter(now);
        case 'finished_filter':
          return dateFin.isBefore(now);
        default:
          return true;
      }
    }).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((reservation) {
        final local = reservation['local'] as Map<String, dynamic>?;
        final numero = local?['numero']?.toString().toLowerCase() ?? '';
        final usage = reservation['usage']?.toString().toLowerCase() ?? '';
        final periodicite = reservation['periodicite']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        
        return numero.contains(query) || 
               usage.contains(query) || 
               periodicite.contains(query);
      }).toList();
    }

    return filtered;
  }


  String _getReservationStatus(String dateDebutRaw, String dateFinRaw) {
    final now = DateTime.now();
    final dateDebut = DateTime.tryParse(dateDebutRaw);
    final dateFin = DateTime.tryParse(dateFinRaw);
    
    if (dateDebut == null || dateFin == null) return 'unknown_status'.tr();
    
    if (dateDebut.isAfter(now)) {
      return 'upcoming_filter'.tr();
    } else if (dateFin.isBefore(now)) {
      return 'finished_status'.tr();
    } else {
      return 'ongoing_filter'.tr();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ongoing_filter':
        return Colors.green;
      case 'upcoming_filter':
        return Theme.of(context).primaryColor.withBlue(200);
      case 'finished_status':
        return Colors.grey;
      default:
        return Theme.of(context).primaryColor.withBlue(200);
    }
  }


  Color _getContractColor(String periodicite) {
    switch (periodicite.toLowerCase()) {
      case 'journalier':
        return Theme.of(context).primaryColor.withBlue(200);
      case 'hebdomadaire':
        return Colors.green;
      case 'mensuel':
        return Theme.of(context).primaryColor.withBlue(200);
      case 'annuel':
        return Theme.of(context).primaryColor.withBlue(200);
      default:
        return Colors.grey;
    }
  }

  bool _isClickableReservation(String periodicite) {
    return periodicite.toLowerCase() == 'journalier' || 
           periodicite.toLowerCase() == 'mensuel' || 
           periodicite.toLowerCase() == 'hebdomadaire';
  }



}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(maxHeight, minHeight);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
