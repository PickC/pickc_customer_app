import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';
import '../../providers/providers.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String? _amount;
  String? _bookingNo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    final localStorage = ref.read(localStorageProvider);
    _bookingNo = localStorage.getBookingNo() ?? 'DEMO-001';
    final dio = ref.read(dioClientProvider).dio;
    try {
      final url = ApiConstants.getAmtCurrentBooking
          .replaceAll('{bno}', _bookingNo!);
      final response = await dio.get(url);
      if (mounted) {
        setState(() {
          _amount = response.data?['amount']?.toString() ?? '1.00';
          _loading = false;
        });
      }
    } catch (_) {
      // Hardcoded to ₹1 for now (replace with real API amount in production)
      if (mounted) setState(() { _amount = '1.00'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localStorage = ref.read(localStorageProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.home),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentYellow))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Booking + amount card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1800),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.accentYellow.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'CRN: ${_bookingNo ?? '--'}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accentYellow,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '₹${_amount ?? '--'}',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.accentYellow,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Total Amount Due',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'Select Payment Method',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.textHint),
                  ),
                  const SizedBox(height: 14),

                  // ── Cash payment ────────────────────────────────────────
                  _PaymentTile(
                    icon: Icons.payments_outlined,
                    title: 'Cash Payment',
                    subtitle: 'Pay directly to the driver',
                    onTap: () {
                      final amount = _amount ?? '0';
                      ref.read(cashPaidAmountProvider.notifier).state = amount;
                      ref.read(homeNotifierProvider.notifier).resetAfterPayment();
                      context.go(RouteNames.home);
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Razorpay online payment ─────────────────────────────
                  _PaymentTile(
                    icon: Icons.credit_card_outlined,
                    title: 'Pay Online',
                    subtitle: 'Cards, UPI, Net Banking, Wallets',
                    isHighlighted: true,
                    onTap: () => context.push(
                      RouteNames.razorpayPayment,
                      extra: {
                        'amount': _amount ?? '0',
                        'bookingNo': _bookingNo ?? '',
                        'customerName':
                            localStorage.getName() ?? 'Customer',
                        'customerMobile':
                            localStorage.getMobileNo() ?? '',
                      },
                    ),
                  ),

                  const Spacer(),

                  // ── Security note ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline,
                          color: AppColors.textHint.withValues(alpha: 0.6),
                          size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Secured by Razorpay',
                        style: AppTextStyles.bodySmall
                            .copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isHighlighted;

  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.accentYellow.withValues(alpha: 0.08)
              : const Color(0xFF1E1800),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted
                ? AppColors.accentYellow
                : AppColors.textHint.withValues(alpha: 0.3),
            width: isHighlighted ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accentYellow, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: isHighlighted
                    ? AppColors.accentYellow
                    : AppColors.textHint,
                size: 22),
          ],
        ),
      ),
    );
  }
}
