import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum PickCToastType { success, error, info, warning }

/// App-styled toast using SnackBar.
/// Usage:
///   PickCToast.show(context, 'Booking confirmed!', type: PickCToastType.success);
class PickCToast {
  PickCToast._();

  static void show(
    BuildContext context,
    String message, {
    PickCToastType type = PickCToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: duration,
        content: _ToastContent(message: message, type: type),
      ),
    );
  }
}

class _ToastContent extends StatelessWidget {
  final String message;
  final PickCToastType type;

  const _ToastContent({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1800),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _borderColor,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(_icon, color: _iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (type) {
        PickCToastType.success => Icons.check_circle_outline,
        PickCToastType.error => Icons.error_outline,
        PickCToastType.warning => Icons.warning_amber_outlined,
        PickCToastType.info => Icons.info_outline,
      };

  Color get _iconColor => switch (type) {
        PickCToastType.success => AppColors.statusCompleted,
        PickCToastType.error => AppColors.statusCancelled,
        PickCToastType.warning => AppColors.accentYellow,
        PickCToastType.info => AppColors.accentYellow,
      };

  Color get _borderColor => switch (type) {
        PickCToastType.success => AppColors.statusCompleted.withValues(alpha: 0.5),
        PickCToastType.error => AppColors.statusCancelled.withValues(alpha: 0.5),
        PickCToastType.warning => AppColors.accentYellow.withValues(alpha: 0.4),
        PickCToastType.info => AppColors.textHint.withValues(alpha: 0.4),
      };
}
