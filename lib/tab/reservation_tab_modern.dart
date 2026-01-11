import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tsena_servisy/services/api_service.dart';
import 'package:tsena_servisy/services/user_service.dart';
import 'package:tsena_servisy/services/real_time_service.dart';
import '../models/api_response.dart' as model;
import '../screens/location_detail_screen.dart';
import '../utils/date_formatter.dart';
import '../components/custom_app_bar.dart';

class ReservationTab extends StatefulWidget {
  const ReservationTab({super.key});

  @override
  State<ReservationTab> createState() => _ReservationTabState();
}

class _ReservationTabState extends State<ReservationTab> with TickerProviderStateMixin {
  Timer? _debounceTimer;
  Future<model.ApiResponse<List<dynamic>>>? _reservationsFuture;
  String _selectedFilter = 'all';
  List<dynamic> _allReservations = [];
  StreamSubscription? _dataChangeSubscription;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadReservations();
    _setupDataChangeListener();
    _animationController.forward();
  }

  void _setupDataChangeListener() {
    final realTimeService = Provider.of<RealTimeService>(context, listen: false);
    _dataChangeSubscription = realTimeService.dataChangeStream.listen((dataType) {
      if (dataType.toString() == 'reservations') {
        debugPrint('🔄 Rafraîchissement automatique des réservations détecté');
        _loadReservations();
      }
    });
  }

  @override
  void dispose() {
    _dataChangeSubscription?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReservations() async {
    final user = await UserService.getUserProfile();
    debugPrint('User profile: $user');
    _reservationsFuture = ApiService().getUserLocations(user?['user_id'] ?? '').then((response) {
      _allReservations = response.data ?? [];
      return model.ApiResponse<List<dynamic>>(
        success: response.success,
        data: response.data,
        error: response.error,
      );
    });
    setState(() {});
  }

  Widget _buildModernSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Rechercher une réservation...',
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        onChanged: _onSearchChanged,
      ),
    );
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

  Widget _buildQuickStats() {
    final total = _allReservations.length;
    final enCours = _getReservationsByStatus('En cours').length;
    final aVenir = _getReservationsByStatus('À venir').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', total.toString(), Icons.event_note_rounded),
          _buildStatItem('En cours', enCours.toString(), Icons.play_circle_filled_rounded),
          _buildStatItem('À venir', aVenir.toString(), Icons.schedule_rounded),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildModernFilterChip(String label, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected 
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        selected: isSelected,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        side: BorderSide(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: isSelected ? 2 : 1,
        ),
        checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onSelected: (bool selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
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
    final dateDebut = DateFormatter.formatDateString(dateDebutRaw);
    final dateFin = DateFormatter.formatDateString(dateFinRaw);
    final numero = local?['numero'] ?? '';
    final status = _getReservationStatus(dateDebutRaw, dateFinRaw);
    final isClickable = _isClickableReservation(periodicite);

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutBack,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
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
          },
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
                        _getStatusIcon(status),
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
                            'local_number'.tr(namedArgs: {'number': numero}),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            usage,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getStatusColor(status).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                        if (isClickable)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'from_to_date'.tr(namedArgs: {'start': dateDebut, 'end': dateFin}),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getContractColor(periodicite).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          periodicite,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getContractColor(periodicite),
                          ),
                        ),
                      ),
                    ],
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(
        title: 'Mes Réservations',
      ),
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header avec recherche et statistiques rapides
              Container(
                margin: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildModernSearchBar(),
                    const SizedBox(height: 16),
                    _buildQuickStats(),
                  ],
                ),
              ),
              
              // Filtres modernes
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildModernFilterChip('Toutes', _selectedFilter == 'Toutes'),
                      const SizedBox(width: 12),
                      _buildModernFilterChip('En cours', _selectedFilter == 'En cours'),
                      const SizedBox(width: 12),
                      _buildModernFilterChip('À venir', _selectedFilter == 'À venir'),
                      const SizedBox(width: 12),
                      _buildModernFilterChip('Terminées', _selectedFilter == 'Terminées'),
                    ],
                  ),
                ),
              ),
              
              Expanded(
                child: FutureBuilder<model.ApiResponse<List<dynamic>>>(
                  future: _reservationsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildModernLoadingState();
                    }
                    if (snapshot.hasError) {
                      return _buildModernErrorState(snapshot.error.toString());
                    }
                    final response = snapshot.data;
                    if (response == null || !response.isSuccess || response.data == null || (response.data?.isEmpty ?? true)) {
                      return _buildModernEmptyState();
                    }
                    final reservations = _filterReservations(_allReservations);
                    if (reservations.isEmpty) {
                      return _buildModernNoResultsState();
                    }
                    return RefreshIndicator(
                      onRefresh: _loadReservations,
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
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('new_reservation_coming'.tr()),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text('new_reservation'.tr()),
      ),
    );
  }

  List<dynamic> _filterReservations(List<dynamic> reservations) {
    final now = DateTime.now();
    var filtered = reservations.where((reservation) {
      final dateDebut = DateTime.tryParse(reservation['date_debut_loc'] ?? '');
      final dateFin = DateTime.tryParse(reservation['date_fin_loc'] ?? '');
      
      if (dateDebut == null || dateFin == null) return false;
      
      switch (_selectedFilter) {
        case 'ongoing':
          return dateDebut.isBefore(now) && dateFin.isAfter(now);
        case 'upcoming':
          return dateDebut.isAfter(now);
        case 'finished':
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

  List<dynamic> _getReservationsByStatus(String status) {
    final now = DateTime.now();
    return _allReservations.where((reservation) {
      final dateDebut = DateTime.tryParse(reservation['date_debut_loc'] ?? '');
      final dateFin = DateTime.tryParse(reservation['date_fin_loc'] ?? '');
      
      if (dateDebut == null || dateFin == null) return false;
      
      switch (status) {
        case 'En cours':
          return dateDebut.isBefore(now) && dateFin.isAfter(now);
        case 'À venir':
          return dateDebut.isAfter(now);
        case 'Terminées':
          return dateFin.isBefore(now);
        default:
          return true;
      }
    }).toList();
  }

  String _getReservationStatus(String dateDebutRaw, String dateFinRaw) {
    final now = DateTime.now();
    final dateDebut = DateTime.tryParse(dateDebutRaw);
    final dateFin = DateTime.tryParse(dateFinRaw);
    
    if (dateDebut == null || dateFin == null) return 'Inconnu';
    
    if (dateDebut.isAfter(now)) {
      return 'À venir';
    } else if (dateFin.isBefore(now)) {
      return 'Terminée';
    } else {
      return 'En cours';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'En cours':
        return Colors.green;
      case 'À venir':
        return Colors.blue;
      case 'Terminée':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'En cours':
        return Icons.play_circle_filled_rounded;
      case 'À venir':
        return Icons.schedule_rounded;
      case 'Terminée':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getContractColor(String periodicite) {
    switch (periodicite.toLowerCase()) {
      case 'journalier':
        return Colors.blue;
      case 'hebdomadaire':
        return Colors.green;
      case 'mensuel':
        return Colors.orange;
      case 'annuel':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  bool _isClickableReservation(String periodicite) {
    return periodicite.toLowerCase() == 'journalier' || 
           periodicite.toLowerCase() == 'mensuel';
  }
}
