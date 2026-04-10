import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';
import '../../providers/vehicle_provider.dart';
import 'book_later_sheet.dart';
import 'cargo_type_sheet.dart';
import 'loading_unloading_card.dart';
import 'receiver_mobile_sheet.dart';

/// Tracks the open/close body toggle per vehicle id.
final _bodyOpenProvider =
    StateProvider.family<bool, int>((ref, id) => false);

/// Uber-style full-width truck selection cards with OPEN / CLOSE body toggle.
/// Designed to live inside a [DraggableScrollableSheet].
class TruckCategoriesWidget extends ConsumerWidget {
  final ScrollController scrollController;

  const TruckCategoriesWidget({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleTypesProvider);
    final selectedId = ref.watch(selectedVehicleProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        boxShadow: [
          BoxShadow(
              color: Colors.black45, blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Vehicle cards list
          Expanded(
            child: vehiclesAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.accentYellow)),
              error: (e, _) => Center(
                  child: Text(e.toString(), style: AppTextStyles.bodySmall)),
              data: (vehicles) => ListView.separated(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                // index 0 = loading/unloading card; rest are vehicle cards
                itemCount: vehicles.length + 1,
                separatorBuilder: (_, i) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const LoadingUnloadingCard();
                  }
                  final v = vehicles[index - 1];
                  final isSelected = selectedId == v.id;
                  final isOpen = ref.watch(_bodyOpenProvider(v.id));
                  final assets = _assetsFor(v.name, isOpen);

                  return GestureDetector(
                    onTap: () => ref
                        .read(homeNotifierProvider.notifier)
                        .selectVehicle(v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentYellow.withValues(alpha: 0.08)
                            : AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentYellow
                              : AppColors.textHint.withValues(alpha: 0.4),
                          width: isSelected ? 1.5 : 0.8,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          // Truck image — changes with OPEN/CLOSE toggle
                          SizedBox(
                            width: 90,
                            height: 60,
                            child: Image.asset(
                              assets.image,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const Icon(
                                Icons.local_shipping,
                                color: AppColors.accentYellow,
                                size: 40,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Name + description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.name,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: isSelected
                                        ? AppColors.accentYellow
                                        : AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  v.description ?? '',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textHint),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isSelected ? '~19 mins' : 'Available',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isSelected
                                        ? AppColors.statusCompleted
                                        : AppColors.textHint,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // OPEN / CLOSE toggle
                          Column(
                            children: [
                              _toggleBtn(
                                label: 'OPEN',
                                active: isOpen,
                                onTap: () => ref
                                    .read(_bodyOpenProvider(v.id).notifier)
                                    .state = true,
                              ),
                              const SizedBox(height: 4),
                              _toggleBtn(
                                label: 'CLOSE',
                                active: !isOpen,
                                onTap: () => ref
                                    .read(_bodyOpenProvider(v.id).notifier)
                                    .state = false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // BOOK LATER | BOOK NOW
          SizedBox(
            height: 50,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: selectedId == null
                        ? null
                        : () => _onBookLater(context, ref),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.backgroundDark,
                      foregroundColor: AppColors.accentYellow,
                      disabledForegroundColor:
                          AppColors.accentYellow.withValues(alpha: 0.35),
                      shape: const RoundedRectangleBorder(),
                      side: const BorderSide(
                          color: AppColors.accentYellow, width: 0.5),
                    ),
                    child: Text('BOOK LATER',
                        style: AppTextStyles.labelButton
                            .copyWith(color: AppColors.accentYellow)),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: selectedId != null
                        ? () => _onBookNow(context, ref)
                        : null,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.accentYellow,
                      foregroundColor: AppColors.backgroundDark,
                      disabledBackgroundColor:
                          AppColors.accentYellow.withValues(alpha: 0.35),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text('BOOK NOW',
                        style: AppTextStyles.labelButton
                            .copyWith(color: AppColors.backgroundDark)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Booking flow helpers ───────────────────────────────────────────────────

  Future<void> _onBookNow(BuildContext context, WidgetRef ref) async {
    // Step 1: cargo type + weight
    final cargoOk = await showCargoTypeSheet(context);
    if (!cargoOk || !context.mounted) return;

    // Step 2: receiver mobile
    final mobileOk = await showReceiverMobileSheet(context);
    if (!mobileOk || !context.mounted) return;

    // Clear any scheduled time (this is Book Now)
    ref.read(scheduledDateTimeProvider.notifier).state = null;

    ref.read(homeNotifierProvider.notifier).confirmBooking();
  }

  Future<void> _onBookLater(BuildContext context, WidgetRef ref) async {
    // Step 1: pick date + time
    final scheduleOk = await showBookLaterSheet(context, ref);
    if (!scheduleOk || !context.mounted) return;

    // Step 2: cargo type + weight
    final cargoOk = await showCargoTypeSheet(context);
    if (!cargoOk || !context.mounted) return;

    // Step 3: receiver mobile
    final mobileOk = await showReceiverMobileSheet(context);
    if (!mobileOk || !context.mounted) return;

    ref.read(homeNotifierProvider.notifier).confirmBooking();
  }

  // ── Toggle button ──────────────────────────────────────────────────────────

  Widget _toggleBtn({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:
              active ? AppColors.accentYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? AppColors.accentYellow : AppColors.textHint,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active
                ? AppColors.backgroundDark
                : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

/// Maps vehicle name + open/close state to the correct asset path.
class _TruckAssets {
  final String image;
  const _TruckAssets({required this.image});
}

_TruckAssets _assetsFor(String vehicleName, bool isOpen) {
  final name = vehicleName.toLowerCase();
  if (name.contains('mini')) {
    return _TruckAssets(
      image: isOpen
          ? 'assets/trucks/mini_opened_truck.png'
          : 'assets/trucks/mini_closed_truck.png',
    );
  }
  if (name.contains('pickup') || name.contains('van') || name.contains('small')) {
    return _TruckAssets(
      image: isOpen
          ? 'assets/trucks/small_open_truck.png'
          : 'assets/trucks/small_closed_truck.png',
    );
  }
  if (name.contains('tata') || name.contains('ace') || name.contains('medium')) {
    return _TruckAssets(
      image: isOpen
          ? 'assets/trucks/meduim_open_truck.png'
          : 'assets/trucks/medium_closed_truck.png',
    );
  }
  if (name.contains('canter') || name.contains('large')) {
    return _TruckAssets(
      image: isOpen
          ? 'assets/trucks/large_open_truck.png'
          : 'assets/trucks/large_closed_truck.png',
    );
  }
  if (name.contains('407') || name.contains('truck')) {
    return _TruckAssets(
      image: isOpen
          ? 'assets/trucks/large_open_truck.png'
          : 'assets/trucks/large_closed_truck.png',
    );
  }
  // fallback
  return _TruckAssets(
    image: isOpen
        ? 'assets/trucks/mini_opened_truck.png'
        : 'assets/trucks/mini_closed_truck.png',
  );
}
