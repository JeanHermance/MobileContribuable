import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/real_time_service.dart';
import '../models/notification_model.dart';

enum NotificationFilter { all, unread, read }

class NotificationTab extends StatefulWidget {
  const NotificationTab({super.key});

  @override
  State<NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends State<NotificationTab> {
  NotificationFilter _currentFilter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RealTimeService>(context, listen: false).refreshNotifications();
    });
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return 'le ${DateFormat('dd/MM/yyyy').format(date)}';
    } else if (difference.inDays >= 1) {
      return 'il y a ${difference.inDays} jours';
    } else if (difference.inHours >= 1) {
      return 'il y a ${difference.inHours} h';
    } else if (difference.inMinutes >= 1) {
      return 'il y a ${difference.inMinutes} min';
    } else {
      return "à l'instant";
    }
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
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80.0),
          child: Container(
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
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'notifications'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: false,
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                      ),
                      onPressed: () {},
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Consumer<RealTimeService>(
                        builder: (context, service, child) {
                          if (service.unreadNotificationCount == 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${service.unreadNotificationCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'mark_all_read') {
                      Provider.of<RealTimeService>(context, listen: false).markAllNotificationsAsRead();
                    } else if (value == 'filter_all') {
                      setState(() => _currentFilter = NotificationFilter.all);
                    } else if (value == 'filter_unread') {
                      setState(() => _currentFilter = NotificationFilter.unread);
                    } else if (value == 'filter_read') {
                      setState(() => _currentFilter = NotificationFilter.read);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'filter_unread',
                      child: Row(
                        children: [
                          Icon(
                            Icons.mark_email_unread_outlined, 
                            color: _currentFilter == NotificationFilter.unread ? Theme.of(context).primaryColor : Colors.grey, 
                            size: 20
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Non lue',
                            style: TextStyle(
                              fontWeight: _currentFilter == NotificationFilter.unread ? FontWeight.bold : FontWeight.normal,
                              color: _currentFilter == NotificationFilter.unread ? Theme.of(context).primaryColor : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'filter_read',
                      child: Row(
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined, 
                            color: _currentFilter == NotificationFilter.read ? Theme.of(context).primaryColor : Colors.grey, 
                            size: 20
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Lue',
                            style: TextStyle(
                              fontWeight: _currentFilter == NotificationFilter.read ? FontWeight.bold : FontWeight.normal,
                              color: _currentFilter == NotificationFilter.read ? Theme.of(context).primaryColor : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'filter_all',
                      child: Row(
                        children: [
                          Icon(
                            Icons.list_alt, 
                            color: _currentFilter == NotificationFilter.all ? Theme.of(context).primaryColor : Colors.grey, 
                            size: 20
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Tout',
                            style: TextStyle(
                              fontWeight: _currentFilter == NotificationFilter.all ? FontWeight.bold : FontWeight.normal,
                              color: _currentFilter == NotificationFilter.all ? Theme.of(context).primaryColor : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'mark_all_read',
                      child: Row(
                        children: [
                          Icon(Icons.done_all, color: Theme.of(context).primaryColor, size: 20),
                          const SizedBox(width: 12),
                          Text('mark_all_read'.tr()),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Consumer<RealTimeService>(
          builder: (context, realTimeService, child) {
            var notifications = realTimeService.notifications;
            
            // Apply filter
            if (_currentFilter == NotificationFilter.unread) {
              notifications = notifications.where((n) => !n.isRead).toList();
            } else if (_currentFilter == NotificationFilter.read) {
              notifications = notifications.where((n) => n.isRead).toList();
            }

            final isLoading = realTimeService.isLoading;

            if (isLoading && notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            } else if (notifications.isEmpty) {
              return _buildEmptyState();
            } else {
              return ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationItem(notification);
                },
              );
            }
          },
        ),
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'no_notifications_yet'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'no_notifications_desc'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final isRead = notification.isRead;
    final title = notification.title;
    final message = notification.message;
    final date = notification.createdAt;
    final type = notification.type;
    
    final timeStr = _getRelativeTime(date);

    return InkWell(
      onTap: () {
        if (!isRead) {
          Provider.of<RealTimeService>(context, listen: false)
              .markNotificationAsRead(notification.id);
        }
      },
      child: Container(
        color: isRead ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(type, title),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String type, String title) {
    IconData icon;
    Color color;
    Color bg;
    
    final lowerTitle = title.toLowerCase();
    final lowerType = type.toLowerCase();

    if (lowerType == 'payment' || lowerType == 'paiement' || lowerTitle.contains('paiement')) {
      icon = Icons.money_rounded;
      color = Colors.white;
      bg = Theme.of(context).primaryColor;
    } else if (lowerType == 'reservation' || lowerType == 'location' || lowerTitle.contains('location')) {
      icon = Icons.store_rounded;
      color = Colors.white;
      bg = Theme.of(context).primaryColor.withBlue(200);
    } else if (lowerType == 'alert' || lowerType == 'warning' || lowerTitle.contains('attention') || lowerTitle.contains('alert')) {
      icon = Icons.warning_amber_rounded;
      color = Colors.white;
      bg = Colors.orange.shade800;
    } else {
      icon = Icons.notifications_outlined;
      color = Colors.white;
      bg = Theme.of(context).primaryColor;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}
