import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'new_home_tab.dart';
import '../tab/reservation_tab.dart'; // Reuse existing for now
import '../tab/payement_history_tab.dart'; // Reuse existing for now
import '../tab/notification_tab.dart'; // Reuse existing for now
import '../tab/profile_tab.dart'; // Reuse existing for now
import '../services/real_time_service.dart';
import '../services/enhanced_notification_service.dart';
import '../services/data_refresh_service.dart';

class NewMainNavigation extends StatefulWidget {
  const NewMainNavigation({super.key});

  static NewMainNavigationState? of(BuildContext context) => 
      context.findAncestorStateOfType<NewMainNavigationState>();

  @override
  State<NewMainNavigation> createState() => NewMainNavigationState();
}

class NewMainNavigationState extends State<NewMainNavigation> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late RealTimeService _realTimeService;
  late DataRefreshService _dataRefreshService;
  final EnhancedNotificationService _enhancedNotificationService = EnhancedNotificationService();
  final ScrollController _profileScrollController = ScrollController();
  late AnimationController _badgeAnimationController;
  late Animation<double> _badgeScaleAnimation;

  // Keys to preserve state
  final GlobalKey _homeTabKey = GlobalKey();
  final GlobalKey _reservationTabKey = GlobalKey();
  final GlobalKey _notificationTabKey = GlobalKey();
  final GlobalKey _paymentHistoryTabKey = GlobalKey();
  final GlobalKey _profileTabKey = GlobalKey();

  late final List<Widget> _tabs;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _realTimeService = RealTimeService();
    _realTimeService.startRealTimeUpdates();
    
    _dataRefreshService = DataRefreshService();
    _dataRefreshService.initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });

    _tabs = [
      NewHomeTab(key: _homeTabKey),
      ReservationTab(key: _reservationTabKey),
      NotificationTab(key: _notificationTabKey),
      PaymentHistoryTab(key: _paymentHistoryTabKey),
      ProfileTab(key: _profileTabKey, scrollController: _profileScrollController),
    ];

    _badgeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _badgeScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _badgeAnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeNotifications() async {
    try {
      await _enhancedNotificationService.initialize(context);
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _badgeAnimationController.dispose();
    _profileScrollController.dispose();
    _realTimeService.stopRealTimeUpdates();
    super.dispose();
  }

  void changeTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      setState(() {
        _currentIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe to avoid conflicts
        children: _tabs,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: Consumer<RealTimeService>(
        builder: (context, realTimeService, child) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, FontAwesomeIcons.house, FontAwesomeIcons.house, 'home'),
                    _buildNavItem(1, FontAwesomeIcons.map, FontAwesomeIcons.map, 'reservations'),
                    _buildCenterNavItemWithBadge(2, FontAwesomeIcons.bell, FontAwesomeIcons.bell, realTimeService.unreadNotificationCount),
                    _buildNavItem(3, FontAwesomeIcons.creditCard, FontAwesomeIcons.creditCard, 'payments'),
                    _buildNavItem(4, FontAwesomeIcons.user, FontAwesomeIcons.user, 'profile'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String labelKey) {
    final isSelected = _currentIndex == index;
    
    return Flexible(
      child: InkWell(
        onTap: () => changeTab(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withBlue(200),
                        ],
                      ).createShader(bounds),
                      child: Icon(
                        inactiveIcon, // Always use outlined icon
                        color: Colors.white, // Required for ShaderMask
                        size: 24, // Same size as inactive
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withBlue(200),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          tr(labelKey),
                          style: const TextStyle(
                            color: Colors.white, // Required for ShaderMask
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Icon(
                      inactiveIcon,
                      color: Colors.grey.shade500,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr(labelKey),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterNavItemWithBadge(int index, IconData activeIcon, IconData inactiveIcon, int badgeCount) {
    final isSelected = _currentIndex == index;
    
    return Flexible(
      child: InkWell(
        onTap: () => changeTab(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (isSelected)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withBlue(200),
                        ],
                      ).createShader(bounds),
                      child: Icon(
                        inactiveIcon, // Always use outlined icon
                        color: Colors.white, // Required for ShaderMask
                        size: 24, // Same size as inactive
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withBlue(200),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          tr('notifications'), // Label for notification tab
                          style: const TextStyle(
                            color: Colors.white, // Required for ShaderMask
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      inactiveIcon,
                      color: Colors.grey.shade500,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr('notifications'),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              // Badge de notification (Point rouge qui bat)
              if (badgeCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: AnimatedBuilder(
                    animation: _badgeScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _badgeScaleAnimation.value,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
