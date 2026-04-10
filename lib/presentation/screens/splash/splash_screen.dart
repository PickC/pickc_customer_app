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
      body: Column(
        children: [
          // Main logo area fills remaining space
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo / name
                  Text(
                    'PICK-C',
                    style: AppTextStyles.headlineLarge.copyWith(
                      fontSize: 48,
                      color: AppColors.accentYellow,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Trusted Logistics Partner',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  if (kDemoMode) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
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
                ],
              ),
            ),
          ),

          // 50dp yellow bottom bar with Sign Up / Login
          Container(
            height: 50,
            color: AppColors.accentYellow,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => context.push(RouteNames.signup),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.backgroundDark,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(
                      'SIGN UP',
                      style: AppTextStyles.labelButton.copyWith(fontSize: 14),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  color: AppColors.backgroundDark.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => context.push(RouteNames.login),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.backgroundDark,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(
                      'LOGIN',
                      style: AppTextStyles.labelButton.copyWith(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
