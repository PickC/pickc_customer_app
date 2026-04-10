import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';

const _cancelReasons = [
  'Driver is late',
  'Changed my mind',
  'Booked another truck',
  'Driver denied duty',
];

void _showCancelDialog(BuildContext context, WidgetRef ref) {
  String? selected;

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Container(
                width: double.infinity,
                color: AppColors.backgroundDark,
                padding: const EdgeInsets.symmetric(vertical: 18),
                alignment: Alignment.center,
                child: Text(
                  'Cancel Booking',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.accentYellow,
                  ),
                ),
              ),

              // Reason options
              ...List.generate(_cancelReasons.length, (i) {
                final reason = _cancelReasons[i];
                final isSelected = selected == reason;
                return Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => selected = reason),
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFFEEEEEE),
                        child: Row(
                          children: [
                            // Yellow left-border when selected
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 4,
                              height: 52,
                              color: isSelected
                                  ? AppColors.accentYellow
                                  : Colors.transparent,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: Icon(Icons.check_circle,
                                    color: AppColors.accentYellow, size: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (i < _cancelReasons.length - 1)
                      const Divider(height: 1, color: Color(0xFFCCCCCC)),
                  ],
                );
              }),

              // Don't Cancel | Cancel Booking buttons
              Container(
                color: AppColors.backgroundDark,
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          "Don't Cancel",
                          style: AppTextStyles.labelButton.copyWith(
                            color: AppColors.accentYellow,
                          ),
                        ),
                      ),
                    ),
                    Container(
                        width: 1, height: 48, color: AppColors.textHint),
                    Expanded(
                      child: TextButton(
                        onPressed: selected == null
                            ? null
                            : () {
                                Navigator.of(ctx).pop();
                                ref
                                    .read(homeNotifierProvider.notifier)
                                    .cancelBooking(reason: selected!);
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          'Cancel Booking',
                          style: AppTextStyles.labelButton.copyWith(
                            color: selected == null
                                ? AppColors.textHint
                                : AppColors.statusCancelled,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer hint
              Container(
                width: double.infinity,
                color: AppColors.backgroundDark,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                alignment: Alignment.center,
                child: Text(
                  'Please tell us why you want to cancel',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accentYellow),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class DriverDetailsWidget extends ConsumerWidget {
  const DriverDetailsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeNotifierProvider);
    final isWaiting = homeState == HomeState.waitingForDriver;

    if (isWaiting) return _WaitingPanel(ref: ref);

    final driverAsync = ref.watch(currentDriverProvider);
    final otp = ref.watch(otpProvider);
    final eta = ref.watch(etaMinutesProvider);
    final statusText = ref.watch(tripStatusTextProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
              color: Colors.black45, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: driverAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(e.toString(), style: AppTextStyles.bodySmall),
        ),
        data: (driver) {
          if (driver == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── OTP / Status bar ─────────────────────────────────────
              Container(
                width: double.infinity,
                color: AppColors.backgroundDark,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Status
                    Expanded(
                      child: Text(
                        statusText,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.accentYellow,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ETA
                    if (eta > 0) ...[
                      const SizedBox(width: 8),
                      _StatusPill(
                          label: 'ETA: $eta mins',
                          color: AppColors.statusCompleted),
                    ],
                    // OTP
                    if (otp.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _StatusPill(
                          label: 'OTP: $otp',
                          color: AppColors.accentYellow),
                    ],
                  ],
                ),
              ),
              const Divider(
                  height: 1,
                  color: Color(0xFF2A2200),
                  thickness: 1),

              // ── Driver info row ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.accentYellow, width: 2),
                        color: AppColors.appBlue,
                      ),
                      child: const Icon(Icons.person,
                          color: AppColors.textLight, size: 30),
                    ),
                    const SizedBox(width: 12),

                    // Driver details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver.name ?? 'Driver',
                              style: AppTextStyles.titleMedium),
                          Text(driver.vehicleType ?? '',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.accentYellow,
                                  fontSize: 12)),
                          Text('Veh No. ${driver.vehicleNumber ?? ''}',
                              style: AppTextStyles.bodySmall),
                          const SizedBox(height: 4),
                          _StarRating(
                              rating: double.tryParse(
                                      driver.rating ?? '0') ??
                                  0),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(
                  height: 1,
                  color: Color(0xFF2A2200),
                  thickness: 1,
                  indent: 16,
                  endIndent: 16),

              // ── Action buttons ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    _ActionBtn(
                      icon: Icons.phone,
                      label: 'Call Driver',
                      color: AppColors.statusCompleted,
                      onTap: () async {
                        final uri = Uri.parse('tel:${driver.mobile}');
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                    ),
                    _ActionBtn(
                      icon: Icons.support_agent,
                      label: 'Support',
                      color: AppColors.statusPending,
                      onTap: () {},
                    ),
                    if (homeState == HomeState.bookingConfirmed)
                      _ActionBtn(
                        icon: Icons.cancel_outlined,
                        label: 'Cancel',
                        color: AppColors.statusCancelled,
                        onTap: () =>
                            _showCancelDialog(context, ref),
                      ),
                    if (homeState == HomeState.tripActive)
                      _ActionBtn(
                        icon: Icons.my_location,
                        label: 'Track',
                        color: AppColors.accentYellow,
                        onTap: () {
                          final pickup = ref.read(pickupLatLngProvider);
                          final drop = ref.read(dropLatLngProvider);
                          context.push(
                            RouteNames.driverTracking,
                            extra: {
                              'tripId': 'DEMO-001',
                              'pickupLatLng': pickup,
                              'dropLatLng': drop,
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waiting for driver panel
// ─────────────────────────────────────────────────────────────────────────────

class _WaitingPanel extends StatelessWidget {
  final WidgetRef ref;
  const _WaitingPanel({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
              color: Colors.black45, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accentYellow,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Truck booked successfully!',
                    style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.accentYellow)),
                Text('Waiting for driver confirmation...',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(homeNotifierProvider.notifier).cancelBooking(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.statusCancelled,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side:
                    const BorderSide(color: AppColors.statusCancelled),
              ),
            ),
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppColors.statusCancelled,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          half ? Icons.star_half : (filled ? Icons.star : Icons.star_border),
          color: AppColors.accentYellow,
          size: 14,
        );
      }),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
