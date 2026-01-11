import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/contract_service.dart';

/// Widget de test pour vérifier le système de téléchargement
class DownloadTestWidget extends StatefulWidget {
  const DownloadTestWidget({super.key});

  @override
  State<DownloadTestWidget> createState() => _DownloadTestWidgetState();
}

class _DownloadTestWidgetState extends State<DownloadTestWidget> {
  String _status = 'Prêt pour les tests';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🧪 Test du Système de Téléchargement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton(
                  'Vérifier Permissions',
                  Icons.security,
                  Colors.blue,
                  _checkPermissions,
                ),
                _buildTestButton(
                  'Vérifier Dossiers',
                  Icons.folder,
                  Colors.green,
                  _checkDirectories,
                ),
                _buildTestButton(
                  'Test Téléchargement',
                  Icons.download,
                  Colors.purple,
                  _testDownload,
                ),
                _buildTestButton(
                  'Nettoyer Cache',
                  Icons.cleaning_services,
                  Colors.red,
                  _cleanupCache,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTestButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
      ),
    );
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Vérification des permissions...';
    });

    try {
      if (Platform.isAndroid) {
        final storage = await Permission.storage.status;
        final manage = await Permission.manageExternalStorage.status;
        
        setState(() {
          _status = '''Permissions Android:
• Storage: $storage
• Manage External Storage: $manage
• Plateforme: ${Platform.operatingSystemVersion}''';
        });
      } else if (Platform.isIOS) {
        setState(() {
          _status = 'iOS détecté - Pas de permissions spéciales requises';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Erreur lors de la vérification: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkDirectories() async {
    setState(() {
      _isLoading = true;
      _status = 'Vérification des dossiers...';
    });

    try {
      final results = <String>[];
      
      // Dossier temporaire
      final tempDir = await getTemporaryDirectory();
      results.add('📁 Temp: ${tempDir.path} (${await tempDir.exists() ? '✅' : '❌'})');
      
      // Dossier documents
      final docsDir = await getApplicationDocumentsDirectory();
      results.add('📁 Docs: ${docsDir.path} (${await docsDir.exists() ? '✅' : '❌'})');
      
      // Dossier externe (Android)
      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        results.add('📁 External: ${extDir?.path ?? 'null'} (${extDir != null && await extDir.exists() ? '✅' : '❌'})');
        
        // Dossiers Downloads possibles
        final downloadPaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/sdcard/Download',
          '/sdcard/Downloads',
        ];
        
        for (final path in downloadPaths) {
          final dir = Directory(path);
          final exists = await dir.exists();
          results.add('📁 $path (${exists ? '✅' : '❌'})');
        }
      }
      
      setState(() {
        _status = results.join('\n');
      });
    } catch (e) {
      setState(() {
        _status = 'Erreur lors de la vérification: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testDownload() async {
    setState(() {
      _isLoading = true;
      _status = 'Test de téléchargement...';
    });

    try {
      // Créer un PDF de test simple
      final testContent = '''%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj
4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Test PDF) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000206 00000 n 
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
299
%%EOF''';

      final testBytes = Uint8List.fromList(testContent.codeUnits);
      final testLocationId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      
      setState(() {
        _status = 'Création du PDF de test (${testBytes.length} bytes)...';
      });
      
      final savedPath = await ContractService.savePdfToDownloads(testBytes, testLocationId);
      
      if (savedPath != null) {
        final file = File(savedPath);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        
        setState(() {
          _status = '''✅ Test réussi !
📁 Chemin: $savedPath
📊 Taille: $size bytes
✅ Fichier existe: $exists''';
        });
      } else {
        setState(() {
          _status = '❌ Échec du test - savedPath est null';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Erreur lors du test: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cleanupCache() async {
    setState(() {
      _isLoading = true;
      _status = 'Nettoyage du cache...';
    });

    try {
      await ContractService.cleanupOldPdfs();
      setState(() {
        _status = '✅ Cache nettoyé avec succès';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Erreur lors du nettoyage: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
