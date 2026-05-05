import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';
import '../../providers/vehicle_provider.dart';

class LoadingUnloadingCard extends ConsumerWidget {
  const LoadingUnloadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLookupId = ref.watch(selectedLoadingLookupIdProvider);
    final labour = ref.watch(labourOptionProvider);
    final isOpen = ref.watch(selectedVehicleTypeIdProvider) == 1300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentYellow.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: AppColors.accentYellow,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Select helper for Loading/Unloading',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textLight,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (labour != null && labour != LabourOption.none)
                Text(
                  '+ charges apply',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accentYellow,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          Consumer(builder: (context, ref, _) {
            final loadingAsync = ref.watch(loadingTypesProvider);
            final items = loadingAsync.valueOrNull ?? const [];

            LabourOption toLabour(String code) {
              final c = code.toLowerCase();
              if (c == 'both' || c == 'all') return LabourOption.both;
              // Strip 'unload' then check if 'load' still remains → truly combined
              if (c.contains('unload') &&
                  c.replaceAll('unload', '').contains('load')) {
                return LabourOption.both;
              }
              if (c.contains('unload')) return LabourOption.unloading;
              if (c.contains('load')) return LabourOption.loading;
              return LabourOption.none;
            }

            String normalizeLabel(String raw) => raw
                .replaceAll(' And ', '/')
                .replaceAll(' and ', '/')
                .replaceAll(' AND ', '/');


            // Returns an icon builder function so _OptionChip can tint it correctly
            Widget Function(Color) iconBuilderFor(LabourOption opt) {
              switch (opt) {
                case LabourOption.loading:
                  final path = isOpen
                      ? 'assets/helper/loading_open.png'
                      : 'assets/helper/loading_closed.png';
                  return (color) => Image.asset(
                        path,
                        width: 22,
                        height: 22,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.upload_outlined, size: 16, color: color),
                      );
                case LabourOption.unloading:
                  final path = isOpen
                      ? 'assets/helper/unloading_open.png'
                      : 'assets/helper/unloading_closed.png';
                  return (color) => Image.asset(
                        path,
                        width: 22,
                        height: 22,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.download_outlined, size: 16, color: color),
                      );
                case LabourOption.both:
                  return (color) =>
                      Icon(Icons.swap_vert, size: 16, color: color);
                case LabourOption.none:
                  return (color) =>
                      Icon(Icons.do_not_disturb_alt_outlined, size: 16, color: color);
              }
            }

            void select(int lookupId, LabourOption labour) {
              ref.read(labourOptionProvider.notifier).state = labour;
              ref.read(selectedLoadingLookupIdProvider.notifier).state = lookupId;
            }

            final chips = items.isNotEmpty
                ? items.map((item) {
                    final labour = toLabour(item.code);
                    return _OptionChip(
                      label: normalizeLabel(item.description ?? item.code),
                      iconBuilder: iconBuilderFor(labour),
                      isSelected: selectedLookupId == item.id,
                      onTap: () => select(item.id, labour),
                    );
                  }).toList()
                : [
                    _OptionChip(
                      label: 'None',
                      iconBuilder: iconBuilderFor(LabourOption.none),
                      isSelected: selectedLookupId == 0,
                      onTap: () => select(0, LabourOption.none),
                    ),
                    _OptionChip(
                      label: 'Load',
                      iconBuilder: iconBuilderFor(LabourOption.loading),
                      isSelected: selectedLookupId == 1,
                      onTap: () => select(1, LabourOption.loading),
                    ),
                    _OptionChip(
                      label: 'Unload',
                      iconBuilder: iconBuilderFor(LabourOption.unloading),
                      isSelected: selectedLookupId == 2,
                      onTap: () => select(2, LabourOption.unloading),
                    ),
                    _OptionChip(
                      label: 'All',
                      iconBuilder: iconBuilderFor(LabourOption.both),
                      isSelected: selectedLookupId == 3,
                      onTap: () => select(3, LabourOption.both),
                    ),
                  ];

            return Row(
              children: chips
                  .expand((chip) => [chip, const SizedBox(width: 6)])
                  .toList()
                ..removeLast(),
            );
          }),
        ],
      ),
    );
  }


}

// ─────────────────────────────────────────────────────────────────────────────

class _OptionChip extends StatelessWidget {
  final String label;
  final Widget Function(Color iconColor) iconBuilder;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.iconBuilder,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isSelected ? AppColors.backgroundDark : AppColors.textHint;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentYellow : AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentYellow
                  : AppColors.textHint.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconBuilder(iconColor),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.backgroundDark
                      : AppColors.textHint,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
