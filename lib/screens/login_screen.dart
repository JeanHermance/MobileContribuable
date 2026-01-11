import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tab3/new_main_navigation.dart';
import '../components/custom_text_field.dart';
import '../components/custom_button.dart';
import '../components/app_logo.dart';
import '../components/password_field.dart';
import '../components/responsive_layout.dart';
import '../components/web_view_screen.dart';
import '../components/partners_carousel.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final rememberMe = prefs.getBool('remember_me') ?? false;
    
    if (rememberMe && savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Vérification de la connexion internet
      try {
        final result = await InternetAddress.lookup('gateway.agvm.mg');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('no_internet'.tr());
        }
      } on SocketException catch (_) {
        throw Exception('no_internet'.tr());
      }

      // Étape 1: Connexion et récupération des tokens
      final loginResponse = await _apiService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!loginResponse.success) {
        // Gestion spécifique des erreurs de connexion
        if (loginResponse.error?.contains('401') == true || 
            loginResponse.error?.toLowerCase().contains('identifiants') == true) {
          throw Exception('invalid_credentials'.tr());
        } else if (loginResponse.error?.contains('502') == true || 
                  loginResponse.error?.contains('503') == true ||
                  loginResponse.error?.contains('504') == true) {
          throw Exception('server_unavailable'.tr());
        } else {
          throw Exception(loginResponse.error ?? 'login_error'.tr());
        }
      }

      // Étape 2: Récupération du profil utilisateur
      final profileResponse = await _apiService.getProfile();
      if (!profileResponse.success) {
        // Si le serveur est en maintenance
        if (profileResponse.error?.contains('maintenance') == true) {
          throw Exception('maintenance_mode'.tr());
        }
        throw Exception('profile_fetch_error'.tr());
      }

      // Step 3: Get citizen data for profile photo
      final profileData = profileResponse.data;
      if (profileData == null) {
        throw Exception('Données de profil non disponibles');
      }
      
      // Use id_citizen (UUID) instead of citizen_national_card_number
      final citizenId = profileData['id_citizen'];
      debugPrint('🔍 [Login] Profile data keys: ${profileData.keys.toList()}');
      debugPrint('🔍 [Login] Citizen ID (UUID): $citizenId');
      
      Map<String, dynamic>? citizenData;
      if (citizenId != null) {
        debugPrint('📡 [Login] Calling API getCitizenById with UUID: $citizenId');
        final citizenResponse = await _apiService.getCitizenById(citizenId);
        debugPrint('📥 [Login] Citizen API Response - Success: ${citizenResponse.success}');
        debugPrint('📥 [Login] Citizen API Response - Data: ${citizenResponse.data}');
        debugPrint('📥 [Login] Citizen API Response - Error: ${citizenResponse.error}');
        
        if (citizenResponse.success) {
          citizenData = citizenResponse.data;
          debugPrint('✅ [Login] Citizen data retrieved successfully!');
          debugPrint('✅ [Login] Photo URL: ${citizenData?['citizen_photo']}');
        } else {
          debugPrint('❌ [Login] Failed to get citizen data: ${citizenResponse.error}');
        }
      } else {
        debugPrint('⚠️ [Login] No id_citizen found in profile!');
      }

      // Step 4: Extract and validate user roles
      final List<dynamic> userRoles = profileData['roles'] ?? [];
      // Filter roles for application 13633 (Contribuable app)
      final appRoles = userRoles.where((role) {
        final application = role['application'];
        return application != null && application['app_id'] == 13633;
      }).toList();
      
      // If user has no required roles, they get 'Citoyen' access instead of being blocked
      if (appRoles.isEmpty) {
        // Create a default 'Citoyen' role entry
        final defaultRole = {
          'role_name': 'Citoyen',
          'role_slug': 'citoyen',
          'application': {
            'app_id': 13633,
            'app_name': 'Contribuable',
            'app_slug': 'contribuable'
          }
        };
        await UserService.saveUserRoles([defaultRole]);
      } else {
        // Save actual roles if user has them
        await UserService.saveUserRoles(appRoles.cast<Map<String, dynamic>>());
      }

      // Step 4: Fetch and save municipality data
      final municipalityId = profileData['municipality_id'];
      if (municipalityId != null) {
        try {
          final municipalityResponse = await _apiService.getMunicipality(municipalityId.toString());
          if (municipalityResponse.success && municipalityResponse.data != null) {
            final municipalityData = municipalityResponse.data;
            if (municipalityData != null) {
              await UserService.saveMunicipalityData(municipalityData);
            }
          }
        } catch (e) {
          // Don't fail login if municipality fetch fails
        }
      }

      // Step 5: Save all user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', json.encode(profileData));
      debugPrint('✅ [Login] Saved user_profile to SharedPreferences');
      
      if (citizenData != null) {
        final citizenJson = json.encode(citizenData);
        debugPrint('💾 [Login] Saving citizen_data: $citizenJson');
        await prefs.setString('citizen_data', citizenJson);
        debugPrint('✅ [Login] Saved citizen_data to SharedPreferences');
        
        // Verify it was saved
        final saved = prefs.getString('citizen_data');
        debugPrint('✅ [Login] Verification - citizen_data in prefs: ${saved != null ? "YES" : "NO"}');
      } else {
        debugPrint('⚠️ [Login] citizenData is NULL - NOT saving to SharedPreferences!');
        debugPrint('⚠️ [Login] This means no profile photo will be available!');
      }

      await _saveCredentials();
      
      // Sauvegarder la préférence de session
      await _authService.saveSession(rememberMe: _rememberMe);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        NotificationService.showToast(context, 'login_success'.tr(), type: ToastType.success);

        // Navigate to main app
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const NewMainNavigation(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage;
        
        // Traduction des messages d'erreur courants
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('no_internet') || 
            errorStr.contains('socketexception') ||
            errorStr.contains('connection')) {
          errorMessage = 'no_internet'.tr();
        } else if (errorStr.contains('401') || 
                  errorStr.contains('invalid_credentials') ||
                  errorStr.contains('identifiants')) {
          errorMessage = 'invalid_credentials'.tr();
        } else if (errorStr.contains('502') || 
                  errorStr.contains('503') || 
                  errorStr.contains('504') ||
                  errorStr.contains('unavailable')) {
          errorMessage = 'server_unavailable'.tr();
        } else if (errorStr.contains('maintenance')) {
          errorMessage = 'maintenance_mode'.tr();
        } else {
          // Message d'erreur générique pour les autres cas
          errorMessage = e.toString().replaceAll('Exception: ', '');
          
          // Si le message d'erreur est trop technique, on affiche un message plus générique
          if (errorMessage.contains('DioException') || 
              errorMessage.contains('Failed host lookup')) {
            errorMessage = 'connection_error'.tr();
          }
        }
        
        // Affichage du message d'erreur
        if (mounted) {
          NotificationService.showToast(
            context, 
            errorMessage, 
            type: ToastType.error,
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }

  void _openForgotPasswordWebView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WebViewScreen(
          url: 'https://criv.agvm.mg/forgot-password',
          title: 'Mot de passe oublié',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false, // Don't add bottom padding as we'll handle it manually
        child: ResponsiveLayout(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24), // Add bottom padding for navigation bar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  const ResponsiveSizedBox(height: 20),
                  
                  // Carrousel des partenaires
                  const PartnersCarousel(height: 80),
                  
                  const ResponsiveSizedBox(height: 20),
                  
                  // Logo/Title Section
                  AppLogo(
                    title: 'app_name'.tr(),
                    subtitle: 'login_subtitle'.tr(),
                    titleGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withBlue(200),
                      ],
                    ),
                    subtitleColor: Colors.black87,
                  ),
                  
                  const ResponsiveSizedBox(height: 48),
              
              // Login Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email Field
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'email'.tr(),
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'email_required'.tr();
                        }
                        if (!EmailValidator.validate(value)) {
                          return 'email_invalid'.tr();
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Password Field
                    PasswordField(
                      controller: _passwordController,
                      labelText: 'password'.tr(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'password_required'.tr();
                        }
                        if (value.length < 6) {
                          return 'password_min_length'.tr();
                        }
                        return null;
                      },
                    ),
                    
                    const ResponsiveSizedBox(height: 16),
                    
                    // Remember Me & Forgot Password
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                            Text('remember_me'.tr()),
                          ],
                        ),
                        TextButton(
                          onPressed: _openForgotPasswordWebView,
                          child: Text('forgot_password'.tr()),
                        ),
                      ],
                    ),

                    
                    const ResponsiveSizedBox(height: 24),
                    
                    // Login Button
                    CustomButton(
                      text: 'login'.tr(),
                      onPressed: _login,
                      isLoading: _isLoading,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withBlue(200),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const ResponsiveSizedBox(height: 32),
              
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or'.tr(),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              
              const ResponsiveSizedBox(height: 32),
              
              // Sign Up Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'no_account_yet'.tr(),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const WebViewScreen(
                            url: 'https://criv.agvm.mg/register',
                            title: 'S\'inscrire',
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'sign_up'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
