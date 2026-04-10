import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/services/razorpay_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/providers.dart';

/// Launched from PaymentScreen with extra:
/// { 'amount': '277.00', 'bookingNo': 'BK001',
///   'customerName': 'Raju', 'customerMobile': '9876543210' }
class RazorpayPaymentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> paymentData;
  const RazorpayPaymentScreen({super.key, required this.paymentData});

  @override
  ConsumerState<RazorpayPaymentScreen> createState() =>
      _RazorpayPaymentScreenState();
}

class _RazorpayPaymentScreenState
    extends ConsumerState<RazorpayPaymentScreen> {
  late final RazorpayService _service;
  bool _processing = false;

  String get _amountStr =>
      widget.paymentData['amount']?.toString() ?? '0';
  String get _bookingNo =>
      widget.paymentData['bookingNo']?.toString() ?? '';
  String get _customerName =>
      widget.paymentData['customerName']?.toString() ?? 'Customer';
  String get _customerMobile =>
      widget.paymentData['customerMobile']?.toString() ?? '';

  /// Amount in paise (Razorpay expects paise, not rupees)
  int get _amountPaise {
    final parsed = double.tryParse(_amountStr) ?? 0.0;
    return (parsed * 100).round();
  }

  @override
  void initState() {
    super.initState();
    _service = RazorpayService();
    // Auto-open checkout after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPayment());
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _startPayment() async {
    if (_processing) return;
    setState(() => _processing = true);

    final result = await _service.openCheckout(
      amountPaise: _amountPaise,
      bookingNo: _bookingNo,
      customerName: _customerName,
      customerMobile: _customerMobile,
    );

    if (!mounted) return;
    setState(() => _processing = false);

    if (result.isSuccess) {
      // Optional: verify signature on backend
      final dio = ref.read(dioClientProvider).dio;
      await _service.verifyPayment(
        dio: dio,
        razorpayPaymentId: result.paymentId ?? '',
        razorpayOrderId: result.orderId ?? '',
        razorpaySignature: result.signature ?? '',
        bookingNo: _bookingNo,
      );

      if (mounted) {
        context.go(RouteNames.paymentStatus, extra: {
          'isSuccess': true,
          'paymentId': result.paymentId,
          'amount': _amountStr,
          'bookingNo': _bookingNo,
        });
      }
    } else {
      if (mounted) {
        context.go(RouteNames.paymentStatus, extra: {
          'isSuccess': false,
          'errorMessage': result.errorMessage,
          'amount': _amountStr,
          'bookingNo': _bookingNo,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This screen shows a loading state while Razorpay checkout is open.
    // The checkout renders as a native overlay on top of this screen.
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Online Payment'),
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _service.dispose();
            context.pop();
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Amount display
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 24),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1800),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.accentYellow.withValues(alpha: 0.35)),
              ),
              child: Column(
                children: [
                  Text('Amount to Pay',
                      style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    '₹$_amountStr',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppColors.accentYellow,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Booking: $_bookingNo',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (_processing) ...[
              const CircularProgressIndicator(
                  color: AppColors.accentYellow),
              const SizedBox(height: 16),
              Text('Opening payment gateway...',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textHint)),
            ] else ...[
              // Retry button if checkout was dismissed without paying
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.credit_card,
                        color: AppColors.backgroundDark),
                    label: Text('RETRY PAYMENT',
                        style: AppTextStyles.labelButton),
                    onPressed: _startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentYellow,
                      foregroundColor: AppColors.backgroundDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('Go back',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textHint)),
              ),
            ],

            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    size: 14,
                    color: AppColors.textHint.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Text('Secured by Razorpay',
                    style:
                        AppTextStyles.bodySmall.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
