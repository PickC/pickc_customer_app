import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/providers.dart';
import '../widgets/pickc_button.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

class CashPaymentScreen extends ConsumerStatefulWidget {
  const CashPaymentScreen({super.key});

  @override
  ConsumerState<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends ConsumerState<CashPaymentScreen> {
  bool _isLoading = false;
  String? _amount;

  @override
  void initState() {
    super.initState();
    _loadAmount();
  }

  Future<void> _loadAmount() async {
    final bookingNo = ref.read(localStorageProvider).getBookingNo() ?? '';
    final dio = ref.read(dioClientProvider).dio;
    // TODO: GET master/customer/billDetails/{bno}
    try {
      final url = ApiConstants.getAmtCurrentBooking.replaceAll('{bno}', bookingNo);
      final response = await dio.get(url);
      if (mounted) {
        setState(() => _amount = response.data?['amount']?.toString());
      }
    } catch (_) {}
  }

  Future<void> _confirmCashPayment() async {
    setState(() => _isLoading = true);
    final localStorage = ref.read(localStorageProvider);
    final bookingNo = localStorage.getBookingNo() ?? '';
    final driverId = localStorage.getDriverId() ?? '';
    final dio = ref.read(dioClientProvider).dio;

    // TODO: POST master/customer/pay/{bookingNo}/{mDriverId}/{payType}
    try {
      final url = ApiConstants.payByCash
          .replaceAll('{bookingNo}', bookingNo)
          .replaceAll('{mDriverId}', driverId)
          .replaceAll('{payType}', 'CASH');
      await dio.post(url);
      if (mounted) {
        context.go(RouteNames.paymentStatus, extra: {'isSuccess': true});
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Payment failed'),
            backgroundColor: AppColors.statusCancelled,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Cash Payment'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.money, color: AppColors.accentYellow, size: 80),
            const SizedBox(height: 24),
            Text('Amount Due', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              '₹${_amount ?? '--'}',
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.accentYellow,
                fontSize: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please pay this amount to the driver in cash.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            PickcButton(
              label: 'CONFIRM CASH PAYMENT',
              isLoading: _isLoading,
              onPressed: _confirmCashPayment,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
