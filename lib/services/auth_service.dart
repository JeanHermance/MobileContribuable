import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'user_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();

  /// Vérifie si l'utilisateur a une session valide au démarrage de l'app
  Future<bool> checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberSession = prefs.getBool('remember_session') ?? false;
      
      if (!rememberSession) {
        return false;
      }

      // Vérifier si le token est valide
      final isValid = await _apiService.isTokenValid();
      if (!isValid) {
        await clearSession();
        return false;
      }

      // Vérifier le token avec le serveur
      final verifyResponse = await _apiService.verifyToken();
      if (!verifyResponse.success) {
        await clearSession();
        return false;
      }

      // Vérifier si les données utilisateur sont toujours disponibles
      final userProfile = await UserService.getUserProfile();
      if (userProfile == null) {
        await clearSession();
        return false;
      }

      return true;
    } catch (e) {
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
    
    // Supprimer toutes les données de session
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('token_timestamp');
    await prefs.remove('remember_session');
    await prefs.remove('user_profile');
    await prefs.remove('citizen_data');
    await prefs.remove('municipality_data');
    await prefs.remove('user_roles');
    
    // Note: _removeToken est déjà appelé dans clearSession via les prefs
  }

  /// Déconnexion complète
  Future<void> logout() async {
    try {
      // Tenter de déconnecter du serveur
      await _apiService.logout();
    } catch (e) {
      // Continuer même si la déconnexion serveur échoue
    } finally {
      // Nettoyer la session locale
      await clearSession();
    }
  }

  /// Vérifie si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    if (token == null) return false;
    
    return await _apiService.isTokenValid();
  }
}
