import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle headlineLarge = TextStyle(
    color: AppColors.textLight,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headlineMedium = TextStyle(
    color: AppColors.textLight,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle titleLarge = TextStyle(
    color: AppColors.textLight,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMedium = TextStyle(
    color: AppColors.textLight,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyLarge = TextStyle(
    color: AppColors.textLight,
    fontSize: 16,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: AppColors.textLight,
    fontSize: 14,
  );

  static const TextStyle bodySmall = TextStyle(
    color: AppColors.textHint,
    fontSize: 12,
  );

  static const TextStyle labelButton = TextStyle(
    color: AppColors.backgroundDark,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  static const TextStyle hintText = TextStyle(
    color: AppColors.textHint,
    fontSize: 14,
  );

  // Dark background variants
  static const TextStyle bodyDark = TextStyle(
    color: AppColors.textDark,
    fontSize: 14,
  );

  static const TextStyle titleDark = TextStyle(
    color: AppColors.textDark,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}
