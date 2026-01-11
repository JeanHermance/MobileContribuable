import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'styled_title.dart';
import 'animated_badge_button.dart';

class WelcomeHeader extends StatelessWidget {
  final String userName;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final int? notificationCount;
  final VoidCallback? onQrCodeTap;

  const WelcomeHeader({
    super.key,
    required this.userName,
    this.onProfileTap,
    this.onNotificationTap,
    this.notificationCount,
    this.onQrCodeTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          // Section de bienvenue
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Texte de bienvenue avec le composant StyledTitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    StyledTitle(
                      title: 'welcome_message'.tr(),
                    ),
                    StyledTitle(
                      title: userName,
                      color: Colors.deepOrange,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          // Logos and notifications à droite
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 12),
              // Notifications sans background
              AnimatedBadgeButton(
                icon: Icons.notifications_outlined,
                badgeCount: notificationCount ?? 0,
                onPressed: onNotificationTap,
                iconColor: Colors.white,
                backgroundColor: Colors.transparent,
                animationDuration: const Duration(milliseconds: 150),
                badgeAnimationDuration: const Duration(milliseconds: 200),
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(width: 8),
              // Bouton QR code
              if (onQrCodeTap != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onQrCodeTap,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(
                          Icons.qr_code,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      
    );
  }
}
