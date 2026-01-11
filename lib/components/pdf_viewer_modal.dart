import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

class PdfViewerModal extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String? subtitle;

  const PdfViewerModal({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.subtitle,
  });

  @override
  State<PdfViewerModal> createState() => _PdfViewerModalState();
}

class _PdfViewerModalState extends State<PdfViewerModal> {
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _error;
  String? _pdfPath;
  Uint8List? _pdfBytes;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      debugPrint('📄 Chargement du PDF depuis: ${widget.pdfUrl}');
      
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Télécharger le PDF depuis l'URL
      final response = await http.get(
        Uri.parse(widget.pdfUrl),
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
        
        // Sauvegarder temporairement
        final tempPath = await _savePdfToTemp(response.bodyBytes);
        
        setState(() {
          _pdfPath = tempPath;
          _pdfBytes = response.bodyBytes;
          _isLoading = false;
        });
        
        debugPrint('✅ PDF chargé avec succès');
      } else {
        throw Exception('Erreur lors du téléchargement du PDF: ${response.statusCode}');
      }

    } catch (e) {
      debugPrint('❌ Erreur lors du chargement du PDF: $e');
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<String> _savePdfToTemp(Uint8List pdfBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'justificatif_$timestamp.pdf';
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsBytes(pdfBytes);
      debugPrint('💾 PDF sauvegardé temporairement: ${file.path}');
      
      return file.path;
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde temporaire: $e');
      rethrow;
    }
  }

  Future<void> _downloadToDevice() async {
    debugPrint('📥 Téléchargement du justificatif...');
    
    if (_pdfBytes == null) {
      debugPrint('❌ _pdfBytes est null, impossible de télécharger');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('download_error'.tr(args: ['PDF non disponible'])),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      setState(() => _isDownloading = true);

      final savedPath = await _savePdfToDownloads(_pdfBytes!);
      
      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download_done, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'receipt_downloaded'.tr(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        savedPath.split('/').last,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'open'.tr(),
              textColor: Colors.white,
              onPressed: () => _openPdfWithExternalApp(savedPath),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'download_failed'.tr(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Vérifiez les permissions de stockage',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('💥 Exception lors du téléchargement: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'download_error'.tr(args: ['Erreur technique']),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 7),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<String?> _savePdfToDownloads(Uint8List pdfBytes) async {
    try {
      debugPrint('📥 Début du téléchargement du justificatif...');
      
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        // Demander les permissions
        bool hasPermission = false;
        
        final storagePermission = await Permission.storage.status;
        if (storagePermission.isGranted) {
          hasPermission = true;
        } else {
          final requestedStorage = await Permission.storage.request();
          hasPermission = requestedStorage.isGranted;
        }
        
        if (hasPermission) {
          // Essayer les dossiers Downloads publics
          final possiblePaths = [
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Downloads',
          ];
          
          for (final path in possiblePaths) {
            final dir = Directory(path);
            if (await dir.exists()) {
              downloadsDir = dir;
              break;
            }
          }
        }
        
        // Fallback vers le stockage de l'app
        downloadsDir ??= await getExternalStorageDirectory();
        
        // Dernier recours
        downloadsDir ??= await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Impossible d\'accéder à un dossier de téléchargement');
      }

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'justificatif_paiement_$timestamp.pdf';
      final file = File('${downloadsDir.path}/$fileName');
      
      await file.writeAsBytes(pdfBytes);
      
      if (await file.exists()) {
        debugPrint('✅ Justificatif sauvegardé: ${file.path}');
        return file.path;
      } else {
        throw Exception('Le fichier n\'a pas pu être créé');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde: $e');
      return null;
    }
  }

  Future<void> _openPdfWithExternalApp(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      debugPrint('📖 Ouverture du PDF: ${result.message}');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ouverture du PDF: $e');
    }
  }

  Future<void> _shareReceipt() async {
    if (_pdfPath == null) return;
    
    try {
      await _openPdfWithExternalApp(_pdfPath!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('open_error'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverFillRemaining(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 80.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).primaryColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      centerTitle: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withBlue(200),
              ],
            ),
          ),
        ),
      ),
      actions: !_isLoading && _pdfPath != null
          ? [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _shareReceipt,
                tooltip: 'share'.tr(),
              ),
              IconButton(
                icon: _isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.download, color: Colors.white),
                onPressed: _isDownloading ? null : _downloadToDevice,
                tooltip: 'download'.tr(),
              ),
            ]
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_pdfPath != null) {
      return _buildPdfViewer();
    }

    return _buildEmptyState();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 24),
          Text(
            'loading_receipt'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'please_wait'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              'receipt_error'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadPdf,
              icon: const Icon(Icons.refresh),
              label: Text('retry'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'contract_unavailable'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PDFView(
          filePath: _pdfPath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          defaultPage: _currentPage,
          fitPolicy: FitPolicy.BOTH,
          preventLinkNavigation: false,
          onRender: (pages) {
            // Pages rendered
          },
          onViewCreated: (PDFViewController pdfViewController) {
            // PDF view created
          },
          onPageChanged: (int? page, int? total) {
            setState(() {
              _currentPage = page ?? 0;
            });
          },
          onError: (error) {
            setState(() {
              _error = error.toString();
            });
          },
          onPageError: (page, error) {
            debugPrint('Erreur page $page: $error');
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Nettoyer le fichier temporaire
    if (_pdfPath != null) {
      File(_pdfPath!).delete().catchError((e) {
        debugPrint('Erreur lors de la suppression du fichier temporaire: $e');
        return File(_pdfPath!);
      });
    }
    super.dispose();
  }
}
