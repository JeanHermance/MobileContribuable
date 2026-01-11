import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/notification_model.dart';
import 'notification_sound_service.dart';

/// Service pour afficher les alertes de notification en haut de l'écran
class NotificationAlertService {
  static OverlayEntry? _currentOverlay;
  static bool _isShowing = false;

  /// Affiche une alerte de notification en haut de l'écran
  static void showNotificationAlert(
    BuildContext context,
    NotificationModel notification, {
    Duration duration = const Duration(seconds: 4),
  }) {
    // Ne pas afficher si une alerte est déjà visible
    if (_isShowing) {
      debugPrint('🚫 Alerte déjà visible, ignorée');
      return;
    }

    // Jouer le son de notification si activé
    NotificationSoundService.playNotificationSound();

    _isShowing = true;
    
    final overlay = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (context) => _NotificationAlertWidget(
        notification: notification,
        onDismiss: () => _dismissAlert(),
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto-dismiss après la durée spécifiée
    Future.delayed(duration, () {
      _dismissAlert();
    });
  }

  /// Affiche une alerte personnalisée
  static void showCustomAlert(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (_isShowing) return;

    NotificationSoundService.playNotificationSound();
    _isShowing = true;

    final overlay = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (context) => _CustomAlertWidget(
        title: title,
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        onDismiss: () => _dismissAlert(),
      ),
    );

    overlay.insert(_currentOverlay!);

    Future.delayed(duration, () {
      _dismissAlert();
    });
  }

  /// Ferme l'alerte actuelle
  static void _dismissAlert() {
    if (_currentOverlay != null && _isShowing) {
      _currentOverlay!.remove();
      _currentOverlay = null;
      _isShowing = false;
      debugPrint('🔔 Alerte fermée');
    }
  }

  /// Force la fermeture de toute alerte
  static void dismissAll() {
    _dismissAlert();
  }
}

/// Widget pour afficher l'alerte de notification
class _NotificationAlertWidget extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onDismiss;

  const _NotificationAlertWidget({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_NotificationAlertWidget> createState() => _NotificationAlertWidgetState();
}

class _NotificationAlertWidgetState extends State<_NotificationAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: InkWell(
              onTap: widget.onDismiss,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'notifications_title'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notification.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pour afficher une alerte personnalisée
class _CustomAlertWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color? backgroundColor;
  final VoidCallback onDismiss;

  const _CustomAlertWidget({
    required this.title,
    required this.message,
    required this.icon,
    this.backgroundColor,
    required this.onDismiss,
  });

  @override
  State<_CustomAlertWidget> createState() => _CustomAlertWidgetState();
}

class _CustomAlertWidgetState extends State<_CustomAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: widget.backgroundColor ?? Theme.of(context).colorScheme.secondary,
            ),
            child: InkWell(
              onTap: widget.onDismiss,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
