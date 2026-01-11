import 'package:flutter/material.dart';
import '../services/real_time_service.dart';

/// Widget de démonstration pour tester le système de notification de données
class DataRefreshDemo extends StatelessWidget {
  const DataRefreshDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final realTimeService = RealTimeService();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔄 Système de Notification de Données',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Testez les notifications automatiques des onglets :',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTestButton(
                'Nouvelle Réservation',
                Icons.add_location,
                Colors.green,
                () => realTimeService.notifyNewReservation(
                  reservationId: 'test-${DateTime.now().millisecondsSinceEpoch}',
                  localId: 'local-123',
                ),
              ),
              _buildTestButton(
                'Nouveau Paiement',
                Icons.payment,
                Colors.orange,
                () => realTimeService.notifyNewPayment(
                  paymentId: 'pay-${DateTime.now().millisecondsSinceEpoch}',
                  amount: 2000.0,
                  status: 'success',
                ),
              ),
              _buildTestButton(
                'Réservation Annulée',
                Icons.cancel,
                Colors.red,
                () => realTimeService.notifyReservationCancelled(
                  reservationId: 'res-${DateTime.now().millisecondsSinceEpoch}',
                ),
              ),
              _buildTestButton(
                'Profil Mis à Jour',
                Icons.person,
                Colors.purple,
                () => realTimeService.notifyProfileUpdated(
                  userId: 'user-123',
                ),
              ),
              _buildTestButton(
                'Zone Modifiée',
                Icons.location_city,
                Colors.teal,
                () => realTimeService.notifyZoneChanged(
                  zoneId: 'zone-456',
                  action: 'updated',
                ),
              ),
              _buildTestButton(
                'Rafraîchissement Forcé',
                Icons.refresh,
                Colors.indigo,
                () => realTimeService.forceRefresh(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les onglets Réservations et Paiements se rafraîchiront automatiquement.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
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
}
