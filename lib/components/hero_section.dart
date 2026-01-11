import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'welcome_header.dart';
import 'qr_code_modal.dart';
import 'package:tsena_servisy/utils/app_colors.dart';
import 'package:tsena_servisy/models/municipality.dart';

class HeroSection extends StatelessWidget {
  final String userPseudo;
  final String? title;
  final String? subtitle;
  final Widget? customContent;
  final VoidCallback? onNotificationTap;
  final int? notificationCount;
  final Municipality? currentMunicipality;
  final List<Municipality>? availableMunicipalities;
  final Function(Municipality)? onMunicipalityChanged;
  final bool isLoadingMunicipalities;

  const HeroSection({
    super.key,
    required this.userPseudo,
    this.title,
    this.subtitle,
    this.customContent,
    this.onNotificationTap,
    this.notificationCount,
    this.currentMunicipality,
    this.availableMunicipalities,
    this.onMunicipalityChanged,
    this.isLoadingMunicipalities = false,
  });

  @override
  Widget build(BuildContext context) {
    // La configuration de la barre de statut est maintenant gérée par le widget parent (tab)
    // pour éviter les conflits et permettre une configuration spécifique par écran
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16.0, // Padding status bar + padding normal
        left: 16.0,
        right: 16.0,
        bottom: 8.0, // Réduit de 16 à 8 pour éviter l'overflow dans l'AppBar
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Changé de max à min pour s'adapter au contenu
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WelcomeHeader(
            userName: userPseudo,
            onNotificationTap: onNotificationTap,
            notificationCount: notificationCount,
            onQrCodeTap: () => _showQrCodeModal(context),
          ),
          if (title != null || subtitle != null) ...[
            const SizedBox(height: 12.0), // Réduit de 16 à 12
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6.0), // Réduit de 8 à 6
                  Text(
                    subtitle ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                      fontSize: 16.0,
                    ),
                  ),
                ],
              ],
            ),
          ],
          // Municipality selector section
          if (currentMunicipality != null || isLoadingMunicipalities) ...[
            const SizedBox(height: 12.0), // Réduit de 16 à 12
            _buildMunicipalitySection(context),
            const SizedBox(height: 70.0), // Augmenté de 50 à 70 pour éviter le chevauchement avec le SearchBar
          ],
          if (customContent != null) ...[
            const SizedBox(height: 12.0), // Réduit de 16 à 12
            customContent ?? const SizedBox.shrink(),
          ],
          const SizedBox(height: 12.0), // Réduit car l'espace est maintenant géré après la section municipalité
        ],
      ),
    );
  }

  void _showQrCodeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const QrCodeModal(),
    );
  }

  Widget _buildMunicipalitySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_city,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'municipality'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoadingMunicipalities)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'loading'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            )
          else if (currentMunicipality != null)
            GestureDetector(
              onTap: availableMunicipalities != null && (availableMunicipalities?.length ?? 0) > 1
                  ? () => _showMunicipalitySelector(context)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentMunicipality?.name ?? 'Commune inconnue',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${currentMunicipality?.region.name ?? 'Région inconnue'} - ${currentMunicipality?.district.name ?? 'District inconnu'}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (availableMunicipalities != null && (availableMunicipalities?.length ?? 0) > 1)
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMunicipalitySelector(BuildContext context) {
    if (availableMunicipalities == null || onMunicipalityChanged == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'choose_municipality'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableMunicipalities?.length ?? 0,
                itemBuilder: (context, index) {
                  final municipalities = availableMunicipalities;
                  if (municipalities == null || index >= municipalities.length) return const SizedBox.shrink();
                  final municipality = municipalities[index];
                  final isSelected = currentMunicipality?.communeId == municipality.communeId;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: !municipality.isMember 
                          ? Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1)
                          : null,
                      color: !municipality.isMember 
                          ? Colors.orange.withValues(alpha: 0.05)
                          : null,
                    ),
                    child: ListTile(
                      leading: Icon(
                        municipality.isMember ? Icons.location_city : Icons.home,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary
                            : municipality.isMember ? Colors.grey : Colors.orange,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              municipality.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          if (!municipality.isMember)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'my_municipality'.tr(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${municipality.region.name} - ${municipality.district.name}'),
                          if (!municipality.isMember)
                            Text(
                              'not_member_municipality'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.withValues(alpha: 0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      trailing: isSelected 
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        onMunicipalityChanged?.call(municipality);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
