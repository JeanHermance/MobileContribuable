import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';

class PlaceCalendarModal extends StatefulWidget {
  final String municipalityId;
  final String localId;
  final String placeName;

  const PlaceCalendarModal({
    super.key,
    required this.municipalityId,
    required this.localId,
    required this.placeName,
  });

  @override
  State<PlaceCalendarModal> createState() => _PlaceCalendarModalState();
}

class _PlaceCalendarModalState extends State<PlaceCalendarModal> with SingleTickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _occupiedDates = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _animationController.forward();
    _loadOccupiedDates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadOccupiedDates() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getLocalOccupiedDates(
        widget.municipalityId,
        widget.localId,
      );

      if (response.success && response.data != null) {
        setState(() {
          _occupiedDates = response.data!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement dates occupées: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isDateOccupied(DateTime day) {
    return _occupiedDates.any((occupied) {
      final startDate = DateTime.tryParse(occupied['dateDebutLoc']?.toString() ?? '');
      final endDate = DateTime.tryParse(occupied['dateFinLoc']?.toString() ?? '');
      
      if (startDate == null || endDate == null) return false;
      
      final dayStart = DateTime(day.year, day.month, day.day);
      final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
      final rangeEnd = DateTime(endDate.year, endDate.month, endDate.day);
      
      return dayStart.isAtSameMomentAs(rangeStart) ||
             dayStart.isAtSameMomentAs(rangeEnd) ||
             (dayStart.isAfter(rangeStart) && dayStart.isBefore(rangeEnd));
    });
  }

  Map<String, dynamic>? _getOccupationInfo(DateTime day) {
    for (var occupied in _occupiedDates) {
      final startDate = DateTime.tryParse(occupied['dateDebutLoc']?.toString() ?? '');
      final endDate = DateTime.tryParse(occupied['dateFinLoc']?.toString() ?? '');
      
      if (startDate == null || endDate == null) continue;
      
      final dayStart = DateTime(day.year, day.month, day.day);
      final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
      final rangeEnd = DateTime(endDate.year, endDate.month, endDate.day);
      
      if (dayStart.isAtSameMomentAs(rangeStart) ||
          dayStart.isAtSameMomentAs(rangeEnd) ||
          (dayStart.isAfter(rangeStart) && dayStart.isBefore(rangeEnd))) {
        return occupied;
      }
    }
    return null;
  }

  void _showOccupationDetails(Map<String, dynamic> occupation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_busy_rounded,
                    color: Colors.red.shade400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'occupation_details'.tr(),
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1D1E),
                        ),
                      ),
                      Text(
                        widget.placeName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow(
              icon: Icons.person_outline_rounded,
              label: 'occupied_by'.tr(),
              value: occupation['userName']?.toString() ?? 'unknown_user'.tr(),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'start_date'.tr(),
              value: _formatDate(occupation['dateDebutLoc']?.toString()),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.event_rounded,
              label: 'end_date'.tr(),
              value: _formatDate(occupation['dateFinLoc']?.toString()),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.schedule_rounded,
              label: 'period_type'.tr(),
              value: occupation['periodicite']?.toString() ?? 'unknown_period'.tr(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'close'.tr(),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
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
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'unknown_date'.tr();
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy', context.locale.toString()).format(date);
    } catch (e) {
      return 'unknown_date'.tr();
    }
  }

  void _closeModal() {
    _animationController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeModal();
        }
      },
      child: GestureDetector(
        onTap: _closeModal,
        child: Material(
          color: Colors.black.withValues(alpha: 0.5),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when tapping inside
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(maxWidth: 500),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).primaryColor.withBlue(200),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'place_calendar'.tr(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.placeName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _closeModal,
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Calendar
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                TableCalendar(
                                  firstDay: DateTime.utc(2020, 1, 1),
                                  lastDay: DateTime.utc(2030, 12, 31),
                                  focusedDay: _focusedDay,
                                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                  calendarFormat: CalendarFormat.month,
                                  startingDayOfWeek: StartingDayOfWeek.monday,
                                  headerStyle: HeaderStyle(
                                    formatButtonVisible: false,
                                    titleCentered: true,
                                    titleTextStyle: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1A1D1E),
                                    ),
                                    leftChevronIcon: Icon(
                                      Icons.chevron_left_rounded,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    rightChevronIcon: Icon(
                                      Icons.chevron_right_rounded,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  calendarStyle: CalendarStyle(
                                    todayDecoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    selectedDecoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    markerDecoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                    outsideDaysVisible: false,
                                  ),
                                  calendarBuilders: CalendarBuilders(
                                    defaultBuilder: (context, day, focusedDay) {
                                      if (_isDateOccupied(day)) {
                                        return Container(
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.red.shade300,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${day.day}',
                                              style: GoogleFonts.inter(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                  onDaySelected: (selectedDay, focusedDay) {
                                    setState(() {
                                      _selectedDay = selectedDay;
                                      _focusedDay = focusedDay;
                                    });
                                    
                                    final occupationInfo = _getOccupationInfo(selectedDay);
                                    if (occupationInfo != null) {
                                      _showOccupationDetails(occupationInfo);
                                    }
                                  },
                                  onPageChanged: (focusedDay) {
                                    _focusedDay = focusedDay;
                                  },
                                ),
                                const SizedBox(height: 20),
                                // Legend
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildLegendItem(
                                      color: Colors.red.shade300,
                                      label: 'occupied'.tr(),
                                    ),
                                    const SizedBox(width: 24),
                                    _buildLegendItem(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                                      label: 'today'.tr(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
