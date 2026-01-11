import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    // Attendre un peu pour l'effet splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final hasValidSession = await _authService.checkAutoLogin();
      
      if (!mounted) return;
      
      if (hasValidSession) {
        // Utilisateur connecté avec session valide
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const NewMainNavigation(),
          ),
        );
      } else {
        // Pas de session valide, aller à l'écran de connexion
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // En cas d'erreur, aller à l'écran de connexion
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Contenu principal centré
          Expanded(
            child: Center(
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
          ),
        ],
      ),
    );
  }
}
