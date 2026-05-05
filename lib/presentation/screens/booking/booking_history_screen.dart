import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/demo_mode.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/booking/booking_model.dart';
import '../../../demo/mock_data.dart';
import '../../providers/providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final bookingHistoryProvider = FutureProvider<List<BookingModel>>((ref) async {
  if (kDemoMode) return MockData.bookings;
  final dio = ref.read(dioClientProvider).dio;
  final mobile = ref.read(localStorageProvider).getMobileNo() ?? '';
  final url =
      ApiConstants.customerBookings.replaceAll('{customerId}', mobile);
  try {
    final response = await dio.get(url);
    return (response.data as List? ?? [])
        .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class BookingHistoryScreen extends ConsumerWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(bookingHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Booking History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(bookingHistoryProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentYellow),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off,
                  color: AppColors.textHint, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load bookings',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textHint)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(bookingHistoryProvider),
                child: const Text('Retry',
                    style: TextStyle(color: AppColors.accentYellow)),
              ),
            ],
          ),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history,
                      color: AppColors.textHint, size: 64),
                  const SizedBox(height: 16),
                  Text('No bookings yet',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.accentYellow,
            backgroundColor: AppColors.backgroundDark,
            onRefresh: () async {
              ref.invalidate(bookingHistoryProvider);
              try {
                await ref.read(bookingHistoryProvider.future);
              } catch (_) {}
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _BookingCard(
                booking: bookings[i],
                onTap: () => context.push(
                  RouteNames.bookingDetail,
                  extra: bookings[i],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card widget — Uber activity history style
// ─────────────────────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.onTap});

  static final _dateFmt = DateFormat('dd-MM-yyyy · HH:mm');

  @override
  Widget build(BuildContext context) {
    final statusColor = booking.statusColor;
    final dateStr = booking.bookingDate != null
        ? _dateFmt.format(booking.bookingDate!)
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1500),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textHint.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Vehicle icon ──────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accentYellow.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.accentYellow,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // ── Main content ──────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle name + status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.vehicleTypeName?.isNotEmpty == true
                                  ? booking.vehicleTypeName!
                                  : 'Vehicle',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 14,
                                color: AppColors.textLight,
                              ),
                            ),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.6),
                              width: 0.8),
                        ),
                        child: Text(
                          booking.statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // From
                  _TripRow(
                    icon: Icons.circle,
                    iconColor: const Color(0xFF43A047),
                    text: booking.locationFrom,
                  ),

                  // Dashed connector
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Column(
                      children: List.generate(
                        2,
                        (_) => Container(
                          width: 1.5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(vertical: 1.5),
                          color: AppColors.textHint.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),

                  // To
                  _TripRow(
                    icon: Icons.stop_rounded,
                    iconColor: const Color(0xFFE53935),
                    text: booking.locationTo,
                  ),
                ],
              ),
            ),

            // ── Chevron ───────────────────────────────────────────────────
            const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _TripRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 11),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 12,
              color: AppColors.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
