import 'package:flutter/material.dart';
import '../services/enhanced_notification_service.dart';

class NotificationInitializer extends StatefulWidget {
  final Widget child;
  
  const NotificationInitializer({
    super.key,
    required this.child,
  });

  @override
  State<NotificationInitializer> createState() => _NotificationInitializerState();
}

class _NotificationInitializerState extends State<NotificationInitializer> {
  final EnhancedNotificationService _notificationService = EnhancedNotificationService();
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeNotifications();
      _isInitialized = true;
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize(context);
      debugPrint('✅ Notifications initialisées avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
