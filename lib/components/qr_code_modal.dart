import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';

class QrCodeModal extends StatefulWidget {
  const QrCodeModal({super.key});

  @override
  State<QrCodeModal> createState() => _QrCodeModalState();
}

class _QrCodeModalState extends State<QrCodeModal> {
  final ApiService _apiService = ApiService();
  String? _qrCodeData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }

  Future<void> _loadQrCode() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userProfile = await UserService.getUserProfile();
      debugPrint('🔍 [QR Modal] User Profile: $userProfile');
      
      final userId = userProfile?['user_id'];
      debugPrint('🔍 [QR Modal] User ID: $userId');
      debugPrint('🔍 [QR Modal] User ID Type: ${userId.runtimeType}');
      
      if (userId == null) {
        debugPrint('❌ [QR Modal] User ID is null');
        setState(() {
          _error = 'Utilisateur non connecté';
          _isLoading = false;
        });
        return;
      }
      
      if (userId.toString().isEmpty) {
        debugPrint('❌ [QR Modal] User ID is empty');
        setState(() {
          _error = 'ID utilisateur invalide';
          _isLoading = false;
        });
        return;
      }

      debugPrint('🔍 [QR Modal] Calling API with userId: $userId');
      final response = await _apiService.getUserQrCode(userId);
      
      if (response.success && response.data != null) {
        debugPrint('✅ [QR Modal] QR Code loaded successfully');
        setState(() {
          _qrCodeData = response.data;
          _isLoading = false;
        });
      } else {
        debugPrint('❌ [QR Modal] API Error: ${response.error}');
        setState(() {
          _error = response.error ?? 'Erreur lors du chargement du QR code';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [QR Modal] Unexpected error: $e');
      setState(() {
        _error = 'Une erreur inattendue s\'est produite: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withBlue(200),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'my_qr_code'.tr(),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildContent(),
                  const SizedBox(height: 24),
                  if (!_isLoading && _error != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loadQrCode,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text('retry'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  if (!_isLoading && _error == null)
                    Text(
                      'Scannez ce code pour vérifier votre identité',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'loading_qr_code'.tr(),
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Erreur inconnue',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.error,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (_qrCodeData != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _buildQrCodeImage(),
          ),
          const SizedBox(height: 20),
          Text(
            'qr_code_description'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      );
    }

    return Center(
      child: Text(
        'no_data_available'.tr(),
        style: GoogleFonts.inter(color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildQrCodeImage() {
    if (_qrCodeData == null) {
      return SizedBox(
        width: 200,
        height: 200,
        child: Center(child: Text('no_data'.tr())),
      );
    }

    try {
      final qrData = _qrCodeData ?? '';
      Uint8List bytes;
      
      if (qrData.startsWith('data:image/')) {
        final base64String = qrData.split(',').last;
        bytes = base64Decode(base64String);
      } else {
        bytes = base64Decode(qrData);
      }
      
      return Image.memory(
        bytes,
        width: 200,
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }
  
  Widget _buildErrorWidget() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'qr_decode_error'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
