import 'package:flutter/material.dart';
import '../components/pdf_viewer_modal.dart';

/// Classe utilitaire pour tester la modal PDF avec des données d'exemple
class PdfTestHelper {
  
  /// Teste la modal PDF avec une URL d'exemple
  static void showTestPdfModal(BuildContext context) {
    // URL d'exemple d'un PDF de test (remplacer par une vraie URL de justificatif)
    const testPdfUrl = 'https://gateway.agvm.mg/serviceupload/file/tickets-transactions%2F1759925991966-92dde14f-75da-4374-91c0-b4b833c0219d.pdf';
    
    showDialog(
      context: context,
      builder: (context) => const PdfViewerModal(
        pdfUrl: testPdfUrl,
        title: 'Test - Justificatif de paiement',
        subtitle: 'Local P-002 - Test Reference',
      ),
    );
  }
  
  /// Teste la modal PDF avec des données réelles d'un paiement
  static void showRealReceiptModal(
    BuildContext context, {
    required String pdfUrl,
    required String localName,
    required String reference,
  }) {
    showDialog(
      context: context,
      builder: (context) => PdfViewerModal(
        pdfUrl: pdfUrl,
        title: 'Justificatif de paiement',
        subtitle: '$localName - $reference',
      ),
    );
  }
  
  /// Simule une erreur de chargement PDF
  static void showErrorTestModal(BuildContext context) {
    const invalidPdfUrl = 'https://invalid-url.com/nonexistent.pdf';
    
    showDialog(
      context: context,
      builder: (context) => const PdfViewerModal(
        pdfUrl: invalidPdfUrl,
        title: 'Test Erreur - Justificatif',
        subtitle: 'URL invalide pour test d\'erreur',
      ),
    );
  }
  
  /// Affiche un bouton de test dans l'interface (pour debug uniquement)
  static Widget buildTestButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => showTestPdfModal(context),
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text('Test PDF'),
      backgroundColor: Colors.orange,
    );
  }
  
  /// Affiche un menu de test avec plusieurs options
  static void showTestMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tests Modal PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.green),
              title: const Text('Test PDF Valide'),
              subtitle: const Text('Teste avec une URL PDF valide'),
              onTap: () {
                Navigator.pop(context);
                showTestPdfModal(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text('Test Erreur'),
              subtitle: const Text('Teste la gestion d\'erreur'),
              onTap: () {
                Navigator.pop(context);
                showErrorTestModal(context);
              },
            ),
            
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension pour ajouter facilement des tests PDF à n'importe quel widget
extension PdfTestExtension on BuildContext {
  
  /// Raccourci pour afficher la modal de test PDF
  void showTestPdf() {
    PdfTestHelper.showTestPdfModal(this);
  }
  
  /// Raccourci pour afficher le menu de test
  void showPdfTestMenu() {
    PdfTestHelper.showTestMenu(this);
  }
}
