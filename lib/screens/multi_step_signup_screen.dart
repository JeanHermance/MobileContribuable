import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'dart:io';
import '../components/custom_text_field.dart';
import '../components/custom_button.dart';
import '../components/app_logo.dart';
import '../components/password_field.dart';
import '../components/responsive_layout.dart';
import '../components/progress_bar.dart';
import '../components/photo_picker.dart';
import '../services/api_service.dart';
import '../services/image_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

class MultiStepSignUpScreen extends StatefulWidget {
  const MultiStepSignUpScreen({super.key});

  @override
  State<MultiStepSignUpScreen> createState() => _MultiStepSignUpScreenState();
}

class _MultiStepSignUpScreenState extends State<MultiStepSignUpScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4; // Back to 4 steps, removed role selection
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  String? _citizenId;
  String? _createdUserId;

  // Form keys for each step
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  // Step 1: Personal Information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _locationOfBirthController = TextEditingController();
  File? _citizenPhoto;

  // Step 2: Identity & Address
  final _nationalCardNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _workController = TextEditingController();
  final _fokotanyIdController = TextEditingController();

  // Step 3: Family & Card Details
  final _fatherController = TextEditingController();
  final _motherController = TextEditingController();
  final _cardLocationController = TextEditingController();
  final _cardDateController = TextEditingController();

  // Removed: Step 4 taxpayer type selection - users get all access by default

  // Step 4: Account Information
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _municipalityIdController = TextEditingController();

  final List<String> _stepTitles = [
    'Informations personnelles',
    'Identité et adresse',
    'Famille et carte d\'identité',
    'Compte et validation',
  ];

  @override
  void initState() {
    super.initState();
    // Removed role loading - users get default access
  }

  // Removed _loadRoles method - no longer needed

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose all controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    _locationOfBirthController.dispose();
    _nationalCardNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _workController.dispose();
    _fokotanyIdController.dispose();
    _fatherController.dispose();
    _motherController.dispose();
    _cardLocationController.dispose();
    _cardDateController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _municipalityIdController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKeys[_currentStep].currentState!.validate()) {
      // Special validation for step 1 (photo required)
      if (_currentStep == 0 && _citizenPhoto == null) {
        NotificationService.showToast(context, 'Veuillez sélectionner une photo', type: ToastType.warning);
        return;
      }
      // Removed role selection validation - no longer needed
      
      if (_currentStep < _totalSteps - 1) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _submitForm();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      controller.text = "${picked.day}/${picked.month}/${picked.year}";
    }
  }

  Future<void> _selectPhoto() async {
    try {
      final File? image = await ImageService.showImageSourceDialog(context);
      if (image != null) {
        setState(() {
          _citizenPhoto = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection de la photo: $e')));
      }
    }
  }

  Future<void> _submitForm() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Convert date format from DD/MM/YYYY to YYYY-MM-DD
      String formatDateForApi(String dateString) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
        return dateString;
      }

      // Step 1: Register citizen
      final citizenResponse = await _apiService.registerCitizen(
        citizenName: _firstNameController.text,
        citizenLastname: _lastNameController.text,
        citizenDateOfBirth: formatDateForApi(_dateOfBirthController.text),
        citizenLocationOfBirth: _locationOfBirthController.text,
        citizenNationalCardNumber: int.parse(_nationalCardNumberController.text),
        citizenAddress: _addressController.text,
        citizenCity: _cityController.text,
        citizenWork: _workController.text,
        fokotanyId: int.parse(_fokotanyIdController.text),
        citizenFather: _fatherController.text,
        citizenMother: _motherController.text,
        citizenNationalCardLocation: _cardLocationController.text,
        citizenNationalCardDate: formatDateForApi(_cardDateController.text),
        citizenPhoto: _citizenPhoto!.path,
      );

      if (!citizenResponse.success) {
        throw Exception(citizenResponse.error ?? 'Erreur lors de l\'enregistrement du citoyen');
      }

      // Extract citizen ID from response
      _citizenId = citizenResponse.data?['id_citizen'] ?? citizenResponse.data?['id_citizen'];
      if (_citizenId == null) {
        throw Exception('ID citoyen non reçu du serveur');
      }

      // Step 2: Register user account
      final userResponse = await _apiService.registerUser(
        userPseudo: _usernameController.text,
        userEmail: _emailController.text,
        userPassword: _passwordController.text,
        userPhone: _phoneController.text,
        municipalityId: _municipalityIdController.text,
        idCitizen: _citizenId!,
      );

      if (!userResponse.success) {
        throw Exception(userResponse.error ?? 'Erreur lors de la création du compte utilisateur');
      }

      // Extract user ID from response
      _createdUserId = userResponse.data?['user_id'] ?? userResponse.data?['id'];
      if (_createdUserId == null) {
        throw Exception('ID utilisateur non reçu du serveur');
      }

      // Step 3: Role verification will be handled during login
      // Users get default citizen access, roles verified against API during authentication

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        NotificationService.showToast(context, 'Compte créé avec succès !', type: ToastType.success);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Affiche une erreur plus conviviale
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        NotificationService.showToast(context, errorMessage, type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Créer un compte',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false, // Don't add bottom padding as we'll handle it manually
        child: ResponsiveLayout(
          child: Column(
            children: [
            // Progress Bar
            ProgressBar(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
              stepTitles: _stepTitles,
            ),
            
            const SizedBox(height: 24),
            
            // Form Steps
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(), // Account information step
                ],
              ),
            ),
            
            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: CustomButton(
                        text: 'Précédent',
                        onPressed: _previousStep,
                        backgroundColor: Colors.grey[600],
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      text: _currentStep == _totalSteps - 1 ? 'Créer le compte' : 'Suivant',
                      onPressed: _nextStep,
                      isLoading: _isLoading,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppLogo(
              icon: Icons.person,
              size: 60,
            ),
            
            const SizedBox(height: 24),
            
            // Photo
            Center(
              child: PhotoPicker(
                selectedImage: _citizenPhoto,
                onTap: _selectPhoto,
                errorText: _citizenPhoto == null ? null : null,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // First Name & Last Name
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _firstNameController,
                    labelText: 'Prénom',
                    prefixIcon: Icons.person_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requis';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _lastNameController,
                    labelText: 'Nom',
                    prefixIcon: Icons.person_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requis';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Date of Birth
            CustomTextField(
              controller: _dateOfBirthController,
              labelText: 'Date de naissance',
              prefixIcon: Icons.calendar_today,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez sélectionner votre date de naissance';
                }
                return null;
              },
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(_dateOfBirthController),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Location of Birth
            CustomTextField(
              controller: _locationOfBirthController,
              labelText: 'Lieu de naissance',
              prefixIcon: Icons.location_on_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre lieu de naissance';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      child: Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppLogo(
              icon: Icons.badge,
              size: 60,
            ),
            
            const SizedBox(height: 24),
            
            // National Card Number
            CustomTextField(
              controller: _nationalCardNumberController,
              labelText: 'Numéro de carte d\'identité',
              prefixIcon: Icons.credit_card,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre numéro de carte d\'identité';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Address
            CustomTextField(
              controller: _addressController,
              labelText: 'Adresse',
              prefixIcon: Icons.home_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre adresse';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // City & Work
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _cityController,
                    labelText: 'Ville',
                    prefixIcon: Icons.location_city,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requis';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _workController,
                    labelText: 'Profession',
                    prefixIcon: Icons.work_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requis';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Fokotany ID
            CustomTextField(
              controller: _fokotanyIdController,
              labelText: 'ID Fokotany',
              prefixIcon: Icons.numbers,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer l\'ID Fokotany';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppLogo(
              icon: Icons.family_restroom,
              size: 60,
            ),
            
            const SizedBox(height: 24),
            
            // Father & Mother
            CustomTextField(
              controller: _fatherController,
              labelText: 'Nom du père',
              prefixIcon: Icons.man,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le nom du père';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _motherController,
              labelText: 'Nom de la mère',
              prefixIcon: Icons.woman,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le nom de la mère';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Card Location
            CustomTextField(
              controller: _cardLocationController,
              labelText: 'Lieu de délivrance de la carte',
              prefixIcon: Icons.location_on,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le lieu de délivrance';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Card Date
            CustomTextField(
              controller: _cardDateController,
              labelText: 'Date de délivrance de la carte',
              prefixIcon: Icons.calendar_today,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez sélectionner la date de délivrance';
                }
                return null;
              },
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(_cardDateController),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 4: Account Information (formerly step 5)
  Widget _buildStep4() {
    return SingleChildScrollView(
      child: Form(
        key: _formKeys[3], // Updated key index
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppLogo(
              icon: Icons.account_circle,
              size: 60,
            ),
            
            const SizedBox(height: 24),
            
            // Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Résumé des informations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryItem('Nom complet', '${_firstNameController.text} ${_lastNameController.text}'),
                    _buildSummaryItem('Date de naissance', _dateOfBirthController.text),
                    _buildSummaryItem('Lieu de naissance', _locationOfBirthController.text),
                    _buildSummaryItem('Carte d\'identité', _nationalCardNumberController.text),
                    _buildSummaryItem('Adresse', '${_addressController.text}, ${_cityController.text}'),
                    _buildSummaryItem('Profession', _workController.text),
                    _buildSummaryItem('Statut', 'Citoyen'), // Default citizen status
                    _buildSummaryItem('Nom d\'utilisateur', _usernameController.text),
                    _buildSummaryItem('Email', _emailController.text),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            // Username
            CustomTextField(
              controller: _usernameController,
              labelText: 'Nom d\'utilisateur',
              prefixIcon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un nom d\'utilisateur';
                }
                if (value.length < 3) {
                  return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Email
            CustomTextField(
              controller: _emailController,
              labelText: 'Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre email';
                }
                if (!EmailValidator.validate(value)) {
                  return 'Veuillez entrer un email valide';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Phone & Municipality ID
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _phoneController,
                    labelText: 'Téléphone',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requis';
                      }
                      if (value.length < 10) {
                        return 'Numéro invalide';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _municipalityIdController,
                    labelText: 'ID Municipalité',
                    prefixIcon: Icons.location_city,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requis';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Password
            PasswordField(
              controller: _passwordController,
              labelText: 'Mot de passe',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un mot de passe';
                }
                if (value.length < 8) {
                  return 'Le mot de passe doit contenir au moins 8 caractères';
                }
                if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                  return 'Le mot de passe doit contenir au moins une majuscule, une minuscule et un chiffre';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Confirm Password
            PasswordField(
              controller: _confirmPasswordController,
              labelText: 'Confirmer le mot de passe',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez confirmer votre mot de passe';
                }
                if (value != _passwordController.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Non renseigné',
              style: TextStyle(
                color: value.isNotEmpty ? Colors.black87 : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}