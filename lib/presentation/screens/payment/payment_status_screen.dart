import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';
import '../widgets/pickc_button.dart';

class PaymentStatusScreen extends ConsumerWidget {
  final bool isSuccess;
  final String? paymentId;
  final String? amount;
  final String? bookingNo;
  final String? errorMessage;

  const PaymentStatusScreen({
    super.key,
    required this.isSuccess,
    this.paymentId,
    this.amount,
    this.bookingNo,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Status icon ───────────────────────────────────────────
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isSuccess
                    ? AppColors.statusCompleted
                    : AppColors.statusCancelled,
                size: 100,
              ),
              const SizedBox(height: 20),

              // ── Title ─────────────────────────────────────────────────
              Text(
                isSuccess ? 'Payment Successful!' : 'Payment Failed',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: isSuccess
                      ? AppColors.statusCompleted
                      : AppColors.statusCancelled,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isSuccess
                    ? 'Your payment was processed successfully.\nThank you for using Pick-C!'
                    : (errorMessage ??
                        'Payment could not be processed.\nPlease try again.'),
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ── Details card ──────────────────────────────────────────
              if (isSuccess)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1800),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            AppColors.statusCompleted.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      if (amount != null)
                        _DetailRow(
                          icon: Icons.currency_rupee,
                          label: 'Amount Paid',
                          value: '₹$amount',
                          valueColor: AppColors.accentYellow,
                        ),
                      if (bookingNo != null) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.receipt_outlined,
                          label: 'Booking No',
                          value: bookingNo!,
                        ),
                      ],
                      if (paymentId != null && paymentId!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Payment ID',
                          value: paymentId!,
                          small: true,
                        ),
                      ],
                    ],
                  ),
                ),

              if (!isSuccess && amount != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1800),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.statusCancelled
                            .withValues(alpha: 0.3)),
                  ),
                  child: _DetailRow(
                    icon: Icons.currency_rupee,
                    label: 'Amount',
                    value: '₹$amount',
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // ── Actions ───────────────────────────────────────────────
              PickcButton(
                label: 'GO TO HOME',
                onPressed: () {
                  if (isSuccess) {
                    ref.read(homeNotifierProvider.notifier).resetAfterPayment();
                  }
                  context.go(RouteNames.home);
                },
              ),
              if (isSuccess) ...[
                const SizedBox(height: 12),
                PickcButton(
                  label: 'VIEW INVOICE',
                  onPressed: () => context.push(
                    RouteNames.invoice,
                    extra: {'bookingNo': bookingNo ?? ''},
                  ),
                ),
              ],
              if (!isSuccess) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentYellow,
                    side: const BorderSide(color: AppColors.accentYellow),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('TRY AGAIN',
                      style: AppTextStyles.labelButton
                          .copyWith(color: AppColors.accentYellow)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool small;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textHint, size: 18),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.bodySmall),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: valueColor ?? AppColors.textLight,
              fontSize: small ? 11 : 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
