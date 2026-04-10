import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';
import '../../providers/vehicle_provider.dart';
import 'book_later_sheet.dart';
import 'loading_unloading_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step labels
// ─────────────────────────────────────────────────────────────────────────────

const _stepLabels = ['Vehicle', 'Cargo', 'Contact'];

// ─────────────────────────────────────────────────────────────────────────────
// Main sheet widget — lives inside the DraggableScrollableSheet
// ─────────────────────────────────────────────────────────────────────────────

class BookingStepperSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  const BookingStepperSheet({super.key, required this.scrollController});

  @override
  ConsumerState<BookingStepperSheet> createState() =>
      _BookingStepperSheetState();
}

class _BookingStepperSheetState extends ConsumerState<BookingStepperSheet>
    with SingleTickerProviderStateMixin {
  int _step = 0;

  // Step-2 controllers
  final _weightCtrl = TextEditingController();

  // Step-3 controllers
  final _mobileCtrl = TextEditingController();
  bool _useOwnMobile = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goNext() {
    if (_step == 0) {
      if (ref.read(selectedVehicleProvider) == null) {
        _snack('Please select a vehicle type');
        return;
      }
    }
    if (_step == 1) {
      if (ref.read(cargoTypeProvider) == null) {
        _snack('Please select a cargo type');
        return;
      }
      ref.read(cargoWeightProvider.notifier).state = _weightCtrl.text.trim();
    }
    setState(() => _step++);
  }

  void _goBack() => setState(() => _step--);

  void _onConfirm() {
    final mobile = _mobileCtrl.text.trim();
    if (!_useOwnMobile && mobile.length < 10) {
      _snack('Please enter a valid 10-digit mobile number');
      return;
    }
    ref.read(receiverMobileProvider.notifier).state =
        _useOwnMobile ? ref.read(customerMobileProvider) : mobile;
    ref.read(scheduledDateTimeProvider.notifier).state = null;
    ref.read(homeNotifierProvider.notifier).confirmBooking();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // ── Step indicator ───────────────────────────────────────────────
          _StepIndicator(currentStep: _step),
          const SizedBox(height: 16),

          // ── Animated step content ────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: _buildStepContent(),
              ),
            ),
          ),

          // ── Bottom navigation bar ─────────────────────────────────────────
          _buildNavBar(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _Step1Vehicle(scrollController: widget.scrollController);
      case 1:
        return _Step2Cargo(weightCtrl: _weightCtrl);
      default:
        return _Step3Contact(
          mobileCtrl: _mobileCtrl,
          useOwn: _useOwnMobile,
          onToggleOwn: (v) {
            setState(() => _useOwnMobile = v);
            if (v) {
              _mobileCtrl.text = ref.read(customerMobileProvider) ?? '';
            } else {
              _mobileCtrl.clear();
            }
          },
        );
    }
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2200), width: 1)),
      ),
      child: Row(
        children: [
          // BACK or BOOK LATER
          Expanded(
            child: TextButton(
              onPressed: _step == 0
                  ? () => _onBookLater()
                  : _goBack,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: AppColors.accentYellow,
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(
                _step == 0 ? 'BOOK LATER' : '← BACK',
                style: AppTextStyles.labelButton
                    .copyWith(color: AppColors.accentYellow),
              ),
            ),
          ),

          Container(width: 1, height: 48, color: const Color(0xFF2A2200)),

          // NEXT or OK
          Expanded(
            child: TextButton(
              onPressed: _step < 2 ? _goNext : _onConfirm,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.accentYellow,
                foregroundColor: AppColors.backgroundDark,
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(
                _step < 2 ? 'NEXT  →' : 'CONFIRM',
                style: AppTextStyles.labelButton
                    .copyWith(color: AppColors.backgroundDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onBookLater() async {
    if (ref.read(selectedVehicleProvider) == null) {
      _snack('Please select a vehicle type first');
      return;
    }
    final ok = await showBookLaterSheet(context, ref);
    if (!ok || !mounted) return;
    _goNext();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: List.generate(_stepLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            // connector line
            final stepIndex = i ~/ 2;
            final done = currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: done ? AppColors.accentYellow : const Color(0xFF2A2200),
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final done = currentStep > stepIndex;
          final active = currentStep == stepIndex;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active
                      ? AppColors.accentYellow
                      : const Color(0xFF2A2200),
                  border: Border.all(
                    color: done || active
                        ? AppColors.accentYellow
                        : AppColors.textHint,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check,
                          size: 14, color: AppColors.backgroundDark)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: active
                                ? AppColors.backgroundDark
                                : AppColors.textHint,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _stepLabels[stepIndex],
                style: TextStyle(
                  fontSize: 10,
                  color: done || active
                      ? AppColors.accentYellow
                      : AppColors.textHint,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Vehicle type + Labour
// ─────────────────────────────────────────────────────────────────────────────

class _Step1Vehicle extends ConsumerWidget {
  final ScrollController scrollController;
  const _Step1Vehicle({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleTypesProvider);
    final selectedId = ref.watch(selectedVehicleProvider);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        const LoadingUnloadingCard(),
        const SizedBox(height: 10),

        vehiclesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.accentYellow),
            ),
          ),
          error: (e, _) =>
              Center(child: Text(e.toString(), style: AppTextStyles.bodySmall)),
          data: (vehicles) => Column(
            children: vehicles.map((v) {
              final isSelected = selectedId == v.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _VehicleTile(
                  vehicle: v,
                  isSelected: isSelected,
                  onTap: () => ref
                      .read(homeNotifierProvider.notifier)
                      .selectVehicle(v),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _VehicleTile extends ConsumerWidget {
  final dynamic vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleTile({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(_bodyOpenProvider(vehicle.id as int));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentYellow.withValues(alpha: 0.08)
              : AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.accentYellow
                : AppColors.textHint.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 54,
              child: Image.asset(
                _imageFor(vehicle.name as String, isOpen),
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => const Icon(
                  Icons.local_shipping,
                  color: AppColors.accentYellow,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name as String,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isSelected
                          ? AppColors.accentYellow
                          : AppColors.textLight,
                    ),
                  ),
                  Text(
                    (vehicle.description as String?) ?? '',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    isSelected ? '~19 mins away' : 'Available nearby',
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
                _ToggleBtn(
                  label: 'OPEN',
                  active: isOpen,
                  onTap: () => ref
                      .read(_bodyOpenProvider(vehicle.id as int).notifier)
                      .state = true,
                ),
                const SizedBox(height: 4),
                _ToggleBtn(
                  label: 'CLOSE',
                  active: !isOpen,
                  onTap: () => ref
                      .read(_bodyOpenProvider(vehicle.id as int).notifier)
                      .state = false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final _bodyOpenProvider =
    StateProvider.family<bool, int>((ref, id) => false);

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.accentYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? AppColors.accentYellow : AppColors.textHint,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active ? AppColors.backgroundDark : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

String _imageFor(String name, bool isOpen) {
  final n = name.toLowerCase();
  final suffix = isOpen ? 'open' : 'closed';
  if (n.contains('mini')) return 'assets/trucks/mini_${suffix}_truck.png';
  if (n.contains('small') || n.contains('van')) {
    return 'assets/trucks/small_${suffix}_truck.png';
  }
  if (n.contains('medium') || n.contains('tata') || n.contains('ace')) {
    return isOpen
        ? 'assets/trucks/meduim_open_truck.png'
        : 'assets/trucks/medium_closed_truck.png';
  }
  return isOpen
      ? 'assets/trucks/large_open_truck.png'
      : 'assets/trucks/large_closed_truck.png';
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Cargo type + weight
// ─────────────────────────────────────────────────────────────────────────────

class _Step2Cargo extends ConsumerWidget {
  final TextEditingController weightCtrl;
  const _Step2Cargo({required this.weightCtrl});

  static const _cargoMeta = {
    CargoType.industrial: (icon: Icons.settings_outlined, label: 'Industrial Goods'),
    CargoType.vegetables: (icon: Icons.eco_outlined, label: 'Vegetables & Fruits'),
    CargoType.household: (icon: Icons.home_outlined, label: 'Household Items'),
    CargoType.fragile: (icon: Icons.wine_bar_outlined, label: 'Fragile Goods'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(cargoTypeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What are you shipping?',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textHint, fontSize: 13)),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: CargoType.values.map((type) {
              final meta = _cargoMeta[type]!;
              final isSelected = selected == type;
              return GestureDetector(
                onTap: () =>
                    ref.read(cargoTypeProvider.notifier).state = type,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentYellow.withValues(alpha: 0.12)
                        : AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentYellow
                          : AppColors.textHint.withValues(alpha: 0.35),
                      width: isSelected ? 1.5 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(meta.icon,
                          color: isSelected
                              ? AppColors.accentYellow
                              : AppColors.textHint,
                          size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meta.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.accentYellow
                                : AppColors.textLight,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          Text('Cargo Weight (kg)',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: weightCtrl,
            keyboardType: TextInputType.number,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'e.g. 650',
              hintStyle: AppTextStyles.hintText,
              filled: true,
              fillColor: AppColors.backgroundDark,
              prefixIcon: const Icon(Icons.scale_outlined,
                  color: AppColors.textHint, size: 20),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.textHint.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.accentYellow, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Delivery receiver contact
// ─────────────────────────────────────────────────────────────────────────────

class _Step3Contact extends StatelessWidget {
  final TextEditingController mobileCtrl;
  final bool useOwn;
  final ValueChanged<bool> onToggleOwn;

  const _Step3Contact({
    required this.mobileCtrl,
    required this.useOwn,
    required this.onToggleOwn,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Delivery Receiver's Mobile",
              style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Enter the mobile number of the person receiving the delivery.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: mobileCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            enabled: !useOwn,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: '9xxxxxxxxx',
              hintStyle: AppTextStyles.hintText,
              counterText: '',
              filled: true,
              fillColor: AppColors.backgroundDark,
              prefixIcon: const Icon(Icons.phone_android_outlined,
                  color: AppColors.textHint, size: 20),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.textHint.withValues(alpha: 0.4)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.textHint.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.accentYellow, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Use registered number toggle
          GestureDetector(
            onTap: () => onToggleOwn(!useOwn),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: useOwn
                    ? AppColors.accentYellow.withValues(alpha: 0.12)
                    : AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: useOwn
                      ? AppColors.accentYellow
                      : AppColors.textHint.withValues(alpha: 0.35),
                  width: useOwn ? 1.5 : 0.8,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: useOwn
                          ? AppColors.accentYellow
                          : Colors.transparent,
                      border: Border.all(
                        color: useOwn
                            ? AppColors.accentYellow
                            : AppColors.textHint,
                        width: 1.5,
                      ),
                    ),
                    child: useOwn
                        ? const Icon(Icons.check,
                            size: 13,
                            color: AppColors.backgroundDark)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Use my registered mobile number',
                    style: TextStyle(
                      color: useOwn
                          ? AppColors.accentYellow
                          : AppColors.textLight,
                      fontSize: 14,
                      fontWeight: useOwn
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
