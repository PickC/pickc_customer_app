import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';
import '../../providers/vehicle_provider.dart';

/// First card in the truck sheet — lets the customer choose whether
/// they need labour help for loading / unloading.
class LoadingUnloadingCard extends ConsumerWidget {
  const LoadingUnloadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(labourOptionProvider);

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
                'Do you need Labour?',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (selected != LabourOption.none)
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
          // Fetch loading types from API so the correct lookupID is sent in the booking payload.
          // Falls back to hardcoded labels/indices if the API is unavailable.
          Consumer(builder: (context, ref, _) {
            final loadingAsync = ref.watch(loadingTypesProvider);
            final items = loadingAsync.valueOrNull ?? const [];

            // Map API items to LabourOption by matching the code name (case-insensitive)
            LabourOption toLabour(String code) {
              final c = code.toLowerCase();
              if (c == 'both' || c == 'all') return LabourOption.both;
              if (c.contains('load') && c.contains('un')) return LabourOption.both;
              if (c.contains('unload')) return LabourOption.unloading;
              if (c.contains('load')) return LabourOption.loading;
              return LabourOption.none;
            }

            IconData iconFor(LabourOption opt) {
              switch (opt) {
                case LabourOption.none:      return Icons.do_not_disturb_alt_outlined;
                case LabourOption.loading:   return Icons.upload_outlined;
                case LabourOption.unloading: return Icons.download_outlined;
                case LabourOption.both:      return Icons.swap_vert;
              }
            }

            void select(int lookupId, LabourOption labour) {
              ref.read(labourOptionProvider.notifier).state = labour;
              ref.read(selectedLoadingLookupIdProvider.notifier).state = lookupId;
            }

            // If API returned items, use them; otherwise fall back to the four hardcoded options
            final chips = items.isNotEmpty
                ? items.map((item) {
                    final labour = toLabour(item.code);
                    return _OptionChip(
                      label: item.code,
                      icon: iconFor(labour),
                      isSelected: selected == labour,
                      onTap: () => select(item.id, labour),
                    );
                  }).toList()
                : [
                    _OptionChip(label: 'None',      icon: Icons.do_not_disturb_alt_outlined, isSelected: selected == LabourOption.none,      onTap: () => select(0, LabourOption.none)),
                    _OptionChip(label: 'Loading',   icon: Icons.upload_outlined,             isSelected: selected == LabourOption.loading,   onTap: () => select(1, LabourOption.loading)),
                    _OptionChip(label: 'Unloading', icon: Icons.download_outlined,           isSelected: selected == LabourOption.unloading, onTap: () => select(2, LabourOption.unloading)),
                    _OptionChip(label: 'Both',      icon: Icons.swap_vert,                   isSelected: selected == LabourOption.both,      onTap: () => select(3, LabourOption.both)),
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

class _OptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentYellow
                : AppColors.backgroundDark,
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
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.backgroundDark
                    : AppColors.textHint,
              ),
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
