import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/demo_mode.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    if (kDemoMode) {
      // Auto-navigate to home so user can review all screens
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go(RouteNames.home);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pick-C logo
              Image.asset(
                'assets/images/pick_c.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 20),
              // App name
              Text(
                'Pick-C',
                style: AppTextStyles.headlineLarge.copyWith(
                  fontSize: 40,
                  color: AppColors.accentYellow,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              // Tagline
              Text(
                'Logistics simplified',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                  letterSpacing: 0.5,
                ),
              ),
              if (kDemoMode) ...[
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusCancelled.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.statusCancelled),
                  ),
                  child: Text(
                    'DEMO MODE — Navigating to Home…',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.statusCancelled,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 48),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push(RouteNames.signup),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentYellow,
                        foregroundColor: AppColors.backgroundDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'SIGN UP',
                        style: AppTextStyles.labelButton.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push(RouteNames.login),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentYellow,
                        foregroundColor: AppColors.backgroundDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'LOGIN',
                        style: AppTextStyles.labelButton.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
