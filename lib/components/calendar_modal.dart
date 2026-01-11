import 'package:flutter/material.dart';
import 'package:tsena_servisy/utils/date_formatter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tsena_servisy/models/local_model.dart';
import 'package:tsena_servisy/services/api_service.dart';
import 'package:tsena_servisy/services/user_service.dart';

class CalendarModal extends StatefulWidget {
  final LocalModel local;
  final Function(List<DateTime>) onConfirm;

  const CalendarModal({super.key, required this.local, required this.onConfirm});

  @override
  State<CalendarModal> createState() => _CalendarModalState();
}

class _CalendarModalState extends State<CalendarModal> {
  // Format de calendrier fixe
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  // Champs inutilisés commentés pour référence future
  // DateTime? _rangeStart;
  // DateTime? _rangeEnd;
  Set<DateTime> _selectedDays = {};

  // Jours occupés (depuis l'API)
  Set<DateTime> _occupiedDays = {};
  
  bool _isLoadingOccupiedDates = false;

  @override
  void initState() {
    super.initState();
    // Initialiser le format de date pour la locale française via DateFormatter
    DateFormatter.initialize();
    
    // Définir le jour actuel et initialiser les sélections
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDays = {};
    
    // Charger les jours occupés depuis l'API (à implémenter)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadOccupiedDates();
      }
    });
  }
  
  // Méthode pour charger les jours occupés depuis l'API
  Future<void> _loadOccupiedDates() async {
    if (!mounted) return;
    
    debugPrint('🚀 [CALENDAR] === DÉBUT CHARGEMENT DES DATES OCCUPÉES (API UNIQUEMENT) ===');
    debugPrint('🚀 [CALENDAR] Local sélectionné: ${widget.local.id} - ${widget.local.nom}');
    debugPrint('🚀 [CALENDAR] Numéro de place: ${widget.local.number}');
    
    setState(() {
      _isLoadingOccupiedDates = true;
    });
    
    try {
      debugPrint('🚀 [CALENDAR] Chargement des dates occupées via API endpoint...');
      // Utiliser UNIQUEMENT l'endpoint /servicemodernmarket/local/municipality/{municipalityId}/{localId}/occupied-dates
      await _loadAllOccupiedDates();
      
      debugPrint('🚀 [CALENDAR] === CHARGEMENT TERMINÉ AVEC SUCCÈS ===');
      debugPrint('🚀 [CALENDAR] Total dates occupées (API): ${_occupiedDays.length}');
      
    } catch (e, stackTrace) {
      debugPrint('❌ [CALENDAR] Erreur lors du chargement des dates occupées: $e');
      debugPrint('❌ [CALENDAR] Stack trace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOccupiedDates = false;
        });
        debugPrint('🚀 [CALENDAR] Indicateur de chargement désactivé');
      }
    }
  }


  // Charger toutes les dates occupées du local (tous utilisateurs)
  Future<void> _loadAllOccupiedDates() async {
    try {
      final userProfile = await UserService.getUserProfile();
      final municipalityId = userProfile?['municipality_id']?.toString() ?? 
                            userProfile?['municipalityId']?.toString();
      
      if (municipalityId == null) {
        debugPrint('❌ [ALL_DATES] Municipality ID non trouvé dans le profil utilisateur');
        debugPrint('❌ [ALL_DATES] Profil utilisateur: $userProfile');
        return;
      }

      debugPrint('📅 [ALL_DATES] === DÉBUT CHARGEMENT TOUTES DATES OCCUPÉES ===');
      debugPrint('📅 [ALL_DATES] LocalId: ${widget.local.id}');
      debugPrint('📅 [ALL_DATES] Nom du local: ${widget.local.nom}');
      debugPrint('📅 [ALL_DATES] MunicipalityId: $municipalityId');
      debugPrint('📅 [ALL_DATES] URL: GET /servicemodernmarket/local/municipality/$municipalityId/${widget.local.id}/occupied-dates');

      final apiService = ApiService();
      final response = await apiService.getLocalOccupiedDates(municipalityId, widget.local.id);

      if (response.success && response.data != null) {
        final occupiedDatesData = response.data!;
        debugPrint('📅 [ALL_DATES] Réponse API reçue avec ${occupiedDatesData.length} plages de dates');
        
        Set<DateTime> allOccupiedDates = {};
        int rangeProcessed = 0;

        for (final dateRange in occupiedDatesData) {
          rangeProcessed++;
          debugPrint('📅 [ALL_DATES] --- Plage $rangeProcessed ---');
          debugPrint('📅 [ALL_DATES] Données brutes: $dateRange');
          
          final dateDebutStr = dateRange['date_debut_loc']?.toString();
          final dateFinStr = dateRange['date_fin_loc']?.toString();
          
          debugPrint('📅 [ALL_DATES] Date début brute: $dateDebutStr');
          debugPrint('📅 [ALL_DATES] Date fin brute: $dateFinStr');
          
          if (dateDebutStr != null && dateFinStr != null) {
            final dateDebut = DateTime.tryParse(dateDebutStr);
            final dateFin = DateTime.tryParse(dateFinStr);
            
            debugPrint('📅 [ALL_DATES] Date début parsée: $dateDebut');
            debugPrint('📅 [ALL_DATES] Date fin parsée: $dateFin');
            
            if (dateDebut != null && dateFin != null) {
              // Ajouter toutes les dates entre début et fin (inclus)
              DateTime current = DateTime(dateDebut.year, dateDebut.month, dateDebut.day);
              final end = DateTime(dateFin.year, dateFin.month, dateFin.day);
              
              debugPrint('📅 [ALL_DATES] Génération des dates de $current à $end');
              
              int daysInRange = 0;
              while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
                allOccupiedDates.add(current);
                daysInRange++;
                debugPrint('📅 [ALL_DATES]   ✅ Date ajoutée: $current');
                current = current.add(const Duration(days: 1));
              }
              
              debugPrint('📅 [ALL_DATES] $daysInRange jours ajoutés pour cette plage');
            } else {
              debugPrint('❌ [ALL_DATES] Impossible de parser les dates de la plage $rangeProcessed');
            }
          } else {
            debugPrint('⚠️ [ALL_DATES] Dates manquantes dans la plage $rangeProcessed');
          }
        }

        debugPrint('📅 [ALL_DATES] === RÉSUMÉ CHARGEMENT TOUTES DATES ===');
        debugPrint('📅 [ALL_DATES] Plages traitées: $rangeProcessed');
        debugPrint('📅 [ALL_DATES] Total dates occupées: ${allOccupiedDates.length}');

        if (mounted) {
          setState(() {
            // Utiliser TOUTES les dates occupées de l'API
            _occupiedDays = allOccupiedDates;
          });
          
          debugPrint('📅 [ALL_DATES] Dates occupées (API uniquement): ${_occupiedDays.length}');
          debugPrint('📅 [ALL_DATES] Liste des dates occupées: $_occupiedDays');
        }
      } else {
        debugPrint('❌ [ALL_DATES] Échec de récupération des dates occupées');
        debugPrint('❌ [ALL_DATES] Success: ${response.success}');
        debugPrint('❌ [ALL_DATES] Error: ${response.error}');
        debugPrint('❌ [ALL_DATES] Data: ${response.data}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [ALL_DATES] Erreur lors du chargement des dates occupées: $e');
      debugPrint('❌ [ALL_DATES] Stack trace: $stackTrace');
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!mounted) return;
    
    // Vérifier si le jour est dans la plage autorisée et non occupé
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(now.year, now.month + 1, now.day);
    
    // Vérifier si le jour est dans la plage autorisée et non occupé (API uniquement)
    if (selectedDay.isBefore(today) || 
        selectedDay.isAfter(lastDay) ||
        _occupiedDays.any((day) => 
          day.year == selectedDay.year &&
          day.month == selectedDay.month &&
          day.day == selectedDay.day
        )) {
      // Afficher un message informatif pour les dates occupées
      if (_occupiedDays.any((day) => 
          day.year == selectedDay.year &&
          day.month == selectedDay.month &&
          day.day == selectedDay.day
        )) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cette date est déjà occupée'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _focusedDay = focusedDay;
      
      // Créer une nouvelle liste pour forcer le rafraîchissement
      final newSelectedDays = Set<DateTime>.from(_selectedDays);
      
      if (newSelectedDays.contains(selectedDay)) {
        newSelectedDays.remove(selectedDay);
      } else {
        newSelectedDays.add(selectedDay);
      }
      
      _selectedDays = newSelectedDays;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Définir la plage de dates affichée (du 12 septembre au 12 octobre)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = today; // 12 septembre
    final lastDay = DateTime(now.year, now.month + 1, now.day); // 12 octobre

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Utiliser une fraction de la largeur de l'écran pour une meilleure adaptation
          final width = constraints.maxWidth > 500 ? 500.0 : constraints.maxWidth * 0.9;
          
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Place N° ${widget.local.number}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sélectionnez les jours de réservation (12/09 - 12/10)',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    _buildCalendar(firstDay, lastDay),
                    const SizedBox(height: 8),
                    _buildLegend(),
                    const SizedBox(height: 16),
                    _buildSummary(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendar(DateTime firstDay, DateTime lastDay) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: TableCalendar(
          locale: 'fr_FR',
          firstDay: firstDay,
          lastDay: lastDay,
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          availableCalendarFormats: const {
            CalendarFormat.month: 'Mois',
          },
          availableGestures: AvailableGestures.all,
          headerVisible: true,
          daysOfWeekHeight: 32.0,
          rowHeight: 40.0,
          selectedDayPredicate: (day) => _selectedDays.any((selectedDay) => 
            selectedDay.year == day.year &&
            selectedDay.month == day.month &&
            selectedDay.day == day.day
          ),
          onDaySelected: _onDaySelected,
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 12),
            weekendStyle: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12),
          ),
          calendarStyle: CalendarStyle(
            // Style pour aujourd'hui
            todayDecoration: BoxDecoration(
              color: Colors.orange.withValues(red: 255, green: 165, blue: 0, alpha: 0.7),
              shape: BoxShape.circle,
            ),
            // Style pour les jours sélectionnés
            selectedDecoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            // Style pour les jours désactivés (en dehors de la plage)
            disabledTextStyle: TextStyle(
              color: Colors.grey[400],
              decoration: TextDecoration.lineThrough,
            ),
            // Style par défaut des jours
            defaultTextStyle: const TextStyle(
              fontSize: 14.0,
              color: Colors.black87,
            ),
            // Style des week-ends
            weekendTextStyle: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
            // Style pour les jours en dehors du mois
            outsideTextStyle: const TextStyle(
              color: Colors.transparent,
            ),
            // Cacher les jours en dehors du mois et configurer la mise en page
            outsideDaysVisible: false,
            cellMargin: const EdgeInsets.all(1),
            cellPadding: EdgeInsets.zero,
          ),
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false, // Cacher le bouton de format
            titleTextStyle: const TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: const Icon(Icons.chevron_left, size: 24, color: Colors.green),
            rightChevronIcon: const Icon(Icons.chevron_right, size: 24, color: Colors.green),
            leftChevronMargin: const EdgeInsets.only(left: 8.0),
            rightChevronMargin: const EdgeInsets.only(right: 8.0),
            headerMargin: const EdgeInsets.only(bottom: 8),
            titleTextFormatter: (date, locale) => DateFormatter.formatMonthYear(date),
          ),
          calendarBuilders: CalendarBuilders(
            // Personnalisation de l'affichage des jours normaux
            defaultBuilder: (context, date, _) {
              return Center(
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              );
            },
            // Style pour les jours désactivés (passés, hors plage ou occupés)
            disabledBuilder: (context, date, _) {
              final isOccupied = _occupiedDays.any((day) => 
                day.year == date.year &&
                day.month == date.month &&
                day.day == date.day
              );
              
              // Style pour les jours occupés (rouge)
              if (isOccupied) {
                return Container(
                  margin: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red, width: 1.0),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }
              
              // Style pour les jours en dehors de la plage (gris)
              return Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),
              );
            },
            // Marqueur pour les jours occupés
            markerBuilder: (context, date, events) {
              final isOccupied = _occupiedDays.any((day) => 
                day.year == date.year &&
                day.month == date.month &&
                day.day == date.day
              );
              
              // Marqueur pour les jours occupés (croix rouge)
              if (isOccupied) {
                return Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                );
              }
              
              return null;
            },
          ),
          // Désactiver les jours passés, les jours occupés et les jours hors plage
          enabledDayPredicate: (date) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final lastDay = DateTime(now.year, now.month + 1, now.day);
            
            // Vérifier si le jour est occupé (API uniquement)
            final isOccupied = _occupiedDays.any((day) => 
              day.year == date.year &&
              day.month == date.month &&
              day.day == date.day
            );
            
            // Vérifier si le jour est dans la plage autorisée
            final isInRange = !date.isBefore(today) && !date.isAfter(lastDay);
            
            return isInRange && !isOccupied;
          },
            ),
          ),
          // Indicateur de chargement
          if (_isLoadingOccupiedDates)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text(
                        'Chargement des dates occupées...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Légende pour les dates occupées
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 1.0),
                ),
                child: Icon(
                  Icons.close,
                  size: 10,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Occupé',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Légende pour les dates disponibles
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 1.0),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Disponible',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final tarif = widget.local.typeLocal?['tarif'] as num? ?? 0;
    final total = tarif * _selectedDays.length;
    
    // Trier les jours sélectionnés
    final sortedDays = _selectedDays.toList()..sort((a, b) => a.compareTo(b));
    
    // Formater la plage de dates si plusieurs jours sont sélectionnés
    String dateRangeText = 'Aucun jour sélectionné';
    if (sortedDays.isNotEmpty) {
      if (sortedDays.length == 1) {
        dateRangeText = 'Le ${DateFormatter.formatShortDate(sortedDays.first)}';
      } else {
        dateRangeText = '${sortedDays.length} jours (${DateFormatter.formatShortDate(sortedDays.first)} - ${DateFormatter.formatShortDate(sortedDays.last)})';
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _selectedDays.isNotEmpty ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedDays.isNotEmpty ? (Colors.green[200] ?? Colors.green) : (Colors.grey[300] ?? Colors.grey),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Résumé de la réservation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (_selectedDays.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_selectedDays.length} ${_selectedDays.length > 1 ? 'jours' : 'jour'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dateRangeText,
            style: TextStyle(
              color: _selectedDays.isNotEmpty ? Colors.grey[800] : Colors.grey[600],
              fontStyle: _selectedDays.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (_selectedDays.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total estimé :'),
                Text(
                  '${total.toStringAsFixed(0)} Ar',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ANNULER'),
        ),
        ElevatedButton(
          onPressed: _selectedDays.isNotEmpty
              ? () {
                  // Trier les jours avant de les envoyer
                  final sortedDays = _selectedDays.toList()..sort((a, b) => a.compareTo(b));
                  widget.onConfirm(sortedDays);
                  // Removed Navigator.of(context).pop() and SnackBar - handled by parent
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Confirmer', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
