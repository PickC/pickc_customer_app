import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/demo_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/booking/booking_history_model.dart';
import '../../../demo/mock_data.dart';
import '../../providers/providers.dart';
import 'package:dio/dio.dart';

final bookingHistoryProvider =
    FutureProvider<List<BookingHistoryModel>>((ref) async {
  if (kDemoMode) return MockData.bookings;
  final dio = ref.read(dioClientProvider).dio;
  final mobile = ref.read(localStorageProvider).getMobileNo() ?? '';
  final url =
      ApiConstants.bookingHistory.replaceAll('{mobile}', mobile);
  // TODO: GET master/customer/bookingHistoryListbyCustomerMobileNo/{mobile}
  try {
    final response = await dio.get(url);
    final list = (response.data as List? ?? [])
        .map((e) =>
            BookingHistoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  } on DioException {
    return [];
  }
});

class BookingHistoryScreen extends ConsumerWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(bookingHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Booking History'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(), style: AppTextStyles.bodyMedium),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, color: AppColors.textHint, size: 64),
                  const SizedBox(height: 16),
                  Text('No bookings yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final b = bookings[index];
              return _BookingCard(booking: b);
            },
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingHistoryModel booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final statusColor = (booking.status ?? '').toStatusColor();

    return Card(
      color: AppColors.appBlue.withValues(alpha:0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.textHint, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BK#${booking.bookingNo ?? ''}',
                  style: AppTextStyles.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    booking.status ?? '',
                    style: AppTextStyles.bodySmall.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _tripRow(Icons.circle, Colors.green, booking.fromAddress ?? ''),
            _tripRow(Icons.location_on, AppColors.statusCancelled, booking.toAddress ?? ''),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(booking.date ?? '', style: AppTextStyles.bodySmall),
                Text(
                  '₹${booking.amount ?? ''}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.accentYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
