import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class StatusBarManager {
  /// Configure la barre de statut avec le style du header (HeroSection)
  static void setHeaderStyle() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent pour laisser voir le gradient
      statusBarIconBrightness: Brightness.light, // Icônes blanches
      statusBarBrightness: Brightness.dark, // Pour iOS
    ));
  }

  /// Configure la barre de statut avec le style par défaut (interfaces sans header)
  static void setDefaultStyle(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Theme.of(context).colorScheme.surface, // Couleur de fond par défaut
      statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
          ? Brightness.light 
          : Brightness.dark, // Icônes adaptées au thème
      statusBarBrightness: Theme.of(context).brightness == Brightness.dark 
          ? Brightness.light 
          : Brightness.dark, // Pour iOS
    ));
  }

  /// Configure la barre de statut avec une couleur personnalisée
  static void setCustomStyle({
    required Color statusBarColor,
    required Brightness iconBrightness,
  }) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: iconBrightness == Brightness.light 
          ? Brightness.dark 
          : Brightness.light, // Inverse pour iOS
    ));
  }

  /// Configure la barre de statut avec le style primaire de l'app
  static void setPrimaryStyle() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  }
}
