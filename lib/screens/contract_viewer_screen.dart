import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/contract_service.dart';

class ContractViewerScreen extends StatefulWidget {
  final String locationId;
  final String? locationName;

  const ContractViewerScreen({
    super.key,
    required this.locationId,
    this.locationName,
  });

  @override
  State<ContractViewerScreen> createState() => _ContractViewerScreenState();
}

class _ContractViewerScreenState extends State<ContractViewerScreen> {
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _error;
  String? _pdfPath;
  Uint8List? _pdfBytes;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadContract();
    // Nettoyer les anciens PDFs au démarrage
    ContractService.cleanupOldPdfs();
  }

  Future<void> _loadContract() async {
    try {
      debugPrint('📄 _loadContract appelé pour locationId: ${widget.locationId}');
      
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Vérifier si le PDF existe déjà en local
      String? existingPath = await ContractService.getExistingPdfPath(widget.locationId);
      debugPrint('🔍 Vérification du PDF existant: $existingPath');
      
      if (existingPath != null && await File(existingPath).exists()) {
        debugPrint('📄 Utilisation du PDF existant: $existingPath');
        
        // Charger aussi les bytes pour le téléchargement
        final existingFile = File(existingPath);
        final existingBytes = await existingFile.readAsBytes();
        debugPrint('📊 Taille du PDF existant: ${existingBytes.length} bytes');
        
        setState(() {
          _pdfPath = existingPath;
          _pdfBytes = existingBytes;
          _isLoading = false;
        });
        return;
      }

      // Télécharger le PDF depuis l'API
      debugPrint('🔄 Téléchargement du nouveau contrat depuis l\'API...');
      debugPrint('🌐 URL: https://gateway.agvm.mg/servicemodernmarket/locations/contrat-bail/${widget.locationId}');
      
      final pdfBytes = await ContractService.downloadContractPdf(widget.locationId);
      debugPrint('📥 PDF téléchargé, taille: ${pdfBytes.length} bytes');
      
      // Sauvegarder temporairement
      debugPrint('💾 Sauvegarde temporaire du PDF...');
      final tempPath = await ContractService.savePdfToTemp(pdfBytes, widget.locationId);
      debugPrint('📁 PDF sauvegardé temporairement: $tempPath');
      
      setState(() {
        _pdfPath = tempPath;
        _pdfBytes = pdfBytes;
        _isLoading = false;
      });
      
      debugPrint('✅ Contrat chargé avec succès');

    } catch (e) {
      debugPrint('❌ Erreur lors du chargement du contrat: $e');
      debugPrint('🔍 Stack trace: ${StackTrace.current}');
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadToDevice() async {
    debugPrint('📥 _downloadToDevice appelé');
    
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

    debugPrint('📊 Taille du PDF à télécharger: ${_pdfBytes!.length} bytes');
    debugPrint('🆔 LocationId: ${widget.locationId}');

    try {
      setState(() => _isDownloading = true);
      debugPrint('🔄 État de téléchargement activé');

      final savedPath = await ContractService.savePdfToDownloads(_pdfBytes!, widget.locationId);
      debugPrint('💾 Résultat de sauvegarde: $savedPath');
      
      if (savedPath != null && mounted) {
        debugPrint('✅ Téléchargement réussi, affichage du message de succès');
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
                        'contract_downloaded_successfully'.tr(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        savedPath.split('/').last, // Nom du fichier
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
              onPressed: () {
                debugPrint('📖 Tentative d\'ouverture du PDF: $savedPath');
                ContractService.openPdfWithExternalApp(savedPath);
              },
            ),
          ),
        );
      } else if (mounted) {
        debugPrint('❌ Échec du téléchargement, savedPath est null');
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
      debugPrint('🔍 Stack trace: ${StackTrace.current}');
      
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
        debugPrint('🔄 État de téléchargement désactivé');
      }
    }
  }

  Future<void> _shareContract() async {
    if (_pdfPath == null) return;
    
    try {
      await ContractService.openPdfWithExternalApp(_pdfPath!);
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
            'contract_title'.tr(),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (widget.locationName != null)
            Text(
              widget.locationName!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
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
                onPressed: _shareContract,
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
            'loading_contract'.tr(),
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
              'contract_load_error'.tr(),
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
              onPressed: _loadContract,
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
            'no_contract_available'.tr(),
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

}
