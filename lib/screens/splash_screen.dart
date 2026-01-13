import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app_links/app_links.dart'; // Import pour les liens
import '../services/auth_service.dart';
import '../components/app_logo.dart';
import 'login_screen.dart';
import '../tab3/new_main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  final _appLinks = AppLinks(); // Instance pour écouter les liens entrants

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    try {
      // 1. 🔍 TENTATIVE DE RÉCUPÉRATION DU TOKEN VIA DEEPLINK (SSO)
      final Uri? uri = await _appLinks.getInitialLink();

      if (uri != null && uri.queryParameters.containsKey('token')) {
        final String? token = uri.queryParameters['token'];

        if (token != null && token.isNotEmpty && token != "null") {
          debugPrint(
              "🔑 [Contribuable] Token détecté dans l'URL, tentative SSO...");

          // Utilise la méthode que nous avons créée dans ton AuthService
          final success = await _authService.loginWithExternalToken(token);

          if (success && mounted) {
            debugPrint("✅ [Contribuable] Connexion automatique réussie");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const NewMainNavigation()),
            );
            return; // On s'arrête ici car le SSO a fonctionné
          }
        }
      }

      // 2. ⏳ ATTENTE POUR L'EFFET VISUEL (Seulement si pas de SSO direct)
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      // 3. 🔄 FLUX CLASSIQUE (Vérification de la session locale existante)
      final hasValidSession = await _authService.checkAutoLogin();

      if (!mounted) return;

      if (hasValidSession) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const NewMainNavigation()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint("❌ [Contribuable] Erreur lors du checkAutoLogin: $e");
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogo(
              title: 'TSENA servisy',
              subtitle: 'loading'.tr(),
              titleColor: Colors.green,
              subtitleColor: const Color.fromARGB(255, 61, 212, 66),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
