import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/demo_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invoice/invoice_model.dart';
import '../../../demo/mock_data.dart';
import '../../providers/providers.dart';
import '../widgets/pickc_button.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  final String bookingNo;

  const InvoiceScreen({super.key, required this.bookingNo});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  InvoiceModel? _invoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    if (kDemoMode) {
      setState(() {
        _invoice = MockData.invoice;
        _isLoading = false;
      });
      return;
    }
    final dio = ref.read(dioClientProvider).dio;
    final bno = widget.bookingNo.isNotEmpty
        ? widget.bookingNo
        : ref.read(localStorageProvider).getBookingNo() ?? '';
    // TODO: GET master/customer/tripInvoice/{bookingNumber}
    try {
      final url = ApiConstants.getUserInvoiceDetails
          .replaceAll('{bookingNumber}', bno);
      final response = await dio.get(url);
      setState(() {
        _invoice = InvoiceModel.fromJson(response.data as Map<String, dynamic>);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendByEmail() async {
    final email = ref.read(localStorageProvider).getEmail() ?? '';
    final bno = _invoice?.bookingNo ?? '';
    final dio = ref.read(dioClientProvider).dio;
    // TODO: GET master/customer/sendInvoiceMail/{bno}/{email}/true
    try {
      final url = ApiConstants.sendInvoiceMail
          .replaceAll('{bno}', bno)
          .replaceAll('{email}', email);
      await dio.get(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice sent to your email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send email: $e'),
              backgroundColor: AppColors.statusCancelled),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Invoice'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoice == null
              ? Center(
                  child: Text('Invoice not available',
                      style: AppTextStyles.bodyMedium))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text('INVOICE',
                            style: AppTextStyles.headlineMedium.copyWith(
                                color: AppColors.accentYellow)),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text('BK#${_invoice!.bookingNo ?? ''}',
                            style: AppTextStyles.bodyMedium),
                      ),
                      const Divider(color: AppColors.textHint, height: 32),
                      _row('Customer', _invoice!.customerName),
                      _row('Driver', _invoice!.driverName),
                      _row('Vehicle', _invoice!.vehicleType),
                      _row('Vehicle No.', _invoice!.vehicleNumber),
                      const Divider(color: AppColors.textHint, height: 24),
                      _row('From', _invoice!.fromAddress),
                      _row('To', _invoice!.toAddress),
                      _row('Date', _invoice!.date),
                      _row('Start Time', _invoice!.startTime),
                      _row('End Time', _invoice!.endTime),
                      const Divider(color: AppColors.textHint, height: 24),
                      _row('Payment Type', _invoice!.paymentType),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Amount',
                              style: AppTextStyles.titleMedium),
                          Text(
                            '₹${_invoice!.totalAmount ?? '--'}',
                            style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.accentYellow),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      PickcButton(
                          label: 'EMAIL INVOICE',
                          onPressed: _sendByEmail),
                      const SizedBox(height: 12),
                      PickcButton(
                        label: 'RATE THE DRIVER',
                        onPressed: () => context.push(RouteNames.driverRating),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint)),
          Flexible(
            child: Text(
              value ?? '--',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
