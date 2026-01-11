import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tsena_servisy/services/notification_service.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  // Pick image from gallery or camera
  static Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur lors de la sélection de l\'image: $e');
    }
  }

  // Crop image
  static Future<File?> cropImage(File imageFile, BuildContext context) async {
    try {
      // Check if the file exists before cropping
      if (!await imageFile.exists()) {
        return null;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        maxWidth: 1000,
        maxHeight: 1000,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Rogner la photo',
            toolbarColor: Colors.green,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.white,
            activeControlsWidgetColor: Colors.green,
            lockAspectRatio: true,
            showCropGrid: true,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Rogner la photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
          ),
        ],
      );
      if (croppedFile != null && await File(croppedFile.path).exists()) {
        return File(croppedFile.path);
      }
      return imageFile;
    } catch (e) {
      debugPrint('Crop error: $e');
      // If cropping fails, return the original image
      return imageFile;
    }
  }


  // Show image source selection dialog
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sélectionner une photo'),
          content: const Text('Choisissez une source pour votre photo.\nLa photo sera automatiquement rognée au format carré.'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop('camera'),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Appareil photo'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop('gallery'),
              icon: const Icon(Icons.photo_library),
              label: const Text('Galerie'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );

    if (result == null) return null;

    try {
      File? image;
      if (result == 'camera') {
        image = await pickImage(source: ImageSource.camera);
      } else if (result == 'gallery') {
        image = await pickImage(source: ImageSource.gallery);
      }

      if (image != null && context.mounted) {
        // Proposer de rogner l'image
        final croppedImage = await cropImage(image, context);
        return croppedImage ?? image;
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        final message = result == 'camera' 
            ? 'Caméra non disponible ou erreur.'
            : 'Erreur lors de la sélection depuis la galerie.';
        NotificationService.showToast(context, message, type: ToastType.error);
      }
    }
    
    return null;
  }
}
