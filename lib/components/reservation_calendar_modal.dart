import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';

class ReservationCalendarModal extends StatefulWidget {
  const ReservationCalendarModal({super.key});

  @override
  State<ReservationCalendarModal> createState() => _ReservationCalendarModalState();
}

class _ReservationCalendarModalState extends State<ReservationCalendarModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reservations = [];
  Set<DateTime> _reservationDates = {};
  DateTime _selectedMonth = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Récupérer l'ID utilisateur
      final userProfile = await UserService.getUserProfile();
      final userId = userProfile?['user_id']?.toString();
      
      if (userId == null || userId.isEmpty) {
        throw Exception('ID utilisateur non trouvé');
      }

      debugPrint('📅 Chargement des réservations en cours pour userId: $userId');

      // Appeler l'API pour récupérer les locations en cours
      final apiService = ApiService();
      final response = await apiService.getUserLocationsEnCours(userId);

      if (response.success && response.data != null) {
        final reservations = response.data as List<dynamic>;
        debugPrint('📅 ${reservations.length} réservations trouvées');

        // Extraire toutes les dates de réservation
        Set<DateTime> dates = {};
        List<Map<String, dynamic>> reservationsList = [];

        for (final reservation in reservations) {
          final reservationMap = reservation as Map<String, dynamic>;
          reservationsList.add(reservationMap);

          // Extraire UNIQUEMENT les dates de location (plus précises)
          if (reservationMap['periodicite'] == 'JOURNALIER') {
            final dateDebutLoc = DateTime.tryParse(reservationMap['date_debut_loc']?.toString() ?? '');
            final dateFinLoc = DateTime.tryParse(reservationMap['date_fin_loc']?.toString() ?? '');
            
            if (dateDebutLoc != null && dateFinLoc != null) {
              // Ajouter toutes les dates entre début et fin de location
              DateTime current = DateTime(dateDebutLoc.year, dateDebutLoc.month, dateDebutLoc.day);
              final end = DateTime(dateFinLoc.year, dateFinLoc.month, dateFinLoc.day);
              
              while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
                dates.add(current);
                current = current.add(const Duration(days: 1));
              }
            }
          } else {
            // Pour les contrats mensuels, utiliser les dates de paiement
            final paiementLocations = reservationMap['paiement_locations'] as List<dynamic>? ?? [];
            
            for (final paiement in paiementLocations) {
              final paiementMap = paiement as Map<String, dynamic>;
              
              final dateDebutStr = paiementMap['date_debut']?.toString();
              final dateFinStr = paiementMap['date_fin']?.toString();
              
              if (dateDebutStr != null && dateFinStr != null) {
                final dateDebut = DateTime.tryParse(dateDebutStr);
                final dateFin = DateTime.tryParse(dateFinStr);
                
                if (dateDebut != null && dateFin != null) {
                  // Ajouter toutes les dates de la période payée
                  DateTime current = DateTime(dateDebut.year, dateDebut.month, dateDebut.day);
                  final end = DateTime(dateFin.year, dateFin.month, dateFin.day);
                  
                  while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
                    dates.add(current);
                    current = current.add(const Duration(days: 1));
                  }
                }
              }
            }
          }
        }

        debugPrint('📅 ${dates.length} dates de réservation extraites');

        if (mounted) {
          setState(() {
            _reservations = reservationsList;
            _reservationDates = dates;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(response.error ?? 'Erreur lors du chargement des réservations');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des réservations: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _changeMonth(int monthOffset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthOffset);
    });
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    // Jours de la semaine
    final weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return Column(
      children: [
        // En-tête avec navigation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: Icon(Icons.chevron_left, color: Colors.grey.shade700),
              ),
              Text(
                DateFormat('MMMM yyyy', 'fr').format(_selectedMonth),
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: Icon(Icons.chevron_right, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),

        // Jours de la semaine
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
          ),
          child: Row(
            children: weekdays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            )).toList(),
          ),
        ),

        // Grille du calendrier
        Container(
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 42, // 6 semaines max
            itemBuilder: (context, index) {
              final dayOffset = index - (firstWeekday - 1);
              
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox(); // Cellule vide
              }

              final day = dayOffset + 1;
              final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
              final isReserved = _reservationDates.contains(date);
              final isToday = DateTime.now().day == day && 
                             DateTime.now().month == _selectedMonth.month && 
                             DateTime.now().year == _selectedMonth.year;

              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isReserved 
                      ? Colors.green.shade100
                      : isToday 
                          ? Colors.blue.shade100
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isReserved 
                      ? Border.all(color: Colors.green.shade400, width: 2)
                      : isToday
                          ? Border.all(color: Colors.blue.shade400, width: 2)
                          : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.toString(),
                        style: TextStyle(
                          fontWeight: isReserved || isToday ? FontWeight.bold : FontWeight.normal,
                          color: isReserved 
                              ? Colors.green.shade700
                              : isToday
                                  ? Colors.blue.shade700
                                  : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      if (isReserved)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReservationsList() {
    if (_reservations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune réservation en cours',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _reservations.length,
        itemBuilder: (context, index) {
          final reservation = _reservations[index];
          final local = reservation['local'] as Map<String, dynamic>? ?? {};
          final periodicite = reservation['periodicite']?.toString() ?? '';
          final usage = reservation['usage']?.toString() ?? 'Usage non spécifié';
          final localNumber = local['numero']?.toString() ?? 'N/A';

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: periodicite == 'JOURNALIER' 
                        ? Colors.orange.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    periodicite == 'JOURNALIER' 
                        ? Icons.today
                        : Icons.calendar_month,
                    color: periodicite == 'JOURNALIER' 
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local $localNumber',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        usage,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        periodicite,
                        style: TextStyle(
                          color: periodicite == 'JOURNALIER' 
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade700],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Calendrier des réservations',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Contenu
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Chargement des réservations...'),
                          ],
                        ),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Erreur de chargement',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadReservations,
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildCalendar(),
                              const Divider(height: 1),
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Réservations en cours',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildReservationsList(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
