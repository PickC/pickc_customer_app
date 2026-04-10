import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Emergency'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.statusCancelled.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.statusCancelled),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.statusCancelled, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'In case of emergency, please call the numbers below.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _emergencyTile('Police', '100', Icons.local_police),
            _emergencyTile('Ambulance', '102', Icons.local_hospital),
            _emergencyTile('Fire Brigade', '101', Icons.local_fire_department),
            _emergencyTile('Pick-C Support', '1800-PICKC-00', Icons.support_agent),
          ],
        ),
      ),
    );
  }

  Widget _emergencyTile(String label, String number, IconData icon) {
    return Builder(builder: (context) {
      return Card(
        color: AppColors.appBlue.withValues(alpha:0.3),
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(icon, color: AppColors.accentYellow),
          title: Text(label, style: AppTextStyles.titleMedium),
          subtitle: Text(number, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accentYellow)),
          trailing: IconButton(
            icon: const Icon(Icons.call, color: AppColors.statusCompleted),
            onPressed: () => _call(number),
          ),
        ),
      );
    });
  }
}
