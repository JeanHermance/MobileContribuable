import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../tab/home_tab.dart';
import '../tab/reservation_tab.dart';
import '../tab/payement_history_tab.dart';
import '../tab/notification_tab.dart';
import '../tab/profile_tab.dart';
import '../services/real_time_service.dart';
import '../services/enhanced_notification_service.dart';
import '../services/data_refresh_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  static MainNavigationState? of(BuildContext context) => 
      context.findAncestorStateOfType<MainNavigationState>();

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late RealTimeService _realTimeService;
  late DataRefreshService _dataRefreshService;
  final EnhancedNotificationService _enhancedNotificationService = EnhancedNotificationService();

  final ScrollController _profileScrollController = ScrollController();
  // Animations supprimées pour éviter les rebuilds inutiles

  late final List<Widget> _tabs = [];
  
  // Clés pour préserver l'état des onglets
  final GlobalKey _homeTabKey = GlobalKey();
  final GlobalKey _reservationTabKey = GlobalKey();
  final GlobalKey _notificationTabKey = GlobalKey();
  final GlobalKey _paymentHistoryTabKey = GlobalKey();
  final GlobalKey _profileTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _realTimeService = RealTimeService();
    _realTimeService.startRealTimeUpdates();
    
    // Initialiser le service de rechargement de données
    _dataRefreshService = DataRefreshService();
    _dataRefreshService.initialize();
    
    // Animations supprimées pour optimiser les performances
    
    // Plus besoin de PageController avec IndexedStack
    
    // Initialiser le service de notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
    
    // Initialiser les onglets avec des clés pour préserver l'état
    _tabs.addAll([
      HomeTab(key: _homeTabKey),
      ReservationTab(key: _reservationTabKey),
      NotificationTab(key: _notificationTabKey),
      PaymentHistoryTab(key: _paymentHistoryTabKey),
      ProfileTab(key: _profileTabKey, scrollController: _profileScrollController),
    ]);
  }
  
  Future<void> _initializeNotifications() async {
    try {
      await _enhancedNotificationService.initialize(context);
      debugPrint('✅ Service de notifications initialisé dans MainNavigation');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des notifications: $e');
    }
  }

  @override
  void dispose() {
    _profileScrollController.dispose();
    _realTimeService.stopRealTimeUpdates();
    // Plus d'animations à disposer
    super.dispose();
  }

  void changeTab(int index, {String? reservationFilter, String? paymentFilter}) {
    if (index >= 0 && index < _tabs.length) {
      // Suppression de la vibration pour éviter les effets
      
      // Pour l'instant, on garde la navigation simple sans filtres dynamiques
      // Les filtres seront gérés directement dans les onglets
      if (reservationFilter != null) {
        debugPrint('📝 Filtre réservation demandé: $reservationFilter');
      }
      if (paymentFilter != null) {
        debugPrint('💳 Filtre paiement demandé: $paymentFilter');
      }
      
      setState(() {
        _currentIndex = index;
      });
    }
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required BuildContext context,
    Widget? badge,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: badge != null 
            ? Badge(child: Icon(icon, size: 24))
            : Icon(icon, size: 24),
      ),
      activeIcon: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: badge != null 
            ? Badge(child: Icon(activeIcon, size: 24, color: Theme.of(context).colorScheme.primary))
            : Icon(activeIcon, size: 24, color: Theme.of(context).colorScheme.primary),
      ),
      label: label,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Consumer<RealTimeService>(
        builder: (context, realTimeService, child) {
          return Container(
            height: 85,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      changeTab(index);
                    },
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: Theme.of(context).colorScheme.primary,
                    unselectedItemColor: Colors.grey.shade400,
                    selectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      color: Colors.grey.shade400,
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    showSelectedLabels: true,
                    showUnselectedLabels: true,
                    selectedFontSize: 12,
                    unselectedFontSize: 11,
                    enableFeedback: false,
              items: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'home'.tr(),
                  context: context,
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.event_note_outlined,
                  activeIcon: Icons.event_note,
                  label: 'reservations'.tr(),
                  context: context,
                  index: 1,
                ),
                // Bouton central avec couleur primary et badge
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: realTimeService.unreadNotificationCount > 0,
                    label: Text(
                      realTimeService.unreadNotificationCount > 99 
                          ? '99+' 
                          : '${realTimeService.unreadNotificationCount}',
                    ),
                    backgroundColor: Colors.red,
                    alignment: Alignment.topRight,
                    offset: const Offset(8, -8),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  activeIcon: Badge(
                    isLabelVisible: realTimeService.unreadNotificationCount > 0,
                    label: Text(
                      realTimeService.unreadNotificationCount > 99 
                          ? '99+' 
                          : '${realTimeService.unreadNotificationCount}',
                    ),
                    backgroundColor: Colors.red,
                    alignment: Alignment.topRight,
                    offset: const Offset(8, -8),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  label: '',
                ),
                _buildNavItem(
                  icon: Icons.payment_outlined,
                  activeIcon: Icons.payment,
                  label: 'payments'.tr(),
                  context: context,
                  index: 3,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'profile'.tr(),
                  context: context,
                  index: 4,
                ),
              ],
                ),
            ),
          );
        },
      ),
    );
  }
}