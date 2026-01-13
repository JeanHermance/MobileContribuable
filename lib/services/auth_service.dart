import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'user_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();

  /// 🔑 NOUVEAU : Gère la connexion via un token externe (Diamadio)
  Future<bool> loginWithExternalToken(String token) async {
    try {
      // 1. On sauvegarde le token via l'ApiService (qui met à jour les headers)
      await _apiService.saveToken(token);
      
      // 2. On active "remember_session" par défaut pour le SSO
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_session', true);

      // 3. On récupère et stocke le profil utilisateur immédiatement
      final profileResponse = await _apiService.getProfile();
      if (profileResponse.success && profileResponse.data != null) {
        await UserService.saveUserProfile(profileResponse.data!);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Erreur SSO AuthService: $e");
      return false;
    }
  }

  /// Vérifie si l'utilisateur a une session valide au démarrage de l'app
  Future<bool> checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      // Si pas de token du tout, on ne peut pas se connecter
      if (token == null || token.isEmpty) return false;

      // Vérifier si le token est encore valide temporellement
      final isValid = await _apiService.isTokenValid();
      if (!isValid) {
        await clearSession();
        return false;
      }

      // Vérifier le token avec le serveur (SSO ou session normale)
      final verifyResponse = await _apiService.verifyToken();
      if (!verifyResponse.success) {
        await clearSession();
        return false;
      }

      // Vérifier/Charger les données utilisateur
      final userProfile = await UserService.getUserProfile();
      if (userProfile == null) {
        // Tentative de rechargement si les données locales ont disparu
        final profileResponse = await _apiService.getProfile();
        if (!profileResponse.success) {
          await clearSession();
          return false;
        }
        await UserService.saveUserProfile(profileResponse.data!);
      }

      return true;
    } catch (e) {
      debugPrint("❌ Erreur checkAutoLogin: $e");
      await clearSession();
      return false;
    }
  }

  /// Sauvegarde la session avec la préférence "Se souvenir de moi"
  Future<void> saveSession({required bool rememberMe}) async {
    await _apiService.saveSessionPreference(rememberMe);
  }

  /// Efface complètement la session
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('token_timestamp');
    await prefs.remove('remember_session');
    await prefs.remove('user_profile');
    await prefs.remove('citizen_data');
    await prefs.remove('municipality_data');
    await prefs.remove('user_roles');
    debugPrint("🧹 Session locale nettoyée");
  }

  /// Déconnexion complète
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      debugPrint("⚠️ Erreur logout serveur: $e");
    } finally {
      await clearSession();
    }
  }

  /// Vérifie simplement si un token existe et est valide
  Future<bool> isLoggedIn() async {
    return await _apiService.isTokenValid();
  }
}