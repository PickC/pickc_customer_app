import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

extension StatusColorExtension on String {
  Color toStatusColor() {
    switch (toUpperCase()) {
      case 'CONFIRMED':
        return AppColors.statusConfirmed;
      case 'CANCELLED':
        return AppColors.statusCancelled;
      case 'COMPLETED':
        return AppColors.statusCompleted;
      case 'PENDING':
        return AppColors.statusPending;
      default:
        return AppColors.textHint;
    }
  }

  bool get isConfirmed => toUpperCase() == AppConstants.statusConfirmed;
  bool get isCancelled => toUpperCase() == AppConstants.statusCancelled;
  bool get isCompleted => toUpperCase() == AppConstants.statusCompleted;
  bool get isPending => toUpperCase() == AppConstants.statusPending;
}

extension ContextExtension on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.statusCancelled : null,
      ),
    );
  }
}
