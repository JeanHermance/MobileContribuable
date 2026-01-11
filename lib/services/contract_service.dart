import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

class ContractService {
  static const String _baseUrl = 'https://gateway.agvm.mg/servicemodernmarket';

  /// Télécharge le contrat PDF depuis l'API
  static Future<Uint8List> downloadContractPdf(String locationId) async {
    try {
      debugPrint('📄 Téléchargement du contrat pour location: $locationId');
      
      final url = Uri.parse('$_baseUrl/locations/contrat-bail/$locationId');
      debugPrint('🔗 URL: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/pdf',
          'Content-Type': 'application/pdf',
        },
      );

      debugPrint('📊 Status code: ${response.statusCode}');
      debugPrint('📏 Content length: ${response.bodyBytes.length}');

      if (response.statusCode == 200) {
        if (response.bodyBytes.isEmpty) {
          throw Exception('Le fichier PDF est vide');
        }
        
        debugPrint('✅ Contrat téléchargé avec succès');
        return response.bodyBytes;
      } else {
        throw Exception('Erreur lors du téléchargement du contrat: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du téléchargement du contrat: $e');
      rethrow;
    }
  }

  /// Sauvegarde le PDF dans le stockage local temporaire
  static Future<String> savePdfToTemp(Uint8List pdfBytes, String locationId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'contrat_bail_$locationId.pdf';
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsBytes(pdfBytes);
      debugPrint('💾 PDF sauvegardé temporairement: ${file.path}');
      
      return file.path;
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde temporaire: $e');
      rethrow;
    }
  }

  /// Sauvegarde le PDF dans le dossier Téléchargements
  static Future<String?> savePdfToDownloads(Uint8List pdfBytes, String locationId) async {
    try {
      debugPrint('📥 Début du téléchargement du PDF...');
      debugPrint('📊 Taille du PDF: ${pdfBytes.length} bytes');
      
      // Demander les permissions appropriées selon la version Android
      if (Platform.isAndroid) {
        debugPrint('🤖 Plateforme Android détectée');
        
        // Pour Android 13+ (API 33+), on n'a pas besoin de permission pour Downloads
        // Pour Android 10-12, essayer storage permission
        // Pour Android < 10, utiliser storage permission
        
        bool hasPermission = false;
        
        // Essayer d'abord sans permission (Android 13+)
        final managePermission = await Permission.manageExternalStorage.status;
        final storagePermission = await Permission.storage.status;
        
        debugPrint('🔐 Permission manageExternalStorage: $managePermission');
        debugPrint('🔐 Permission storage: $storagePermission');
        
        if (managePermission.isGranted || storagePermission.isGranted) {
          hasPermission = true;
        } else {
          // Demander les permissions
          final requestedStorage = await Permission.storage.request();
          if (!requestedStorage.isGranted) {
            final requestedManage = await Permission.manageExternalStorage.request();
            hasPermission = requestedManage.isGranted;
          } else {
            hasPermission = true;
          }
        }
        
        debugPrint('✅ Permission accordée: $hasPermission');
        
        if (!hasPermission) {
          debugPrint('⚠️ Permissions refusées, utilisation du stockage interne');
        }
      }

      Directory? downloadsDir;
      String dirType = '';
      
      if (Platform.isAndroid) {
        // Essayer plusieurs emplacements pour Android
        final possiblePaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/sdcard/Download',
          '/sdcard/Downloads',
        ];
        
        for (final path in possiblePaths) {
          final dir = Directory(path);
          if (await dir.exists()) {
            downloadsDir = dir;
            dirType = 'Downloads public';
            debugPrint('📁 Dossier Downloads trouvé: ${dir.path}');
            break;
          }
        }
        
        // Si aucun dossier Downloads trouvé, utiliser le stockage externe de l'app
        if (downloadsDir == null) {
          downloadsDir = await getExternalStorageDirectory();
          dirType = 'Stockage externe app';
          debugPrint('📁 Utilisation du stockage externe de l\'app: ${downloadsDir?.path}');
        }
        
        // En dernier recours, utiliser le stockage interne
        if (downloadsDir == null) {
          downloadsDir = await getApplicationDocumentsDirectory();
          dirType = 'Stockage interne app';
          debugPrint('📁 Utilisation du stockage interne: ${downloadsDir.path}');
        }
      } else if (Platform.isIOS) {
        // Pour iOS, utiliser le dossier Documents
        downloadsDir = await getApplicationDocumentsDirectory();
        dirType = 'Documents iOS';
        debugPrint('📁 Utilisation du dossier Documents iOS: ${downloadsDir.path}');
      }

      if (downloadsDir == null) {
        throw Exception('Impossible d\'accéder à un dossier de téléchargement');
      }

      // Créer le dossier s'il n'existe pas
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
        debugPrint('📁 Dossier créé: ${downloadsDir.path}');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'contrat_bail_${locationId}_$timestamp.pdf';
      final file = File('${downloadsDir.path}/$fileName');
      
      debugPrint('💾 Sauvegarde vers: ${file.path}');
      debugPrint('📂 Type de dossier: $dirType');
      
      await file.writeAsBytes(pdfBytes);
      
      // Vérifier que le fichier a bien été créé
      if (await file.exists()) {
        final fileSize = await file.length();
        debugPrint('✅ PDF sauvegardé avec succès!');
        debugPrint('📱 Chemin: ${file.path}');
        debugPrint('📊 Taille finale: $fileSize bytes');
        return file.path;
      } else {
        throw Exception('Le fichier n\'a pas pu être créé');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde: $e');
      debugPrint('🔍 Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Ouvre le PDF avec l'application par défaut
  static Future<void> openPdfWithExternalApp(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      debugPrint('📖 Ouverture du PDF: ${result.message}');
      
      if (result.type != ResultType.done) {
        throw Exception('Impossible d\'ouvrir le PDF: ${result.message}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ouverture du PDF: $e');
      rethrow;
    }
  }

  /// Vérifie si un fichier PDF existe déjà en local
  static Future<String?> getExistingPdfPath(String locationId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'contrat_bail_$locationId.pdf';
      final file = File('${tempDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('📄 PDF existant trouvé: ${file.path}');
        return file.path;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification du fichier existant: $e');
      return null;
    }
  }

  /// Supprime les fichiers PDF temporaires anciens
  static Future<void> cleanupOldPdfs() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      for (final file in files) {
        if (file is File && file.path.contains('contrat_bail_') && file.path.endsWith('.pdf')) {
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);
          
          // Supprimer les fichiers de plus de 24 heures
          if (age.inHours > 24) {
            await file.delete();
            debugPrint('🗑️ Fichier PDF ancien supprimé: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage: $e');
    }
  }
}
