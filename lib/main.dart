import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'screens/splash_screen.dart';
import 'services/real_time_service.dart';
import 'services/api_service.dart';
import 'services/language_service.dart';
import 'services/data_refresh_service.dart';
import 'utils/app_colors.dart';
import 'services/cart_service.dart';

void _initializeWebView() {
  // Initialiser WebView selon la plateforme
  if (kIsWeb) {
    // Pour le web, pas besoin d'initialisation spéciale
    return;
  }
  
  if (defaultTargetPlatform == TargetPlatform.android) {
    WebViewPlatform.instance = AndroidWebViewPlatform();
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    WebViewPlatform.instance = WebKitWebViewPlatform();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  // Initialiser WebView pour les plateformes spécifiques
  _initializeWebView();
  
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('mg'), Locale('fr'), Locale('en')],
      path: 'assets/langs',
      fallbackLocale: const Locale('mg'),
      startLocale: const Locale('mg'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartService()),
          ChangeNotifierProvider(create: (_) => RealTimeService()),
          ChangeNotifierProvider(create: (_) => DataRefreshService()),
          ChangeNotifierProvider(create: (_) => LanguageService()),
          Provider<ApiService>(create: (_) => ApiService()),
        ],
        child: ReservationApp(),
      ),
    ),
  );
}

class ReservationApp extends StatelessWidget {
  const ReservationApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Configuration de la barre de statut déplacée vers chaque écran pour plus de flexibilité
    return MaterialApp(
      title: 'Réservation',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      localeResolutionCallback: (locale, supportedLocales) {
        // Si la locale demandée n'est pas supportée par Material, utiliser le français comme fallback
        if (locale != null && locale.languageCode == 'mg') {
          return const Locale('fr'); // Fallback vers français pour Material
        }
        return locale;
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            viewInsets: MediaQuery.of(context).viewInsets,
            viewPadding: MediaQuery.of(context).viewPadding,
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        primaryColor: AppColors.primary,
        fontFamily: GoogleFonts.roboto().fontFamily,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: Colors.black26,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textTheme: GoogleFonts.robotoTextTheme(
          const TextTheme(
            displayLarge: TextStyle(fontWeight: FontWeight.w300, color: AppColors.textPrimary),
            displayMedium: TextStyle(fontWeight: FontWeight.w400, color: AppColors.textPrimary),
            displaySmall: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            headlineLarge: TextStyle(fontWeight: FontWeight.w400, color: AppColors.textPrimary),
            headlineMedium: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}