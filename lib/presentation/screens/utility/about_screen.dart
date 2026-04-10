import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('About Pick-C'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'PICK-C',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.accentYellow,
                  fontSize: 48,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Your Trusted Logistics Partner',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 32),
            Text('About Us', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            Text(
              'Pick-C is a technology-driven logistics platform connecting customers with reliable truck drivers for seamless goods transportation. We provide end-to-end visibility, real-time tracking, and transparent pricing.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Version', style: AppTextStyles.titleMedium),
            const SizedBox(height: 4),
            Text('1.0.0', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
            const SizedBox(height: 24),
            Text('Contact', style: AppTextStyles.titleMedium),
            const SizedBox(height: 4),
            Text('support@pickcargo.in', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accentYellow)),
          ],
        ),
      ),
    );
  }
}
