import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';

// ── Public API ───────────────────────────────────────────────────────────────

/// Shows the cargo type + weight bottom sheet.
/// Returns true if the user pressed NEXT, false/null if dismissed.
Future<bool> showCargoTypeSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _CargoTypeSheet(),
  );
  return result == true;
}

// ── Sheet widget ─────────────────────────────────────────────────────────────

class _CargoTypeSheet extends ConsumerStatefulWidget {
  const _CargoTypeSheet();

  @override
  ConsumerState<_CargoTypeSheet> createState() => _CargoTypeSheetState();
}

class _CargoTypeSheetState extends ConsumerState<_CargoTypeSheet> {
  final _weightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(cargoWeightProvider);
    if (existing.isNotEmpty) _weightCtrl.text = existing;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _onNext() {
    final selected = ref.read(cargoTypeProvider);
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cargo type')),
      );
      return;
    }
    ref.read(cargoWeightProvider.notifier).state = _weightCtrl.text.trim();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(cargoTypeProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title row
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: AppColors.accentYellow, size: 20),
              const SizedBox(width: 8),
              Text('Select Cargo Type', style: AppTextStyles.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textHint, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2×2 cargo type grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: CargoType.values
                .map((type) => _CargoTile(
                      type: type,
                      isSelected: selected == type,
                      onTap: () => ref
                          .read(cargoTypeProvider.notifier)
                          .state = type,
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),

          // Weight input
          Text('Cargo Weight (kg)',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _weightCtrl,
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),

          // NEXT button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                foregroundColor: AppColors.backgroundDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text('NEXT', style: AppTextStyles.labelButton),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual cargo tile ────────────────────────────────────────────────────

class _CargoTile extends StatelessWidget {
  final CargoType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _CargoTile({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  static const _meta = {
    CargoType.industrial: (
      icon: Icons.settings_outlined,
      label: 'Industrial Goods',
    ),
    CargoType.vegetables: (
      icon: Icons.eco_outlined,
      label: 'Vegetables & Fruits',
    ),
    CargoType.household: (
      icon: Icons.home_outlined,
      label: 'Household Items',
    ),
    CargoType.fragile: (
      icon: Icons.wine_bar_outlined,
      label: 'Fragile Goods',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _meta[type]!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            Icon(
              meta.icon,
              color: isSelected ? AppColors.accentYellow : AppColors.textHint,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                meta.label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.accentYellow
                      : AppColors.textLight,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
